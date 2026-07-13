import 'dart:convert';
import 'package:aaram_bd/config.dart';
import 'package:aaram_bd/screens/shops_favorite_screen.dart';
import 'package:flutter/material.dart';

// ── Models — unchanged ────────────────────────────────────────────────────────

final String host = Config.host;

class CategoryCount {
  final int categoryCount;
  final String categoryName;
  final dynamic photo;
  final String cat_id;
  final int catUsed;

  CategoryCount({
    required this.categoryCount,
    required this.categoryName,
    required this.cat_id,
    required this.photo,
    required this.catUsed,
  });

  factory CategoryCount.fromJson(Map<String, dynamic> json) {
    return CategoryCount(
      categoryCount: json['count'],
      categoryName: json['name']?.toString() ?? '',
      cat_id: json['cat_id'].toString(),
      photo: json['photo'],
      catUsed: json['cat_used'] is int
          ? json['cat_used']
          : int.tryParse(json['cat_used']?.toString() ?? '0') ?? 0,
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

// ── Shop category card ────────────────────────────────────────────────────────

// ── Shop category card — storefront banner theme ──────────────────────────────
class _ShopCategoryCard extends StatelessWidget {
  final String imageUrl;
  final String name;
  final int count;
  final int catUsed;
  final VoidCallback onTap;

  const _ShopCategoryCard({
    required this.imageUrl,
    required this.name,
    required this.catUsed,
    required this.count,
    required this.onTap,
  });

  static const Color _blue = Color(0xFF1A56DB);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Banner image with overlays ─────────────────────────
                AspectRatio(
                  aspectRatio: 2.4,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Image
                      imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildBannerFallback(),
                              loadingBuilder: (_, child, progress) =>
                                  progress == null ? child : _buildBannerFallback(),
                            )
                          : _buildBannerFallback(),
                      // Bottom gradient so text is readable
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.62),
                              ],
                              stops: const [0.35, 1.0],
                            ),
                          ),
                        ),
                      ),
                      // SHOP badge — top left
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _blue,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: _blue.withValues(alpha: 0.40),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.shopping_bag_rounded,
                                  size: 10, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'SHOP',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Category name overlay — bottom left
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 9,
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                            shadows: [
                              Shadow(
                                color: Colors.black54,
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Footer ────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(13, 10, 13, 13),
                  child: Row(
                    children: [
                      const Icon(Icons.storefront_rounded,
                          size: 13, color: _blue),
                      const SizedBox(width: 5),
                      Text(
                        '$count shops',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black.withValues(alpha: 0.52),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (catUsed > 0) ...[
                        const SizedBox(width: 10),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.25),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(Icons.local_fire_department_rounded,
                            size: 13, color: Color(0xFFF97316)),
                        const SizedBox(width: 4),
                        Text(
                          '$catUsed visits',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFF97316),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 13, vertical: 8),
                        decoration: BoxDecoration(
                          color: _blue,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: _blue.withValues(alpha: 0.32),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Browse',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.2,
                              ),
                            ),
                            SizedBox(width: 5),
                            Icon(Icons.arrow_forward_rounded,
                                size: 12, color: Colors.white),
                          ],
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

  Widget _buildBannerFallback() {
    return Container(
      color: _blue.withValues(alpha: 0.08),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.storefront_rounded, color: _blue, size: 30),
            const SizedBox(height: 4),
            Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _blue,
              ),
            ),
          ],
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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Future<Map<String, List<dynamic>>>? _dataFuture;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final q = _searchController.text.toLowerCase().trim();
      if (q != _searchQuery) setState(() => _searchQuery = q);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _dataFuture ??= fetchData(context);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _dataFuture = fetchData(context));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FF),
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
                      'Unable to load data',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Check your internet connection\nand try again.',
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
                      label: const Text('Try Again'),
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

          final filtered = _searchQuery.isEmpty
              ? categories
              : categories
                  .where((c) => c.categoryName
                      .toLowerCase()
                      .contains(_searchQuery))
                  .toList();

          return Column(
            children: [
              // ── Pinned search bar ───────────────────────────────────────
              _buildSearchBar(),
              // ── Scrollable content ──────────────────────────────────────
              Expanded(
                child: RefreshIndicator(
                  color: const Color(0xFF1A56DB),
                  onRefresh: _refresh,
                  child: CustomScrollView(
                    controller: _scrollCtrl,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: _buildHeader(categories.length, filtered.length),
                      ),
                      categories.isEmpty
                          ? SliverFillRemaining(child: _buildEmptyState())
                          : filtered.isEmpty
                              ? SliverFillRemaining(child: _buildSearchEmpty())
                              : SliverPadding(
                                  padding: EdgeInsets.fromLTRB(
                                      14,
                                      0,
                                      14,
                                      20 + MediaQuery.of(context).padding.bottom),
                                  sliver: SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (ctx, i) {
                                        final cat = filtered[i];
                                        return Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 10),
                                          child: _ShopCategoryCard(
                                            imageUrl:
                                                cat.photo?.toString() ?? '',
                                            name: cat.categoryName,
                                            count: cat.categoryCount,
                                            catUsed: cat.catUsed,
                                            onTap: () {
                                              updateCategoryUsage(
                                                  cat.cat_id, context);
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => ShopsFavorite(
                                                    userPhone: widget.userPhone,
                                                    cat_id: cat.cat_id,
                                                    categoryName:
                                                        cat.categoryName,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        );
                                      },
                                      childCount: filtered.length,
                                    ),
                                  ),
                                ),
                    ],
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

  Widget _buildHeader(int total, int filtered) {
    final isFiltering = _searchQuery.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
      child: Row(
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
                'Shop Categories',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                  letterSpacing: -0.3,
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  isFiltering
                      ? '$filtered of $total matched'
                      : '$total categories available',
                  key: ValueKey(isFiltering ? filtered : -1),
                  style: TextStyle(
                    fontSize: 12,
                    color: isFiltering
                        ? const Color(0xFF1A56DB)
                        : const Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final isFiltering = _searchQuery.isNotEmpty;
    return Container(
      color: const Color(0xFFF3F7FF),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isFiltering
                ? const Color(0xFF1A56DB).withValues(alpha: 0.40)
                : Colors.black.withValues(alpha: 0.08),
            width: isFiltering ? 1.5 : 1.0,
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
            hintText: 'Search shop categories…',
            hintStyle: TextStyle(
              color: Colors.black.withValues(alpha: 0.32),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 14, right: 8),
              child: Icon(Icons.search_rounded,
                  color: Color(0xFF1A56DB), size: 21),
            ),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 48, minHeight: 48),
            suffixIcon: isFiltering
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    color: Colors.black38,
                    splashRadius: 18,
                    onPressed: _searchController.clear,
                  )
                : null,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFEEF2FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_off_rounded,
                  size: 34, color: Color(0xFF1A56DB)),
            ),
            const SizedBox(height: 16),
            const Text(
              'No results found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'No categories match "$_searchQuery".',
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
              'No categories found',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Pull down to refresh.',
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