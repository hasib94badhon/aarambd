import 'dart:convert';
import 'dart:io';

import 'package:aaram_bd/config.dart';
import 'package:aaram_bd/screens/thoughtdetails.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

// ── Category colour helper (used by description_landing_page too) ────────────
Color getColorFromCategory(String name) {
  const colors = [
    Color(0xFF5B8DEF), Color(0xFF43C6A3), Color(0xFF9B59B6),
    Color(0xFFE67E22), Color(0xFFE74C3C), Color(0xFF1ABC9C),
    Color(0xFFD63384),
  ];
  final idx = name.codeUnits.fold(0, (p, c) => p + c) % colors.length;
  return colors[idx];
}

// ── Per-category theme ───────────────────────────────────────────────────────
class CatTheme {
  final int catId;
  final String label;
  final String emoji;
  final Color primary;
  final Color accent;
  final Color bg;
  final Color chipBg;
  final Color chipText;
  final String composerHint;
  final String postButtonLabel;
  final IconData icon;

  const CatTheme({
    required this.catId,
    required this.label,
    required this.emoji,
    required this.primary,
    required this.accent,
    required this.bg,
    required this.chipBg,
    required this.chipText,
    required this.composerHint,
    required this.postButtonLabel,
    required this.icon,
  });
}

const _themes = <int, CatTheme>{
  23: CatTheme(
    catId: 23, label: 'Billboard For Ads', emoji: '📢',
    primary: Color(0xFF1A1A2E), accent: Color(0xFFF5C518),
    bg: Color(0xFF16213E), chipBg: Color(0xFF0F3460),
    chipText: Color(0xFFF5C518),
    composerHint: 'আপনার বিজ্ঞাপনের বিবরণ লিখুন...',
    postButtonLabel: 'Publish Ad',
    icon: Icons.campaign_rounded,
  ),
  190: CatTheme(
    catId: 190, label: 'Need Service', emoji: '🔧',
    primary: Color(0xFF1A56DB), accent: Color(0xFF43C6A3),
    bg: Color(0xFFF0F7FF), chipBg: Color(0xFFE8F1FF),
    chipText: Color(0xFF1A56DB),
    composerHint: 'কী সেবা দরকার সেটা বিস্তারিত লিখুন...',
    postButtonLabel: 'Post Request',
    icon: Icons.build_rounded,
  ),
  191: CatTheme(
    catId: 191, label: 'Need Shops', emoji: '🏪',
    primary: Color(0xFFD97706), accent: Color(0xFFF59E0B),
    bg: Color(0xFFFFFBEB), chipBg: Color(0xFFFEF3C7),
    chipText: Color(0xFF92400E),
    composerHint: 'কোন পণ্য বা দোকান খুঁজছেন লিখুন...',
    postButtonLabel: 'Post Inquiry',
    icon: Icons.storefront_rounded,
  ),
  192: CatTheme(
    catId: 192, label: 'Need Help', emoji: '🆘',
    primary: Color(0xFFDC2626), accent: Color(0xFFFCA5A5),
    bg: Color(0xFFFFF5F5), chipBg: Color(0xFFFEE2E2),
    chipText: Color(0xFF991B1B),
    composerHint: 'আপনার সমস্যা বা সাহায্যের বিষয়টি লিখুন...',
    postButtonLabel: 'Ask for Help',
    icon: Icons.sos_rounded,
  ),
  194: CatTheme(
    catId: 194, label: 'Need Information', emoji: 'ℹ️',
    primary: Color(0xFF0891B2), accent: Color(0xFF67E8F9),
    bg: Color(0xFFF0FDFF), chipBg: Color(0xFFCFFAFE),
    chipText: Color(0xFF164E63),
    composerHint: 'কী জানতে চান বিস্তারিত লিখুন...',
    postButtonLabel: 'Ask Question',
    icon: Icons.info_outline_rounded,
  ),
};

CatTheme themeFor(int? catId) => _themes[catId] ?? const CatTheme(
  catId: 0, label: 'Post', emoji: '📝',
  primary: Color(0xFF1A56DB), accent: Color(0xFF43C6A3),
  bg: Color(0xFFF3F7FF), chipBg: Color(0xFFE8F1FF),
  chipText: Color(0xFF1A56DB),
  composerHint: 'কিছু লিখুন...',
  postButtonLabel: 'Post',
  icon: Icons.edit_rounded,
);

// ── Sub-category model ───────────────────────────────────────────────────────
class _SubCat {
  final int id;
  final String nameBn;
  final String nameEn;
  final String emoji;
  const _SubCat(this.id, this.nameBn, this.nameEn, this.emoji);
}

// ═════════════════════════════════════════════════════════════════════════════
//  NeedBuilderPage
// ═════════════════════════════════════════════════════════════════════════════
class NeedBuilderPage extends StatefulWidget {
  final String? initialCatId;
  const NeedBuilderPage({super.key, this.initialCatId});

  @override
  State<NeedBuilderPage> createState() => _NeedBuilderPageState();
}

class _NeedBuilderPageState extends State<NeedBuilderPage> {
  final _textCtrl   = TextEditingController();
  final _noteCtrl   = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<Map<String, dynamic>> _categories  = [];
  List<Map<String, dynamic>> _myPosts     = [];
  List<_SubCat>              _subCats     = [];
  List<String>               _suggestions = [];
  final Set<String>          _selectedChips = {};

  String?   _selectedCatId;
  _SubCat?  _selectedSubCat;
  XFile?    _pickedPhoto;
  bool      _catPanelExpanded = false;
  bool      _loadingCats      = true;
  bool      _loadingPosts     = true;
  bool      _loadingSubCats   = false;
  bool      _loadingSugg      = false;
  bool      _isPosting        = false;

  final Map<String, bool> _expandedMap = {};

  CatTheme get _theme => themeFor(int.tryParse(_selectedCatId ?? ''));

  @override
  void initState() {
    super.initState();
    _selectedCatId = widget.initialCatId;
    _fetchCategories();
    _fetchMyPosts();
    if (_selectedCatId != null) _fetchSubCats(_selectedCatId!);
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _noteCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  Future<void> _fetchCategories() async {
    final resp = await Config.apiGet('/get_description_categories', context);
    if (!mounted) return;
    if (resp != null && resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      setState(() {
        _categories = List<Map<String, dynamic>>.from(data['categories'] ?? []);
        _loadingCats = false;
      });
    } else {
      setState(() => _loadingCats = false);
    }
  }

  Future<void> _fetchMyPosts() async {
    final ctx = context;
    setState(() => _loadingPosts = true);
    final userId = await Config.getLoggedInUser();
    if (userId == null) { setState(() => _loadingPosts = false); return; }
    if (!ctx.mounted) return;
    final resp = await Config.apiGet('/get_user_description?user_id=$userId', ctx);
    if (!mounted) return;
    if (resp != null && resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      setState(() {
        _myPosts = List<Map<String, dynamic>>.from(data['descriptions'] ?? []);
      });
    }
    setState(() => _loadingPosts = false);
  }

  Future<void> _fetchSubCats(String catId) async {
    setState(() { _subCats = []; _selectedSubCat = null; _suggestions = []; _loadingSubCats = true; });
    final resp = await Config.apiGet('/get_des_sub_categories?des_cat_id=$catId', context);
    if (!mounted) return;
    if (resp != null && resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      final list = (data['sub_categories'] as List? ?? []);
      setState(() {
        _subCats = list.map((e) => _SubCat(
          e['des_sub_cat_id'] as int,
          e['name_bn'] as String,
          e['name_en'] as String? ?? '',
          e['emoji'] as String? ?? '',
        )).toList();
        _loadingSubCats = false;
      });
    } else {
      setState(() => _loadingSubCats = false);
    }
  }

  Future<void> _fetchSuggestions(int subCatId) async {
    setState(() { _suggestions = []; _loadingSugg = true; });
    final resp = await Config.apiGet(
        '/get_des_cat_suggestions?des_sub_cat_id=$subCatId', context);
    if (!mounted) return;
    if (resp != null && resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      setState(() {
        _suggestions = List<String>.from(data['suggestions'] ?? []);
        _loadingSugg = false;
      });
    } else {
      setState(() => _loadingSugg = false);
    }
  }

  Future<void> _pickPhoto() async {
    final photo = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (photo != null) setState(() => _pickedPhoto = photo);
  }

  Future<void> _submitPost() async {
    final text = _buildText();
    if (text.isEmpty && _pickedPhoto == null) {
      _snack('কমপক্ষে একটি টেক্সট বা ছবি দিন');
      return;
    }
    if (_selectedCatId == null) {
      _snack('আগে একটি ক্যাটাগরি নির্বাচন করুন');
      return;
    }
    if (_selectedSubCat == null) {
      _snack('আগে একটি সাব-ক্যাটাগরি নির্বাচন করুন');
      return;
    }
    setState(() => _isPosting = true);
    final userId = await Config.getLoggedInUser() ?? '';

    Map<String, File>? files;
    if (_pickedPhoto != null) {
      final compressed = await Config.compressImageIfNeeded(File(_pickedPhoto!.path));
      files = {'des_photo': compressed};
    }
    if (!mounted) return;

    final resp = await Config.apiMultipartPost(
      '/update_user_description', context,
      fields: {
        'user_id':        userId,
        'des_cat_id':     _selectedCatId!,
        'des_sub_cat_id': _selectedSubCat!.id.toString(),
        'description':    text,
        'special_note':   _noteCtrl.text.trim(),
        'status':         'live',
        'is_hidden':      '0',
      },
      files: files,
    );
    if (!mounted) return;
    setState(() => _isPosting = false);

    if (resp != null) {
      final body = jsonDecode(await resp.stream.bytesToString());
      _snack(body['message'] ?? 'Posted');
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        _resetComposer();
        await _fetchMyPosts();
      }
    }
  }

  Future<void> _changeStatus(String desId, String newStatus) async {
    final resp = await Config.apiPost(
        '/change_description_status', {'des_id': desId, 'status': newStatus}, context);
    if (resp == null) return;
    _snack(jsonDecode(resp.body)['message'] ?? 'Updated');
    if (resp.statusCode == 200) await _fetchMyPosts();
  }

  Future<void> _toggleHidden(String desId, bool hide) async {
    final resp = await Config.apiPost(
        '/toggle_description_hidden', {'des_id': desId, 'is_hidden': hide}, context);
    if (resp == null) return;
    _snack(jsonDecode(resp.body)['message'] ?? 'Updated');
    if (resp.statusCode == 200) await _fetchMyPosts();
  }

  Future<void> _confirmDelete(String desId) async {
    final ctx = context;
    final yes = await showDialog<bool>(
      context: ctx,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('পোস্ট ডিলিট করবেন?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('এই পোস্ট মুছে ফেলা হবে এবং আর ফেরত আনা যাবে না।'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dlgCtx, false), child: const Text('না')),
          ElevatedButton(
            onPressed: () => Navigator.pop(dlgCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('ডিলিট'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    if (!ctx.mounted) return;
    final resp = await Config.apiPost('/delete_user_description', {'des_id': desId}, ctx);
    if (resp == null) return;
    final data = jsonDecode(resp.body);
    _snack(data['message'] ?? '');
    if (resp.statusCode == 200 && data['success'] == true) {
      _expandedMap.remove(desId);
      await _fetchMyPosts();
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _buildText() {
    final chips = _selectedChips.join(' ');
    final typed = _textCtrl.text.trim();
    return [chips, typed].where((s) => s.isNotEmpty).join(' ');
  }

  void _resetComposer() {
    setState(() {
      _selectedChips.clear();
      _textCtrl.clear();
      _noteCtrl.clear();
      _pickedPhoto = null;
      _selectedSubCat = null;
      _suggestions = [];
    });
  }

  void _selectCategory(String id) {
    setState(() {
      _selectedCatId = id;
      _catPanelExpanded = false;
      _resetComposer();
    });
    _fetchSubCats(id);
  }

  void _selectSubCat(_SubCat sub) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedSubCat = sub;
      _selectedChips.clear();
    });
    _fetchSuggestions(sub.id);
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final t = _theme;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F3F8),
      appBar: AppBar(
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(t.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 7),
          Text(t.label,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
        ]),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: t.primary,
        surfaceTintColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFEAEDF2)),
        ),
      ),
      body: CustomScrollView(
        controller: _scrollCtrl,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverToBoxAdapter(child: _buildCategoryPanel()),
          SliverToBoxAdapter(child: _buildComposerArea()),
          const SliverToBoxAdapter(child: SizedBox(height: 18)),
          SliverToBoxAdapter(child: _buildMyPostsHeader()),
          if (_loadingPosts)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Padding(
                padding: EdgeInsets.only(bottom: 60),
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )),
            )
          else if (_myPosts.isEmpty)
            _buildEmptySliver()
          else
            SliverList.separated(
              itemCount: _myPosts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _buildPostCard(_myPosts[i]),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  // ── Category panel ────────────────────────────────────────────────────────

  Widget _buildCategoryPanel() {
    final t = _theme;
    final selName = _selectedCatId == null ? '' :
        (_categories.firstWhere(
          (c) => c['des_cat_id'].toString() == _selectedCatId,
          orElse: () => {},
        )['des_cat_name'] ?? '').toString();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(
              color: Color(0x10000000), blurRadius: 16, offset: Offset(0, 6))],
        ),
        child: Column(children: [
          InkWell(
            onTap: () => setState(() => _catPanelExpanded = !_catPanelExpanded),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: t.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.category_outlined, color: t.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Category', style: TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 13,
                        color: Color(0xFF4A5568))),
                    const SizedBox(height: 2),
                    Text(
                      selName.isNotEmpty ? selName : 'ক্যাটাগরি নির্বাচন করুন',
                      style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13.5,
                        color: selName.isNotEmpty ? t.primary : const Color(0xFFB0B7C3),
                      ),
                    ),
                  ],
                )),
                if (selName.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                        color: t.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999)),
                    child: Text('✓ Selected', style: TextStyle(
                        color: t.primary, fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                const SizedBox(width: 6),
                AnimatedRotation(
                  turns: _catPanelExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF8A94A6)),
                ),
              ]),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeInOut,
            child: _catPanelExpanded
                ? Column(children: [
                    const Divider(height: 1, color: Color(0xFFF0F3F8)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
                      child: _loadingCats
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                          : Wrap(
                              spacing: 8, runSpacing: 8,
                              children: _categories.map((cat) {
                                final name = (cat['des_cat_name'] ?? '').toString();
                                final id   = (cat['des_cat_id'] ?? '').toString();
                                final sel  = _selectedCatId == id;
                                final ct   = themeFor(int.tryParse(id));
                                return GestureDetector(
                                  onTap: () { HapticFeedback.lightImpact(); _selectCategory(id); },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                                    decoration: BoxDecoration(
                                      color: sel ? ct.primary : ct.primary.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: sel ? ct.primary : ct.primary.withValues(alpha: 0.25),
                                        width: sel ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                                      Text(ct.emoji, style: const TextStyle(fontSize: 14)),
                                      const SizedBox(width: 5),
                                      Text(name, style: TextStyle(
                                        color: sel ? Colors.white : ct.primary,
                                        fontWeight: FontWeight.w800, fontSize: 13,
                                      )),
                                    ]),
                                  ),
                                );
                              }).toList(),
                            ),
                    ),
                  ])
                : const SizedBox.shrink(),
          ),
        ]),
      ),
    );
  }

  // ── Composer area: sub-cat picker → word chips + text + image ─────────────

  Widget _buildComposerArea() {
    if (_selectedCatId == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
        child: _emptyComposerHint(),
      );
    }

    final t = _theme;
    final isBillboard = t.catId == 23;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: Container(
        decoration: BoxDecoration(
          color: isBillboard ? t.bg : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: isBillboard
              ? Border.all(color: t.accent.withValues(alpha: 0.35), width: 1.5)
              : null,
          boxShadow: [BoxShadow(
            color: t.primary.withValues(alpha: isBillboard ? 0.20 : 0.08),
            blurRadius: 20, offset: const Offset(0, 6),
          )],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

          // ── Header bar ─────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            decoration: BoxDecoration(
              color: isBillboard ? t.primary : t.primary.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(children: [
              Icon(t.icon, color: isBillboard ? t.accent : t.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('${t.emoji}  ${t.label}',
                  style: TextStyle(
                    color: isBillboard ? t.accent : t.primary,
                    fontWeight: FontWeight.w900, fontSize: 14.5,
                  ))),
              if (_selectedSubCat != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: isBillboard
                        ? t.accent.withValues(alpha: 0.18)
                        : t.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(_selectedSubCat!.emoji,
                        style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Text(_selectedSubCat!.nameBn,
                        style: TextStyle(
                          color: isBillboard ? t.accent : t.primary,
                          fontSize: 11, fontWeight: FontWeight.w800,
                        )),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => setState(() {
                        _selectedSubCat = null;
                        _suggestions = [];
                        _selectedChips.clear();
                      }),
                      child: Icon(Icons.close_rounded, size: 13,
                          color: isBillboard ? t.accent : t.primary),
                    ),
                  ]),
                ),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

              // ── STEP 1: Sub-category selection ─────────────────────────
              if (_selectedSubCat == null) ...[
                Text('Sub-category নির্বাচন করুন',
                    style: TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w700,
                      color: isBillboard
                          ? t.accent.withValues(alpha: 0.80)
                          : t.primary,
                    )),
                const SizedBox(height: 10),
                if (_loadingSubCats)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ))
                else
                  _buildSubCatGrid(t, isBillboard),
              ]

              // ── STEP 2: Word chips + text + image ──────────────────────
              else ...[
                // Word suggestion chips
                if (_loadingSugg)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Center(child: SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2))),
                  )
                else if (_suggestions.isNotEmpty) ...[
                  Text('Quick suggestions',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700,
                          color: isBillboard
                              ? t.accent.withValues(alpha: 0.75)
                              : t.primary.withValues(alpha: 0.65))),
                  const SizedBox(height: 8),
                  Wrap(spacing: 7, runSpacing: 7,
                    children: _suggestions.map((s) {
                      final sel = _selectedChips.contains(s);
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => sel
                              ? _selectedChips.remove(s)
                              : _selectedChips.add(s));
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: sel ? t.primary : t.chipBg,
                            borderRadius: BorderRadius.circular(
                                isBillboard ? 6 : 999),
                            border: isBillboard
                                ? Border.all(color: sel
                                    ? t.accent : t.accent.withValues(alpha: 0.30))
                                : Border.all(color: sel
                                    ? t.primary : t.primary.withValues(alpha: 0.18)),
                            boxShadow: sel ? [BoxShadow(
                                color: t.primary.withValues(alpha: 0.28),
                                blurRadius: 8, offset: const Offset(0, 3))] : null,
                          ),
                          child: Text(s, style: TextStyle(
                            color: sel ? Colors.white : t.chipText,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          )),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                ],

                // Text field
                TextField(
                  controller: _textCtrl,
                  minLines: 3, maxLines: 6,
                  style: TextStyle(
                    fontSize: 15, height: 1.5, fontWeight: FontWeight.w600,
                    color: isBillboard ? Colors.white : const Color(0xFF1A2340),
                  ),
                  decoration: InputDecoration(
                    hintText: t.composerHint,
                    hintStyle: TextStyle(
                      color: isBillboard
                          ? Colors.white.withValues(alpha: 0.35)
                          : const Color(0xFFB0B7C3),
                      fontSize: 14, fontWeight: FontWeight.w500,
                    ),
                    filled: true,
                    fillColor: isBillboard
                        ? Colors.white.withValues(alpha: 0.06)
                        : const Color(0xFFF7F9FC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: isBillboard
                              ? t.accent.withValues(alpha: 0.30)
                              : const Color(0xFFE8EDF5)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: isBillboard
                              ? t.accent.withValues(alpha: 0.30)
                              : const Color(0xFFE8EDF5)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: t.primary, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 10),

                // Special note
                TextField(
                  controller: _noteCtrl,
                  minLines: 1, maxLines: 3,
                  style: TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w500,
                    color: isBillboard ? Colors.white70 : const Color(0xFF4A5568),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Additional note (optional)...',
                    hintStyle: TextStyle(
                      color: isBillboard
                          ? Colors.white.withValues(alpha: 0.28)
                          : const Color(0xFFB0B7C3),
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: isBillboard
                        ? Colors.white.withValues(alpha: 0.04)
                        : const Color(0xFFF7F9FC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: isBillboard
                              ? t.accent.withValues(alpha: 0.20)
                              : const Color(0xFFE8EDF5)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: isBillboard
                              ? t.accent.withValues(alpha: 0.20)
                              : const Color(0xFFE8EDF5)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: t.primary.withValues(alpha: 0.50), width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                ),
                const SizedBox(height: 10),

                // Photo picker
                GestureDetector(
                  onTap: _pickPhoto,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isBillboard
                          ? Colors.white.withValues(alpha: 0.06)
                          : const Color(0xFFF8FAFD),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isBillboard
                            ? t.accent.withValues(alpha: 0.25)
                            : const Color(0xFFE8EDF5),
                      ),
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: t.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.image_outlined, color: t.primary, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(
                        _pickedPhoto == null
                            ? 'Add a photo (optional)'
                            : 'Photo selected ✓',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isBillboard
                              ? (_pickedPhoto == null ? Colors.white54 : t.accent)
                              : (_pickedPhoto == null
                                  ? const Color(0xFF8A94A6)
                                  : t.primary),
                        ),
                      )),
                      Icon(Icons.add_photo_alternate_rounded,
                          color: isBillboard
                              ? t.accent.withValues(alpha: 0.60)
                              : const Color(0xFF8A94A6)),
                    ]),
                  ),
                ),
                if (_pickedPhoto != null) ...[
                  const SizedBox(height: 10),
                  Stack(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.file(File(_pickedPhoto!.path),
                          height: 160, width: double.infinity, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 8, right: 8,
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
                  ]),
                ],
                const SizedBox(height: 14),

                // Post button
                SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    icon: _isPosting
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Icon(t.icon, size: 18),
                    label: Text(_isPosting ? 'Posting...' : t.postButtonLabel,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w900)),
                    onPressed: _isPosting ? null : _submitPost,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: t.primary,
                      foregroundColor: isBillboard ? t.accent : Colors.white,
                      disabledBackgroundColor: t.primary.withValues(alpha: 0.45),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildSubCatGrid(CatTheme t, bool isBillboard) {
    if (_subCats.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text('No sub-categories found',
              style: TextStyle(color: isBillboard ? Colors.white54 : Colors.grey)),
        ),
      );
    }
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.5,
      children: _subCats.map((sub) {
        return GestureDetector(
          onTap: () => _selectSubCat(sub),
          child: Container(
            decoration: BoxDecoration(
              color: isBillboard
                  ? t.accent.withValues(alpha: 0.12)
                  : t.primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isBillboard
                    ? t.accent.withValues(alpha: 0.35)
                    : t.primary.withValues(alpha: 0.20),
              ),
            ),
            child: Row(children: [
              const SizedBox(width: 10),
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: isBillboard
                      ? t.accent.withValues(alpha: 0.20)
                      : t.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: Text(sub.emoji.isNotEmpty ? sub.emoji : '📌',
                    style: const TextStyle(fontSize: 16))),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(sub.nameBn,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 12.5,
                    color: isBillboard ? t.accent : t.primary,
                  ))),
            ]),
          ),
          
        );
      }).toList(),
    );
  }

  Widget _emptyComposerHint() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(
            color: Color(0x10000000), blurRadius: 16, offset: Offset(0, 6))],
      ),
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      child: Column(children: [
        Icon(Icons.touch_app_rounded, size: 40, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        const Text('আগে ক্যাটাগরি নির্বাচন করুন',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15,
                color: Color(0xFF1A2340))),
        const SizedBox(height: 4),
        const Text('প্রতিটি ক্যাটাগরির জন্য আলাদা পোস্টিং অভিজ্ঞতা পাবেন',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF8A94A6), fontSize: 13)),
      ]),
    );
  }

  // ── My posts ──────────────────────────────────────────────────────────────

  Widget _buildMyPostsHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(children: [
        const Icon(Icons.format_list_bulleted_rounded,
            size: 17, color: Color(0xFF86A8E7)),
        const SizedBox(width: 6),
        Text('My Posts (${_myPosts.length})',
            style: const TextStyle(fontWeight: FontWeight.w900,
                fontSize: 13.5, color: Color(0xFF4A5568))),
      ]),
    );
  }

  SliverFillRemaining _buildEmptySliver() {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 60),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: const BoxDecoration(
                  color: Color(0xFFEFF4FF), shape: BoxShape.circle),
              child: const Icon(Icons.post_add_rounded, size: 42,
                  color: Color(0xFF5B8DEF)),
            ),
            const SizedBox(height: 16),
            const Text('এখনো কোনো পোস্ট নেই',
                style: TextStyle(fontWeight: FontWeight.w900,
                    fontSize: 16, color: Color(0xFF2B3A55))),
            const SizedBox(height: 6),
            const Text('উপরে ক্যাটাগরি বেছে পোস্ট করুন',
                style: TextStyle(color: Color(0xFF8A94A6), fontSize: 13.5)),
          ]),
        ),
      ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> item) {
    final catId = (item['des_cat_id'] ?? 0) as int? ?? 0;
    final t     = themeFor(catId);
    switch (catId) {
      case 23:  return _BillboardCard(item: item, theme: t, expanded: _expandedMap, onStatusToggle: _changeStatus, onHideToggle: _toggleHidden, onDelete: _confirmDelete, onExpandToggle: (id, val) => setState(() => _expandedMap[id] = val), onNavigate: _navigateToDetail);
      case 190: return _ServiceCard(item: item, theme: t, expanded: _expandedMap, onStatusToggle: _changeStatus, onHideToggle: _toggleHidden, onDelete: _confirmDelete, onExpandToggle: (id, val) => setState(() => _expandedMap[id] = val), onNavigate: _navigateToDetail);
      case 191: return _ShopsCard(item: item, theme: t, expanded: _expandedMap, onStatusToggle: _changeStatus, onHideToggle: _toggleHidden, onDelete: _confirmDelete, onExpandToggle: (id, val) => setState(() => _expandedMap[id] = val), onNavigate: _navigateToDetail);
      case 192: return _HelpCard(item: item, theme: t, expanded: _expandedMap, onStatusToggle: _changeStatus, onHideToggle: _toggleHidden, onDelete: _confirmDelete, onExpandToggle: (id, val) => setState(() => _expandedMap[id] = val), onNavigate: _navigateToDetail);
      case 194: return _InfoCard(item: item, theme: t, expanded: _expandedMap, onStatusToggle: _changeStatus, onHideToggle: _toggleHidden, onDelete: _confirmDelete, onExpandToggle: (id, val) => setState(() => _expandedMap[id] = val), onNavigate: _navigateToDetail);
      default:  return _ServiceCard(item: item, theme: t, expanded: _expandedMap, onStatusToggle: _changeStatus, onHideToggle: _toggleHidden, onDelete: _confirmDelete, onExpandToggle: (id, val) => setState(() => _expandedMap[id] = val), onNavigate: _navigateToDetail);
    }
  }

  void _navigateToDetail(String desId) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => ThoughtDetails(desId: desId)));
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

typedef _OnAction  = void Function(String desId, String value);
typedef _OnToggle  = void Function(String desId, bool value);
typedef _OnExpand  = void Function(String desId, bool expanded);
typedef _OnNav     = void Function(String desId);

Widget _actionChip(String label, Color color, bool dark, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: dark ? color.withValues(alpha: 0.18) : color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
            color: dark ? color.withValues(alpha: 0.40) : color.withValues(alpha: 0.22)),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
    ),
  );
}

Widget _statRow(Map item, Color iconColor, bool dark) {
  return Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.visibility_outlined, size: 13,
        color: dark ? Colors.white38 : Colors.grey.shade400),
    const SizedBox(width: 3),
    Text('${item['des_view'] ?? 0}',
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700,
            color: dark ? Colors.white54 : Colors.grey.shade600)),
    const SizedBox(width: 9),
    Icon(Icons.chat_bubble_outline_rounded, size: 12,
        color: dark ? Colors.white38 : Colors.grey.shade400),
    const SizedBox(width: 3),
    Text('${item['des_com'] ?? 0}',
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700,
            color: dark ? Colors.white54 : Colors.grey.shade600)),
  ]);
}

// ═════════════════════════════════════════════════════════════════════════════
//  23 — Billboard: dark wide card, gold accents, headline style
// ═════════════════════════════════════════════════════════════════════════════
class _BillboardCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final CatTheme theme;
  final Map<String, bool> expanded;
  final _OnAction onStatusToggle;
  final _OnToggle onHideToggle;
  final void Function(String) onDelete;
  final _OnExpand onExpandToggle;
  final _OnNav onNavigate;

  const _BillboardCard({
    required this.item, required this.theme, required this.expanded,
    required this.onStatusToggle, required this.onHideToggle,
    required this.onDelete, required this.onExpandToggle, required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final t         = theme;
    final desId     = item['des_id'].toString();
    final des       = (item['des'] ?? '').toString();
    final subName   = (item['sub_cat_name_bn'] ?? '').toString();
    final subEmoji  = (item['sub_cat_emoji'] ?? '').toString();
    final photoUrl  = (item['des_photo'] ?? '').toString();
    final isLive    = (item['status'] ?? 'live') == 'live';
    final isHidden  = item['is_hidden'] == true;
    final isExp     = expanded[desId] ?? false;
    final time      = Config.getTimeDifference((item['time'] ?? '').toString());

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: t.accent.withValues(alpha: 0.22)),
          boxShadow: [BoxShadow(color: t.primary.withValues(alpha: 0.30),
              blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

          // Gold top ribbon
          Container(height: 6,
              decoration: BoxDecoration(
                color: isLive ? t.accent : Colors.grey.shade600,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              )),

          // Photo banner if present
          if (photoUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.zero,
              child: SizedBox(height: 130,
                child: Image.network(photoUrl, fit: BoxFit.cover, width: double.infinity,
                    errorBuilder: (_, __, ___) => const SizedBox()),
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Sub-cat + status badge row
              Row(children: [
                if (subName.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: t.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: t.accent.withValues(alpha: 0.35)),
                    ),
                    child: Text('${subEmoji.isNotEmpty ? "$subEmoji " : ""}$subName',
                        style: TextStyle(color: t.accent,
                            fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                if (subName.isNotEmpty) const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isLive
                        ? Colors.greenAccent.withValues(alpha: 0.12)
                        : Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(isLive ? 'LIVE' : 'DEAD',
                      style: TextStyle(
                        color: isLive ? Colors.greenAccent.shade400 : Colors.redAccent,
                        fontSize: 10, fontWeight: FontWeight.w900,
                      )),
                ),
                if (isHidden) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.visibility_off_rounded, size: 13, color: Colors.white30),
                ],
                const Spacer(),
                Text(time, style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ]),

              const SizedBox(height: 12),

              // Ad headline — big and bold
              Text(des,
                maxLines: isExp ? null : 3,
                overflow: isExp ? TextOverflow.visible : TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18, height: 1.4, fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
              if (des.length > 100)
                GestureDetector(
                  onTap: () => onExpandToggle(desId, !isExp),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(isExp ? 'See less' : 'See more',
                        style: TextStyle(color: t.accent,
                            fontSize: 12, fontWeight: FontWeight.w800)),
                  ),
                ),

              const SizedBox(height: 14),

              // Stats + actions
              Row(children: [
                _statRow(item, t.accent, true),
                const Spacer(),
                _actionChip(isLive ? 'Deactivate' : 'Activate',
                    isLive ? Colors.orangeAccent : Colors.greenAccent.shade400,
                    true, () => onStatusToggle(desId, isLive ? 'dead' : 'live')),
                const SizedBox(width: 6),
                _actionChip(isHidden ? 'Unhide' : 'Hide',
                    t.accent, true, () => onHideToggle(desId, !isHidden)),
                const SizedBox(width: 6),
                _actionChip('Del', Colors.redAccent, true, () => onDelete(desId)),
              ]),
            ]),
          ),

          // Gold visit strip at bottom
          GestureDetector(
            onTap: () => onNavigate(desId),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: t.accent.withValues(alpha: 0.10),
                border: Border(top: BorderSide(color: t.accent.withValues(alpha: 0.20))),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('View full ad', style: TextStyle(
                    color: t.accent, fontSize: 13, fontWeight: FontWeight.w800)),
                const SizedBox(width: 5),
                Icon(Icons.arrow_forward_rounded, size: 14, color: t.accent),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  190 — Need Service: task-board card, blue header + white body
// ═════════════════════════════════════════════════════════════════════════════
class _ServiceCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final CatTheme theme;
  final Map<String, bool> expanded;
  final _OnAction onStatusToggle;
  final _OnToggle onHideToggle;
  final void Function(String) onDelete;
  final _OnExpand onExpandToggle;
  final _OnNav onNavigate;

  const _ServiceCard({
    required this.item, required this.theme, required this.expanded,
    required this.onStatusToggle, required this.onHideToggle,
    required this.onDelete, required this.onExpandToggle, required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final t        = theme;
    final desId    = item['des_id'].toString();
    final des      = (item['des'] ?? '').toString();
    final subName  = (item['sub_cat_name_bn'] ?? '').toString();
    final subEmoji = (item['sub_cat_emoji'] ?? '').toString();
    final note     = (item['special_note'] ?? '').toString();
    final photoUrl = (item['des_photo'] ?? '').toString();
    final isLive   = (item['status'] ?? 'live') == 'live';
    final isHidden = item['is_hidden'] == true;
    final isExp    = expanded[desId] ?? false;
    final time     = Config.getTimeDifference((item['time'] ?? '').toString());

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: t.primary.withValues(alpha: 0.10),
              blurRadius: 18, offset: const Offset(0, 6))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

          // Blue header with sub-cat label
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: isLive ? t.primary : Colors.grey.shade500,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(children: [
              Icon(t.icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(
                subName.isNotEmpty
                    ? '${subEmoji.isNotEmpty ? "$subEmoji " : ""}$subName'
                    : t.label,
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w800, fontSize: 13.5),
              )),
              if (isHidden)
                const Icon(Icons.visibility_off_rounded,
                    size: 14, color: Colors.white54),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(time,
                    style: const TextStyle(color: Colors.white70,
                        fontSize: 10.5, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Task description
              Text(des,
                maxLines: isExp ? null : 4,
                overflow: isExp ? TextOverflow.visible : TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14.5, height: 1.55,
                    color: Color(0xFF1A2340), fontWeight: FontWeight.w600),
              ),
              if (des.length > 120)
                GestureDetector(
                  onTap: () => onExpandToggle(desId, !isExp),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(isExp ? 'See less' : 'See more',
                        style: TextStyle(color: t.primary,
                            fontSize: 12, fontWeight: FontWeight.w800)),
                  ),
                ),

              if (note.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: t.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: t.primary.withValues(alpha: 0.12)),
                  ),
                  child: Text(note, style: const TextStyle(
                      fontSize: 13, color: Color(0xFF4A5568), fontWeight: FontWeight.w500)),
                ),
              ],

              if (photoUrl.isNotEmpty) ...[
                const SizedBox(height: 10),
                ClipRRect(borderRadius: BorderRadius.circular(12),
                  child: Image.network(photoUrl, height: 150,
                      width: double.infinity, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox())),
              ],

              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFF0F3F8)),
              const SizedBox(height: 10),

              Row(children: [
                _statRow(item, t.primary, false),
                const Spacer(),
                _actionChip(isLive ? 'Pause' : 'Resume',
                    isLive ? const Color(0xFFD0703A) : const Color(0xFF30A882),
                    false, () => onStatusToggle(desId, isLive ? 'dead' : 'live')),
                const SizedBox(width: 6),
                _actionChip(isHidden ? 'Show' : 'Hide',
                    const Color(0xFF6B7280), false, () => onHideToggle(desId, !isHidden)),
                const SizedBox(width: 6),
                _actionChip('Del', Colors.redAccent, false, () => onDelete(desId)),
              ]),

              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => onNavigate(desId),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: t.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: t.primary.withValues(alpha: 0.15)),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('View task', style: TextStyle(
                        color: t.primary, fontSize: 13, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios_rounded, size: 12, color: t.primary),
                  ]),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  191 — Need Shops: two-col layout, warm/storefront card
// ═════════════════════════════════════════════════════════════════════════════
class _ShopsCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final CatTheme theme;
  final Map<String, bool> expanded;
  final _OnAction onStatusToggle;
  final _OnToggle onHideToggle;
  final void Function(String) onDelete;
  final _OnExpand onExpandToggle;
  final _OnNav onNavigate;

  const _ShopsCard({
    required this.item, required this.theme, required this.expanded,
    required this.onStatusToggle, required this.onHideToggle,
    required this.onDelete, required this.onExpandToggle, required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final t        = theme;
    final desId    = item['des_id'].toString();
    final des      = (item['des'] ?? '').toString();
    final subName  = (item['sub_cat_name_bn'] ?? '').toString();
    final subEmoji = (item['sub_cat_emoji'] ?? '').toString();
    final note     = (item['special_note'] ?? '').toString();
    final photoUrl = (item['des_photo'] ?? '').toString();
    final isLive   = (item['status'] ?? 'live') == 'live';
    final isHidden = item['is_hidden'] == true;
    final isExp    = expanded[desId] ?? false;
    final time     = Config.getTimeDifference((item['time'] ?? '').toString());

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: t.accent.withValues(alpha: 0.30)),
          boxShadow: [BoxShadow(color: t.primary.withValues(alpha: 0.12),
              blurRadius: 16, offset: const Offset(0, 5))],
        ),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

            // Left storefront panel
            Container(
              width: 70,
              decoration: BoxDecoration(
                color: isLive ? t.primary : Colors.grey.shade400,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(18)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(subEmoji.isNotEmpty ? subEmoji : '🏪',
                      style: const TextStyle(fontSize: 26)),
                  const SizedBox(height: 6),
                  if (isHidden)
                    Icon(Icons.visibility_off_rounded,
                        size: 14, color: Colors.white54),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(isLive ? 'LIVE' : 'PAUSED',
                        style: const TextStyle(color: Colors.white,
                            fontSize: 9, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
            ),

            // Right content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    if (subName.isNotEmpty)
                      Expanded(child: Text(subName, maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: t.primary,
                              fontSize: 12, fontWeight: FontWeight.w800))),
                    Text(time, style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 10.5)),
                  ]),
                  const SizedBox(height: 6),
                  Text(des,
                    maxLines: isExp ? null : 3,
                    overflow: isExp ? TextOverflow.visible : TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5, height: 1.5,
                        color: Color(0xFF1A2340), fontWeight: FontWeight.w600),
                  ),
                  if (des.length > 80)
                    GestureDetector(
                      onTap: () => onExpandToggle(desId, !isExp),
                      child: Text(isExp ? 'See less' : 'See more',
                          style: TextStyle(color: t.primary,
                              fontSize: 11.5, fontWeight: FontWeight.w800)),
                    ),
                  if (note.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(note, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12,
                            color: Color(0xFF78716C), fontWeight: FontWeight.w500)),
                  ],
                  if (photoUrl.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ClipRRect(borderRadius: BorderRadius.circular(10),
                      child: Image.network(photoUrl, height: 100,
                          width: double.infinity, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox())),
                  ],
                  const SizedBox(height: 8),
                  Row(children: [
                    _statRow(item, t.primary, false),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => onNavigate(desId),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: t.primary,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [BoxShadow(
                            color: t.primary.withValues(alpha: 0.30),
                            blurRadius: 6, offset: const Offset(0, 2),
                          )],
                        ),
                        child: const Text('Visit', style: TextStyle(
                            color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Row(children: [
                    _actionChip(isLive ? 'Pause' : 'Resume',
                        isLive ? const Color(0xFFD0703A) : const Color(0xFF30A882),
                        false, () => onStatusToggle(desId, isLive ? 'dead' : 'live')),
                    const SizedBox(width: 5),
                    _actionChip(isHidden ? 'Show' : 'Hide',
                        const Color(0xFF6B7280), false, () => onHideToggle(desId, !isHidden)),
                    const SizedBox(width: 5),
                    _actionChip('Del', Colors.redAccent, false, () => onDelete(desId)),
                  ]),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  192 — Need Help: compact urgent card, heavy red left stripe
// ═════════════════════════════════════════════════════════════════════════════
class _HelpCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final CatTheme theme;
  final Map<String, bool> expanded;
  final _OnAction onStatusToggle;
  final _OnToggle onHideToggle;
  final void Function(String) onDelete;
  final _OnExpand onExpandToggle;
  final _OnNav onNavigate;

  const _HelpCard({
    required this.item, required this.theme, required this.expanded,
    required this.onStatusToggle, required this.onHideToggle,
    required this.onDelete, required this.onExpandToggle, required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final t        = theme;
    final desId    = item['des_id'].toString();
    final des      = (item['des'] ?? '').toString();
    final subName  = (item['sub_cat_name_bn'] ?? '').toString();
    final subEmoji = (item['sub_cat_emoji'] ?? '').toString();
    final isLive   = (item['status'] ?? 'live') == 'live';
    final isHidden = item['is_hidden'] == true;
    final isExp    = expanded[desId] ?? false;
    final time     = Config.getTimeDifference((item['time'] ?? '').toString());

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFF5F5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.primary.withValues(alpha: 0.18)),
          boxShadow: [BoxShadow(color: t.primary.withValues(alpha: 0.14),
              blurRadius: 14, offset: const Offset(0, 5))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15.5),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                    color: isLive ? t.primary : Colors.grey.shade400, width: 7),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: t.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(Icons.sos_rounded, color: t.primary, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (subName.isNotEmpty)
                      Text('${subEmoji.isNotEmpty ? "$subEmoji " : ""}$subName',
                          style: TextStyle(color: t.primary,
                              fontSize: 11.5, fontWeight: FontWeight.w800)),
                    Text(time, style: const TextStyle(
                        fontSize: 10.5, color: Color(0xFF9CA3AF))),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isLive ? t.primary.withValues(alpha: 0.10) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(isLive ? '🆘 ACTIVE' : 'RESOLVED',
                        style: TextStyle(
                          color: isLive ? t.primary : Colors.grey,
                          fontSize: 10, fontWeight: FontWeight.w900,
                        )),
                  ),
                  if (isHidden) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.visibility_off_rounded,
                        size: 13, color: Colors.grey.shade400),
                  ],
                ]),

                const SizedBox(height: 10),

                Text(des,
                  maxLines: isExp ? null : 3,
                  overflow: isExp ? TextOverflow.visible : TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14.5, height: 1.5,
                      fontWeight: FontWeight.w700,
                      color: isLive ? const Color(0xFF1A2340) : Colors.grey),
                ),
                if (des.length > 100)
                  GestureDetector(
                    onTap: () => onExpandToggle(desId, !isExp),
                    child: Text(isExp ? 'See less' : 'See more',
                        style: TextStyle(color: t.primary,
                            fontSize: 12, fontWeight: FontWeight.w800)),
                  ),

                const SizedBox(height: 10),

                Row(children: [
                  _statRow(item, t.primary, false),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => onNavigate(desId),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isLive ? t.primary : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text('View', style: TextStyle(
                          color: isLive ? Colors.white : Colors.grey.shade600,
                          fontSize: 12, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ]),

                const SizedBox(height: 6),
                Row(children: [
                  _actionChip(isLive ? 'Mark Resolved' : 'Reopen',
                      isLive ? const Color(0xFF16A34A) : t.primary,
                      false, () => onStatusToggle(desId, isLive ? 'dead' : 'live')),
                  const SizedBox(width: 6),
                  _actionChip(isHidden ? 'Show' : 'Hide',
                      const Color(0xFF6B7280), false, () => onHideToggle(desId, !isHidden)),
                  const SizedBox(width: 6),
                  _actionChip('Del', Colors.redAccent, false, () => onDelete(desId)),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  194 — Need Information: Q&A style, teal, question mark prominent
// ═════════════════════════════════════════════════════════════════════════════
class _InfoCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final CatTheme theme;
  final Map<String, bool> expanded;
  final _OnAction onStatusToggle;
  final _OnToggle onHideToggle;
  final void Function(String) onDelete;
  final _OnExpand onExpandToggle;
  final _OnNav onNavigate;

  const _InfoCard({
    required this.item, required this.theme, required this.expanded,
    required this.onStatusToggle, required this.onHideToggle,
    required this.onDelete, required this.onExpandToggle, required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final t        = theme;
    final desId    = item['des_id'].toString();
    final des      = (item['des'] ?? '').toString();
    final note     = (item['special_note'] ?? '').toString();
    final subName  = (item['sub_cat_name_bn'] ?? '').toString();
    final subEmoji = (item['sub_cat_emoji'] ?? '').toString();
    final isLive   = (item['status'] ?? 'live') == 'live';
    final isHidden = item['is_hidden'] == true;
    final isExp    = expanded[desId] ?? false;
    final time     = Config.getTimeDifference((item['time'] ?? '').toString());

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: t.primary.withValues(alpha: 0.18)),
          boxShadow: [BoxShadow(color: t.primary.withValues(alpha: 0.10),
              blurRadius: 16, offset: const Offset(0, 5))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

          // Teal top bar with Q icon
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              color: isLive ? t.primary.withValues(alpha: 0.08) : Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              border: Border(
                bottom: BorderSide(color: t.primary.withValues(alpha: 0.12)),
              ),
            ),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: isLive ? t.primary : Colors.grey.shade300,
                  shape: BoxShape.circle,
                ),
                child: const Center(child: Text('?',
                    style: TextStyle(color: Colors.white,
                        fontSize: 20, fontWeight: FontWeight.w900))),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  subName.isNotEmpty
                      ? '${subEmoji.isNotEmpty ? "$subEmoji " : ""}$subName'
                      : 'Information Request',
                  style: TextStyle(
                    color: isLive ? t.primary : Colors.grey,
                    fontSize: 12.5, fontWeight: FontWeight.w800,
                  ),
                ),
                Text(time, style: const TextStyle(
                    fontSize: 10.5, color: Color(0xFF9CA3AF))),
              ])),
              if (isHidden)
                Icon(Icons.visibility_off_rounded,
                    size: 14, color: Colors.grey.shade400),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: isLive
                      ? t.primary.withValues(alpha: 0.10)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(isLive ? 'OPEN' : 'CLOSED',
                    style: TextStyle(
                      color: isLive ? t.primary : Colors.grey,
                      fontSize: 9.5, fontWeight: FontWeight.w900,
                    )),
              ),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Question text with leading quotes
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('"', style: TextStyle(
                    fontSize: 32, color: t.primary.withValues(alpha: 0.25),
                    height: 0.85, fontWeight: FontWeight.w900)),
                const SizedBox(width: 6),
                Expanded(child: Text(des,
                  maxLines: isExp ? null : 4,
                  overflow: isExp ? TextOverflow.visible : TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14.5, height: 1.55,
                      color: Color(0xFF1A2340), fontWeight: FontWeight.w600),
                )),
              ]),
              if (des.length > 120)
                GestureDetector(
                  onTap: () => onExpandToggle(desId, !isExp),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 3, left: 28),
                    child: Text(isExp ? 'See less' : 'See more',
                        style: TextStyle(color: t.primary,
                            fontSize: 12, fontWeight: FontWeight.w800)),
                  ),
                ),

              if (note.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: t.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: t.primary.withValues(alpha: 0.12)),
                  ),
                  child: Text(note, style: const TextStyle(
                      fontSize: 12.5, color: Color(0xFF4A5568),
                      fontWeight: FontWeight.w500)),
                ),
              ],

              const SizedBox(height: 12),

              Row(children: [
                _statRow(item, t.primary, false),
                const Spacer(),
                GestureDetector(
                  onTap: () => onNavigate(desId),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: t.primary,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [BoxShadow(color: t.primary.withValues(alpha: 0.28),
                          blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: const Text('View Answers', style: TextStyle(
                        color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                  ),
                ),
              ]),

              const SizedBox(height: 8),
              Row(children: [
                _actionChip(isLive ? 'Close Q' : 'Reopen',
                    isLive ? const Color(0xFF6B7280) : t.primary,
                    false, () => onStatusToggle(desId, isLive ? 'dead' : 'live')),
                const SizedBox(width: 6),
                _actionChip(isHidden ? 'Show' : 'Hide',
                    const Color(0xFF6B7280), false, () => onHideToggle(desId, !isHidden)),
                const SizedBox(width: 6),
                _actionChip('Del', Colors.redAccent, false, () => onDelete(desId)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}
