// File: widgets/my_activity_dialog.dart
//
// "My Activity" bottom sheet for a user's own profile — a unified,
// reverse-chronological feed of posts they created, comments/replies they
// left (on posts and on thoughts), and outgoing views/calls they made on
// other profiles. Fed by GET /get_my_activity.

import 'package:flutter/material.dart';
import 'package:aaram_bd/config.dart';
import 'package:aaram_bd/screens/post_details.dart';
import 'package:aaram_bd/screens/thoughtdetails.dart'
    show ThoughtDetails, openProfileForEntity;

const Color _brand = Color(0xFF1A56DB);

IconData _iconForType(String type) {
  switch (type) {
    case 'post':
      return Icons.article_rounded;
    case 'post_comment':
      return Icons.chat_bubble_rounded;
    case 'post_reply':
      return Icons.reply_rounded;
    case 'thought_comment':
      return Icons.forum_rounded;
    case 'thought_reply':
      return Icons.reply_rounded;
    case 'call':
      return Icons.call_made_rounded;
    case 'view':
      return Icons.visibility_rounded;
    default:
      return Icons.circle_notifications_rounded;
  }
}

Color _colorForType(String type) {
  switch (type) {
    case 'post':
      return const Color(0xFF7C3AED);
    case 'post_comment':
    case 'post_reply':
      return const Color(0xFF1976D2);
    case 'thought_comment':
    case 'thought_reply':
      return const Color(0xFF0EA5A4);
    case 'call':
      return const Color(0xFF16A34A);
    case 'view':
      return const Color(0xFFF57C00);
    default:
      return Colors.grey;
  }
}

String _titleForItem(Map<String, dynamic> item) {
  final type = (item['activity_type'] ?? '').toString();
  final targetName = (item['target_name'] ?? '').toString();
  switch (type) {
    case 'post':
      return 'You created a post';
    case 'post_comment':
      return 'You commented on a post';
    case 'post_reply':
      return 'You replied on a post';
    case 'thought_comment':
      return 'You commented on a thought';
    case 'thought_reply':
      return 'You replied on a thought';
    case 'call':
      return targetName.isNotEmpty
          ? 'You called $targetName'
          : 'You made a call';
    case 'view':
      return targetName.isNotEmpty
          ? 'You viewed $targetName'
          : 'You viewed a profile';
    default:
      return 'Activity';
  }
}

void _onTapItem(
    BuildContext context, Map<String, dynamic> item, String currentUserId) {
  final type = (item['activity_type'] ?? '').toString();
  final refId = item['ref_id'];
  if (refId == null) return;

  switch (type) {
    case 'post':
    case 'post_comment':
    case 'post_reply':
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PostDetails(postId: refId.toString(), userId: currentUserId),
        ),
      );
      break;
    case 'thought_comment':
    case 'thought_reply':
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ThoughtDetails(desId: refId.toString())),
      );
      break;
    case 'call':
    case 'view':
      final targetUserId = (item['target_user_id'] ?? '').toString();
      if (targetUserId.isEmpty) return;
      openProfileForEntity(context, userId: targetUserId);
      break;
  }
}

void showMyActivityDialog({
  required BuildContext context,
  required List<Map<String, dynamic>> activityList,
  required Future<void> Function() loadMore,
  required bool hasMore,
  required String currentUserId,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _MyActivitySheet(
      initialList: activityList,
      loadMore: loadMore,
      hasMore: hasMore,
      currentUserId: currentUserId,
    ),
  );
}

class _MyActivitySheet extends StatefulWidget {
  final List<Map<String, dynamic>> initialList;
  final Future<void> Function() loadMore;
  final bool hasMore;
  final String currentUserId;

  const _MyActivitySheet({
    required this.initialList,
    required this.loadMore,
    required this.hasMore,
    required this.currentUserId,
  });

  @override
  State<_MyActivitySheet> createState() => _MyActivitySheetState();
}

class _MyActivitySheetState extends State<_MyActivitySheet> {
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
  void didUpdateWidget(covariant _MyActivitySheet oldWidget) {
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
    final sheetHeight = MediaQuery.of(context).size.height * 0.85;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: sheetHeight,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _brand.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.timeline_rounded,
                          color: _brand, size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'My Activity',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827)),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded,
                          color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: items.isEmpty
                    ? _EmptyState()
                    : ListView.separated(
                        controller: _sc,
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
                        itemCount: items.length + (_hasMore ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          if (index >= items.length) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: _loadingMore
                                    ? const CircularProgressIndicator(
                                        strokeWidth: 2)
                                    : const SizedBox.shrink(),
                              ),
                            );
                          }

                          final item = items[index];
                          final type = (item['activity_type'] ?? '').toString();
                          final color = _colorForType(type);
                          final targetName =
                              (item['target_name'] ?? '').toString();
                          final snippet = (item['snippet'] ?? '').toString();
                          final isComment = type.contains('comment') ||
                              type.contains('reply');

                          return Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => _onTapItem(
                                  context, item, widget.currentUserId),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color:
                                          Colors.black.withValues(alpha: 0.06)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(_iconForType(type),
                                          size: 16, color: color),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  _titleForItem(item),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                      fontSize: 13.5,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Color(0xFF111827)),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                Config.getTimeDifference(
                                                    (item['activity_time'] ??
                                                            '')
                                                        .toString(),
                                                    fallback: ''),
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    color:
                                                        Colors.grey.shade500),
                                              ),
                                            ],
                                          ),
                                          if (isComment &&
                                              targetName.isNotEmpty) ...[
                                            const SizedBox(height: 3),
                                            Text(
                                              'on: $targetName',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontStyle: FontStyle.italic,
                                                  color: Colors.grey.shade600),
                                            ),
                                          ],
                                          if (snippet.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              snippet,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontSize: 12.5,
                                                  color: Color(0xFF374151),
                                                  height: 1.35),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
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
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _brand.withValues(alpha: 0.08),
              ),
              child:
                  const Icon(Icons.timeline_rounded, size: 32, color: _brand),
            ),
            const SizedBox(height: 14),
            const Text(
              'No activity yet',
              style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87),
            ),
            const SizedBox(height: 6),
            Text(
              'Posts, comments, calls and views you make will show up here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
