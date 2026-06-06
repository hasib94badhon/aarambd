import 'dart:async';
import 'dart:convert';

import 'package:aaram_bd/config.dart';
import 'package:aaram_bd/screens/Search_Category.dart';
import 'package:aaram_bd/screens/Service_favorite_screen.dart';
import 'package:aaram_bd/widgets/SearchPillButton.dart';
import 'package:flutter/material.dart';

// ─── Host ─────────────────────────────────────────────────────────────────────
final String host = Config.host;

// ─── Brand token ─────────────────────────────────────────────────────────────
const Color _brand = Color(0xFF1A56DB);

// ─── Accent palette — one per card for visual scanning ───────────────────────
const List<Color> _accents = [
  Color(0xFF1A56DB), // blue
  Color(0xFF0891B2), // cyan
  Color(0xFF059669), // green
  Color(0xFFD97706), // amber
  Color(0xFF7C3AED), // purple
  Color(0xFFDC2626), // red
  Color(0xFF0D9488), // teal
  Color(0xFF9333EA), // violet
];
Color _accentFor(int i) => _accents[i % _accents.length];

// ─── Data models (UNCHANGED) ──────────────────────────────────────────────────
class CategoryCount {
  final int categoryCount;
  final String categoryName;
  final String cat_id;
  final dynamic photo;

  CategoryCount({
    required this.categoryCount,
    required this.categoryName,
    required this.cat_id,
    required this.photo,
  });

  factory CategoryCount.fromJson(Map<String, dynamic> json) {
    return CategoryCount(
      categoryCount: json['count'],
      cat_id: json['cat_id'].toString(),
      categoryName: json['name']?.toString() ?? '',
      photo: json['photo'],
    );
  }
}

class UserDetail {
  final String address;
  final String business_name;
  final String category;
  final String phone;
  final String photo;
  final int service_id;
  final int shop_id;
  final bool isService;

  UserDetail({
    required this.address,
    required this.business_name,
    required this.category,
    required this.phone,
    required this.photo,
    required this.service_id,
    required this.shop_id,
    required this.isService,
  });

  factory UserDetail.fromJson(Map<String, dynamic> json) {
    return UserDetail(
      category: json['cat_name']?.toString() ?? '',
      address: json['location']?.toString() ?? '',
      business_name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      service_id: (json['service_id'] ?? 0) is int
          ? (json['service_id'] ?? 0)
          : int.tryParse(json['service_id'].toString()) ?? 0,
      shop_id: (json['shop_id'] ?? json['service_id'] ?? 0) is int
          ? (json['shop_id'] ?? json['service_id'] ?? 0)
          : int.tryParse(
                  (json['shop_id'] ?? json['service_id'] ?? 0).toString()) ??
              0,
      photo: json['photo']?.toString() ?? '',
      isService: true,
    );
  }
}

// ─── API helpers (UNCHANGED) ──────────────────────────────────────────────────
Future<Map<String, List<dynamic>>> fetchData(BuildContext context) async {
  final resp = await Config.apiGet("/get_service_data", context);

  if (resp != null && resp.statusCode == 200) {
    final jsonResponse = json.decode(resp.body);

    final categoryCounts = (jsonResponse['category_count'] as List)
        .map((data) => CategoryCount.fromJson(data))
        .toList();

    final userDetails = (jsonResponse['service_information'] as List)
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

// ─── Category tile ────────────────────────────────────────────────────────────
// Redesigned as a StatelessWidget — removes the per-tile AnimationController
// that was running continuously on every card (CPU waste + visual noise).
// Tap feedback is handled by Material + InkWell (native splash).
class CategoryImageTile extends StatelessWidget {
  final String imageUrl;
  final String title;
  final int count;
  final VoidCallback onTap;
  final Color accentColor;

  const CategoryImageTile({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.count,
    required this.onTap,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EDF5), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: accentColor.withValues(alpha: 0.08),
          highlightColor: accentColor.withValues(alpha: 0.04),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Accent top strip ───────────────────────────────────────────
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
              ),

              // ── Image (4:3 ratio) ──────────────────────────────────────────
              AspectRatio(
                aspectRatio: 4 / 3,
                child: imageUrl.isEmpty
                    ? _imagePlaceholder()
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _imagePlaceholder(),
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            color: const Color(0xFFF0F4FA),
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: accentColor,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // ── Content ────────────────────────────────────────────────────
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category name
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                          color: Color(0xFF111827),
                        ),
                      ),

                      const Spacer(),

                      // Expert count with icon
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.people_alt_outlined,
                              size: 12,
                              color: accentColor,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              '$count জন বিশেষজ্ঞ',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: accentColor,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // CTA row
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'বিশেষজ্ঞ দেখুন',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: accentColor,
                                letterSpacing: 0.1,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 11,
                              color: accentColor,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: accentColor.withValues(alpha: 0.07),
      child: Center(
        child: Icon(
          Icons.engineering_rounded,
          size: 36,
          color: accentColor.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

// ─── ServiceCart ──────────────────────────────────────────────────────────────
class ServiceCart extends StatefulWidget {
  final dynamic dataa;
  final String userPhone;

  const ServiceCart({Key? key, this.dataa, required this.userPhone})
      : super(key: key);

  @override
  State<ServiceCart> createState() => _ServiceCartState();
}

class _ServiceCartState extends State<ServiceCart> {
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
    if (_pillOpacity != 0.25) setState(() => _pillOpacity = 0.25);
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
      backgroundColor: const Color(0xFFF0F4FA),
      body: FutureBuilder<Map<String, List<dynamic>>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          // ── Loading ──────────────────────────────────────────────────────
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: _brand),
            );
          }

          // ── Error ────────────────────────────────────────────────────────
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEDF4FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.wifi_off_rounded,
                        size: 40,
                        color: _brand,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'ডেটা লোড হয়নি',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'ইন্টারনেট সংযোগ পরীক্ষা করুন',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('আবার চেষ্টা করুন'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _brand,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // ── No data fallback ─────────────────────────────────────────────
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: _brand),
            );
          }

          final categories =
              snapshot.data!['categoryCounts'] as List<CategoryCount>;

          return Stack(
            children: [
              // ── Grid with section header ──────────────────────────────
              RefreshIndicator(
                color: _brand,
                onRefresh: _refresh,
                child: CustomScrollView(
                  controller: _scrollCtrl,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // Section header
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEDF4FF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.engineering_rounded,
                                color: _brand,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'সার্ভিস বিভাগ',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                  Text(
                                    'মোট ${categories.length}টি বিভাগ পাওয়া গেছে',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF6B7280),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 2-column card grid
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        14,
                        0,
                        14,
                        80 + MediaQuery.of(context).padding.bottom,
                      ),
                      sliver: SliverGrid(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final category = categories[index];
                            return CategoryImageTile(
                              imageUrl: category.photo?.toString() ?? '',
                              title: category.categoryName,
                              count: category.categoryCount,
                              accentColor: _accentFor(index),
                              onTap: () {
                                updateCategoryUsage(
                                  category.cat_id.toString(),
                                  context,
                                );
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ServiceFavorite(
                                      userPhone: widget.userPhone,
                                      cat_id: category.cat_id,
                                      category_name: category.categoryName,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                          childCount: categories.length,
                        ),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          // Image (4:3) + content ~100px
                          childAspectRatio: 0.68,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Floating search pill ─────────────────────────────────────
              Positioned(
                right: 14,
                bottom: 14 + MediaQuery.of(context).padding.bottom,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: _pillOpacity,
                  child: SearchPillButton(
                    onTap: () => openSearchCategorySheet(
                      context,
                      CategoryType.service,
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
}
