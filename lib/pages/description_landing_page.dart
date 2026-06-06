import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart' show Ticker;
import 'package:aaram_bd/config.dart';
import 'package:aaram_bd/screens/thoughtdetails.dart';
import 'package:aaram_bd/widgets/thoughtsection.dart';
import 'package:flutter/material.dart';

final String host = Config.host;

class DescriptionLandingPage extends StatefulWidget {
  final VoidCallback? onLoaded;

  const DescriptionLandingPage({Key? key, this.onLoaded}) : super(key: key);

  @override
  State<DescriptionLandingPage> createState() => _DescriptionLandingPageState();
}

/* ─────────────────────── ExpandableText (unchanged) ─────────────────────── */
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
      _expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
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

/* ─────────────────────── Main State ─────────────────────── */

class _DescriptionLandingPageState extends State<DescriptionLandingPage> {
  /* ── existing data state (unchanged) ── */
  List _descriptionCategories = [];
  final Map<String, List> _categoryDescriptions = {};
  final Map<String, int> _categoryPage = {};
  final Map<String, bool> _categoryLoading = {};
  final Map<String, bool> _categoryHasMore = {};
  final Map<String, ScrollController> _scrollControllers = {};
  bool _descLoading = true;
  bool _didNotifyLoaded = false;
  String? _selectedCatId;
  String _selectedStatus = 'live';
  static const int _pageSize = 10;

  /* ── search ── */
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  /* ── collapsible header ── */
  bool _headerExpanded = true;

  /* ── colors ── */
  static const Color _brandBlue = Color(0xFF1A56DB);
  static const Color _bg = Color(0xFFF3F7FF);
  static const Color _green = Color(0xFF16A34A);
  static const Color _orange = Color(0xFFF97316);
  static const BoxShadow _softShadow = BoxShadow(
    color: Color(0x10000000),
    blurRadius: 16,
    offset: Offset(0, 6),
  );

  /* ── derived ── */
  List get _filteredCategories {
    final sorted = [..._descriptionCategories]
      ..sort((a, b) => (a['des_cat_name'] ?? '')
          .toString()
          .compareTo((b['des_cat_name'] ?? '').toString()));

    if (_searchQuery.isEmpty) return sorted;

    final exact = sorted
        .where((c) => (c['des_cat_name'] ?? '')
            .toString()
            .toLowerCase()
            .contains(_searchQuery))
        .toList();

    if (exact.isNotEmpty) {
      return _appendNearby(sorted, exact);
    }

    return _alphabeticallyNearest(sorted, _searchQuery);
  }

  List _appendNearby(List sorted, List matched) {
    final ids = matched.map((c) => c['des_cat_id'].toString()).toSet();
    int lastIdx = 0;
    for (int i = 0; i < sorted.length; i++) {
      if (ids.contains(sorted[i]['des_cat_id'].toString())) lastIdx = i;
    }
    final nearby = <dynamic>[];
    for (int i = lastIdx + 1; i < sorted.length && nearby.length < 3; i++) {
      if (!ids.contains(sorted[i]['des_cat_id'].toString())) {
        nearby.add(sorted[i]);
      }
    }
    return [...matched, ...nearby];
  }

  List _alphabeticallyNearest(List sorted, String query) {
    if (sorted.isEmpty) return sorted;
    int insertAt = sorted.length;
    for (int i = 0; i < sorted.length; i++) {
      if ((sorted[i]['des_cat_name'] ?? '')
              .toString()
              .toLowerCase()
              .compareTo(query) >=
          0) {
        insertAt = i;
        break;
      }
    }
    final start = (insertAt - 2).clamp(0, sorted.length);
    final end = (start + 5).clamp(0, sorted.length);
    return sorted.sublist(start, end);
  }

  String get _selectedCategoryName {
    if (_selectedCatId == null) return 'Select category';
    final cat = _descriptionCategories.firstWhere(
      (e) => e['des_cat_id'].toString() == _selectedCatId,
      orElse: () => {},
    );
    return (cat['des_cat_name'] ?? 'Category').toString();
  }

  /* ── lifecycle ── */
  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final q = _searchController.text.toLowerCase().trim();
      if (q != _searchQuery) setState(() => _searchQuery = q);
    });
    fetchDescriptionData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (final c in _scrollControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /* ────────────────────── Logic (all unchanged) ────────────────────── */

  void _notifyLoadedOnce() {
    if (_didNotifyLoaded) return;
    _didNotifyLoaded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onLoaded?.call();
    });
  }

  String _cacheKey(String desCatId, String status) => '$desCatId::$status';

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

  Future<void> _prepareCategoryStatusState(
      String desCatId, String status) async {
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
    if ((_categoryDescriptions[key] ?? []).isEmpty &&
        _categoryPage[key] == 0) {
      await _loadPageForCategory(desCatId,
          status: _selectedStatus, page: 1, replace: true);
    }
  }

  Future<void> _selectStatus(String status) async {
    if (_selectedStatus == status) return;
    if (_selectedCatId == null) return;
    setState(() => _selectedStatus = status);
    await _prepareCategoryStatusState(_selectedCatId!, status);
    final key = _cacheKey(_selectedCatId!, status);
    if ((_categoryDescriptions[key] ?? []).isEmpty &&
        _categoryPage[key] == 0) {
      await _loadPageForCategory(_selectedCatId!,
          status: status, page: 1, replace: true);
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
      final uri =
          '/get_description_by_cat?des_cat_id=$desCatId&description_status=$status&page=$page&page_size=$_pageSize';
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

  Future<void> _loadMoreCategory(String desCatId,
      {required String status}) async {
    final key = _cacheKey(desCatId, status);
    if (!(_categoryHasMore[key] ?? true)) return;
    final nextPage = (_categoryPage[key] ?? 0) + 1;
    await _loadPageForCategory(desCatId,
        status: status, page: nextPage, replace: false);
  }

  /* ────────────────────── UI Builders ────────────────────── */

  /* 1 ── Search Bar */
  Widget _buildSearchBar() {
    final active = _searchQuery.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active
                ? _brandBlue.withValues(alpha: 0.40)
                : Colors.black.withValues(alpha: 0.08),
            width: active ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: 'Search categories…',
            hintStyle: TextStyle(
              color: Colors.black.withValues(alpha: 0.32),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 14, right: 8),
              child: Icon(Icons.search_rounded, color: _brandBlue, size: 21),
            ),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 48, minHeight: 48),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (active)
                  GestureDetector(
                    onTap: _searchController.clear,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(Icons.close_rounded,
                          size: 17, color: Colors.black38),
                    ),
                  ),
                GestureDetector(
                  onTap: _openCategorySheet,
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: _brandBlue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.grid_view_rounded,
                            size: 11, color: _brandBlue),
                        const SizedBox(width: 4),
                        Text(
                          'See all',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _brandBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
          ),
        ),
      ),
    );
  }

  /* 2 ── Sphere Carousel — bare, no container */
  Widget _buildSphereCarousel() {
    return _SphereCarousel(
      categories: _filteredCategories,
      selectedCatId: _selectedCatId,
      brandBlue: _brandBlue,
      onSelect: (id) => _selectCategory(id),
      onBrowseAll: null,
    );
  }

  /* 3 ── Collapsible wrapper for search bar + sphere carousel
     Uses ClipRect + AnimatedAlign(heightFactor) for a clean slide
     animation — content slides up into nothing when collapsing and
     slides back down when expanding. No fade, no opacity tricks. */
  // _headerExpanded is the single source of truth.
  // Auto-collapse happens in _loadPageForCategory (empty result).
  // The icon button in _buildSectionHeader is the only manual toggle.
  Widget _buildCollapsibleHeader() {
    return ClipRect(
      child: AnimatedAlign(
        alignment: Alignment.topCenter,
        heightFactor: _headerExpanded ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSearchBar(),
            const SizedBox(height: 4),
            _buildSphereCarousel(),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }


  /* 4 ── Section Header (category name + count) */
  Widget _buildSectionHeader(int count, bool loading) {
    final isPast = _selectedStatus == 'dead';
    final canToggle = !loading;
    final statusColor = isPast ? _green : _brandBlue;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: const [_softShadow],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [

          // ── Toggle button — circular, fills blue when collapsed ──────────
          GestureDetector(
            onTap: canToggle
                ? () => setState(() => _headerExpanded = !_headerExpanded)
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _headerExpanded
                    ? _brandBlue.withValues(alpha: 0.08)
                    : _brandBlue,
                border: Border.all(
                  color: _headerExpanded
                      ? _brandBlue.withValues(alpha: 0.22)
                      : _brandBlue,
                  width: 1.5,
                ),
                boxShadow: _headerExpanded
                    ? []
                    : [
                        BoxShadow(
                          color: _brandBlue.withValues(alpha: 0.38),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
              ),
              child: Center(
                child: AnimatedRotation(
                  turns: _headerExpanded ? 0.0 : 0.5,
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  child: Icon(
                    Icons.keyboard_arrow_up_rounded,
                    color: _headerExpanded ? _brandBlue : Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // ── Category name + status badge ─────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated name — slides + fades when category changes
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  transitionBuilder: (child, anim) {
                    final slide = Tween<Offset>(
                      begin: const Offset(0.0, 0.35),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                        parent: anim, curve: Curves.easeOutCubic));
                    return FadeTransition(
                      opacity: anim,
                      child: SlideTransition(position: slide, child: child),
                    );
                  },
                  child: Row(
                    key: ValueKey(_selectedCatId),
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Status dot
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: statusColor,
                          boxShadow: [
                            BoxShadow(
                              color: statusColor.withValues(alpha: 0.45),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          _selectedCategoryName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: Colors.black87,
                            letterSpacing: -0.3,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 4),

                // Count / loading indicator
                if (loading)
                  Row(
                    children: [
                      SizedBox(
                        height: 9,
                        width: 9,
                        child: CircularProgressIndicator(
                            strokeWidth: 1.5, color: _brandBlue),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Loading posts…',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: _brandBlue.withValues(alpha: 0.55),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                else
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    child: count > 0
                        ? Container(
                            key: ValueKey(count),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(
                                  color: statusColor.withValues(alpha: 0.20)),
                            ),
                            child: Text(
                              '$count ${isPast ? 'visited' : 'active'} post${count == 1 ? '' : 's'}',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: statusColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        : Text(
                            key: const ValueKey('empty'),
                            'No posts yet',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Colors.black.withValues(alpha: 0.28),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // ── Post button — gradient, glowing, two-line label ─────────────
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    NeedBuilderPage(initialCatId: _selectedCatId),
              ),
            ),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF2563EB),
                    Color(0xFF1A56DB),
                    Color(0xFF3B7CF6),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: _brandBlue.withValues(alpha: 0.48),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: _brandBlue.withValues(alpha: 0.15),
                    blurRadius: 32,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon bubble
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Post',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                          height: 1.15,
                        ),
                      ),
                      Text(
                        'Share now',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.1,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /* 5 ── Task Card
     Navigation is ONLY through the VISIT button.
     The card itself is not tappable — avoids accidental navigation
     and makes the CTA intentional.                                     */
  Widget _taskCard(Map item) {
    final bool hasPhoto = (item['des_photo']?.toString().isNotEmpty ?? false) &&
        item['des_photo'] != null;
    final userName   = (item['user_name'] ?? 'Unknown').toString();
    final timeStr    = Config.getTimeDifference(item['time']).toString();
    final hasAvatar  = item['photo']?.toString().isNotEmpty ?? false;
    final descStatus = (item['description_status'] ?? item['status'] ?? 'live')
        .toString()
        .toLowerCase();

    final isVisited  = descStatus == 'dead' ||
        descStatus == 'solved' ||
        descStatus == 'inactive';
    final accentColor = isVisited ? _green : _brandBlue;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isVisited ? const Color(0xFFF8FBFF) : Colors.white,
        border: Border.all(
          color: isVisited
              ? _green.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: [_softShadow],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15.5),
        // Left accent bar via Border.only — no Stack/Positioned needed.
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: accentColor, width: 4)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(13, 13, 13, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Row 1: status pill + posted time ──────────────────────
                Row(
                  children: [
                    // Status pill — communicates task state at a glance
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: accentColor.withValues(alpha: 0.22)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isVisited
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_checked_rounded,
                            size: 10,
                            color: accentColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isVisited ? 'VISITED' : 'ACTIVE',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: accentColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Timestamp
                    Text(
                      timeStr,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black38,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // ── Row 2: description (the task content, hero) ───────────
                ExpandableText(
                  text: (item['des'] ?? '').toString(),
                  maxLines: 3,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.55,
                    color: isVisited ? Colors.black54 : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                  moreLabel: 'See more',
                  lessLabel: 'See less',
                  linkStyle: const TextStyle(
                    fontSize: 13,
                    color: _brandBlue,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                // ── Optional photo ─────────────────────────────────────────
                if (hasPhoto) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(
                        item['des_photo'],
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade100,
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image,
                              color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // ── Thin rule — separates content from footer ──────────────
                Container(
                  height: 1,
                  color: Colors.black.withValues(alpha: 0.06),
                ),

                const SizedBox(height: 10),

                // ── Footer: avatar + name + stats + VISIT button ───────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Author avatar
                    hasAvatar
                        ? CircleAvatar(
                            backgroundImage: NetworkImage(item['photo']),
                            radius: 12,
                          )
                        : const CircleAvatar(
                            backgroundColor: Color(0xFFB0BEC5),
                            radius: 12,
                            child: Icon(Icons.person,
                                color: Colors.white, size: 12),
                          ),
                    const SizedBox(width: 6),
                    // Author name
                    Expanded(
                      child: Text(
                        userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isVisited
                              ? Colors.black38
                              : Colors.black54,
                        ),
                      ),
                    ),
                    // View count
                    const Icon(Icons.remove_red_eye_outlined,
                        size: 12, color: Colors.black26),
                    const SizedBox(width: 3),
                    Text(
                      Config.formatLargeNumber(item['des_view'] ?? 0),
                      style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black38,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    // Comment count
                    const Icon(Icons.chat_bubble_outline_rounded,
                        size: 11, color: Colors.black26),
                    const SizedBox(width: 3),
                    Text(
                      Config.formatLargeNumber(item['des_com'] ?? 0),
                      style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black38,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 10),

                    // ── VISIT button — the ONLY navigation trigger ─────────
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ThoughtDetails(
                              desId: item['des_id'].toString()),
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          // Muted for visited tasks, branded for active ones
                          color: isVisited
                              ? const Color(0xFFEEF0F4)
                              : _brandBlue,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: isVisited
                              ? []
                              : [
                                  BoxShadow(
                                    color:
                                        _brandBlue.withValues(alpha: 0.28),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'VISIT',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                color: isVisited
                                    ? Colors.black45
                                    : Colors.white,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 12,
                              color: isVisited
                                  ? Colors.black38
                                  : Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

              ],
            ),
          ),
        ),
      ),
    );
  }

  /* 6 ── Category Bottom Sheet */
  void _openCategorySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CategorySheet(
        categories: _descriptionCategories,
        selectedCatId: _selectedCatId,
        brandBlue: _brandBlue,
        onSelect: (id) async {
          Navigator.pop(context);
          await _selectCategory(id);
        },
      ),
    );
  }

  /* 7 ── Empty States */
  Widget _emptyStateCard({
    required IconData icon,
    required String title,
    required String subtitle,
    bool showRefreshHint = true,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 22),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [_softShadow],
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              color: _brandBlue.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _brandBlue.withValues(alpha: 0.18)),
            ),
            child: Icon(icon, color: _brandBlue, size: 28),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: Colors.black54,
                fontWeight: FontWeight.w600),
          ),
          if (showRefreshHint) ...[
            const SizedBox(height: 18),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F7FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.keyboard_arrow_down,
                      size: 18, color: Colors.black38),
                  SizedBox(width: 6),
                  Text('Pull down to refresh',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.black45,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _alwaysScrollableEmpty({
    required bool loading,
    required String title,
    required String subtitle,
  }) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.50,
        child: Center(
          child: loading
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 32,
                      width: 32,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: _brandBlue),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Loading posts…',
                      style: TextStyle(
                          fontSize: 13.5,
                          color: Colors.black45,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                )
              : _emptyStateCard(
                  icon: Icons.inbox_outlined,
                  title: title,
                  subtitle: subtitle),
        ),
      ),
    );
  }

  // Shown when a category has zero posts and is not loading.
  // Replaces all negative "nothing here" messages with an invitation to post.
  Widget _buildFirstPostInvite() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 48, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Friendly icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _brandBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _brandBlue.withValues(alpha: 0.15)),
              ),
              child: const Icon(Icons.emoji_people_rounded,
                  color: _brandBlue, size: 32),
            ),

            const SizedBox(height: 18),

            // Encouraging headline
            Text(
              'Be the first in $_selectedCategoryName!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
                height: 1.3,
              ),
            ),

            const SizedBox(height: 10),

            // Subtitle — no negative framing
            const Text(
              'No one has shared here yet.\nYour post could be exactly what\nsomeone is looking for.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.6,
                color: Colors.black45,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 32),

            // Tappable pseudo-text-field → navigates to NeedBuilderPage
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      NeedBuilderPage(initialCatId: _selectedCatId),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: _brandBlue.withValues(alpha: 0.30)),
                  boxShadow: [_softShadow],
                ),
                child: Row(
                  children: [
                    Icon(Icons.edit_note_rounded,
                        color: _brandBlue.withValues(alpha: 0.60), size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Write something for $_selectedCategoryName…',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black.withValues(alpha: 0.32),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Post button hint
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: _brandBlue,
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: [
                          BoxShadow(
                            color: _brandBlue.withValues(alpha: 0.28),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Text(
                        'Post',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Subtle pull-to-refresh hint
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.arrow_downward_rounded,
                    size: 13, color: Colors.black26),
                SizedBox(width: 5),
                Text(
                  'Pull down to refresh',
                  style: TextStyle(fontSize: 12, color: Colors.black26),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _noCategoriesView() {
    return Center(
      child: _emptyStateCard(
        icon: Icons.category_outlined,
        title: 'No categories available',
        subtitle: 'Please try again later.',
        showRefreshHint: false,
      ),
    );
  }

  /* ─────────────────────── Build ─────────────────────── */

  @override
  Widget build(BuildContext context) {
    if (_descLoading && _descriptionCategories.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFFE3F2FD),
        body: SizedBox.shrink(),
      );
    }
    if (_descriptionCategories.isEmpty || _selectedCatId == null) {
      return Scaffold(backgroundColor: _bg, body: _noCategoriesView());
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
          _buildCollapsibleHeader(),
          _buildSectionHeader(descriptions.length, loading),
          Expanded(
            child: RefreshIndicator(
                onRefresh: _refreshCurrentCategory,
                color: _brandBlue,
                child: descriptions.isEmpty
                  // Loading → spinner; truly empty → invitation to post first
                  ? (loading
                      ? _alwaysScrollableEmpty(
                          loading: true,
                          title: '',
                          subtitle: '')
                      : _buildFirstPostInvite())
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      controller: controller,
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      itemCount: descriptions.length + (hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index < descriptions.length) {
                          return _taskCard(descriptions[index] as Map);
                        }
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: (_categoryLoading[currentKey] ?? false)
                                ? SizedBox(
                                    height: 28,
                                    width: 28,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: _brandBlue),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        );
                      },
                    ),
              ),        // closes RefreshIndicator
          ),            // closes Expanded
        ],
      ),
    );
  }
}

/* ─────────────────────── Category Bottom Sheet ─────────────────────── */
class _CategorySheet extends StatefulWidget {
  final List categories;
  final String? selectedCatId;
  final Color brandBlue;
  final void Function(String id) onSelect;

  const _CategorySheet({
    required this.categories,
    required this.selectedCatId,
    required this.brandBlue,
    required this.onSelect,
  });

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  final TextEditingController _ctrl = TextEditingController();
  String _query = '';

  List get _filtered {
    final sorted = [...widget.categories]
      ..sort((a, b) => (a['des_cat_name'] ?? '')
          .toString()
          .compareTo((b['des_cat_name'] ?? '').toString()));
    if (_query.isEmpty) return sorted;
    return sorted
        .where((c) =>
            (c['des_cat_name'] ?? '').toString().toLowerCase().contains(_query))
        .toList();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final blue = widget.brandBlue;
    final cats = _filtered;

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(
            children: [
              /* drag handle */
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 14),
              /* sheet header */
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Container(
                      height: 42,
                      width: 42,
                      decoration: BoxDecoration(
                        color: blue.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.dashboard_customize_outlined,
                          color: blue),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('All Categories',
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black87)),
                          SizedBox(height: 2),
                          Text('Search and select a category',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black54)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              /* search inside sheet */
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F7FF),
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: Colors.black.withValues(alpha: 0.07)),
                  ),
                  child: TextField(
                    controller: _ctrl,
                    onChanged: (v) =>
                        setState(() => _query = v.toLowerCase().trim()),
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Search categories…',
                      hintStyle: const TextStyle(
                          fontSize: 13.5, color: Colors.black38),
                      prefixIcon:
                          Icon(Icons.search_rounded, color: blue, size: 19),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 16),
                              color: Colors.black38,
                              splashRadius: 16,
                              onPressed: () {
                                _ctrl.clear();
                                setState(() => _query = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 13),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              /* grid or empty */
              Expanded(
                child: cats.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.search_off_rounded,
                                size: 42, color: Colors.black26),
                            const SizedBox(height: 10),
                            Text(
                              'No results for "$_query"',
                              style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black45,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: cats.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 2.8,
                        ),
                        itemBuilder: (context, index) {
                          final cat = cats[index];
                          final id = cat['des_cat_id'].toString();
                          final name =
                              (cat['des_cat_name'] ?? '').toString();
                          final selected = id == widget.selectedCatId;

                          return GestureDetector(
                            onTap: () => widget.onSelect(id),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: selected
                                    ? blue
                                    : const Color(0xFFF7F9FF),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: selected
                                      ? blue
                                      : Colors.black.withValues(alpha: 0.07),
                                ),
                                boxShadow: selected
                                    ? [
                                        BoxShadow(
                                            color: blue.withValues(alpha: 0.18),
                                            blurRadius: 14,
                                            offset: const Offset(0, 6))
                                      ]
                                    : [],
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 13,
                                    backgroundColor: selected
                                        ? Colors.white24
                                        : blue.withValues(alpha: 0.10),
                                    child: Icon(
                                      selected
                                          ? Icons.check_rounded
                                          : Icons.category_outlined,
                                      size: 14,
                                      color: selected ? Colors.white : blue,
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: selected
                                            ? Colors.white
                                            : Colors.black87,
                                        fontSize: 12.5,
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
  }
}

/* ═══════════════════════════════════════════════════════════════
   Sphere Globe Carousel  –  premium equatorial category selector
   ═══════════════════════════════════════════════════════════════ */
class _SphereCarousel extends StatefulWidget {
  final List categories;
  final String? selectedCatId;
  final Color brandBlue;
  final void Function(String id) onSelect;
  final VoidCallback? onBrowseAll;

  const _SphereCarousel({
    required this.categories,
    required this.selectedCatId,
    required this.brandBlue,
    required this.onSelect,
    this.onBrowseAll,
  });

  @override
  State<_SphereCarousel> createState() => _SphereCarouselState();
}

class _SphereCarouselState extends State<_SphereCarousel>
    with SingleTickerProviderStateMixin {

  /* ── physics state ── */
  double _rotation   = 0.0;
  double _velocity   = 0.0;
  bool   _isDragging = false;

  double _snapTarget   = 0.0;
  bool   _snapAnimating = false;

  late Ticker _ticker;
  Duration    _prevElapsed = Duration.zero;

  /* ── drag velocity sampling ── */
  DateTime _lastDragTime = DateTime.now();

  /* ── tuning ── */
  static const double _frictionPerMs  = 0.9970;
  static const double _springK        = 0.0130;
  static const double _stopThreshold  = 0.000030;

  /* ── lifecycle ── */
  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    _jumpToSelected();
  }

  @override
  void didUpdateWidget(_SphereCarousel old) {
    super.didUpdateWidget(old);
    final catsChanged = old.categories.length != widget.categories.length ||
        (old.categories.isNotEmpty &&
         widget.categories.isNotEmpty &&
         old.categories.first['des_cat_id'] !=
             widget.categories.first['des_cat_id']);
    if (catsChanged || old.selectedCatId != widget.selectedCatId) {
      _animateToSelected();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  /* ── helpers ── */
  double _angleDiff(double target, double from) {
    double d = target - from;
    while (d >  math.pi) { d -= 2 * math.pi; }
    while (d < -math.pi) { d += 2 * math.pi; }
    return d;
  }

  int _nearestIndex() {
    final n = widget.categories.length;
    if (n == 0) return 0;
    final step = 2 * math.pi / n;
    return ((-_rotation / step).round() % n + n) % n;
  }

  void _jumpToSelected() {
    final n = widget.categories.length;
    if (n == 0) return;
    final idx = widget.categories
        .indexWhere((c) => c['des_cat_id']?.toString() == widget.selectedCatId);
    if (idx < 0) return;
    _rotation = -(idx * 2 * math.pi / n);
  }

  void _animateToSelected() {
    final n = widget.categories.length;
    if (n == 0) return;
    final idx = widget.categories
        .indexWhere((c) => c['des_cat_id']?.toString() == widget.selectedCatId);
    if (idx < 0) { _jumpToSelected(); return; }
    final target = -(idx * 2 * math.pi / n);
    final diff   = _angleDiff(target, _rotation);
    if (diff.abs() < 0.02) return;
    _snapTarget   = _rotation + diff;
    _snapAnimating = true;
    _velocity      = 0;
  }

  void _notifySelection() {
    final n = widget.categories.length;
    if (n == 0) return;
    final cat = widget.categories[_nearestIndex()];
    final id  = cat['des_cat_id']?.toString() ?? '';
    if (id.isNotEmpty && id != widget.selectedCatId) widget.onSelect(id);
  }

  /* ── ticker ── */
  void _onTick(Duration elapsed) {
    final dtRaw = (elapsed - _prevElapsed).inMicroseconds / 1000.0;
    _prevElapsed = elapsed;
    final dt = dtRaw.clamp(0.0, 50.0);
    if (_isDragging || dt <= 0) return;

    if (_snapAnimating) {
      _doSnap(dt);
    } else if (_velocity.abs() > _stopThreshold) {
      _doInertia(dt);
    }
  }

  void _doInertia(double dt) {
    setState(() {
      _rotation += _velocity * dt;
      _velocity *= math.pow(_frictionPerMs, dt);
    });
    _notifySelection();
    if (_velocity.abs() <= _stopThreshold) {
      _velocity = 0;
      _beginSnap();
    }
  }

  void _beginSnap() {
    final n = widget.categories.length;
    if (n == 0) return;
    final step = 2 * math.pi / n;
    final idx  = _nearestIndex();
    final diff = _angleDiff(-idx * step, _rotation);
    _snapTarget   = _rotation + diff;
    _snapAnimating = true;
  }

  void _doSnap(double dt) {
    final diff = _snapTarget - _rotation;
    if (diff.abs() < 0.0008) {
      setState(() { _rotation = _snapTarget; _snapAnimating = false; });
        _notifySelection();
      return;
    }
    setState(() {
      _rotation += diff * (1.0 - math.exp(-_springK * dt));
    });
    _notifySelection();
  }

  /* ── drag ── */
  void _onDragStart(DragStartDetails d) {
    _isDragging    = true;
    _snapAnimating = false;
    _velocity      = 0;
    _lastDragTime  = DateTime.now();
  }

  void _onDragUpdate(DragUpdateDetails d, double R) {
    final now = DateTime.now();
    final dt  = now.difference(_lastDragTime).inMicroseconds / 1000.0;
    if (dt > 0) _velocity = (d.delta.dx / R) / dt;
    _lastDragTime = now;
    setState(() => _rotation += d.delta.dx / R);
    _notifySelection();
  }

  void _onDragEnd(DragEndDetails _) {
    _isDragging  = false;
    _prevElapsed = _prevElapsed;
  }

  /* ── build ── */
  @override
  Widget build(BuildContext context) {
    const double h = 76.0;
    return LayoutBuilder(builder: (_, box) {
      final w = box.maxWidth;
      final R = w * 0.39;

      return GestureDetector(
        onHorizontalDragStart: _onDragStart,
        onHorizontalDragUpdate: (d) => _onDragUpdate(d, R),
        onHorizontalDragEnd: _onDragEnd,
        child: SizedBox(
          height: h,
          width: w,
          child: ClipRect(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Active-slot pill — subtle indicator on plain background
                Positioned(
                  left: w / 2 - 72,
                  top: h / 2 - 24,
                  child: Container(
                    width: 144,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: widget.brandBlue.withValues(alpha: 0.07),
                      border: Border.all(
                        color: widget.brandBlue.withValues(alpha: 0.20),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                ..._buildItems(w, h, R),
              ],
            ),
          ),
        ),
      );
    });
  }

  /* ── item widgets ── */
  List<Widget> _buildItems(double w, double h, double R) {
    final n = widget.categories.length;
    if (n == 0) return [];

    final cx   = w / 2;
    final step = 2 * math.pi / n;

    final items = <Map<String, dynamic>>[];
    for (int i = 0; i < n; i++) {
      final ang   = _rotation + i * step;
      final depth = math.cos(ang);
      if (depth < -0.05) continue;

      final x = cx + R * math.sin(ang);
      final scale   = 0.38 + 0.62 * depth.clamp(0.0, 1.0);
      final opacity = (0.28 + 0.72 * depth.clamp(0.0, 1.0)).clamp(0.0, 1.0);

      items.add({
        'i': i, 'x': x,
        'depth': depth, 'scale': scale, 'opacity': opacity,
        'cat': widget.categories[i],
      });
    }

    items.sort((a, b) =>
        (a['depth'] as double).compareTo(b['depth'] as double));

    const chipW = 138.0;
    const chipH = 44.0;

    return items.map((item) {
      final cat      = item['cat'] as Map;
      final name     = (cat['des_cat_name'] ?? '').toString();
      final id       = (cat['des_cat_id'] ?? '').toString();
      final depth    = item['depth'] as double;
      final x        = item['x'] as double;
      final scale    = item['scale'] as double;
      final opacity  = item['opacity'] as double;
      // Three depth zones drive three distinct visual tiers:
      //   front  (depth > 0.88) → clearly in focus
      //   mid    (depth > 0.50) → visible, secondary
      //   edge   (depth ≤ 0.50) → ambient, hint of content
      final isCenter = depth > 0.88;
      final isMid    = depth > 0.50;
      final isSel    = id == widget.selectedCatId;

      // ── Chip appearance per tier ──────────────────────────────────
      final Color chipBg;
      final Color chipBorderColor;
      final Color textColor;
      final List<BoxShadow>? chipShadow;

      if (isCenter && isSel) {
        // Selected + centred: filled brand blue, white text, glow
        chipBg          = widget.brandBlue;
        chipBorderColor = widget.brandBlue;
        textColor       = Colors.white;
        chipShadow      = [
          BoxShadow(
            color: widget.brandBlue.withValues(alpha: 0.55),
            blurRadius: 24,
            offset: const Offset(0, 7),
            spreadRadius: 1,
          ),
          BoxShadow(
            color: widget.brandBlue.withValues(alpha: 0.18),
            blurRadius: 44,
            offset: Offset.zero,
          ),
        ];
      } else if (isCenter) {
        // Centred but not selected: white card, brand-blue text
        chipBg          = Colors.white;
        chipBorderColor = const Color(0xFFDDE6FF);
        textColor       = widget.brandBlue;
        chipShadow      = [
          const BoxShadow(
            color: Color(0x24000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ];
      } else if (isMid) {
        // Mid-depth: translucent white, readable dark text
        chipBg          = Colors.white.withValues(alpha: 0.88);
        chipBorderColor = Colors.white.withValues(alpha: 0.60);
        textColor       = const Color(0xFF374151);
        chipShadow      = null;
      } else {
        // Edge: ghost, just enough to hint category name exists
        chipBg          = Colors.white.withValues(alpha: 0.55);
        chipBorderColor = Colors.white.withValues(alpha: 0.35);
        textColor       = const Color(0xFF6B7280);
        chipShadow      = null;
      }

      final chip = Container(
        width: chipW,
        height: chipH,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: (isCenter && isSel) ? null : chipBg,
          gradient: (isCenter && isSel)
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    widget.brandBlue,
                    Color.lerp(widget.brandBlue, const Color(0xFF5B9AEE), 0.45)!,
                  ],
                )
              : null,
          borderRadius: BorderRadius.circular(isCenter ? 22 : 17),
          border: Border.all(
            color: chipBorderColor,
            width: isCenter ? 1.8 : 1.0,
          ),
          boxShadow: chipShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textColor,
              fontSize: isCenter ? 15.0 : isMid ? 13.5 : 12.0,
              fontWeight: isCenter ? FontWeight.w800 : FontWeight.w600,
              letterSpacing: isCenter ? 0.3 : 0,
            ),
          ),
        ),
      );

      return Positioned(
        left: x - chipW * scale / 2,
        top: h / 2 - chipH * scale / 2,
        child: Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: () {
                widget.onSelect(id);
                final n2   = widget.categories.length;
                if (n2 == 0) return;
                final diff = _angleDiff(-(item['i'] as int) * 2 * math.pi / n2,
                    _rotation);
                setState(() {
                  _snapTarget   = _rotation + diff;
                  _snapAnimating = true;
                  _velocity      = 0;
                });
              },
              child: chip,
            ),
          ),
        ),
      );
    }).toList();
  }
}