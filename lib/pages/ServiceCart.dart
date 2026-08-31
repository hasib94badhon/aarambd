import 'dart:convert';

import 'package:aaram_bd/config.dart';
import 'package:aaram_bd/screens/Service_favorite_screen.dart';
import 'package:flutter/material.dart';

// ─── Host ─────────────────────────────────────────────────────────────────────
final String host = Config.host;

// ─── Brand token ─────────────────────────────────────────────────────────────
const Color _brand = Color(0xFF1A56DB);

// ─── Data models (UNCHANGED) ──────────────────────────────────────────────────
class CategoryCount {
  final int categoryCount;
  final String categoryName;
  final String cat_id;
  final dynamic photo;
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
      cat_id: json['cat_id'].toString(),
      categoryName: json['name']?.toString() ?? '',
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
class CategoryImageTile extends StatelessWidget {
  final String imageUrl;
  final String title;
  final int count;
  final int catUsed;
  final VoidCallback onTap;

  const CategoryImageTile({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.count,
    required this.catUsed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: _brand.withValues(alpha: 0.08),
          highlightColor: _brand.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Circular avatar with availability dot ──────────────
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _brand.withValues(alpha: 0.18),
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _brand.withValues(alpha: 0.14),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _avatarFallback(),
                                loadingBuilder: (_, child, progress) =>
                                    progress == null
                                        ? child
                                        : _avatarFallback(),
                              )
                            : _avatarFallback(),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // ── Category name ──────────────────────────────────────
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                    color: Color(0xFF111827),
                  ),
                ),

                const SizedBox(height: 6),

                // ── Expert count ───────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.people_alt_outlined,
                        size: 12, color: _brand),
                    const SizedBox(width: 4),
                    Text(
                      '$count experts',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: _brand,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 4),
                Opacity(
                  opacity: catUsed > 0 ? 1 : 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.local_fire_department_rounded,
                          size: 12, color: Color(0xFFF97316)),
                      const SizedBox(width: 4),
                      Text(
                        '$catUsed visits',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFF97316),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // ── Find Expert button ─────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1040B0), Color(0xFF1A56DB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: [
                      BoxShadow(
                        color: _brand.withValues(alpha: 0.32),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Find Expert',
                        style: TextStyle(
                          fontSize: 11.5,
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
        ),
      ),
    );
  }

  Widget _avatarFallback() {
    return Container(
      color: _brand.withValues(alpha: 0.08),
      child: const Center(
        child: Icon(Icons.engineering_rounded, size: 36, color: _brand),
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
                      'Unable to load data',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Check your internet connection and try again.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Try Again'),
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

          final filtered = _searchQuery.isEmpty
              ? categories
              : categories
                  .where((c) => c.categoryName
                      .toLowerCase()
                      .contains(_searchQuery))
                  .toList();

          final isFiltering = _searchQuery.isNotEmpty;

          return Column(
            children: [
              // ── Pinned search bar ──────────────────────────────────────
              _buildSearchBar(),
              // ── Scrollable content ─────────────────────────────────────
              Expanded(
                child: RefreshIndicator(
                  color: _brand,
                  onRefresh: _refresh,
                  child: CustomScrollView(
                    controller: _scrollCtrl,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // ── Title ──────────────────────────────────────────
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF1040B0),
                                      Color(0xFF1A56DB),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                child: const Icon(
                                  Icons.engineering_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Service Categories',
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
                                          ? '${filtered.length} of ${categories.length} matched'
                                          : '${categories.length} categories available',
                                      key: ValueKey(
                                          isFiltering ? filtered.length : -1),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isFiltering
                                            ? _brand
                                            : const Color(0xFF9CA3AF),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ── Grid or empty states ────────────────────────────
                      if (categories.isEmpty)
                        SliverFillRemaining(child: _buildEmptyState())
                      else if (filtered.isEmpty)
                        SliverFillRemaining(child: _buildSearchEmpty())
                      else
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            14,
                            0,
                            14,
                            20 + MediaQuery.of(context).padding.bottom,
                          ),
                          sliver: SliverGrid(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final category = filtered[index];
                                return CategoryImageTile(
                                  imageUrl: category.photo?.toString() ?? '',
                                  title: category.categoryName,
                                  count: category.categoryCount,
                                  catUsed: category.catUsed,
                                  onTap: () {
                                    updateCategoryUsage(
                                        category.cat_id.toString(), context);
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
                              childCount: filtered.length,
                            ),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              // Measured via intrinsic-height test: at a
                              // typical ~167-177px cell width the card needs
                              // an aspect ratio no higher than ~0.70-0.79 to
                              // fit a 2-line title without overflowing.
                              childAspectRatio: 0.68,
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
                ? _brand.withValues(alpha: 0.40)
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
            hintText: 'Search service categories…',
            hintStyle: TextStyle(
              color: Colors.black.withValues(alpha: 0.32),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 14, right: 8),
              child: Icon(Icons.search_rounded, color: _brand, size: 21),
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

  Widget _buildEmptyState() {
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
              child: const Icon(Icons.engineering_outlined,
                  size: 34, color: _brand),
            ),
            const SizedBox(height: 16),
            const Text(
              'No categories found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Pull down to refresh.',
              textAlign: TextAlign.center,
              style: TextStyle(
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
                  size: 34, color: _brand),
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
}