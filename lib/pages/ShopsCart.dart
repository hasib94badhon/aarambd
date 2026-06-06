import 'dart:async';
import 'dart:convert';
import 'package:aaram_bd/config.dart';
import 'package:aaram_bd/screens/Search_Category.dart';
import 'package:aaram_bd/screens/shops_favorite_screen.dart';
import 'package:aaram_bd/widgets/SearchPillButton.dart';
import 'package:flutter/material.dart';

// ── Models — unchanged ────────────────────────────────────────────────────────

final String host = Config.host;

class CategoryCount {
  final int categoryCount;
  final String categoryName;
  final dynamic photo;
  final String cat_id;

  CategoryCount({
    required this.categoryCount,
    required this.categoryName,
    required this.cat_id,
    required this.photo,
  });

  factory CategoryCount.fromJson(Map<String, dynamic> json) {
    return CategoryCount(
      categoryCount: json['count'],
      categoryName: json['name']?.toString() ?? '',
      cat_id: json['cat_id'].toString(),
      photo: json['photo'],
    );
  }
}

class UserDetail {
  final String address;
  final String business_name;
  final String category;
  final String phone;
  final dynamic photo;
  final int shop_id;
  final int service_id;
  final bool is_service;

  UserDetail({
    required this.address,
    required this.business_name,
    required this.category,
    required this.phone,
    required this.photo,
    required this.shop_id,
    required this.service_id,
    required this.is_service,
  });

  factory UserDetail.fromJson(Map<String, dynamic> json) {
    return UserDetail(
      address: json['location']?.toString() ?? '',
      business_name: json['name']?.toString() ?? '',
      category: json['cat_name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      photo: json['photo'],
      shop_id: (json['shop_id'] ?? 0) is int
          ? (json['shop_id'] ?? 0)
          : int.tryParse(json['shop_id'].toString()) ?? 0,
      service_id: (json['service_id'] ?? json['shop_id'] ?? 0) is int
          ? (json['service_id'] ?? json['shop_id'] ?? 0)
          : int.tryParse(
                  (json['service_id'] ?? json['shop_id'] ?? 0).toString()) ??
              0,
      is_service: false,
    );
  }
}

// ── API functions — unchanged ─────────────────────────────────────────────────

Future<Map<String, List<dynamic>>> fetchData(BuildContext context) async {
  final url = '/get_shops_data';
  final response = await Config.apiGet(url, context);

  if (response != null && response.statusCode == 200) {
    final jsonResponse = json.decode(response.body);

    final categoryCounts = (jsonResponse['category_count'] as List)
        .map((data) => CategoryCount.fromJson(data))
        .toList();

    final userDetails = (jsonResponse['shops_information'] as List)
        .map((data) => UserDetail.fromJson(data))
        .toList();

    return {
      'categoryCounts': categoryCounts,
      'userDetails': userDetails,
    };
  } else {
    throw Exception('Failed to load data from API');
  }
}

Future<void> updateCategoryUsage(String catId, BuildContext context) async {
  final resp = await Config.apiPost(
    "/update_cat_used",
    {'cat_id': catId},
    context,
  );
  if (resp != null && resp.statusCode == 200) {
    // ignore: avoid_print
    print("Category usage updated successfully");
  } else {
    // ignore: avoid_print
    print("Failed to update category usage: ${resp?.body}");
  }
}

// ── Accent palette ────────────────────────────────────────────────────────────

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

Color _accentFor(int i) => _accents[i % _accents.length];

// ── Shop category card — StatelessWidget (no per-tile AnimationController) ────

class _ShopCategoryCard extends StatelessWidget {
  final String imageUrl;
  final String name;
  final int count;
  final Color accent;
  final VoidCallback onTap;

  const _ShopCategoryCard({
    required this.imageUrl,
    required this.name,
    required this.count,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border(
              left: BorderSide(color: accent, width: 4),
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              // ── Image / avatar ─────────────────────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 78,
                  height: 78,
                  child: imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _buildAvatarFallback(),
                          loadingBuilder: (_, child, progress) =>
                              progress == null ? child : _buildAvatarFallback(),
                        )
                      : _buildAvatarFallback(),
                ),
              ),

              const SizedBox(width: 14),

              // ── Details ─────────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Count pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.storefront_rounded,
                                  size: 12, color: accent),
                              const SizedBox(width: 5),
                              Text(
                                '$count টি দোকান',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        // CTA arrow
                        Text(
                          'দেখুন →',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: accent.withValues(alpha: 0.75),
                          ),
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

  Widget _buildAvatarFallback() {
    final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      color: accent.withValues(alpha: 0.10),
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: accent.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }
}

// ── ShopsCart page ────────────────────────────────────────────────────────────

class ShopsCart extends StatefulWidget {
  final dynamic dataa;
  final String userPhone;

  const ShopsCart({Key? key, this.dataa, required this.userPhone})
      : super(key: key);

  @override
  State<ShopsCart> createState() => _ShopsCartState();
}

class _ShopsCartState extends State<ShopsCart> {
  final ScrollController _scrollCtrl = ScrollController();
  double _pillOpacity = 1.0;
  Timer? _opacityTimer;
  Future<Map<String, List<dynamic>>>? _dataFuture;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _dataFuture ??= fetchData(context);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _opacityTimer?.cancel();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_pillOpacity != 0.25) {
      setState(() => _pillOpacity = 0.25);
    }
    _opacityTimer?.cancel();
    _opacityTimer = Timer(const Duration(milliseconds: 260), () {
      if (mounted) setState(() => _pillOpacity = 1.0);
    });
  }

  Future<void> _refresh() async {
    setState(() => _dataFuture = fetchData(context));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      body: FutureBuilder<Map<String, List<dynamic>>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          // ── Loading ─────────────────────────────────────────────────────
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF1A56DB)),
            );
          }

          // ── Error ───────────────────────────────────────────────────────
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
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
                      child: const Icon(Icons.wifi_off_rounded,
                          size: 38, color: Color(0xFF1A56DB)),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'ডেটা লোড হয়নি',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'ইন্টারনেট সংযোগ পরীক্ষা করুন\nএবং আবার চেষ্টা করুন।',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                          height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('আবার চেষ্টা করুন'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A56DB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // ── Data ────────────────────────────────────────────────────────
          final categories =
              snapshot.data!['categoryCounts'] as List<CategoryCount>;

          return Stack(
            children: [
              RefreshIndicator(
                color: const Color(0xFF1A56DB),
                onRefresh: _refresh,
                child: CustomScrollView(
                  controller: _scrollCtrl,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // ── Header ───────────────────────────────────────────
                    SliverToBoxAdapter(
                      child: _buildHeader(categories.length),
                    ),

                    // ── Category list ────────────────────────────────────
                    categories.isEmpty
                        ? SliverFillRemaining(
                            child: _buildEmptyState(),
                          )
                        : SliverPadding(
                            padding:
                                const EdgeInsets.fromLTRB(14, 0, 14, 100),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (ctx, i) {
                                  final cat = categories[i];
                                  return Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 10),
                                    child: _ShopCategoryCard(
                                      imageUrl:
                                          cat.photo?.toString() ?? '',
                                      name: cat.categoryName,
                                      count: cat.categoryCount,
                                      accent: _accentFor(i),
                                      onTap: () {
                                        updateCategoryUsage(
                                            cat.cat_id, context);
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ShopsFavorite(
                                              userPhone: widget.userPhone,
                                              cat_id: cat.cat_id,
                                              categoryName: cat.categoryName,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                                childCount: categories.length,
                              ),
                            ),
                          ),
                  ],
                ),
              ),

              // ── Floating search pill ─────────────────────────────────────
              Positioned(
                right: 10,
                bottom: 10 + MediaQuery.of(context).padding.bottom,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: _pillOpacity,
                  child: SearchPillButton(
                    onTap: () => openSearchCategorySheet(
                      context,
                      CategoryType.shop,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(int total) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1040B0), Color(0xFF1A56DB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.shopping_bag_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'দোকান বিভাগসমূহ',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    'মোট $total টি বিভাগ পাওয়া গেছে',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9CA3AF),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Info banner
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDDE8FF)),
            ),
            child: Row(
              children: const [
                Icon(Icons.info_outline_rounded,
                    size: 15, color: Color(0xFF1A56DB)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'বিভাগ ট্যাপ করুন সেই বিভাগের সব দোকান দেখতে।',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF3B5BA0),
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),
        ],
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
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
              child: const Icon(Icons.storefront_outlined,
                  size: 38, color: Color(0xFF1A56DB)),
            ),
            const SizedBox(height: 20),
            const Text(
              'কোনো বিভাগ পাওয়া যায়নি',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'নিচে টেনে পেজটি রিফ্রেশ করুন।',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: Color(0xFF6B7280), height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
