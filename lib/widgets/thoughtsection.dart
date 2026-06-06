import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:aaram_bd/config.dart';
import 'package:aaram_bd/localization/app_localizations.dart';
import 'package:aaram_bd/localization/language_provider.dart';
import 'package:aaram_bd/screens/thoughtdetails.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

Color getColorFromCategory(String name) {
  const colors = [
    Color(0xFF5B8DEF),
    Color(0xFF43C6A3),
    Color(0xFF9B59B6),
    Color(0xFFE67E22),
    Color(0xFFE74C3C),
    Color(0xFF1ABC9C),
    Color(0xFFD63384),
  ];
  final idx = name.codeUnits.fold(0, (prev, code) => prev + code) % colors.length;
  return colors[idx];
}

// ─── Models ──────────────────────────────────────────────────────────────────

class NeedOption {
  final int id;
  final String text;

  const NeedOption({required this.id, required this.text});

  factory NeedOption.fromJson(Map<String, dynamic> json) => NeedOption(
        id: (json['id'] as num? ?? 0).toInt(),
        text: (json['text'] ?? json['option_text'] ?? '').toString(),
      );
}

// Backend is source of truth; fromJson maps the API response.
class NeedLayer {
  final int layerId;
  final int layerNo;
  final String titleBn;
  final String subtitleBn;
  final String inputType; // chips | search | bottom_sheet
  final int maxVisibleOptions;
  final List<NeedOption> options;
  final bool hasMore;

  const NeedLayer({
    this.layerId = 0,
    required this.layerNo,
    required this.titleBn,
    this.subtitleBn = '',
    this.inputType = 'chips',
    this.maxVisibleOptions = 10,
    required this.options,
    this.hasMore = false,
  });

  factory NeedLayer.fromJson(Map<String, dynamic> json) {
    final raw = (json['options'] as List? ?? []);
    return NeedLayer(
      layerId: (json['layer_id'] as num? ?? 0).toInt(),
      layerNo: (json['layer_no'] as num).toInt(),
      titleBn: (json['title_bn'] ?? json['title'] ?? '').toString(),
      subtitleBn: (json['subtitle_bn'] ?? json['subtitle'] ?? '').toString(),
      inputType: (json['input_type'] ?? 'chips').toString(),
      maxVisibleOptions: (json['max_visible_options'] as num? ?? 10).toInt(),
      options: raw
          .map<NeedOption>((o) => NeedOption.fromJson(o as Map<String, dynamic>))
          .toList(),
      hasMore: json['has_more'] == true,
    );
  }
}

// ─── Page ─────────────────────────────────────────────────────────────────────

class NeedBuilderPage extends StatefulWidget {
  const NeedBuilderPage({super.key});

  @override
  State<NeedBuilderPage> createState() => _NeedBuilderPageState();
}

class _NeedBuilderPageState extends State<NeedBuilderPage>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollCtrl = ScrollController();
  final TextEditingController _noteCtrl = TextEditingController();
  final GlobalKey _composerKey = GlobalKey();

  List<Map<String, dynamic>> descriptions = [];
  List<Map<String, dynamic>> categories = [];

  bool isLoading = false;
  bool _isPosting = false;
  bool _catPanelExpanded = false;

  String? selectedCatId;
  XFile? _pickedPhoto;

  final Map<int, String> _selectedLayers = {};
  final Map<String, bool> _expandedMap = {};

  List<NeedLayer> _layers = [];
  bool _layersLoading = false;

  late final AnimationController _catAnimCtrl;
  late final Animation<double> _catAnim;

  AppLocalizations get _l10n =>
      Provider.of<LanguageProvider>(context, listen: false).l10n;

  NeedLayer? get _activeLayer {
    for (final layer in _layers) {
      if (!_selectedLayers.containsKey(layer.layerNo)) return layer;
    }
    return null;
  }

  bool get _isComposerComplete => _layers.isNotEmpty && _activeLayer == null;
  bool get _allLayersSelected => _isComposerComplete;

  String get _generatedNeedText {
    final words = <String>[];
    for (final layer in _layers) {
      final v = _selectedLayers[layer.layerNo];
      if (v != null && v.trim().isNotEmpty) words.add(v.trim());
    }
    if (words.isEmpty) return '';
    final s = words.join(' ');
    return s.endsWith('।') ? s : '$s।';
  }

  @override
  void initState() {
    super.initState();
    _catAnimCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 240));
    _catAnim = CurvedAnimation(parent: _catAnimCtrl, curve: Curves.easeInOut);
    _fetchCategories();
    _loadDescriptions();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _noteCtrl.dispose();
    _catAnimCtrl.dispose();
    super.dispose();
  }

  // ─── Data ──────────────────────────────────────────────────────────────────

  Future<void> _fetchCategories() async {
    final resp = await Config.apiGet('/get_description_categories', context);
    if (resp != null && resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      if (!mounted) return;
      setState(() {
        categories =
            List<Map<String, dynamic>>.from(data['categories'] ?? []);
      });
    }
  }

  Future<void> _loadDescriptions() async {
    setState(() => isLoading = true);
    final userId = await Config.getLoggedInUser();
    if (userId == null) {
      if (mounted) setState(() => isLoading = false);
      return;
    }
    final resp =
        await Config.apiGet('/get_user_description?user_id=$userId', context);
    if (resp != null && resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      if (!mounted) return;
      setState(() {
        descriptions =
            List<Map<String, dynamic>>.from(data['descriptions'] ?? []);
      });
    }
    if (mounted) setState(() => isLoading = false);
  }

  Future<void> _fetchSuggestionLayers(String desCatId) async {
    if (!mounted) return;
    setState(() {
      _layersLoading = true;
      _layers = [];
      _selectedLayers.clear();
    });
    try {
      final resp = await Config.apiGet(
          '/get_need_suggestion_layers?des_cat_id=$desCatId', context);
      if (!mounted) return;
      if (resp != null && resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          final List raw = data['layers'] ?? [];
          setState(() {
            _layers = raw
                .map((l) => NeedLayer.fromJson(l as Map<String, dynamic>))
                .toList();
            _layersLoading = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('_fetchSuggestionLayers: $e');
    }
    if (!mounted) return;
    setState(() {
      _layers = _fallbackLayers();
      _layersLoading = false;
    });
  }

  List<NeedLayer> _fallbackLayers() => const [
        NeedLayer(
          layerNo: 1,
          titleBn: 'কার জন্য?',
          subtitleBn: 'প্রয়োজনটি কার তা জানান',
          options: [
            NeedOption(id: 1, text: 'আমি'),
            NeedOption(id: 2, text: 'আমার'),
            NeedOption(id: 3, text: 'আমাদের'),
            NeedOption(id: 4, text: 'আমার বাসায়'),
            NeedOption(id: 5, text: 'আমার অফিসে'),
          ],
        ),
        NeedLayer(
          layerNo: 2,
          titleBn: 'কী ধরনের চাহিদা?',
          subtitleBn: 'চাহিদার ধরন নির্বাচন করুন',
          options: [
            NeedOption(id: 1, text: 'দরকার'),
            NeedOption(id: 2, text: 'চাই'),
            NeedOption(id: 3, text: 'খুঁজছি'),
            NeedOption(id: 4, text: 'জরুরি দরকার'),
            NeedOption(id: 5, text: 'সাহায্য দরকার'),
          ],
        ),
        NeedLayer(
          layerNo: 3,
          titleBn: 'কোন সেবা?',
          subtitleBn: 'প্রয়োজনীয় সেবা নির্বাচন করুন',
          options: [
            NeedOption(id: 1, text: 'একজন সার্ভিস প্রোভাইডার'),
            NeedOption(id: 2, text: 'মেরামত সেবা'),
            NeedOption(id: 3, text: 'হোম সার্ভিস'),
            NeedOption(id: 4, text: 'পরামর্শ'),
            NeedOption(id: 5, text: 'জরুরি সেবা'),
          ],
        ),
        NeedLayer(
          layerNo: 4,
          titleBn: 'কখন?',
          subtitleBn: 'সময় বা জরুরিতা নির্বাচন করুন',
          options: [
            NeedOption(id: 1, text: 'আজ'),
            NeedOption(id: 2, text: 'এখনই'),
            NeedOption(id: 3, text: 'জরুরি'),
            NeedOption(id: 4, text: 'দ্রুত'),
            NeedOption(id: 5, text: 'আগামীকাল'),
          ],
        ),
        NeedLayer(
          layerNo: 5,
          titleBn: 'কোথায়?',
          subtitleBn: 'লোকেশন বা পদ্ধতি নির্বাচন করুন',
          options: [
            NeedOption(id: 1, text: 'বাসায়'),
            NeedOption(id: 2, text: 'অফিসে'),
            NeedOption(id: 3, text: 'নিকটে'),
            NeedOption(id: 4, text: 'ঢাকায়'),
            NeedOption(id: 5, text: 'অনলাইনে'),
          ],
        ),
      ];

  Future<void> _pickPhoto() async {
    final photo = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (photo != null) setState(() => _pickedPhoto = photo);
  }

  Future<void> _addNeedPost() async {
    if (selectedCatId == null) {
      _showSnack('আগে একটি ক্যাটাগরি নির্বাচন করুন');
      return;
    }
    if (!_allLayersSelected) {
      _showSnack('পোস্ট করার আগে সব ধাপ সম্পন্ন করুন');
      return;
    }
    setState(() => _isPosting = true);
    final userId = await Config.getLoggedInUser() ?? '';
    final fields = {
      'user_id': userId,
      'des_cat_id': selectedCatId!,
      'description': _generatedNeedText,
      'special_note': _noteCtrl.text.trim(),
      'status': 'live',
      'layer_1': _selectedLayers[1] ?? '',
      'layer_2': _selectedLayers[2] ?? '',
      'layer_3': _selectedLayers[3] ?? '',
      'layer_4': _selectedLayers[4] ?? '',
      'layer_5': _selectedLayers[5] ?? '',
    };
    Map<String, File>? files;
    if (_pickedPhoto != null) {
      final compressed =
          await Config.compressImageIfNeeded(File(_pickedPhoto!.path));
      files = {'des_photo': compressed};
    }
    if (!mounted) return;
    final resp = await Config.apiMultipartPost(
        '/update_user_description', context,
        fields: fields, files: files);
    if (!mounted) return;
    setState(() => _isPosting = false);
    if (resp != null) {
      final body = await resp.stream.bytesToString();
      final data = jsonDecode(body);
      _showSnack(data['message'] ?? 'Need posted');
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        _resetComposer();
        await _loadDescriptions();
      }
    }
  }

  void _resetComposer() {
    setState(() {
      _selectedLayers.clear();
      _noteCtrl.clear();
      _pickedPhoto = null;
    });
  }

  // Selects an option for a layer and clears all downstream selections.
  void _selectLayerOption(NeedLayer layer, NeedOption option) {
    setState(() {
      _selectedLayers[layer.layerNo] = option.text;
      _selectedLayers.removeWhere((key, _) => key > layer.layerNo);
    });
  }

  void _goBackOneLayer() {
    if (_selectedLayers.isEmpty) return;
    final lastKey = _selectedLayers.keys.reduce((a, b) => a > b ? a : b);
    setState(() => _selectedLayers.remove(lastKey));
  }

  void _resetLayers() => setState(() => _selectedLayers.clear());

  Future<void> _changeStatus(String desId, String newStatus) async {
    final resp = await Config.apiPost('/change_description_status', {
      'des_id': desId,
      'status': newStatus,
    }, context);
    if (resp == null) {
      _showSnack('Status API এখনো কানেক্ট করা নেই');
      return;
    }
    final data = jsonDecode(resp.body);
    _showSnack(data['message'] ?? 'Status updated');
    if (resp.statusCode == 200) await _loadDescriptions();
  }

  Future<void> _confirmDelete(String desId) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('পোস্ট ডিলিট করবেন?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text(
            'এই need post ডিলিট করলে পরে আর দেখা যাবে না।'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('না')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('ডিলিট'),
          ),
        ],
      ),
    );
    if (yes == true) await _deleteDescription(desId);
  }

  Future<void> _deleteDescription(String desId) async {
    final resp = await Config.apiPost(
        '/delete_user_description', {'des_id': desId}, context);
    if (resp == null) return;
    final data = jsonDecode(resp.body);
    _showSnack(data['message'] ?? 'No response');
    if (resp.statusCode == 200 && data['success'] == true) {
      _expandedMap.remove(desId);
      await _loadDescriptions();
    }
  }

  void _showSnack(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: color,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  // ─── Decorations ───────────────────────────────────────────────────────────

  BoxDecoration get _cardDeco => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
              color: Color(0x10000000), blurRadius: 18, offset: Offset(0, 6)),
        ],
      );

  BoxDecoration get _softBlueDeco => BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEFF4FF), Color(0xFFF8FBFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDDE8FF)),
      );

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LanguageProvider>().l10n;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F3F8),
      appBar: AppBar(
        title: const Text('Need Builder',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A2340),
        surfaceTintColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFEAEDF2)),
        ),
      ),
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollCtrl,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverToBoxAdapter(child: _buildCategoryPanel(l10n)),
            SliverToBoxAdapter(child: _buildNeedComposer()),
            const SliverToBoxAdapter(child: SizedBox(height: 18)),
            SliverToBoxAdapter(child: _buildMyPostsHeader()),
            if (isLoading)
              _buildLoadingSliver()
            else if (descriptions.isEmpty)
              _buildEmptySliver()
            else
              SliverList.separated(
                itemCount: descriptions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _buildPostCard(descriptions[i]),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
          ],
        ),
      ),
    );
  }

  // ─── Category Panel ────────────────────────────────────────────────────────

  Widget _buildCategoryPanel(AppLocalizations l10n) {
    final selectedCat = categories.firstWhere(
      (c) => (c['des_cat_id'] ?? '').toString() == selectedCatId,
      orElse: () => {},
    );
    final selName = (selectedCat['des_cat_name'] ?? '').toString();
    final selColor = selName.isNotEmpty
        ? getColorFromCategory(selName)
        : const Color(0xFF86A8E7);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Container(
        decoration: _cardDeco,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () {
                setState(() => _catPanelExpanded = !_catPanelExpanded);
                _catPanelExpanded
                    ? _catAnimCtrl.forward()
                    : _catAnimCtrl.reverse();
              },
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                          color: const Color(0xFFEFF4FF),
                          borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.category_outlined,
                          color: Color(0xFF5B8DEF), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Need Category',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: Color(0xFF4A5568))),
                          const SizedBox(height: 3),
                          Text(
                            selName.isNotEmpty
                                ? selName
                                : 'ক্যাটাগরি নির্বাচন করুন',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: selName.isNotEmpty
                                    ? selColor
                                    : const Color(0xFFB0B7C3)),
                          ),
                        ],
                      ),
                    ),
                    if (selName.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                            color: selColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999)),
                        child: Text('Selected',
                            style: TextStyle(
                                color: selColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w800)),
                      ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: _catPanelExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 240),
                      child: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: Color(0xFF8A94A6)),
                    ),
                  ],
                ),
              ),
            ),
            SizeTransition(
              sizeFactor: _catAnim,
              child: Column(
                children: [
                  const Divider(height: 1, color: Color(0xFFF0F3F8)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
                    child: categories.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: Center(
                                child: Text('ক্যাটাগরি লোড হচ্ছে...',
                                    style:
                                        TextStyle(color: Color(0xFFB0B7C3)))),
                          )
                        : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: categories.map((cat) {
                              final name =
                                  (cat['des_cat_name'] ?? '').toString();
                              final id =
                                  (cat['des_cat_id'] ?? '').toString();
                              final sel = selectedCatId == id;
                              final col = getColorFromCategory(name);
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    selectedCatId = id;
                                    _selectedLayers.clear();
                                    _noteCtrl.clear();
                                    _catPanelExpanded = false;
                                  });
                                  _catAnimCtrl.reverse();
                                  _fetchSuggestionLayers(id);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: sel
                                        ? col
                                        : col.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                        color: sel
                                            ? col
                                            : col.withValues(alpha: 0.25),
                                        width: sel ? 1.5 : 1),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (sel) ...[
                                        const Icon(Icons.check_rounded,
                                            size: 14, color: Colors.white),
                                        const SizedBox(width: 4),
                                      ],
                                      Text(
                                        name,
                                        style: TextStyle(
                                          color: sel
                                              ? Colors.white
                                              : col.withValues(alpha: 0.9),
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Need Composer ─────────────────────────────────────────────────────────

  Widget _buildNeedComposer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
      child: Container(
        key: _composerKey,
        decoration: _cardDeco,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _composerHeader(),
            if (selectedCatId == null)
              _buildLockedStartBox()
            else if (_layersLoading)
              _buildLayersLoadingBox()
            else if (_layers.isEmpty)
              _buildLayersEmptyBox()
            else ...[
              _buildSentencePreview(),
              if (_selectedLayers.isNotEmpty) _buildSelectedChips(),
              const Divider(height: 1, thickness: 1, color: Color(0xFFF0F3F8)),
              _buildStepTimeline(),
              _isComposerComplete
                  ? _buildCompletionSection()
                  : _buildActiveLayer(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _composerHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: const Color(0xFFEFF4FF),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.auto_awesome_rounded,
                color: Color(0xFF5B8DEF), size: 18),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Need Sentence Builder',
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14.5,
                        color: Color(0xFF1A2340))),
                Text('৫ ধাপে আপনার প্রয়োজন তৈরি করুন',
                    style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF8A94A6),
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (selectedCatId != null && _layers.isNotEmpty) ...[
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _isComposerComplete
                    ? const Color(0xFF43C6A3).withValues(alpha: 0.12)
                    : const Color(0xFFEFF4FF),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${_selectedLayers.length}/${_layers.length}',
                style: TextStyle(
                  color: _isComposerComplete
                      ? const Color(0xFF2EB88A)
                      : const Color(0xFF3A6BD4),
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
            if (_selectedLayers.isNotEmpty) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _resetLayers,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFFF0F0),
                      borderRadius: BorderRadius.circular(999)),
                  child: const Text('Reset',
                      style: TextStyle(
                          color: Color(0xFFAA4444),
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5)),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildLockedStartBox() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      child: Container(
        decoration: _softBlueDeco,
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
        child: const Column(
          children: [
            Icon(Icons.lock_open_rounded, size: 36, color: Color(0xFF5B8DEF)),
            SizedBox(height: 10),
            Text('আগে ক্যাটাগরি নির্বাচন করুন',
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15.5,
                    color: Color(0xFF1A2340))),
            SizedBox(height: 4),
            Text('ক্যাটাগরি অনুযায়ী সাজেশন দেখানো হবে',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Color(0xFF6B7280), height: 1.4, fontSize: 13.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildLayersLoadingBox() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: Color(0xFF5B8DEF))),
          SizedBox(height: 10),
          Text('সাজেশন লোড হচ্ছে...',
              style: TextStyle(
                  color: Color(0xFF8A94A6),
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildLayersEmptyBox() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: const Color(0xFFFFFBEA),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFFE0A3))),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded,
                color: Color(0xFFD97706), size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('এই ক্যাটাগরির জন্য সাজেশন পাওয়া যায়নি।',
                  style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF92400E),
                      fontWeight: FontWeight.w600)),
            ),
            GestureDetector(
              onTap: () {
                if (selectedCatId != null) {
                  _fetchSuggestionLayers(selectedCatId!);
                }
              },
              child: const Text('Retry',
                  style: TextStyle(
                      color: Color(0xFFD97706),
                      fontWeight: FontWeight.w900,
                      fontSize: 12.5)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSentencePreview() {
    final text = _generatedNeedText;
    final hasText = text.isNotEmpty;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: hasText ? const Color(0xFF101828) : const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: hasText
                ? const Color(0xFF1D2939)
                : const Color(0xFFE8EDF5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.format_quote_rounded,
              size: 16,
              color: hasText
                  ? Colors.white.withValues(alpha: 0.35)
                  : const Color(0xFFD1D5DB)),
          const SizedBox(width: 8),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Text(
                hasText
                    ? text
                    : '৫ ধাপে শব্দ নির্বাচন করলে এখানে need sentence তৈরি হবে...',
                key: ValueKey(text),
                style: TextStyle(
                  color: hasText ? Colors.white : const Color(0xFF9CA3AF),
                  fontWeight:
                      hasText ? FontWeight.w700 : FontWeight.w500,
                  fontSize: hasText ? 15 : 13.5,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final layer in _layers)
              if (_selectedLayers.containsKey(layer.layerNo))
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF43C6A3).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: const Color(0xFF43C6A3)
                              .withValues(alpha: 0.28)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 8,
                          backgroundColor: const Color(0xFF43C6A3)
                              .withValues(alpha: 0.18),
                          child: Text('${layer.layerNo}',
                              style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF2EB88A))),
                        ),
                        const SizedBox(width: 5),
                        Text(_selectedLayers[layer.layerNo]!,
                            style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0D6B4E))),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepTimeline() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: Row(
        children: [
          for (int i = 0; i < _layers.length; i++) ...[
            if (i > 0) const SizedBox(width: 5),
            Expanded(
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    height: 4,
                    decoration: BoxDecoration(
                      color: _selectedLayers
                              .containsKey(_layers[i].layerNo)
                          ? const Color(0xFF43C6A3)
                          : _layers[i] == _activeLayer
                              ? const Color(0xFF5B8DEF)
                              : const Color(0xFFE4E9F2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      color: _selectedLayers
                              .containsKey(_layers[i].layerNo)
                          ? const Color(0xFF43C6A3)
                          : _layers[i] == _activeLayer
                              ? const Color(0xFF5B8DEF)
                              : const Color(0xFFBEC4CF),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Active Layer ──────────────────────────────────────────────────────────

  Widget _buildActiveLayer() {
    final layer = _activeLayer;
    if (layer == null) return const SizedBox.shrink();

    // Show partial chips + "see all" when backend signals more options exist
    // or when the input_type is explicitly search/bottom_sheet.
    final needsSeeAll = layer.hasMore ||
        layer.inputType == 'search' ||
        layer.inputType == 'bottom_sheet';
    final visibleOpts = needsSeeAll
        ? layer.options.take(layer.maxVisibleOptions).toList()
        : layer.options;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row + back button
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(layer.titleBn,
                        style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                            color: Color(0xFF1A2340))),
                    if (layer.subtitleBn.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(layer.subtitleBn,
                          style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF8A94A6),
                              fontWeight: FontWeight.w600)),
                    ],
                  ],
                ),
              ),
              if (_selectedLayers.isNotEmpty) ...[
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _goBackOneLayer,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 11, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F9FC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE4E9F2)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back_ios_rounded,
                            size: 11, color: Color(0xFF4A5568)),
                        SizedBox(width: 3),
                        Text('Back',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF4A5568))),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),

          // "Popular suggestions" label — shown only when truncated
          if (needsSeeAll && visibleOpts.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'জনপ্রিয় সাজেশন:',
                style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8A94A6),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2),
              ),
            ),

          // Option chips
          if (visibleOpts.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  visibleOpts.map((opt) => _optionChip(layer, opt)).toList(),
            ),

          // "See all" button
          if (needsSeeAll) ...[
            const SizedBox(height: 12),
            _buildSeeAllButton(layer),
          ],
        ],
      ),
    );
  }

  Widget _optionChip(NeedLayer layer, NeedOption opt) {
    return GestureDetector(
      onTap: () => _selectLayerOption(layer, opt),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFDDE3EF), width: 1.5),
          boxShadow: const [
            BoxShadow(
                color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2))
          ],
        ),
        child: Text(opt.text,
            style: const TextStyle(
                color: Color(0xFF1A2340),
                fontWeight: FontWeight.w700,
                fontSize: 14)),
      ),
    );
  }

  Widget _buildSeeAllButton(NeedLayer layer) {
    return GestureDetector(
      onTap: () => _openLayerOptionsSheet(layer),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF5B8DEF), Color(0xFF3A6BD4)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          children: [
            Icon(Icons.search_rounded, color: Colors.white, size: 17),
            SizedBox(width: 8),
            Text('সব সাজেশন দেখুন',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5)),
            Spacer(),
            Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white70, size: 13),
          ],
        ),
      ),
    );
  }

  Future<void> _openLayerOptionsSheet(NeedLayer layer) async {
    final selected = await showModalBottomSheet<NeedOption>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LayerOptionsSheet(layer: layer),
    );
    if (selected != null && mounted) {
      _selectLayerOption(layer, selected);
    }
  }

  // ─── Completion Section ────────────────────────────────────────────────────

  Widget _buildCompletionSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFFE8FFF4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFF43C6A3).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF2EB88A), size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Need sentence তৈরি হয়েছে!',
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13.5,
                          color: Color(0xFF0D5939))),
                ),
                GestureDetector(
                  onTap: _resetLayers,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                        color: const Color(0xFF43C6A3)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Text('নতুন করুন',
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF168A60))),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildSpecialNoteField(),
          const SizedBox(height: 12),
          _buildPhotoSection(),
          const SizedBox(height: 14),
          _buildPostButton(),
        ],
      ),
    );
  }

  Widget _buildSpecialNoteField() {
    return TextField(
      controller: _noteCtrl,
      minLines: 3,
      maxLines: 5,
      style: const TextStyle(
          fontSize: 15, height: 1.45, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: 'Special Note',
        hintText: 'অতিরিক্ত তথ্য লিখুন (ঐচ্ছিক)',
        alignLabelWithHint: true,
        filled: true,
        fillColor: const Color(0xFFF7F9FC),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE8EDF5))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE8EDF5))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:
                const BorderSide(color: Color(0xFF5B8DEF), width: 1.5)),
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: _pickPhoto,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: const Color(0xFFF8FAFD),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE8EDF5))),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                      color: const Color(0xFFEFF4FF),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.image_outlined,
                      color: Color(0xFF5B8DEF)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _pickedPhoto == null
                        ? 'Problem photo যোগ করুন'
                        : 'Photo selected',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF4A5568)),
                  ),
                ),
                const Icon(Icons.add_photo_alternate_rounded,
                    color: Color(0xFF8A94A6)),
              ],
            ),
          ),
        ),
        if (_pickedPhoto != null) ...[
          const SizedBox(height: 10),
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(File(_pickedPhoto!.path),
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => setState(() => _pickedPhoto = null),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: Colors.black54),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 17),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildPostButton() {
    final enabled = _allLayersSelected && !_isPosting;
    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        icon: _isPosting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.campaign_rounded, size: 19),
        label: Text(_isPosting ? 'Posting...' : 'Post Need',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
        onPressed: enabled ? _addNeedPost : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF5B8DEF),
          disabledBackgroundColor: const Color(0xFFD3DAE8),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  // ─── My Posts ──────────────────────────────────────────────────────────────

  Widget _buildMyPostsHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          const Icon(Icons.format_list_bulleted_rounded,
              size: 17, color: Color(0xFF86A8E7)),
          const SizedBox(width: 6),
          Text('My Need Posts (${descriptions.length})',
              style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13.5,
                  color: Color(0xFF4A5568))),
        ],
      ),
    );
  }

  SliverFillRemaining _buildLoadingSliver() {
    return const SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: EdgeInsets.only(bottom: 70),
          child: CircularProgressIndicator(
              color: Color(0xFF5B8DEF), strokeWidth: 3),
        ),
      ),
    );
  }

  SliverFillRemaining _buildEmptySliver() {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 60),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: const BoxDecoration(
                    color: Color(0xFFEFF4FF), shape: BoxShape.circle),
                child: const Icon(Icons.campaign_rounded,
                    size: 42, color: Color(0xFF5B8DEF)),
              ),
              const SizedBox(height: 16),
              const Text('এখনো কোনো need post নেই',
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: Color(0xFF2B3A55))),
              const SizedBox(height: 6),
              const Text('উপরে ৫ ধাপে আপনার প্রয়োজন তৈরি করুন',
                  style: TextStyle(color: Color(0xFF8A94A6), fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> item) {
    final des = (item['des'] ?? item['description'] ?? '').toString();
    final note = (item['special_note'] ?? '').toString();
    final catName = (item['des_cat_name'] ?? '').toString();
    final time = (item['time'] ?? '').toString();
    final views = (item['des_view'] ?? 0).toString();
    final photoUrl = item['des_photo']?.toString() ?? '';
    final desId = item['des_id'].toString();
    final status = (item['status'] ?? 'live').toString().toLowerCase();
    final isLive = status != 'dead';
    final accent = getColorFromCategory(catName);
    final isExpanded = _expandedMap[desId] ?? false;

    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => ThoughtDetails(desId: desId))),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
        child: Container(
          decoration: _cardDeco,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 5,
                decoration: BoxDecoration(
                  color: isLive
                      ? const Color(0xFF43C6A3)
                      : const Color(0xFFAA4444),
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                  color: accent.withValues(alpha: 0.2))),
                          child: Text(catName,
                              style: TextStyle(
                                  color: accent,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12)),
                        ),
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                              color: isLive
                                  ? const Color(0xFFE8FFF4)
                                  : const Color(0xFFFFF0F0),
                              borderRadius: BorderRadius.circular(999)),
                          child: Text(
                            isLive ? 'LIVE' : 'DEAD',
                            style: TextStyle(
                                color: isLive
                                    ? const Color(0xFF168A60)
                                    : const Color(0xFFAA4444),
                                fontWeight: FontWeight.w900,
                                fontSize: 11),
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.access_time_rounded,
                            size: 13, color: Colors.grey.shade400),
                        const SizedBox(width: 3),
                        Text(Config.getTimeDifference(time),
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 11),
                    Text(
                      des,
                      maxLines: isExpanded ? null : 4,
                      overflow: isExpanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15.5,
                          height: 1.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A2340)),
                    ),
                    if (note.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                            color: const Color(0xFFF7F9FC),
                            borderRadius: BorderRadius.circular(14),
                            border:
                                Border.all(color: const Color(0xFFE8EDF5))),
                        child: Text(note,
                            style: const TextStyle(
                                fontSize: 14,
                                height: 1.45,
                                color: Color(0xFF4A5568),
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                    if (des.length > 120 || note.length > 120) ...[
                      const SizedBox(height: 5),
                      GestureDetector(
                        onTap: () => setState(
                            () => _expandedMap[desId] = !isExpanded),
                        child: Text(
                            isExpanded ? 'See less' : 'See more',
                            style: TextStyle(
                                color: accent,
                                fontWeight: FontWeight.w800,
                                fontSize: 13)),
                      ),
                    ],
                    if (photoUrl.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          photoUrl,
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 90,
                            color: Colors.grey.shade100,
                            child: const Center(
                                child: Icon(Icons.broken_image_rounded,
                                    color: Colors.grey)),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.visibility_rounded,
                            size: 15, color: Colors.grey.shade400),
                        const SizedBox(width: 4),
                        Text('$views বার দেখা হয়েছে',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w700)),
                        const Spacer(),
                        _smallActionButton(
                          label: isLive ? 'Mark Dead' : 'Make Live',
                          color: isLive
                              ? const Color(0xFFD0703A)
                              : const Color(0xFF30A882),
                          onTap: () => _changeStatus(
                              desId, isLive ? 'dead' : 'live'),
                        ),
                        const SizedBox(width: 6),
                        _smallActionButton(
                          label: 'Delete',
                          color: const Color(0xFFAA4444),
                          onTap: () => _confirmDelete(desId),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _smallActionButton(
      {required String label,
      required Color color,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: color.withValues(alpha: 0.22))),
        child: Text(label,
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                color: color)),
      ),
    );
  }
}

// ─── Layer Options Bottom Sheet ───────────────────────────────────────────────

class _LayerOptionsSheet extends StatefulWidget {
  final NeedLayer layer;

  const _LayerOptionsSheet({required this.layer});

  @override
  State<_LayerOptionsSheet> createState() => _LayerOptionsSheetState();
}

class _LayerOptionsSheetState extends State<_LayerOptionsSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _listScrollCtrl = ScrollController();

  List<NeedOption> _options = [];
  bool _loading = false;
  bool _hasMore = false;
  int _currentPage = 1;
  bool _isFetchingMore = false;
  Timer? _debounce;

  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    // Seed with the popular options that came with the layer response.
    _options = List<NeedOption>.from(widget.layer.options);
    _hasMore = widget.layer.hasMore;
    _listScrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _listScrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_listScrollCtrl.position.pixels >=
            _listScrollCtrl.position.maxScrollExtent - 120 &&
        !_loading &&
        !_isFetchingMore &&
        _hasMore) {
      _loadNextPage();
    }
  }

  void _onSearchChanged(String value) {
    // Rebuild immediately so the clear (×) icon appears/disappears.
    setState(() {});

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 380), () {
      if (!mounted) return;
      if (value.trim().isEmpty) {
        // Restore initial popular options — no API call needed.
        setState(() {
          _options = List<NeedOption>.from(widget.layer.options);
          _hasMore = widget.layer.hasMore;
          _currentPage = 1;
          _loading = false;
        });
      } else {
        _resetAndFetch();
      }
    });
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() {
      _options = List<NeedOption>.from(widget.layer.options);
      _hasMore = widget.layer.hasMore;
      _currentPage = 1;
      _loading = false;
    });
  }

  Future<void> _resetAndFetch() async {
    if (!mounted) return;
    setState(() {
      _options = [];
      _currentPage = 1;
      _hasMore = true;
      _loading = true;
    });
    await _doFetch(page: 1, reset: true);
  }

  Future<void> _loadNextPage() async {
    if (!_hasMore || _isFetchingMore || _loading) return;
    await _doFetch(page: _currentPage + 1, reset: false);
  }

  Future<void> _doFetch({required int page, required bool reset}) async {
    if (_isFetchingMore && !reset) return;
    _isFetchingMore = true;
    try {
      final q = Uri.encodeComponent(_searchCtrl.text.trim());
      final url =
          '/get_need_layer_options?layer_id=${widget.layer.layerId}&q=$q&page=$page&page_size=$_pageSize';
      final resp = await Config.apiGet(url, context);
      if (!mounted) return;
      if (resp != null && resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          final raw = (data['options'] as List? ?? []);
          final fetched = raw
              .map((o) =>
                  NeedOption.fromJson(o as Map<String, dynamic>))
              .toList();
          setState(() {
            _options = reset ? fetched : [..._options, ...fetched];
            _hasMore = data['has_more'] == true;
            _currentPage = page;
            _loading = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('_LayerOptionsSheet._doFetch: $e');
    } finally {
      _isFetchingMore = false;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE4E9F2),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),

          // Title + close + search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.layer.titleBn,
                            style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                color: Color(0xFF1A2340)),
                          ),
                          if (widget.layer.subtitleBn.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              widget.layer.subtitleBn,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF8A94A6),
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F6FA),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.close_rounded,
                            size: 18, color: Color(0xFF4A5568)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'সাজেশন খুঁজুন...',
                    hintStyle: const TextStyle(
                        color: Color(0xFFB0B7C3),
                        fontWeight: FontWeight.w500,
                        fontSize: 14),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: Color(0xFF8A94A6), size: 20),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded,
                                size: 18, color: Color(0xFF8A94A6)),
                            onPressed: _clearSearch,
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF4F6FA),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                          color: Color(0xFF5B8DEF), width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF0F3F8)),

          // Options list
          Expanded(child: _buildOptionsList()),
        ],
      ),
    );
  }

  Widget _buildOptionsList() {
    // Full-screen spinner on first page load.
    if (_loading && _options.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
            color: Color(0xFF5B8DEF), strokeWidth: 2.5),
      );
    }

    // Empty state.
    if (!_loading && _options.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off_rounded,
                  size: 48, color: Color(0xFFD1D5DB)),
              const SizedBox(height: 14),
              const Text(
                'কোনো সাজেশন পাওয়া যায়নি',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF6B7280)),
              ),
              if (_searchCtrl.text.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  '"${_searchCtrl.text}" এর জন্য কোনো ফলাফল নেই',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFFB0B7C3)),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // Paginated list — append a spinner row when more pages exist.
    return ListView.builder(
      controller: _listScrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      itemCount: _options.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _options.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFF5B8DEF)),
              ),
            ),
          );
        }
        return _optionListTile(_options[index]);
      },
    );
  }

  Widget _optionListTile(NeedOption opt) {
    return GestureDetector(
      onTap: () => Navigator.pop(context, opt),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEAEDF4)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x06000000),
                blurRadius: 6,
                offset: Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF4FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.short_text_rounded,
                  color: Color(0xFF5B8DEF), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                opt.text,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A2340)),
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFFBEC4CF), size: 20),
          ],
        ),
      ),
    );
  }
}
