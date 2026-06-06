import 'dart:convert';
import 'package:aaram_bd/config.dart';
import 'package:aaram_bd/screens/favorite_screen.dart';
import 'package:aaram_bd/screens/service_favorite_screen.dart';
import 'package:aaram_bd/screens/shops_favorite_screen.dart';
import 'package:flutter/material.dart';

enum CategoryType { all, service, shop }

/// Call this to open the bottom-sheet search UI.
void openSearchCategorySheet(BuildContext context, CategoryType type) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (ctx, scrollController) {
          return _RoundedSheet(
            child: _SearchCategorySheet(
              type: type,
              scrollController: scrollController,
            ),
          );
        },
      );
    },
  );
}

/// Rounded white container with premium shadow
class _RoundedSheet extends StatelessWidget {
  final Widget child;

  const _RoundedSheet({required this.child});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 24,
              spreadRadius: 2,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

// Professional avatar color palette (brand-aligned)
const List<Color> _avatarColors = [
  Color(0xFF1A56DB),
  Color(0xFF0891B2),
  Color(0xFF059669),
  Color(0xFFD97706),
  Color(0xFF7C3AED),
  Color(0xFFDC2626),
  Color(0xFF0D9488),
  Color(0xFF9333EA),
];

Color _avatarColor(String name) {
  if (name.isEmpty) return _avatarColors[0];
  final code = name.codeUnitAt(0);
  return _avatarColors[code % _avatarColors.length];
}

class _SearchCategorySheet extends StatefulWidget {
  final CategoryType type;
  final ScrollController scrollController;

  const _SearchCategorySheet({
    Key? key,
    required this.type,
    required this.scrollController,
  }) : super(key: key);

  @override
  State<_SearchCategorySheet> createState() => _SearchCategorySheetState();
}

class _SearchCategorySheetState extends State<_SearchCategorySheet> {
  String? storedPhone;
  final TextEditingController _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _allFetched = [];
  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> filteredCategories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStoredPhone();
    fetchCategories();
    _searchCtrl.addListener(() => filterCategories(_searchCtrl.text));
  }

  Future<void> _loadStoredPhone() async {
    storedPhone = await Config.getLoggedInUserPhone();
    // ignore: avoid_print
    print("from Search_Category.dart userphone $storedPhone");
    setState(() {});
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  String? _buildImageUrl(dynamic imagePath) {
    if (imagePath == null) return null;

    final raw = imagePath.toString().trim();
    if (raw.isEmpty) return null;

    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }

    final clean = raw.replaceFirst(RegExp(r'^/+'), '');
    return "${Config.host}/$clean";
  }

  Future<void> fetchCategories() async {
    debugPrint('>>> fetchCategories() called');

    final res = await Config.apiGet("/get_categories_name", context);
    if (res == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      _allFetched = List<Map<String, dynamic>>.from(data['categories']);

      categories = switch (widget.type) {
        CategoryType.service =>
          _allFetched.where((c) => _toInt(c['yes_service']) == 1).toList(),
        CategoryType.shop =>
          _allFetched.where((c) => _toInt(c['yes_shop']) == 1).toList(),
        _ => _allFetched,
      };

      if (mounted) {
        setState(() {
          filteredCategories = categories;
          _isLoading = false;
        });
      }
    } else {
      debugPrint('Failed to fetch categories. User may need to log in again');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void filterCategories(String query) {
    final q = query.toLowerCase();
    if (q.isEmpty) {
      setState(() => filteredCategories = categories);
      return;
    }

    final starts = categories
        .where((c) => (c['cat_name'] ?? '').toString().toLowerCase().startsWith(q))
        .toList();

    final contains = categories
        .where((c) {
          final name = (c['cat_name'] ?? '').toString().toLowerCase();
          return name.contains(q) && !name.startsWith(q);
        })
        .toList();

    starts.sort((a, b) => (a['cat_name'] ?? '')
        .toString()
        .toLowerCase()
        .compareTo((b['cat_name'] ?? '').toString().toLowerCase()));

    contains.sort((a, b) => (a['cat_name'] ?? '')
        .toString()
        .toLowerCase()
        .compareTo((b['cat_name'] ?? '').toString().toLowerCase()));

    setState(() => filteredCategories = [...starts, ...contains]);
  }

  @override
  Widget build(BuildContext context) {
    final bool hasQuery = _searchCtrl.text.isNotEmpty;

    return Column(
      children: [
        // ── Drag handle ──────────────────────────────────────────────────────
        Center(
          child: Container(
            width: 44,
            height: 5,
            margin: const EdgeInsets.only(top: 10, bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFDDE3EE),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),

        // ── Header row: title + count badge ──────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Text(
                'বিভাগ খুঁজুন',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 10),
              if (!_isLoading)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    key: ValueKey(filteredCategories.length),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${filteredCategories.length}টি',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A56DB),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // ── Search field ─────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Focus(
            child: Builder(builder: (ctx) {
              final focused = Focus.of(ctx).hasFocus;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: focused
                        ? const Color(0xFF1A56DB)
                        : const Color(0xFFE5EAF5),
                    width: focused ? 1.5 : 1.0,
                  ),
                  boxShadow: focused
                      ? [
                          BoxShadow(
                            color: const Color(0xFF1A56DB).withValues(alpha: 0.10),
                            blurRadius: 8,
                            spreadRadius: 1,
                          )
                        ]
                      : [],
                ),
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    color: Color(0xFF111827),
                  ),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF1A56DB),
                      size: 22,
                    ),
                    hintText: 'বিভাগ খুঁজুন...',
                    hintStyle: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: Color(0xFFADB5C7),
                    ),
                    suffixIcon: hasQuery
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded,
                                color: Color(0xFFADB5C7), size: 20),
                            onPressed: () {
                              _searchCtrl.clear();
                              filterCategories('');
                            },
                          )
                        : null,
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              );
            }),
          ),
        ),

        const SizedBox(height: 12),

        // ── Divider ───────────────────────────────────────────────────────────
        Container(
          height: 1,
          color: const Color(0xFFF0F3FA),
        ),

        // ── Result list ───────────────────────────────────────────────────────
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF1A56DB),
                    strokeWidth: 2.5,
                  ),
                )
              : filteredCategories.isEmpty
                  ? _EmptyState(hasQuery: hasQuery)
                  : ListView.builder(
                      controller: widget.scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: filteredCategories.length,
                      itemBuilder: (context, index) {
                        final item = filteredCategories[index];
                        final catName = (item['cat_name'] ?? '').toString();
                        final imageUrl = _buildImageUrl(item['cat_logo']);
                        final accentColor = _avatarColor(catName);

                        return _CategoryTile(
                          catName: catName,
                          imageUrl: imageUrl,
                          accentColor: accentColor,
                          isLast: index == filteredCategories.length - 1,
                          onTap: () {
                            final isService = _toInt(item['yes_service']) == 1;
                            final isShop = _toInt(item['yes_shop']) == 1;
                            final id = item['cat_id'].toString();
                            final phoneToPass = storedPhone ?? '';

                            Widget nextPage;

                            if (isService) {
                              nextPage = ServiceFavorite(
                                userPhone: phoneToPass,
                                category_name: catName,
                                cat_id: id,
                              );
                            } else if (isShop) {
                              nextPage = ShopsFavorite(
                                userPhone: phoneToPass,
                                categoryName: catName,
                                cat_id: id,
                              );
                            } else {
                              nextPage = FavoriteScreen(
                                userPhone: phoneToPass,
                                categoryName: catName,
                                cat_id: id,
                              );
                            }

                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => nextPage),
                            );
                          },
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

// ── Category tile ─────────────────────────────────────────────────────────────

class _CategoryTile extends StatelessWidget {
  final String catName;
  final String? imageUrl;
  final Color accentColor;
  final bool isLast;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.catName,
    required this.imageUrl,
    required this.accentColor,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Row(
                children: [
                  // Avatar
                  _CategoryAvatar(
                    name: catName,
                    imageUrl: imageUrl,
                    accentColor: accentColor,
                  ),
                  const SizedBox(width: 14),
                  // Name + chevron
                  Expanded(
                    child: Text(
                      catName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: accentColor.withValues(alpha: 0.7),
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 70,
            color: const Color(0xFFF0F3FA),
          ),
      ],
    );
  }
}

// ── Category avatar ───────────────────────────────────────────────────────────

class _CategoryAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final Color accentColor;

  const _CategoryAvatar({
    required this.name,
    required this.imageUrl,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final letter = name.isNotEmpty ? name[0].toUpperCase() : 'A';
    final hasImg = imageUrl != null && imageUrl!.trim().isNotEmpty;

    if (hasImg) {
      return Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: accentColor.withValues(alpha: 0.25), width: 2),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipOval(
          child: Image.network(
            imageUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallback(letter),
            loadingBuilder: (ctx, child, progress) {
              if (progress == null) return child;
              return Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: accentColor),
                ),
              );
            },
          ),
        ),
      );
    }

    return _fallback(letter);
  }

  Widget _fallback(String letter) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accentColor.withValues(alpha: 0.12),
        border: Border.all(color: accentColor.withValues(alpha: 0.25), width: 2),
      ),
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: accentColor,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasQuery;

  const _EmptyState({required this.hasQuery});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 40,
                color: Color(0xFF1A56DB),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              hasQuery ? 'কোনো বিভাগ পাওয়া যায়নি' : 'বিভাগ লোড হয়নি',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasQuery
                  ? 'অন্য কোনো শব্দ দিয়ে আবার চেষ্টা করুন।'
                  : 'ইন্টারনেট সংযোগ পরীক্ষা করুন এবং আবার চেষ্টা করুন।',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Poppins',
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
