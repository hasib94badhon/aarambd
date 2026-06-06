import 'dart:convert';
import 'package:aaram_bd/screens/advert_screen.dart';
import 'package:aaram_bd/screens/post_details.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aaram_bd/widgets/user_service.dart';
import 'package:aaram_bd/config.dart';

final String host = Config.host;

class NotificationShow extends StatefulWidget {
  const NotificationShow({Key? key}) : super(key: key);

  @override
  State<NotificationShow> createState() => _NotificationShowState();
}

class _NotificationShowState extends State<NotificationShow> {
  List notifications = [];
  bool isLoading = true;

  int _currentPage = 1;
  final int _pageSize = 10;
  bool _isFetchingMore = false;
  bool _hasMore = true;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    fetchNotifications(page: 1);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || !_hasMore || _isFetchingMore) return;

    final threshold = 200.0;
    final position = _scrollController.position;

    if (position.pixels >= position.maxScrollExtent - threshold) {
      fetchNotifications(page: _currentPage + 1);
    }
  }

  Future<String?> getLoggedInUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id');
  }

  Future<void> fetchNotifications({required int page}) async {
    String? userId = await getLoggedInUser();
    if (userId == null || _isFetchingMore || !_hasMore) return;

    setState(() => _isFetchingMore = true);

    final response = await Config.apiGet(
        '/get_notifications?user_id=$userId&page=$page&page_size=$_pageSize',
        context);
    print(
        '🔄 Fetching notifications: $host/get_notifications?user_id=$userId&page=$page&page_size=$_pageSize');

    if (response != null && response.statusCode == 200) {
      final data = json.decode(response.body);
      final List newNotifs = data['notifications'] ?? [];

      setState(() {
        if (page == 1) {
          notifications = newNotifs;
        } else {
          notifications.addAll(newNotifs);
        }

        _currentPage = page;
        _hasMore = newNotifs.length == _pageSize;
        isLoading = false;
      });
    } else {
      setState(() {
        _hasMore = false;
        isLoading = false;
      });
    }

    _isFetchingMore = false;
  }

  Future<void> markNotificationsAsRead(String userId) async {
    await Config.apiPost(
        '/mark_notifications_read', {'user_id': userId}, context);
  }

  Future<void> markAsRead(int index) async {
    String? userId = await getLoggedInUser();
    if (userId == null) return;

    await markNotificationsAsRead(userId); // Backend update

    setState(() {
      notifications[index]['is_read'] = 1; // Local UI update
    });

    getUnreadCount(); // Update badge count
  }

 void getUnreadCount() async {
  final userId = await getLoggedInUser();
  if (userId == null) return;

  final response = await Config.apiGet(
    '/get_notifications?user_id=$userId&page=1&page_size=100',
    context,
  );

  if (response != null && response.statusCode == 200) {
    final data = json.decode(response.body);
    final list = (data['notifications'] as List?) ?? const [];
    final count = list.where((n) => (n['is_read'] == 0)).length;
    // TODO: pass this 'count' back up to whatever sets your badge
    debugPrint('[Notif] Unread count: $count');
  }
}


 String getTimeDifference(String dateTime) {
  DateTime? notifTime;
  try {
    notifTime = DateTime.parse(dateTime);
  } catch (_) {
    // Try trimming or replacing space with 'T'
    try {
      notifTime = DateTime.parse(dateTime.replaceFirst(' ', 'T'));
    } catch (_) {
      return 'now';
    }
  }

  final diff = DateTime.now().difference(notifTime);
  if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 30) return '${diff.inDays}d ago';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}m ago';
  return '${(diff.inDays / 365).floor()}y ago';
}


  IconData getIconByType(String type) {
    switch (type) {
      case 'view':
        return Icons.remove_red_eye;
      case 'call':
        return Icons.call;
      case 'share':
        return Icons.share;
      case 'comment':
        return Icons.comment;
      default:
        return Icons.notifications;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'view':
        return Colors.blueAccent;
      case 'call':
        return Colors.green;
      case 'share':
        return Colors.deepPurple;
      case 'comment':
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }

  Widget _avatar(String? url, {double radius = 24}) {
    final has = (url != null && url.isNotEmpty);
    // gradient ring + avatar
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF7F7FD5), Color(0xFF86A8E7), Color(0xFF91EAE4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: Colors.white,
        child: CircleAvatar(
          radius: radius - 2,
          backgroundColor: Colors.grey.shade200,
          backgroundImage: has ? NetworkImage(url!) : null,
          child: !has ? const Icon(Icons.person, color: Colors.grey) : null,
        ),
      ),
    );
  }

  Widget _timeBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6F9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black12.withValues(alpha: 0.06)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11.5, color: Colors.grey),
      ),
    );
  }

  Widget _typeChip(String type) {
    final color = _typeColor(type);
    final icon = getIconByType(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            type.isEmpty ? 'notice' : type,
            style: TextStyle(
                fontSize: 12, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _unreadBadge(bool unread, Color accent) {
    if (!unread) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: const Text(
        'NEW',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _notificationCard(Map notif, int index) {
    final String type = (notif['type'] ?? '').toString();
    final bool unread = (notif['is_read'] == 0);
    final String timeText = getTimeDifference(notif['created_at']);
    final Color accent = _typeColor(type);
    final IconData typeIcon = getIconByType(type);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            await markAsRead(index);

            String? userId = notif['user_id']?.toString();
            int postId =
                int.tryParse(notif['detail_post_id']?.toString() ?? '0') ?? 0;
            bool isService = notif['is_service'] == 1;
            int service_id =
                int.tryParse(notif['service_id']?.toString() ?? '0') ?? 0;
            int shop_id =
                int.tryParse(notif['shop_id']?.toString() ?? '0') ?? 0;

            if (type == 'comment') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PostDetails(
                    postId: postId.toString(),
                    userId: userId ?? '',
                  ),
                ),
              );
            } else if (type == 'call' || type == 'view' || type == 'share') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AdvertScreen(
                    advertData: AdvertData(
                      userId: userId ?? '',
                      isService: isService,
                      additionalData: isService
                          ? {'service_id': service_id}
                          : {'shop_id': shop_id},
                    ),
                    userId: userId ?? '',
                    isService: isService,
                  ),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Unknown notification type")),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black12,
                    blurRadius: 12,
                    offset: Offset(0, 6)),
              ],
              border: Border.all(
                color: unread
                    ? accent.withValues(alpha: 0.28)
                    : Colors.black12.withValues(alpha: 0.06),
                width: unread ? 1.2 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar with small type bubble
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _avatar(notif['user_pic']),
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black12,
                                blurRadius: 6,
                                offset: Offset(0, 3)),
                          ],
                        ),
                        child: Center(
                          child: Icon(typeIcon, size: 14, color: accent),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),

                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // First row: message + time + NEW
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              (notif['message'] ?? '').toString(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15.5,
                                height: 1.28,
                                fontWeight:
                                    unread ? FontWeight.w800 : FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _timeBadge(timeText),
                          const SizedBox(width: 6),
                          _unreadBadge(unread, accent),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Second row: type chip + chevron
                      Row(
                        children: [
                          _typeChip(type),
                          const Spacer(),
                          Icon(Icons.chevron_right_rounded,
                              color: Colors.black26),
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      backgroundColor: const Color(0xFFF7F8FA),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : notifications.isEmpty
              ? const Center(
                  child: Text(
                    'No Notifications Found',
                    style: TextStyle(fontSize: 18),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => fetchNotifications(page: 1),
                  child: ListView.builder(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics()),
                    padding: const EdgeInsets.only(top: 6, bottom: 12),
                    // itemCount: notifications.length,
                    // itemBuilder: (context, index) {
                    //   final notif = notifications[index];
                    //   return _notificationCard(notif, index);
                    // },
                    itemCount: notifications.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index < notifications.length) {
                        final notif = notifications[index];
                        return _notificationCard(notif, index);
                      } else {
                        // Bottom loader while next page is fetching
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                    },
                  ),
                ),
    );
  }
}
