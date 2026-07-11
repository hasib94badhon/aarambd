import 'dart:convert';
import 'package:aaram_bd/api_service.dart';
import 'package:aaram_bd/widgets/modular_listview.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aaram_bd/screens/post_details.dart';
import 'package:aaram_bd/config.dart';
import 'package:aaram_bd/widgets/app_toast.dart';

class UpdatePost extends StatefulWidget {
  final List<dynamic> posts;
  final String selectedSort;
  final int? selectedCategoryId;

  const UpdatePost({
    Key? key,
    required this.posts,
    required this.selectedSort,
    this.selectedCategoryId,
  }) : super(key: key);

  @override
  State<UpdatePost> createState() => _UpdatePostState();
}

class _UpdatePostState extends State<UpdatePost> {
  final String host = Config.host;
  final ApiService _apiService = ApiService();

  String selectedSort = 'recent';
  int? selectedCategoryId;
  int _resetTrigger = 0;
  int pageSize = 4;
  Map<int, String> catIdName = {};

  @override
  void initState() {
    super.initState();
    selectedSort = widget.selectedSort;
    selectedCategoryId = widget.selectedCategoryId;
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    final response = await Config.apiGet('/get_categories_name', context);

    if (response == null) return; // Token expired and user was logged out

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      final list = decoded['categories'] as List;
      setState(() {
        catIdName = {
          for (var cat in list) cat['cat_id'] as int: cat['cat_name'] as String,
        };
      });
    } else {
      final body = json.decode(response.body);
      final msg =
          body['error'] ?? body['message'] ?? 'Failed to load categories';
      showAppToast(context, msg, icon: Icons.error_outline_rounded);
    }
  }

  Future<String?> _getUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id');
  }

  // Soft, friendly color rotation for avatars
  Color _softColorForIndex(int i) {
    const palette = [
      Color(0xFF7F7FD5), // indigo/violet
      Color(0xFF86A8E7), // blue
      Color(0xFF91EAE4), // aqua
      Color(0xFF6EE7B7), // mint
      Color(0xFFFBCF71), // warm
    ];
    return palette[i % palette.length];
  }

  String _initial(String s) {
    if (s.trim().isEmpty) return '?';
    final parts = s.trim().split(RegExp(r'\s+'));
    final first = parts.first.characters.first.toUpperCase();
    final second =
        parts.length > 1 ? parts.last.characters.first.toUpperCase() : '';
    return (first + second).trim();
  }

  TextSpan _highlightMatches({
    required String source,
    required String query,
    required TextStyle baseStyle,
    required TextStyle highlightStyle,
  }) {
    if (query.isEmpty) return TextSpan(text: source, style: baseStyle);

    final lowerSource = source.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;

    while (true) {
      final index = lowerSource.indexOf(lowerQuery, start);
      if (index < 0) {
        spans.add(TextSpan(text: source.substring(start), style: baseStyle));
        break;
      }
      if (index > start) {
        spans.add(
            TextSpan(text: source.substring(start, index), style: baseStyle));
      }
      spans.add(TextSpan(
          text: source.substring(index, index + query.length),
          style: highlightStyle));
      start = index + query.length;
    }

    return TextSpan(children: spans);
  }

  void _showCategorySearchSheet(BuildContext context) {
    final TextEditingController searchController = TextEditingController();
    final List<MapEntry<int, String>> entries = catIdName.entries.toList();
    List<MapEntry<int, String>> filtered = List.from(entries);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  // 70% of screen height like before, but responsive
                  maxHeight: MediaQuery.of(context).size.height * 0.75,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black26,
                        blurRadius: 20,
                        offset: Offset(0, -6)),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      // Grab handle
                      Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.black12,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),

                      // Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF7F7FD5),
                                    Color(0xFF86A8E7),
                                    Color(0xFF91EAE4)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                boxShadow: const [
                                  BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 8,
                                      offset: Offset(0, 3)),
                                ],
                              ),
                              child: const Icon(Icons.category_rounded,
                                  color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Choose a category',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w800),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              splashRadius: 22,
                              icon: const Icon(Icons.close_rounded,
                                  color: Colors.black54),
                            ),
                          ],
                        ),
                      ),

                      // Search box
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: TextField(
                          controller: searchController,
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: 'Search category...',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: searchController.text.isEmpty
                                ? null
                                : IconButton(
                                    splashRadius: 18,
                                    onPressed: () {
                                      searchController.clear();
                                      setModalState(() {
                                        filtered = List.from(entries);
                                      });
                                    },
                                    icon: const Icon(Icons.clear_rounded),
                                  ),
                            filled: true,
                            fillColor: const Color(0xFFF6F7FB),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                  color: Colors.black12.withValues(alpha: 0.06)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                  color: Colors.black12.withValues(alpha: 0.06)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                  color: Color(0xFF86A8E7), width: 1.2),
                            ),
                          ),
                          onChanged: (value) {
                            setModalState(() {
                              final q = value.toLowerCase();
                              filtered = entries
                                  .where(
                                      (e) => e.value.toLowerCase().contains(q))
                                  .toList();
                            });
                          },
                        ),
                      ),

                      // Results
                      Expanded(
                        child: filtered.isEmpty
                            ? const _EmptySearchState()
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 6),
                                itemBuilder: (context, index) {
                                  final entry = filtered[index];
                                  final name = entry.value;
                                  return InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: () {
                                      setState(() {
                                        selectedCategoryId = entry.key;
                                        _resetTrigger++;
                                      });
                                      Navigator.pop(context);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                            color: Colors.black12
                                                .withValues(alpha: 0.06)),
                                        boxShadow: const [
                                          BoxShadow(
                                              color: Colors.black12,
                                              blurRadius: 8,
                                              offset: Offset(0, 3)),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          // Initials avatar with soft tint
                                          CircleAvatar(
                                            radius: 18,
                                            backgroundColor:
                                                _softColorForIndex(index)
                                                    .withValues(alpha: 0.15),
                                            child: Text(
                                              _initial(name),
                                              style: TextStyle(
                                                color: _softColorForIndex(index)
                                                    .withValues(alpha: 0.9),
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),

                                          // Highlighted name
                                          Expanded(
                                            child: RichText(
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              text: _highlightMatches(
                                                source: name,
                                                query: searchController.text,
                                                baseStyle: const TextStyle(
                                                  fontSize: 15,
                                                  color: Colors.black87,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                highlightStyle: const TextStyle(
                                                  fontSize: 15,
                                                  color: Colors.blueAccent,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                          ),

                                          const SizedBox(width: 8),
                                          const Icon(
                                              Icons.chevron_right_rounded,
                                              color: Colors.black38),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _getUserId(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        final userId = snapshot.data;

        return Scaffold(

          backgroundColor: const Color(0xFFF3F7FF),
          body: Column(
            children: [
              // ── Toolbar ─────────────────────────────────────────────────
              Container(
                margin: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.black.withValues(alpha: 0.06)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Category picker
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showCategorySearchSheet(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 11),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A56DB)
                                .withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: const Color(0xFF1A56DB)
                                    .withValues(alpha: 0.20)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.campaign_rounded,
                                  color: Color(0xFF1A56DB), size: 17),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  selectedCategoryId != null
                                      ? catIdName[selectedCategoryId!] ??
                                          'All Categories'
                                      : 'All Categories',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1A56DB),
                                  ),
                                ),
                              ),
                              const Icon(Icons.expand_more_rounded,
                                  color: Color(0xFF1A56DB), size: 17),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Sort dropdown
                    SizedBox(
                      width: 170,
                      child: DropdownButtonFormField<String>(
                        value: selectedSort,
                        isExpanded: true,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              selectedSort = value;
                              _resetTrigger++;
                            });
                          }
                        },
                        icon: const Icon(Icons.keyboard_arrow_down_rounded,
                            size: 18, color: Color(0xFF1A56DB)),
                        borderRadius: BorderRadius.circular(16),
                        dropdownColor: Colors.white,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.sort_rounded,
                              size: 17, color: Color(0xFF1A56DB)),
                          isDense: true,
                          filled: true,
                          fillColor: const Color(0xFF1A56DB)
                              .withValues(alpha: 0.06),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 13),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: const Color(0xFF1A56DB)
                                    .withValues(alpha: 0.20)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFF1A56DB), width: 1.5),
                          ),
                        ),
                        items: const [
                          'recent',
                          'most_viewed',
                          'most_commented'
                        ]
                            .map((s) => DropdownMenuItem<String>(
                                  value: s,
                                  child: Text(
                                    s.replaceAll('_', ' ').toUpperCase(),
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12.5),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ModularListView(
                  apiService: _apiService,
                  sortBy: selectedSort,
                  pageSize: pageSize,
                  catId: selectedCategoryId,
                  resetTrigger: _resetTrigger,
                  itemBuilder: (context, post) {
                    final hasImage = post['photo'] != null &&
                        post['photo'].toString().isNotEmpty;
                    final createdAt = post['time'];
                    final formattedTime = Config.getTimeDifference(createdAt);

                    // ── Extract fields ───────────────────────────────
                    final mainDesc =
                        (post['main_description'] ?? '').toString().trim();
                    final name = (post['name'] ?? '').toString().trim();
                    final category =
                        (post['category'] ?? '').toString().trim();

                    return Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: Colors.black.withValues(alpha: 0.06)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 18,
                            offset: const Offset(0, 7),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            splashColor: const Color(0xFF1A56DB)
                                .withValues(alpha: 0.08),
                            highlightColor: const Color(0xFF1A56DB)
                                .withValues(alpha: 0.04),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PostDetails(
                                    postId: post['post_id'].toString(),
                                    userId: userId.toString(),
                                  ),
                                ),
                              );
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [

                                // ── Billboard header strip ───────────
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 7),
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFF1040B0),
                                        Color(0xFF1A56DB),
                                        Color(0xFF2563EB),
                                      ],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // AD badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.white
                                              .withValues(alpha: 0.22),
                                          borderRadius:
                                              BorderRadius.circular(5),
                                          border: Border.all(
                                            color: Colors.white
                                                .withValues(alpha: 0.40),
                                          ),
                                        ),
                                        child: const Text(
                                          'AD',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 9),
                                      // Category name
                                      Expanded(
                                        child: Text(
                                          category.isNotEmpty
                                              ? Config.capitalizeFirst(category)
                                              : 'Advertisement',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.1,
                                          ),
                                        ),
                                      ),
                                      // Time
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.schedule_rounded,
                                              size: 11,
                                              color: Colors.white
                                                  .withValues(alpha: 0.70)),
                                          const SizedBox(width: 4),
                                          Text(
                                            formattedTime,
                                            style: TextStyle(
                                              color: Colors.white
                                                  .withValues(alpha: 0.80),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // ── Media ────────────────────────────
                                AspectRatio(
                                  aspectRatio: 16 / 9,
                                  child: hasImage
                                      ? Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            Image.network(
                                              post['photo'],
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  _billboardPlaceholder(),
                                              loadingBuilder:
                                                  (_, child, progress) {
                                                if (progress == null) {
                                                  return child;
                                                }
                                                return Container(
                                                    color: const Color(
                                                        0xFFF3F7FF));
                                              },
                                            ),
                                            // Subtle bottom vignette
                                            Positioned.fill(
                                              child: DecoratedBox(
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    begin:
                                                        Alignment.topCenter,
                                                    end: Alignment
                                                        .bottomCenter,
                                                    colors: [
                                                      Colors.transparent,
                                                      Colors.black
                                                          .withValues(
                                                              alpha: 0.28),
                                                    ],
                                                    stops: const [0.5, 1.0],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        )
                                      : _billboardPlaceholder(),
                                ),

                                // ── Ad copy (body) ───────────────────
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      12, 10, 12, 10),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Headline
                                      if (name.isNotEmpty)
                                        Text(
                                          Config.capitalizeFirst(name),
                                          style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF111827),
                                            height: 1.2,
                                            letterSpacing: -0.3,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),

                                      // Body copy
                                      if (mainDesc.isNotEmpty) ...[
                                        const SizedBox(height: 7),
                                        Text(
                                          Config.capitalizeFirst(mainDesc),
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            height: 1.55,
                                            color: Colors.black
                                                .withValues(alpha: 0.60),
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],

                                      const SizedBox(height: 9),
                                      Divider(
                                          height: 1,
                                          color: Colors.black
                                              .withValues(alpha: 0.07)),
                                      const SizedBox(height: 8),

                                      // Stats + CTA
                                      Row(
                                        children: [
                                          // Views
                                          Icon(Icons.remove_red_eye_outlined,
                                              size: 14,
                                              color: Colors.black38),
                                          const SizedBox(width: 4),
                                          Text(
                                            Config.formatLargeNumber(
                                                post['view']),
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF374151),
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          // Comments
                                          Icon(
                                              Icons
                                                  .chat_bubble_outline_rounded,
                                              size: 13,
                                              color: Colors.black38),
                                          const SizedBox(width: 4),
                                          Text(
                                            Config.formatLargeNumber(
                                                post['comment_count']),
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF374151),
                                            ),
                                          ),
                                          const Spacer(),
                                          // View Ad CTA
                                          Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 6),
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Color(0xFF1040B0),
                                                  Color(0xFF2563EB),
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(
                                                          0xFF1A56DB)
                                                      .withValues(alpha: 0.35),
                                                  blurRadius: 10,
                                                  offset:
                                                      const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  'View Ad',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.w700,
                                                    color: Colors.white,
                                                    letterSpacing: 0.2,
                                                  ),
                                                ),
                                                SizedBox(width: 5),
                                                Icon(
                                                  Icons
                                                      .arrow_forward_rounded,
                                                  size: 13,
                                                  color: Colors.white,
                                                ),
                                              ],
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

  Widget _billboardPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1040B0), Color(0xFF1A56DB), Color(0xFF3B7CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.campaign_rounded,
          size: 64,
          color: Colors.white.withValues(alpha: 0.22),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Metric({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Icon(icon, size: 18, color: Colors.grey[700]),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _EmptySearchState extends StatelessWidget {
  const _EmptySearchState({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blueGrey.withValues(alpha: 0.08),
              ),
              child: const Icon(Icons.search_off_rounded,
                  size: 40, color: Colors.blueGrey),
            ),
            const SizedBox(height: 14),
            const Text(
              'No results',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try a different keyword or check spelling.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}