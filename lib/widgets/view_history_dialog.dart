// File: widgets/view_history_bottom_sheet.dart

import 'package:aaram_bd/config.dart';
import 'package:flutter/material.dart';
import 'package:aaram_bd/screens/advert_screen.dart';

void showViewHistoryDialog({
  required BuildContext context,
  required List<Map<String, dynamic>> viewList,
  required Future<void> Function() loadMore,
  required bool hasMore,
}) {
  final sheetHeight = MediaQuery.of(context).size.height * 0.75;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (_) {
      return _ViewHistorySheet(
        initialList: viewList,
        loadMore: loadMore,
        hasMore: hasMore,
        sheetHeight: sheetHeight,
      );
    },
  );
}

class _ViewHistorySheet extends StatefulWidget {
  final List<Map<String, dynamic>> initialList;
  final Future<void> Function() loadMore;
  final bool hasMore;
  final double sheetHeight;

  const _ViewHistorySheet({
    required this.initialList,
    required this.loadMore,
    required this.hasMore,
    required this.sheetHeight,
    Key? key,
  }) : super(key: key);

  @override
  State<_ViewHistorySheet> createState() => _ViewHistorySheetState();
}

class _ViewHistorySheetState extends State<_ViewHistorySheet> {
  late List<Map<String, dynamic>> items;
  late ScrollController _sc;
  bool _loadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    items = List<Map<String, dynamic>>.from(widget.initialList);
    _hasMore = widget.hasMore;
    _sc = ScrollController()..addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant _ViewHistorySheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.initialList, widget.initialList)) {
      items = List<Map<String, dynamic>>.from(widget.initialList);
      _hasMore = widget.hasMore;
    }
  }

  @override
  void dispose() {
    _sc.removeListener(_onScroll);
    _sc.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || !_sc.hasClients) return;
    final pos = _sc.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    await widget.loadMore();
    await Future.delayed(const Duration(milliseconds: 150));
    setState(() {
      items = List<Map<String, dynamic>>.from(widget.initialList);
      _hasMore = widget.hasMore;
      _loadingMore = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalViews = items.fold<int>(
      0,
      (sum, e) => sum + int.tryParse((e['total_views'] ?? '0').toString())!,
    );

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: widget.sheetHeight,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 10),

              // Gradient header
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.visibility_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Seen By',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _HeaderPill(
                      icon: Icons.remove_red_eye_outlined,
                      label: '$totalViews views',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              Expanded(
                child: items.isEmpty
                    ? const _EmptyState()
                    : ListView.builder(
                        controller: _sc,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                        itemCount: items.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index < items.length) {
                            final v = items[index];

                            final avatarUrl =
                                (v['view_user_photo'] ?? '').toString();
                            final name =
                                (v['view_user_name'] ?? 'Unknown').toString();
                            final catName =
                                (v['cat_name'] ?? '').toString().trim();
                            final dtago = Config.getTimeDifference(
                                (v['last_view_time'] ?? '').toString());
                            final views =
                                (v['total_views']?.toString() ?? '0');

                            final serviceId = int.tryParse(
                                    (v['service_id'] ?? 0).toString()) ??
                                0;
                            final shopId =
                                int.tryParse((v['shop_id'] ?? 0).toString()) ??
                                    0;
                            final advertId = (v['advert_id'] ?? '').toString();

                            String targetId;
                            bool isService;
                            Map<String, String> additionalData;

                            if (serviceId != 0) {
                              targetId = serviceId.toString();
                              isService = true;
                              additionalData = {'service_id': targetId};
                            } else if (shopId != 0) {
                              targetId = shopId.toString();
                              isService = false;
                              additionalData = {'shop_id': targetId};
                            } else {
                              targetId = advertId;
                              isService = false;
                              additionalData = {'user_only': targetId};
                            }

                            return _ViewerTile(
                              name: name,
                              category: catName,
                              timeAgo: dtago,
                              views: views,
                              photoUrl: avatarUrl,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => AdvertScreen(
                                      userId: targetId,
                                      isService: isService,
                                      advertData: AdvertData(
                                        userId: targetId,
                                        isService: isService,
                                        additionalData: additionalData,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          } else {
                            return _LoadMoreFooter(
                              loading: _loadingMore,
                              onVisibleTrigger: () {
                                if (!_loadingMore) _loadMore();
                              },
                            );
                          }
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================== UI sub-widgets =====================

class _HeaderPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeaderPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 0.6),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewerTile extends StatelessWidget {
  final String name;
  final String category;
  final String timeAgo;
  final String views;
  final String photoUrl;
  final VoidCallback onTap;

  const _ViewerTile({
    required this.name,
    required this.category,
    required this.timeAgo,
    required this.views,
    required this.photoUrl,
    required this.onTap,
  });

  String _initials(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return '?';
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0F0F3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Avatar with subtle ring
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE0E7FF), Color(0xFFF5F3FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: const Color(0xFF93C5FD), width: 0.7),
                    ),
                  ),
                  CircleAvatar(
                    radius: 21,
                    backgroundColor: const Color(0xFFE5E7EB),
                    backgroundImage:
                        photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                    child: photoUrl.isEmpty
                        ? Text(
                            _initials(name),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF374151),
                            ),
                          )
                        : null,
                  ),
                ],
              ),
              const SizedBox(width: 12),

              // Texts
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name + time
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timeAgo,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Category
                    Row(
                      children: [
                        const Icon(Icons.label_outline,
                            size: 16, color: Color(0xFF6366F1)),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            category.isNotEmpty ? category : '—',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: Color(0xFF4B5563),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 3),

              // Count text (kept separate to align nicely)
              Container(
  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(30),
    border: Border.all(
      color: const Color(0xFF4F46E5),
      width: 1.2,
    ),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
        blurRadius: 6,
        offset: const Offset(0, 3),
      ),
    ],
  ),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        Icons.remove_red_eye_outlined,
        size: 14,
        color: const Color(0xFF4F46E5),
      ),
      const SizedBox(width: 3),
      Text(
        views,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: Color(0xFF4F46E5),
          fontSize: 14,
        ),
      ),
      const SizedBox(width: 3),
      const Text(
        "times",
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: Color(0xFF4F46E5),
          fontSize: 12,
        ),
      ),
    ],
  ),
)

            ],
          ),
        ),
      ),
    );
  }
}

class _LoadMoreFooter extends StatefulWidget {
  final bool loading;
  final VoidCallback onVisibleTrigger;

  const _LoadMoreFooter({
    required this.loading,
    required this.onVisibleTrigger,
  });

  @override
  State<_LoadMoreFooter> createState() => _LoadMoreFooterState();
}

class _LoadMoreFooterState extends State<_LoadMoreFooter> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onVisibleTrigger();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: widget.loading
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Loading more…',
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.visibility_off_rounded,
                size: 56, color: Color(0xFF9CA3AF)),
            SizedBox(height: 12),
            Text(
              'No views yet',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'People who view your advert will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
