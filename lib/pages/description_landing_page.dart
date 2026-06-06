import 'dart:convert';

import 'package:aaram_bd/config.dart';
import 'package:aaram_bd/screens/thoughtdetails.dart';
import 'package:flutter/material.dart';

final String host = Config.host;

class DescriptionLandingPage extends StatefulWidget {
  final VoidCallback? onLoaded;

  const DescriptionLandingPage({Key? key, this.onLoaded}) : super(key: key);

  @override
  State<DescriptionLandingPage> createState() => _DescriptionLandingPageState();
}

/* ---------------------- ExpandableText ---------------------- */
class ExpandableText extends StatefulWidget {
  final String text;
  final int maxLines;
  final TextStyle? style;
  final String moreLabel;
  final String lessLabel;
  final TextStyle linkStyle;

  const ExpandableText({
    Key? key,
    required this.text,
    this.maxLines = 3,
    this.style,
    this.moreLabel = 'See more',
    this.lessLabel = 'See less',
    this.linkStyle = const TextStyle(
      fontSize: 14,
      color: Colors.blue,
      fontWeight: FontWeight.w600,
    ),
  }) : super(key: key);

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _expanded = false;

  // Cache keyed by width so TextPainter is not re-run when the width
  // hasn't changed (e.g. pure scroll rebuilds). Cleared when text/style
  // changes via didUpdateWidget.
  final Map<double, bool> _overflowCache = {};

  bool _isOverflow(double maxWidth) {
    if (widget.text.isEmpty) return false;
    return _overflowCache.putIfAbsent(maxWidth, () {
      final tp = TextPainter(
        text: TextSpan(text: widget.text, style: widget.style),
        maxLines: widget.maxLines,
        textDirection: TextDirection.ltr,
        ellipsis: '…',
      );
      tp.layout(maxWidth: maxWidth);
      return tp.didExceedMaxLines;
    });
  }

  @override
  void didUpdateWidget(ExpandableText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.maxLines != widget.maxLines ||
        oldWidget.style != widget.style) {
      _overflowCache.clear();
      // Collapse back to default when text changes entirely.
      _expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // LayoutBuilder is only needed for the width — no postFrameCallback,
    // no deferred setState, nothing that touches the semantics tree.
    return LayoutBuilder(
      builder: (context, constraints) {
        final overflows = _isOverflow(constraints.maxWidth);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              style: widget.style,
              maxLines: _expanded ? null : widget.maxLines,
              overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
            if (overflows)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Text(
                    _expanded ? widget.lessLabel : widget.moreLabel,
                    style: widget.linkStyle,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
/* ------------------------------------------------------------ */

class _DescriptionLandingPageState extends State<DescriptionLandingPage> {
  List _descriptionCategories = [];

  final Map<String, List> _categoryDescriptions = {};
  final Map<String, int> _categoryPage = {};
  final Map<String, bool> _categoryLoading = {};
  final Map<String, bool> _categoryHasMore = {};
  final Map<String, ScrollController> _scrollControllers = {};

  bool _descLoading = true;
  bool _didNotifyLoaded = false;

  String? _selectedCatId;
  String _selectedStatus = 'live'; // live, dead, all

  static const int _pageSize = 10;

  Color get _brandBlue => const Color(0xFF1A56DB);
  Color get _bg => const Color(0xFFF3F7FF);
  Color get _green => const Color(0xFF16A34A);
  Color get _orange => const Color(0xFFF97316);
  Color get _red => const Color(0xFFDC2626);

  BoxShadow get _softShadow => const BoxShadow(
        color: Color(0x14000000),
        blurRadius: 14,
        offset: Offset(0, 6),
      );

  @override
  void initState() {
    super.initState();
    fetchDescriptionData();
  }

  @override
  void dispose() {
    for (final c in _scrollControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _notifyLoadedOnce() {
    if (_didNotifyLoaded) return;
    _didNotifyLoaded = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onLoaded?.call();
    });
  }

  String _cacheKey(String desCatId, String status) => '$desCatId::$status';

  String get _selectedCategoryName {
    if (_selectedCatId == null) return 'Select category';
    final cat = _descriptionCategories.firstWhere(
      (e) => e['des_cat_id'].toString() == _selectedCatId,
      orElse: () => {},
    );
    return (cat['des_cat_name'] ?? 'Category').toString();
  }

  Future<void> fetchDescriptionData() async {
    try {
      final res = await Config.apiGet('/get_description_categories', context);

      if (res != null && res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final List cats = decoded['categories'] ?? [];

        _descriptionCategories = cats;

        if (cats.isNotEmpty) {
          _selectedCatId = cats.first['des_cat_id'].toString();
          await _prepareCategoryStatusState(_selectedCatId!, _selectedStatus);
        }

        if (mounted) setState(() => _descLoading = false);
        _notifyLoadedOnce();

        if (_selectedCatId != null) {
          await _loadPageForCategory(
            _selectedCatId!,
            status: _selectedStatus,
            page: 1,
            replace: true,
          );
        }
      } else {
        if (mounted) setState(() => _descLoading = false);
        _notifyLoadedOnce();
      }
    } catch (e) {
      debugPrint('fetchDescriptionData error: $e');
      if (mounted) setState(() => _descLoading = false);
      _notifyLoadedOnce();
    }
  }

  Future<void> _prepareCategoryStatusState(String desCatId, String status) async {
    final key = _cacheKey(desCatId, status);

    _categoryDescriptions.putIfAbsent(key, () => []);
    _categoryPage.putIfAbsent(key, () => 0);
    _categoryLoading.putIfAbsent(key, () => false);
    _categoryHasMore.putIfAbsent(key, () => true);

    if (!_scrollControllers.containsKey(key)) {
      final controller = ScrollController();
      controller.addListener(() {
        if (!(_categoryHasMore[key] ?? true)) return;
        if (_categoryLoading[key] == true) return;
        if (!controller.hasClients) return;

        final pos = controller.position;
        if (pos.pixels >= pos.maxScrollExtent - 240) {
          _loadMoreCategory(desCatId, status: status);
        }
      });
      _scrollControllers[key] = controller;
    }
  }

  Future<void> _selectCategory(String desCatId) async {
    if (_selectedCatId == desCatId) return;

    setState(() => _selectedCatId = desCatId);
    await _prepareCategoryStatusState(desCatId, _selectedStatus);

    final key = _cacheKey(desCatId, _selectedStatus);
    if ((_categoryDescriptions[key] ?? []).isEmpty && _categoryPage[key] == 0) {
      await _loadPageForCategory(desCatId, status: _selectedStatus, page: 1, replace: true);
    }
  }

  Future<void> _selectStatus(String status) async {
    if (_selectedStatus == status) return;
    if (_selectedCatId == null) return;

    setState(() => _selectedStatus = status);
    await _prepareCategoryStatusState(_selectedCatId!, status);

    final key = _cacheKey(_selectedCatId!, status);
    if ((_categoryDescriptions[key] ?? []).isEmpty && _categoryPage[key] == 0) {
      await _loadPageForCategory(_selectedCatId!, status: status, page: 1, replace: true);
    }
  }

  Future<void> _loadPageForCategory(
    String desCatId, {
    required String status,
    required int page,
    bool replace = false,
  }) async {
    await _prepareCategoryStatusState(desCatId, status);

    final key = _cacheKey(desCatId, status);
    if (_categoryLoading[key] == true) return;

    _categoryLoading[key] = true;
    if (mounted) setState(() {});

    try {
      // Backend future format:
      // /get_description_by_cat?des_cat_id=1&description_status=live&page=1&page_size=10
      // If backend does not support description_status yet, it can ignore this parameter.
      final uri = '/get_description_by_cat?des_cat_id=$desCatId&description_status=$status&page=$page&page_size=$_pageSize';
      final resp = await Config.apiGet(uri, context);

      if (resp != null && resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final List newItems = (data['descriptions'] ?? []) as List;

        if (replace) {
          _categoryDescriptions[key] = List.from(newItems);
        } else {
          final existing = _categoryDescriptions[key] ?? [];
          _categoryDescriptions[key] = [...existing, ...newItems];
        }

        _categoryPage[key] = page;
        _categoryHasMore[key] = newItems.length >= _pageSize;
      } else {
        debugPrint('Failed to load descriptions for $desCatId page $page: ${resp?.statusCode}');
      }
    } catch (e) {
      debugPrint('Error loading descriptions for $desCatId page $page: $e');
    } finally {
      _categoryLoading[key] = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _refreshCurrentCategory() async {
    if (_selectedCatId == null) return;
    final key = _cacheKey(_selectedCatId!, _selectedStatus);
    _categoryHasMore[key] = true;
    _categoryPage[key] = 0;
    await _loadPageForCategory(
      _selectedCatId!,
      status: _selectedStatus,
      page: 1,
      replace: true,
    );
  }

  Future<void> _loadMoreCategory(String desCatId, {required String status}) async {
    final key = _cacheKey(desCatId, status);
    if (!(_categoryHasMore[key] ?? true)) return;
    final nextPage = (_categoryPage[key] ?? 0) + 1;
    await _loadPageForCategory(desCatId, status: status, page: nextPage, replace: false);
  }

  // --------------------------- Category UI ---------------------------

  Widget _compactHeader() {
    return Container(
      color: _bg,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _openCategorySheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _brandBlue.withOpacity(0.18)),
                        boxShadow: [
                          BoxShadow(
                            color: _brandBlue.withOpacity(0.07),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: _brandBlue.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.category_rounded, color: _brandBlue, size: 16),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedCategoryName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w900,
                                color: _brandBlue,
                              ),
                            ),
                          ),
                          Icon(Icons.keyboard_arrow_down_rounded, color: _brandBlue.withOpacity(0.7), size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black12.withOpacity(0.07)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _miniStatusTab(label: 'Live', value: 'live', color: _green),
                      _miniStatusTab(label: 'Solved', value: 'dead', color: _orange),
                      _miniStatusTab(label: 'All', value: 'all', color: _brandBlue),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _descriptionCategories.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                if (index == _descriptionCategories.length) {
                  return GestureDetector(
                    onTap: _openCategorySheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: _brandBlue.withOpacity(0.22)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.apps_rounded, size: 13, color: _brandBlue),
                          const SizedBox(width: 4),
                          Text(
                            'See all',
                            style: TextStyle(
                              color: _brandBlue,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final cat = _descriptionCategories[index];
                final id = cat['des_cat_id'].toString();
                final name = (cat['des_cat_name'] ?? '').toString();
                final selected = id == _selectedCatId;

                return GestureDetector(
                  onTap: () => _selectCategory(id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? _brandBlue : Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: selected ? _brandBlue : Colors.black12.withOpacity(0.10),
                      ),
                      boxShadow: selected
                          ? [BoxShadow(color: _brandBlue.withOpacity(0.22), blurRadius: 8, offset: const Offset(0, 3))]
                          : [],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (selected) ...[
                          const Icon(Icons.check_rounded, size: 13, color: Colors.white),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          name,
                          style: TextStyle(
                            color: selected ? Colors.white : Colors.black87,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openCategorySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.70,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (_, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Column(
                children: [
                  Container(
                    width: 46,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        height: 42,
                        width: 42,
                        decoration: BoxDecoration(
                          color: _brandBlue.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.dashboard_customize_outlined, color: _brandBlue),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'All Need Categories',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Choose any category clearly from the full list',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: GridView.builder(
                      controller: scrollController,
                      itemCount: _descriptionCategories.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 2.8,
                      ),
                      itemBuilder: (context, index) {
                        final cat = _descriptionCategories[index];
                        final id = cat['des_cat_id'].toString();
                        final name = (cat['des_cat_name'] ?? '').toString();
                        final selected = id == _selectedCatId;

                        return GestureDetector(
                          onTap: () async {
                            Navigator.pop(ctx);
                            await _selectCategory(id);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: selected ? _brandBlue : const Color(0xFFF7F9FF),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: selected ? _brandBlue : Colors.black12.withOpacity(0.07),
                              ),
                              boxShadow: selected ? [BoxShadow(color: _brandBlue.withOpacity(0.18), blurRadius: 14, offset: const Offset(0, 6))] : [],
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 13,
                                  backgroundColor: selected ? Colors.white24 : _brandBlue.withOpacity(0.10),
                                  child: Icon(
                                    selected ? Icons.check_rounded : Icons.category_outlined,
                                    size: 15,
                                    color: selected ? Colors.white : _brandBlue,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: selected ? Colors.white : Colors.black87,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --------------------------- Status UI ---------------------------

  Widget _miniStatusTab({required String label, required String value, required Color color}) {
    final selected = _selectedStatus == value;
    return GestureDetector(
      onTap: () => _selectStatus(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black54,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  // --------------------------- Post Card ---------------------------

  Widget _postCard(Map item) {
    final bool hasPhoto = (item['des_photo']?.toString().isNotEmpty ?? false) && item['des_photo'] != null;
    final userName = (item['user_name'] ?? 'Unknown').toString();
    final createdAt = item['time'];
    final formattedTime = Config.getTimeDifference(createdAt);
    final hasAvatar = (item['photo']?.toString().isNotEmpty ?? false);
    final catName = (item['cat_name'] ?? item['des_cat_name'] ?? '').toString();
    final descriptionStatus = (item['description_status'] ?? item['status'] ?? 'live').toString();

    final normalized = descriptionStatus.toLowerCase();
    final isSolved = normalized == 'dead' || normalized == 'solved' || normalized == 'inactive';
    final statusColor = isSolved ? _orange : _green;
    final statusLabel = isSolved ? 'Solved' : 'Live';
    final statusIcon = isSolved ? Icons.check_circle_rounded : Icons.bolt_rounded;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ThoughtDetails(desId: item['des_id'].toString()),
          ),
        );
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white,
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          boxShadow: [_softShadow],
        ),
        // ClipRRect trims the Positioned bar at the card's rounded corners.
        // Stack sizes itself to the non-positioned Padding child — no
        // IntrinsicHeight, no double layout pass, safe inside ListView.builder.
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17.5),
          child: Stack(
            children: [
              // Left status accent bar — stretches to Stack height via Positioned.
              Positioned(
                top: 0,
                left: 0,
                bottom: 0,
                child: Container(width: 4, color: statusColor),
              ),
              // Card content — left padding = normal 13 + 4 for the bar.
              Padding(
                padding: const EdgeInsets.fromLTRB(17, 13, 13, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row: avatar + name/meta + status badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        hasAvatar
                            ? CircleAvatar(
                                backgroundImage: NetworkImage(item['photo']),
                                radius: 20,
                              )
                            : const CircleAvatar(
                                backgroundColor: Color(0xFF90A4AE),
                                radius: 20,
                                child: Icon(Icons.person, color: Colors.white, size: 20),
                              ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  if (catName.isNotEmpty) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _brandBlue.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        catName,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: _brandBlue,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Expanded(
                                    child: Text(
                                      formattedTime.toString(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black38,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Status badge — top-right, prominent
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: statusColor.withValues(alpha: 0.28)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, size: 12, color: statusColor),
                              const SizedBox(width: 4),
                              Text(
                                statusLabel,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 11),
                    // Description
                    ExpandableText(
                      text: (item['des'] ?? '').toString(),
                      maxLines: 3,
                      style: const TextStyle(
                        fontSize: 14.5,
                        height: 1.5,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                      moreLabel: 'See more',
                      lessLabel: 'See less',
                      linkStyle: TextStyle(
                        fontSize: 13.5,
                        color: _brandBlue,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    // Photo
                    if (hasPhoto) ...[
                      const SizedBox(height: 11),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Image.network(
                            item['des_photo'],
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, st) => Container(
                              alignment: Alignment.center,
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.broken_image, color: Colors.grey),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 11),
                    // Footer: stats + tap hint
                    Row(
                      children: [
                        Icon(Icons.remove_red_eye_outlined, size: 15, color: Colors.black38),
                        const SizedBox(width: 4),
                        Text(
                          Config.formatLargeNumber(item['des_view'] ?? 0),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black45,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Icon(Icons.chat_bubble_outline_rounded, size: 14, color: Colors.black38),
                        const SizedBox(width: 4),
                        Text(
                          Config.formatLargeNumber(item['des_com'] ?? 0),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black45,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        const Icon(Icons.chevron_right_rounded, color: Colors.black26, size: 20),
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

  // --------------------------- Empty / Loading ---------------------------

  Widget _alwaysScrollableEmpty({
    required bool loading,
    required String title,
    required String subtitle,
  }) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.58,
        child: Center(
          child: loading
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 34,
                      width: 34,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Loading posts…',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              : Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [_softShadow],
                    border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 56,
                        width: 56,
                        decoration: BoxDecoration(
                          color: _brandBlue.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _brandBlue.withOpacity(0.22)),
                        ),
                        child: Icon(Icons.inbox_outlined, color: _brandBlue, size: 28),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.35,
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F7FF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.keyboard_arrow_down, size: 20, color: Colors.black45),
                            SizedBox(width: 6),
                            Text(
                              'Pull down to refresh',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: Colors.black54,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _noCategoriesView() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(18),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [_softShadow],
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 56,
              width: 56,
              decoration: BoxDecoration(
                color: _brandBlue.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.category_outlined, color: _brandBlue, size: 28),
            ),
            const SizedBox(height: 12),
            const Text(
              'No categories available',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Please try again later.',
              style: TextStyle(
                fontSize: 13.5,
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------- Build ---------------------------

  @override
  Widget build(BuildContext context) {
    if (_descLoading && _descriptionCategories.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFFE3F2FD),
        body: SizedBox.shrink(),
      );
    }

    if (_descriptionCategories.isEmpty || _selectedCatId == null) {
      return Scaffold(
        backgroundColor: _bg,
        body: _noCategoriesView(),
      );
    }

    final currentKey = _cacheKey(_selectedCatId!, _selectedStatus);
    final List descriptions = _categoryDescriptions[currentKey] ?? [];
    final bool loading = _categoryLoading[currentKey] ?? false;
    final bool hasMore = _categoryHasMore[currentKey] ?? false;
    final controller = _scrollControllers[currentKey];

    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _compactHeader(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshCurrentCategory,
              color: _brandBlue,
              child: descriptions.isEmpty
                  ? _alwaysScrollableEmpty(
                      loading: loading,
                      title: _selectedStatus == 'live'
                          ? 'No live need posts here'
                          : _selectedStatus == 'dead'
                              ? 'No solved posts here'
                              : 'Nothing here yet',
                      subtitle: 'No posts available in $_selectedCategoryName.\nPull down to refresh.',
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      controller: controller,
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                      itemCount: descriptions.length + (hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index < descriptions.length) {
                          final item = descriptions[index] as Map;
                          return _postCard(item);
                        }

                        final loadingMore = _categoryLoading[currentKey] ?? false;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          child: Center(
                            child: loadingMore
                                ? const SizedBox(
                                    height: 30,
                                    width: 30,
                                    child: CircularProgressIndicator(strokeWidth: 3),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
