// File: widgets/call_history_bottom_sheet.dart

import 'package:flutter/material.dart';
import 'package:aaram_bd/config.dart';
import 'package:aaram_bd/screens/advert_screen.dart';

/// Compact relative time ("13h", "5m", "2d") for tight list rows — unlike
/// Config.getTimeDifference's spelled-out "13 hours ago", which is too wide
/// to sit next to a name and category on the same line without overflowing.
String _compactTimeAgo(String timeString) {
  if (timeString.trim().isEmpty) return '';
  try {
    final past = Config.parseServerTime(timeString);
    if (past == null) return '';
    final rawDiff = DateTime.now().toUtc().difference(past);
    final diff = rawDiff.isNegative ? Duration.zero : rawDiff;

    if (diff.inSeconds < 60) return '${diff.inSeconds + 1}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 30) return '${diff.inDays}d';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo';
    return '${(diff.inDays / 365).floor()}y';
  } catch (_) {
    return '';
  }
}

void showCallHistoryBottomSheet({
  required BuildContext context,
  required List<Map<String, dynamic>> incomingCallList,
  required List<Map<String, dynamic>> outgoingCallList,
  required Future<void> Function() loadMore,
  required bool hasMore,
}) {
  final merged = <Map<String, dynamic>>[];
  merged.addAll(incomingCallList.map((c) => {...c, 'direction': 'incoming'}));
  merged.addAll(outgoingCallList.map((c) => {...c, 'direction': 'outgoing'}));

  merged.sort((a, b) {
    final dtA = Config.parseServerTime(a['last_call_time'] as String) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final dtB = Config.parseServerTime(b['last_call_time'] as String) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return dtB.compareTo(dtA);
  });

  final sheetHeight = MediaQuery.of(context).size.height * 0.8;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (_) {
      return _CallHistorySheet(
        initialMerged: merged,
        loadMore: loadMore,
        hasMore: hasMore,
        sheetHeight: sheetHeight,
      );
    },
  );
}

class _CallHistorySheet extends StatefulWidget {
  final List<Map<String, dynamic>> initialMerged;
  final Future<void> Function() loadMore;
  final bool hasMore;
  final double sheetHeight;

  const _CallHistorySheet({
    required this.initialMerged,
    required this.loadMore,
    required this.hasMore,
    required this.sheetHeight,
    Key? key,
  }) : super(key: key);

  @override
  State<_CallHistorySheet> createState() => _CallHistorySheetState();
}

class _CallHistorySheetState extends State<_CallHistorySheet> {
  late List<Map<String, dynamic>> merged;
  late ScrollController _sc;
  bool _loadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    merged = List<Map<String, dynamic>>.from(widget.initialMerged);
    _hasMore = widget.hasMore;
    _sc = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _sc.removeListener(_onScroll);
    _sc.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore) return;
    if (!_sc.hasClients) return;
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
      _loadingMore = false;
      _hasMore = widget.hasMore; // rely on parent to update before next open
    });
  }

  @override
  Widget build(BuildContext context) {
    final incomingCount =
        merged.where((m) => m['direction'] == 'incoming').length;
    final outgoingCount =
        merged.where((m) => m['direction'] == 'outgoing').length;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: widget.sheetHeight,

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
              // Grab handle
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
                    colors: [Color(0xFF6D28D9), Color(0xFF9333EA)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.history_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Call History',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _CloseButton(onTap: () => Navigator.pop(context)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _Chip(label: 'In: $incomingCount', color: const Color(0xFF10B981)),
                        const SizedBox(width: 8),
                        _Chip(label: 'Out: $outgoingCount', color: const Color(0xFF3B82F6)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Content
              Expanded(
                child: merged.isEmpty
                    ? _EmptyState()
                    : ListView.builder(
                        controller: _sc,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                        itemCount: merged.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (i < merged.length) {
                            final c = merged[i];
                            final name = (c['name'] as String?)?.trim().isNotEmpty == true
                                ? c['name'] as String
                                : 'Unknown';
                            final photo = c['photo'] as String? ?? '';
                            final total = (c['total_calls'] ?? 0).toString();
                            final incoming = c['direction'] == 'incoming';
                            final icon = incoming
                                ? Icons.call_received
                                : Icons.call_made;
                            final iconColor =
                                incoming ? const Color(0xFF10B981) : const Color(0xFF3B82F6);
                            final catName = c['cat_name'] as String? ?? '';
                            final dtago =
                                _compactTimeAgo(c['last_call_time'] as String? ?? '');
                            final serviceId = c['service_id'] as int? ?? 0;
                            final shopId = c['shop_id'] as int? ?? 0;
                            // The caller's real user_id — must be used for
                            // AdvertScreen's userId (review summary / view
                            // tracking target). serviceId/shopId are a
                            // separate id space, only valid for
                            // additionalData routing.
                            final callerUserId =
                                (c['call_user_id'] ?? '').toString();

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
                              isService = false;
                              additionalData = {'user_only': callerUserId};
                            }

                            return _CallTile(
                              name: name,
                              category: catName,
                              timeAgo: dtago,
                              total: total,
                              directionIcon: icon,
                              accentColor: iconColor,
                              photoUrl: photo,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => AdvertScreen(
                                      userId: callerUserId,
                                      isService: isService,
                                      advertData: AdvertData(
                                        userId: callerUserId,
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

// ===================== UI Sub-widgets (visual only) =====================

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

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
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
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

class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
      ),
    );
  }
}

class _CallTile extends StatelessWidget {
  final String name;
  final String category;
  final String timeAgo;
  final String total;
  final IconData directionIcon;
  final Color accentColor;
  final String photoUrl;
  final VoidCallback onTap;

  const _CallTile({
    required this.name,
    required this.category,
    required this.timeAgo,
    required this.total,
    required this.directionIcon,
    required this.accentColor,
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
      margin: const EdgeInsets.only(bottom: 10),
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar with ring
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [accentColor.withValues(alpha: 0.15), Colors.white],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: accentColor.withValues(alpha: 0.35)),
                    ),
                  ),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFFE5E7EB),
                    backgroundImage:
                        photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                    child: photoUrl.isEmpty
                        ? Text(
                            _initials(name),
                            style: const TextStyle(
                              fontSize: 13,
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    // Direction icon + category, with time trailing
                    Row(
                      children: [
                        Icon(directionIcon, size: 14, color: accentColor),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            category.isNotEmpty ? category : '—',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (timeAgo.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            '· $timeAgo',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF9CA3AF),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Total calls badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: accentColor.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.call_rounded, size: 14, color: accentColor),
                    const SizedBox(width: 5),
                    Text(
                      total,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                      ),
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
    // Trigger when footer builds (near end of list)
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
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF6D28D9).withValues(alpha: 0.12),
                    const Color(0xFF9333EA).withValues(alpha: 0.06),
                  ],
                ),
              ),
              child: const Icon(Icons.phone_disabled_rounded,
                  size: 38, color: Color(0xFF6D28D9)),
            ),
            const SizedBox(height: 16),
            const Text(
              'No calls yet',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Your recent call activity will appear here once available.',
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
