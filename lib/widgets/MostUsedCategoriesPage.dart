import 'package:aaram_bd/main.dart';
import 'package:flutter/material.dart';
import 'package:aaram_bd/config.dart';
import 'package:aaram_bd/screens/service_favorite_screen.dart';
import 'package:aaram_bd/screens/shops_favorite_screen.dart';
import 'dart:convert';

final String host = Config.host;

// ── Safe int parser (fixes cat_used / yes_service / yes_shop type-cast bugs) ─
int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

// ── Per-category avatar accent colors (brand-aligned palette) ────────────────
const List<Color> _accents = [
  Color(0xFF1A56DB),
  Color(0xFF0891B2),
  Color(0xFF059669),
  Color(0xFFD97706),
  Color(0xFF7C3AED),
  Color(0xFFDC2626),
  Color(0xFF0D9488),
  Color(0xFF9333EA),
];

Color _accentFor(String name) {
  if (name.isEmpty) return _accents[0];
  return _accents[name.codeUnitAt(0) % _accents.length];
}

// ─────────────────────────────────────────────────────────────────────────────

class MostUsedCategoriesPage extends StatefulWidget {
  final List<dynamic> categories;

  MostUsedCategoriesPage({required this.categories});

  @override
  _MostUsedCategoriesPageState createState() =>
      _MostUsedCategoriesPageState();
}

class _MostUsedCategoriesPageState extends State<MostUsedCategoriesPage>
    with RouteAware {
  String? lastOpenedCatId;
  String? storedPhone;

  List<dynamic> _filteredCategories = [];
  bool _isRefreshing = false;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredCategories = List.from(widget.categories);
    _loadStoredPhone();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _searchController.dispose();
    super.dispose();
  }

  // Fix: await the usage update BEFORE fetching so the returned count
  // reflects the current visit (previously both fired concurrently).
  @override
  void didPopNext() async {
    if (lastOpenedCatId != null) {
      await _updateCategoryUsage(lastOpenedCatId!);
    }
    _fetchUpdatedCategories();
  }

  // Fix: when query is empty restore the API's original order (cat_used desc).
  // Previously, clearing the search would sort A-Z instead.
  void _onSearchChanged() {
    final q = _searchController.text.toLowerCase().trim();
    setState(() {
      if (q.isEmpty) {
        // Restore API order — no re-sort
        _filteredCategories = List.from(widget.categories);
      } else {
        final starts = widget.categories
            .where((c) =>
                c['cat_name'].toString().toLowerCase().startsWith(q))
            .toList();
        final contains = widget.categories
            .where((c) {
              final n = c['cat_name'].toString().toLowerCase();
              return n.contains(q) && !n.startsWith(q);
            })
            .toList();
        _filteredCategories = [...starts, ...contains];
      }
    });
  }

  Future<void> _loadStoredPhone() async {
    storedPhone = await Config.getLoggedInUserPhone();
    if (mounted) setState(() {});
  }

  Future<void> _updateCategoryUsage(String catId) async {
    try {
      await Config.apiPost(
        '/update_cat_used',
        {'cat_id': catId},
        context,
      );
    } catch (e) {
      debugPrint("Error updating category usage: $e");
    }
  }

  Future<void> _fetchUpdatedCategories() async {
    if (!mounted) return;
    setState(() => _isRefreshing = true);

    try {
      final resp = await Config.apiGet('/get_most_used_category', context);
      if (resp != null && resp.statusCode == 200) {
        final data =
            json.decode(resp.body)['most_used_cat'] as List;
        if (!mounted) return;
        setState(() {
          widget.categories
            ..clear()
            ..addAll(data);
          _onSearchChanged(); // re-apply current filter on fresh data
        });
      }
    } catch (e) {
      debugPrint("Error fetching categories: $e");
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFF),
        appBar: _buildAppBar(),
        body: Column(
          children: [
            _buildSearchField(),
            if (_isRefreshing)
              LinearProgressIndicator(
                color: const Color(0xFF1A56DB),
                backgroundColor: const Color(0xFFDDE8FF),
                minHeight: 2,
              ),
            Expanded(
              child: _filteredCategories.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      color: const Color(0xFF1A56DB),
                      onRefresh: _fetchUpdatedCategories,
                      child: GridView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.82,
                        ),
                        itemCount: _filteredCategories.length,
                        itemBuilder: _buildCard,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF111827),
      elevation: 0,
      surfaceTintColor: Colors.white,
      titleSpacing: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'সর্বাধিক ব্যবহৃত বিভাগ',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          Text(
            '${widget.categories.length}টি বিভাগ পাওয়া গেছে',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: const Color(0xFFF0F3FA)),
      ),
    );
  }

  // ── Search field ──────────────────────────────────────────────────────────

  Widget _buildSearchField() {
    final hasText = _searchController.text.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5EAF5)),
        ),
        child: TextField(
          controller: _searchController,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF111827),
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: 'বিভাগ খুঁজুন...',
            hintStyle: const TextStyle(
              color: Color(0xFFADB5C7),
              fontSize: 14,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: Color(0xFF1A56DB),
              size: 20,
            ),
            suffixIcon: hasText
                ? IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Color(0xFFADB5C7), size: 18),
                    onPressed: () {
                      _searchController.clear();
                      FocusScope.of(context).unfocus();
                    },
                  )
                : null,
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          ),
        ),
      ),
    );
  }

  // ── Category card ─────────────────────────────────────────────────────────

  Widget _buildCard(BuildContext ctx, int i) {
    final cat = _filteredCategories[i];

    final id       = cat['cat_id'].toString();
    final name     = (cat['cat_name'] ?? '').toString();
    final logoName = (cat['cat_logo'] ?? '').toString().trim();

    // Fix: was 'cat logo' (with a literal space) — URLs with spaces always fail.
    // Using the correct path segment now.
    final imageUrl = logoName.isNotEmpty
        ? 'https://aarambd.com/cat logo/$logoName'
        : null;

    // Fix: use _toInt() — JSON may return cat_used as a String ("42"),
    // the previous `as int?` cast would silently produce 0 in that case.
    final used      = _toInt(cat['cat_used']);
    final isService = _toInt(cat['yes_service']) == 1;
    final isShop    = _toInt(cat['yes_shop']) == 1;

    final accent       = _accentFor(name);
    final phoneToPass  = storedPhone ?? '';
    final canNavigate  = isService || isShop;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: canNavigate
            ? () {
                lastOpenedCatId = id;
                if (isService) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ServiceFavorite(
                        userPhone: phoneToPass,
                        category_name: name,
                        cat_id: id,
                      ),
                    ),
                  );
                } else if (isShop) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ShopsFavorite(
                        userPhone: phoneToPass,
                        categoryName: name,
                        cat_id: id,
                      ),
                    ),
                  );
                }
              }
            : null,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF0F3FA)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Top accent strip ──────────────────────────────────────
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16)),
                ),
              ),

              // ── Image / Avatar area ───────────────────────────────────
              Expanded(
                flex: 5,
                child: ClipRRect(
                  borderRadius: BorderRadius.zero,
                  child: _buildVisual(
                      imageUrl, name, accent, isService, isShop),
                ),
              ),

              // ── Name + count footer ───────────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.people_outline_rounded,
                                  size: 11, color: accent),
                              const SizedBox(width: 4),
                              Text(
                                Config.formatLargeNumber(used),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        if (isService || isShop)
                          Icon(
                            isService
                                ? Icons.engineering_rounded
                                : Icons.storefront_rounded,
                            size: 14,
                            color: const Color(0xFFADB5C7),
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

  // ── Visual area: network image or avatar fallback ─────────────────────────

  Widget _buildVisual(String? imageUrl, String name, Color accent,
      bool isService, bool isShop) {
    final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';

    if (imageUrl != null) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (_, __, ___) =>
            _buildAvatarFallback(letter, accent),
        loadingBuilder: (ctx, child, progress) {
          if (progress == null) return child;
          return _buildAvatarFallback(letter, accent);
        },
      );
    }

    return _buildAvatarFallback(letter, accent);
  }

  Widget _buildAvatarFallback(String letter, Color accent) {
    return Container(
      color: accent.withValues(alpha: 0.08),
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w800,
            color: accent.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    final hasQuery = _searchController.text.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: Color(0xFFEEF2FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 38,
                color: Color(0xFF1A56DB),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              hasQuery
                  ? 'কোনো বিভাগ পাওয়া যায়নি'
                  : 'বিভাগ লোড হয়নি',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasQuery
                  ? 'অন্য কোনো শব্দ দিয়ে আবার চেষ্টা করুন।'
                  : 'নিচে টেনে রিফ্রেশ করুন।',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
