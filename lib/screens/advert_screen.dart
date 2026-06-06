// advert_screen.dart
// UI-only improvements for reliable image fitting without touching backend logic.

import 'dart:async';
import 'dart:convert';

import 'package:aaram_bd/config.dart';
import 'package:aaram_bd/screens/post_details.dart';
import 'package:aaram_bd/widgets/notification_service.dart';
import 'package:aaram_bd/widgets/post_sorting_buttons.dart';
import 'package:aaram_bd/widgets/profile_picture_dialog.dart';
import 'package:aaram_bd/widgets/userstarwidget.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:marquee/marquee.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/ExpandableText.dart';

final String host = Config.host;

/// ------------------------------
/// Models
/// ------------------------------
class UserDetail {
  final String address;
  final String
      location; // get from GPS (your naming was swapped; kept same mapping)
  final String businessName;
  final String category;
  final String description;
  final String phone;
  final String photo;
  final int serviceId;
  final int shopId;
  final int user_called;
  final int user_shared;
  final int user_viewed;
  final int user_id;
  final List<PostDetail> posts;
  final int? cat_id; // nullable
  final bool is_service;
  final int service_or_shop_id;
  final String? user_distance;
  final String? call_status;
  final String? sub_type;
  final String? nid;
  final String? tin;
  final String? totalpost;

  UserDetail({
    required this.address,
    required this.businessName,
    required this.category,
    required this.description,
    required this.phone,
    required this.photo,
    required this.serviceId,
    required this.shopId,
    required this.user_called,
    required this.user_shared,
    required this.user_viewed,
    required this.user_id,
    required this.cat_id,
    required this.posts,
    required this.is_service,
    required this.service_or_shop_id,
    this.user_distance,
    this.location = '',
    this.call_status,
    this.sub_type,
    this.nid,
    this.tin,
    this.totalpost,
  });

  factory UserDetail.fromJson(Map<String, dynamic> json) {
    final int serviceId = json['service_id'] ?? 0;
    final int shopId = json['shop_id'] ?? 0;
    final bool isService = serviceId != 0;

    return UserDetail(
      cat_id: json['cat_id'],
      address: json['location'] ?? '',
      location: json['address'] ?? '',
      category: json['cat_name'] ?? 'Unknown',
      description: (json['description'] ?? '').toString(),
      businessName: json['name'] ?? '',
      phone: json['phone']?.toString() ?? '',
      photo: json['photo'] ?? '',
      serviceId: serviceId,
      shopId: shopId,
      service_or_shop_id: isService ? serviceId : shopId,
      is_service: isService,
      user_called: json['user_called'] ?? 0,
      user_shared: json['user_shared'] ?? 0,
      user_viewed: json['user_viewed'] ?? 0,
      user_id: json['user_id'] ?? 0,
      user_distance: json['distance']?.toString(),
      call_status: json['call_status'],
      sub_type: json['type'],
      nid: json['nid'],
      tin: json['tin'],
      totalpost: json['total_posts']?.toString(),
      posts: (json['posts'] as List?)
              ?.map((postJson) => PostDetail.fromJson(postJson))
              .toList() ??
          [],
    );
  }
}

class PostDetail {
  final int postId;
  final String postDes; // may be comma-separated captions
  final String
      postMedia; // may be json array string / comma-separated / single URL
  final String postTime;
  final int postViewed;
  final int postComments;
  final String postMainDesc;

  PostDetail({
    required this.postId,
    required this.postDes,
    required this.postMedia,
    required this.postTime,
    required this.postViewed,
    required this.postComments,
    required this.postMainDesc,
  });

  factory PostDetail.fromJson(Map<String, dynamic> json) {
    // Keep raw post_media; we'll normalize in UI widgets
    final rawMedia = json['post_media'];
    String postMediaStr;
    if (rawMedia is List) {
      postMediaStr = rawMedia.join(',');
    } else {
      postMediaStr = (rawMedia ?? '').toString();
    }

    return PostDetail(
      postId: json['post_id'] ?? 0,
      postDes: (json['post_des'] ?? '').toString(),
      postMedia: postMediaStr,
      postMainDesc: (json['post_main_description'] ?? '').toString(),
      postTime: (json['post_time'] ?? '').toString(),
      postViewed: json['post_viewed'] ?? 0,
      postComments: json['comment_count'] ?? 0,
    );
  }
}

class AdvertData {
  final String userId;
  final bool isService;
  final Map<String, dynamic> additionalData;

  AdvertData({
    required this.userId,
    required this.isService,
    required this.additionalData,
  });
}

/// ------------------------------
/// Screen
/// ------------------------------
class AdvertScreen extends StatefulWidget {
  final AdvertData advertData;
  final String userId;
  final bool isService;

  const AdvertScreen({
    Key? key,
    required this.advertData,
    required this.userId,
    required this.isService,
  }) : super(key: key);

  @override
  _AdvertScreenState createState() => _AdvertScreenState();
}

class _AdvertScreenState extends State<AdvertScreen> {
  final String userPhone = '';
  List<int> favoriteUserIds = [];
  String selectedSortValue = 'recent'; // default sort

  List<dynamic> viewList = [];
  List<dynamic> callList = [];

  Future<List<UserDetail>>? userDetailsFuture;
  String? loginUserId;

  final ScrollController _scrollController = ScrollController();
  bool isloading = false;

  int _currentPage = 1;
  final int _pageSize = 8;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  List<PostDetail> _posts = [];

  // Review state
  Map<String, dynamic>? _reviewSummary;
  int? _myReviewId;

  @override
  void initState() {
    super.initState();
    _loadFavoriteUserIds();
    fetchViewList(widget.userId, context);
    _fetchReviewSummary(int.parse(widget.userId));

    _getUserId().then((id) {
      setState(() {
        loginUserId = id;
      });
      if (loginUserId != null) {
        // Prime first fetch
        userDetailsFuture =
            fetchUserDetails(widget.advertData, selectedSortValue);
        _loadPosts(reset: true);
        _checkMyReview(int.parse(widget.userId));
      }
    });

    _scrollController.addListener(() {
      final pos = _scrollController.position;
      if (pos.pixels >= pos.maxScrollExtent - 200) {
        if (_hasMore && !_isLoadingMore) {
          _loadPosts(); // next page
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool isFavorited(UserDetail user) => favoriteUserIds.contains(user.user_id);

  void toggleFavorite(UserDetail user) {
    setState(() {
      if (isFavorited(user)) {
        favoriteUserIds.remove(user.user_id);
        removeFromFavorite(user, context);
      } else {
        favoriteUserIds.add(user.user_id);
        addToFavorite(user, context);
      }
    });
  }

  Future<void> _loadPosts({bool reset = false}) async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);

    if (reset) {
      _currentPage = 1;
      _posts.clear();
      _hasMore = true;
    }

    try {
      final details = await fetchUserDetails(
        widget.advertData,
        selectedSortValue,
        page: _currentPage,
        pageSize: _pageSize,
      );

      if (details.isEmpty) {
        setState(() => _hasMore = false);
        return;
      }

      final newPosts = details[0].posts;
      final totalPosts = int.tryParse(details[0].totalpost ?? '0') ?? 0;

      setState(() {
        _posts.addAll(newPosts);
        _hasMore = _posts.length < totalPosts && newPosts.isNotEmpty;
        _currentPage++;
      });
      print("Loaded page $_currentPage, total posts: ${_posts.length}");
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  /// ------------------------------
  /// API callers (unchanged behavior; UI-only work here)
  /// ------------------------------
  Future<List<UserDetail>> fetchUserDetails(
    AdvertData advertData,
    String sortBy, {
    int page = 1,
    int pageSize = 8,
  }) async {
    String? idParam;
    if (advertData.additionalData.containsKey('service_id')) {
      idParam = 'service_id=${advertData.additionalData['service_id']}';
    } else if (advertData.additionalData.containsKey('shop_id')) {
      idParam = 'shop_id=${advertData.additionalData['shop_id']}';
    } else {
      idParam = '';
    }

    final String url =
        '/get_service_or_shop_data${idParam.isNotEmpty ? '?$idParam&' : '?'}sort_by=$sortBy&page=$page&page_size=$pageSize';

    final prefs = await SharedPreferences.getInstance();
    final String? loginUserId = prefs.getString('user_id');

    final Map<String, dynamic> requestBody = {
      'login_user_id': loginUserId,
    };

    if (advertData.additionalData.containsKey('user_only')) {
      requestBody['user_id'] = advertData.additionalData['user_only'];
    }

    try {
      final response = await Config.apiPost(url, requestBody, context);
      if (response != null && response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);

        String? dataKey;
        if (jsonResponse.containsKey('service_data')) {
          dataKey = 'service_data';
        } else if (jsonResponse.containsKey('shop_data')) {
          dataKey = 'shop_data';
        } else if (jsonResponse.containsKey('user_data')) {
          dataKey = 'user_data';
        }

        final userDetails = dataKey != null
            ? (jsonResponse[dataKey] as List)
                .map((data) => UserDetail.fromJson(data))
                .toList()
            : <UserDetail>[];

        return userDetails;
      } else {
        throw Exception('Failed to load data from API');
      }
    } catch (e) {
      throw Exception("An unexpected error occurred: ${e.toString()}");
    }
  }

  void loadUserDetails() async {
    setState(() => isloading = true);

    try {
      final details =
          await fetchUserDetails(widget.advertData, selectedSortValue);
      setState(() {
        userDetailsFuture = Future.value(details);
        isloading = false;
      });
    } catch (e) {
      debugPrint("Failed to load sorted data: $e");
      setState(() => isloading = false);
    }
  }

  Future<void> _loadFavoriteUserIds() async {
    final loggedInUserId = await _getUserId();
    try {
      final response = await Config.apiGet(
          '/get_favorite_user_ids?user_id=$loggedInUserId', context);
      if (response != null && response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          favoriteUserIds = List<int>.from(data['favorite_user_ids']);
        });
      } else {
        debugPrint("Failed to load favorites: ${response?.body}");
      }
    } catch (e) {
      debugPrint("Error loading favorites: $e");
    }
  }

  Future<void> fetchViewList(String userId, BuildContext context) async {
    try {
      final response =
          await Config.apiGet('/get_view_list?user_id=$userId', context);
      if (response != null && response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        setState(() {
          viewList = (jsonData['view_list'] ?? []) as List;
        });
      } else {
        debugPrint(
            "Failed to load view list, status code: ${response?.statusCode}");
      }
    } catch (error) {
      debugPrint("Error fetching view list: $error");
    }
  }

  Future<void> fetchCallList(String userId, BuildContext context) async {
    try {
      final response =
          await Config.apiGet('/get_call_list?user_id=$userId', context);
      if (response != null && response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        setState(() {
          callList = (jsonData['incoming_calls'] ?? []) as List;
        });
      } else {
        debugPrint(
            "Failed to load call list, status code: ${response?.statusCode}");
      }
    } catch (error) {
      debugPrint("Error fetching call list: $error");
    }
  }

  Future<String?> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id');
  }

  static Future<String?> getLoggedInPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userPhone');
  }

  void addToFavorite(UserDetail user, BuildContext context) async {
    final loggedInUserId = await _getUserId();
    final resp = await Config.apiPost(
      "/add_to_favorite_users",
      {"user_id": loggedInUserId, "fav_users": user.user_id},
      context,
    );
    if (resp != null && resp.statusCode == 200) {
      debugPrint("Added to favorite successfully");
    }
  }

  void removeFromFavorite(UserDetail user, BuildContext context) async {
    final loggedInUserId = await _getUserId();
    final resp = await Config.apiPost(
      "/remove_from_favorite_users",
      {"user_id": loggedInUserId, "fav_users": user.user_id},
      context,
    );
    if (resp != null && resp.statusCode == 200) {
      debugPrint("Removed from favorites successfully");
    }
  }

  // ── Review helpers ──────────────────────────────────────────────────────────

  Future<void> _fetchReviewSummary(int userId) async {
    try {
      final resp = await Config.apiGet('/review/summary?reviewed_id=$userId', context);
      if (resp != null && resp.statusCode == 200) {
        setState(() => _reviewSummary = jsonDecode(resp.body));
      }
    } catch (e) {
      debugPrint("Error fetching review summary: $e");
    }
  }

  Future<void> _checkMyReview(int reviewedId) async {
    final myId = loginUserId;
    if (myId == null) return;
    try {
      final resp = await Config.apiGet(
          '/review/mine?reviewed_id=$reviewedId&reviewer_id=$myId', context);
      if (resp != null && resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final review = data['review'];
        setState(() => _myReviewId = review != null ? review['review_id'] : null);
      }
    } catch (e) {
      debugPrint("Error checking my review: $e");
    }
  }

  void _showReviewSheet(UserDetail user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReviewSheet(
        reviewedId: user.user_id,
        reviewedName: user.businessName,
        reviewedPhoto: user.photo,
        myReviewId: _myReviewId,
        loginUserId: int.tryParse(loginUserId ?? ''),
        onReviewChanged: () {
          _fetchReviewSummary(user.user_id);
          _checkMyReview(user.user_id);
        },
      ),
    );
  }

  // ── Review UI ────────────────────────────────────────────────────────────────

  Widget _buildReviewSection(UserDetail user) {
    final good  = _reviewSummary?['good_count'] ?? 0;
    final bad   = _reviewSummary?['bad_count'] ?? 0;
    final total = _reviewSummary?['total'] ?? 0;
    final isOwnProfile =
        loginUserId != null && int.tryParse(loginUserId!) == user.user_id;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: const Border.fromBorderSide(BorderSide(color: Color(0xFFE8EDF5))),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Reviews',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A2340),
                ),
              ),
              if (!isOwnProfile)
                GestureDetector(
                  onTap: () => _showReviewSheet(user),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDF4FF),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _myReviewId != null
                              ? Icons.edit_outlined
                              : Icons.rate_review_outlined,
                          size: 13,
                          color: const Color(0xFF1A56DB),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _myReviewId != null ? 'Edit Review' : 'Write Review',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A56DB),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _reviewBadge(Icons.thumb_up_rounded, '$good Good',
                  const Color(0xFF16A34A), const Color(0xFFF0FDF4)),
              const SizedBox(width: 8),
              _reviewBadge(Icons.thumb_down_rounded, '$bad Bad',
                  const Color(0xFFDC2626), const Color(0xFFFEF2F2)),
              const Spacer(),
              if (total > 0)
                GestureDetector(
                  onTap: () => _showReviewSheet(user),
                  child: Text(
                    'See all $total',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF1A56DB),
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

  Widget _reviewBadge(IconData icon, String label, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────

  void updateUserCalled(String id, bool isService) async {
    final String idParam = isService ? 'service_id=$id' : 'shop_id=$id';
    final String url = '/post_user_called?$idParam';

    final String callTime = DateTime.now().toIso8601String();
    final prefs = await SharedPreferences.getInstance();
    final String? loginUserId = prefs.getString('user_id');

    try {
      final response = await Config.apiPost(
        url,
        {"call_user_id": loginUserId, "call_time": callTime, "user_id": id},
        context,
      );
      if (response != null && response.statusCode == 200) {
        debugPrint("User Called updated successfully");
      } else {
        debugPrint("Failed to update user called: ${response?.body}");
      }
    } catch (e) {
      debugPrint("Error updating user called: $e");
    }
  }

  void handleAction(int user_id, String actionType, int detail_post_id) async {
    // Your NotificationService call preserved (assuming same signature)
    // you had issues here, keep this as-is; omitted import to keep code focused on UI.
    NotificationService notificationService = NotificationService();
    await notificationService.sendNotificationWithLoggedInUser(
        user_id, actionType, detail_post_id, context);
  }

  String getTimeDifference(String rawDateTime) {
    try {
      rawDateTime =
          rawDateTime.replaceAll(',', '').replaceAll('GMT', '').trim();
      final DateFormat formatter = DateFormat('EEE dd MMM yyyy HH:mm:ss');
      final DateTime notifTime = formatter.parseUtc(rawDateTime);
      final Duration diff = DateTime.now().toUtc().difference(notifTime);

      if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 30) return '${diff.inDays}d ago';
      if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
      return '${(diff.inDays / 365).floor()}y ago';
    } catch (_) {
      return 'Just now';
    }
  }

  Future<void> shareAdvertProfile({
    required int id,
    required bool isService,
    required String userName,
    required String userCategory,
    required String userAddress,
    required BuildContext context,
  }) async {
    try {
      final type = isService ? 'Service' : 'Shop';

      final appLink = defaultTargetPlatform == TargetPlatform.iOS
          ? 'https://apps.apple.com/app/id1234567890' // replace with real App Store ID
          : 'https://play.google.com/store/apps/details?id=com.aarambd.marketing';

      final shareMessage = type +
          ' Profile\n' +
          'Name: ' +
          userName +
          '\n' +
          'Category: ' +
          userCategory +
          '\n' +
          'Address: ' +
          userAddress +
          '\n\n' +
          'Check it out on AaramBD!\n' +
          appLink;

      final overlay =
          Overlay.of(context).context.findRenderObject() as RenderBox?;

      final params = ShareParams(
        text: shareMessage,
        subject: "$type Profile - AaramBD",
        sharePositionOrigin: overlay != null
            ? overlay.localToGlobal(Offset.zero) & overlay.size
            : const Rect.fromLTWH(0, 0, 1, 1),
      );

      await SharePlus.instance.share(params);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sharing: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// ------------------------------
  /// UI Helpers
  /// ------------------------------

  // Safely split mixed-format postMedia into clean URL list
  List<String> _parseMediaToList(String postMedia) {
    if (postMedia.trim().isEmpty) return [];
    // Try JSON first
    try {
      final decoded = jsonDecode(postMedia);
      if (decoded is List) {
        return decoded
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    } catch (_) {
      // not JSON, fallthrough to comma split
    }
    return postMedia
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  // Lightweight fade-in network image that always fits nicely
  Widget _coverImage(String url,
      {double? width,
      double? height,
      BoxFit fit = BoxFit.cover,
      BorderRadius? radius}) {
    final img = Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      alignment: Alignment.center,
      // smooth appearance; avoids layout jumps
      frameBuilder: (ctx, child, frame, wasSyncLoaded) {
        if (wasSyncLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeIn,
          child: child,
        );
      },
      errorBuilder: (ctx, error, stack) => Container(
        width: width,
        height: height,
        color: Colors.grey[200],
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image, size: 42, color: Colors.grey),
      ),
    );

    if (radius != null) {
      return ClipRRect(borderRadius: radius, child: img);
    }
    return img;
  }

  Widget _buildHeader(UserDetail user) {
    final bool isActive = user.call_status?.toLowerCase() == 'active';
    return Container(
      color: const Color(0xFFF0F4FA),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Star badge + Favorite button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UserStarWidget(
                phone: user.phone,
                name: user.businessName,
                profilePicture: user.photo,
                tin: user.tin,
                nid: user.nid,
                postCount: user.posts.length,
                view: user.user_viewed,
                sub_type: user.sub_type,
                usercall: user.user_called,
              ),
              GestureDetector(
                onTap: () => toggleFavorite(user),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFavorited(user)
                        ? const Color(0xFFFFF0F0)
                        : const Color(0xFFF1F5F9),
                    border: Border.all(
                      color: isFavorited(user)
                          ? const Color(0xFFFCA5A5)
                          : const Color(0xFFCBD5E1),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isFavorited(user)
                            ? const Color(0xFFFCA5A5).withValues(alpha: 0.5)
                            : Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(
                    isFavorited(user)
                        ? Icons.favorite_rounded
                        : Icons.favorite_outline_rounded,
                    color: isFavorited(user)
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF64748B),
                    size: 22,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Profile info card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar + name/category
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Stack(
                      children: [
                        ProfilePictureDialog(photoUrl: user.photo),
                        if (user.sub_type != null)
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: user.sub_type == 'paid'
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF1A56DB)
                                              .withValues(alpha: 0.25),
                                          blurRadius: 6,
                                          spreadRadius: 1,
                                        )
                                      ]
                                    : [],
                              ),
                              padding: const EdgeInsets.all(3),
                              child: Icon(
                                Icons.verified_rounded,
                                size: 22,
                                color: user.sub_type == 'paid'
                                    ? const Color(0xFF1A56DB)
                                    : const Color(0xFFCBD5E1),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.businessName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              color: Color(0xFF1A2340),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEDF4FF),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              user.category,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF1A56DB),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (user.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  ExpandableDescription(text: user.description.trim()),
                ],

                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // Stats row
                Row(
                  children: [
                    _statBadge(
                      icon: Icons.phone_in_talk_rounded,
                      label: '${Config.formatLargeNumber(user.user_called)} Calls',
                      iconColor: const Color(0xFF1A56DB),
                      bgColor: const Color(0xFFEDF4FF),
                    ),
                    const SizedBox(width: 8),
                    _statBadge(
                      icon: Icons.visibility_rounded,
                      label: '${Config.formatLargeNumber(user.user_viewed)} Views',
                      iconColor: const Color(0xFFDB2777),
                      bgColor: const Color(0xFFFDF2F8),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Action buttons row
                Row(
                  children: [
                    // Share
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => shareAdvertProfile(
                          id: user.is_service ? user.serviceId : user.shopId,
                          isService: user.is_service,
                          userName: user.businessName,
                          userCategory: user.category,
                          userAddress: user.location,
                          context: context,
                        ),
                        icon: const Icon(Icons.share_outlined, size: 17),
                        label: const Text('Share'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF7C3AED),
                          side: const BorderSide(color: Color(0xFF7C3AED)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          textStyle: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Call
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isActive
                            ? () async {
                                handleAction(user.user_id, 'call', 0);
                                updateUserCalled(
                                  user.service_or_shop_id.toString(),
                                  user.is_service,
                                );
                                final Uri telUri =
                                    Uri(scheme: 'tel', path: user.phone);
                                if (await canLaunchUrl(telUri)) {
                                  await launchUrl(telUri);
                                }
                              }
                            : null,
                        icon: const Icon(Icons.call_rounded, size: 17),
                        label: const Text('Call'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isActive
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFE2E8F0),
                          foregroundColor:
                              isActive ? Colors.white : const Color(0xFF94A3B8),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          textStyle: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // WhatsApp
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isActive
                            ? () async {
                                handleAction(user.user_id, 'call', 0);
                                updateUserCalled(
                                  user.service_or_shop_id.toString(),
                                  user.is_service,
                                );
                                final phoneNumber = user.phone.trim();
                                final fullNumber = phoneNumber.startsWith('+')
                                    ? phoneNumber
                                    : '+88$phoneNumber';
                                final Uri whatsappUri = Uri.parse(
                                    "https://wa.me/${fullNumber.replaceAll('+', '')}");
                                if (await canLaunchUrl(whatsappUri)) {
                                  await launchUrl(whatsappUri,
                                      mode: LaunchMode.externalApplication);
                                }
                              }
                            : null,
                        icon: FaIcon(
                          FontAwesomeIcons.whatsapp,
                          size: 16,
                          color: isActive ? Colors.white : const Color(0xFF94A3B8),
                        ),
                        label: const Text('WhatsApp'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isActive
                              ? const Color(0xFF25D366)
                              : const Color(0xFFE2E8F0),
                          foregroundColor:
                              isActive ? Colors.white : const Color(0xFF94A3B8),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          textStyle: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBadge({
    required IconData icon,
    required String label,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: iconColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSlider(List<PostDetail> posts, int userId) {
    // Collect first image + postId for each post
    final items = posts
        .map((p) {
          final urls = _parseMediaToList(p.postMedia);
          if (urls.isNotEmpty) {
            return {'url': urls.first, 'postId': p.postId};
          }
          return null;
        })
        .where((e) => e != null)
        .toList();

    // ✅ If no post images, show animated banner
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: _NoPostsBanner(),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: CarouselSlider.builder(
        itemCount: items.length,
        options: CarouselOptions(
          height: 200,
          enlargeCenterPage: true,
          enableInfiniteScroll: false,
          viewportFraction: 0.9,
        ),
        itemBuilder: (context, index, realIndex) {
          final item = items[index]!;
          final url = item['url'] as String;
          final postId = item['postId'] as int;

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PostDetails(
                    postId: postId.toString(),
                    userId: userId.toString(),
                  ),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _coverImage(url, fit: BoxFit.cover),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPostCard(PostDetail post) {
    final postImages = _parseMediaToList(post.postMedia);
    final hasImage = postImages.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: const Border.fromBorderSide(
          BorderSide(color: Color(0xFFE8EDF5)),
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PostDetails(
                  postId: post.postId.toString(),
                  userId: widget.userId,
                ),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasImage)
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _coverImage(postImages.first, fit: BoxFit.cover),
                ),
              if (post.postMainDesc.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                  child: Text(
                    post.postMainDesc,
                    style: const TextStyle(
                      fontSize: 14.5,
                      color: Color(0xFF1A2340),
                      height: 1.4,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                child: Row(
                  children: [
                    _postStat(
                      icon: Icons.visibility_outlined,
                      label: Config.formatLargeNumber(post.postViewed),
                      color: const Color(0xFF1A56DB),
                    ),
                    const SizedBox(width: 14),
                    _postStat(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: Config.formatLargeNumber(post.postComments),
                      color: const Color(0xFF0D9488),
                    ),
                    const SizedBox(width: 14),
                    _postStat(
                      icon: Icons.schedule_rounded,
                      label: getTimeDifference(post.postTime),
                      color: const Color(0xFF92400E),
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

  Widget _postStat({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (userDetailsFuture == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return FutureBuilder<List<UserDetail>>(
      future: userDetailsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text("Error")),
            body: Center(child: Text("Error: ${snapshot.error}")),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text("No Data")),
            body: const Center(child: Text("No data available")),
          );
        }

        final users = snapshot.data!;
        final user = users[0];
        final address = (user.user_distance ?? '').toString();

        return Scaffold(
          appBar: AppBar(
            title: SizedBox(
              height: 25,
              child: Marquee(
                text: address,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.black87,
                ),
                scrollAxis: Axis.horizontal,
                blankSpace: 100.0,
                velocity: 35.0,
                pauseAfterRound: const Duration(seconds: 1),
                startPadding: 10.0,
                accelerationDuration: const Duration(seconds: 1),
                accelerationCurve: Curves.linear,
                decelerationDuration: const Duration(milliseconds: 500),
                decelerationCurve: Curves.easeOut,
              ),
            ),
            centerTitle: true,
          ),
          body: CustomScrollView(
            controller: _scrollController,
            slivers: [
              // HEADER
              SliverToBoxAdapter(
                child: _buildHeader(user),
              ),

              // REVIEW SUMMARY
              SliverToBoxAdapter(
                child: _buildReviewSection(user),
              ),

              // IMAGE SLIDER (previous design, but uses paginated posts)
              if (_posts.isNotEmpty)
                SliverToBoxAdapter(
                  child: _buildImageSlider(_posts, user.user_id),
                ),

              // SORTING BUTTONS
              SliverToBoxAdapter(
                child: PostSortingButtons(
                  selectedSort: selectedSortValue,
                  onSortSelected: (newSort) {
                    if (newSort != selectedSortValue) {
                      setState(() => selectedSortValue = newSort);
                      _scrollController.jumpTo(0);
                      _loadPosts(reset: true);
                    }
                  },
                ),
              ),

              // POSTS LIST (your previous card design)
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index == _posts.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Color(0xFF1A56DB),
                            ),
                          ),
                        ),
                      );
                    }
                    final post = _posts[index];
                    return _buildPostCard(post);
                  },
                  childCount: _posts.length + (_hasMore ? 1 : 0),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Review bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _ReviewSheet extends StatefulWidget {
  final int reviewedId;
  final String reviewedName;
  final String reviewedPhoto;
  final int? myReviewId;
  final int? loginUserId;
  final VoidCallback onReviewChanged;

  const _ReviewSheet({
    required this.reviewedId,
    required this.reviewedName,
    required this.reviewedPhoto,
    required this.myReviewId,
    required this.loginUserId,
    required this.onReviewChanged,
  });

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  List<dynamic> _reviews = [];
  int _total = 0;
  int _page = 1;
  final int _pageSize = 10;
  bool _loading = true;
  bool _hasMore = true;
  bool _submitting = false;

  // Write-review form state
  String? _selectedRating; // 'good' or 'bad'
  final _commentController = TextEditingController();
  late int? _myReviewId;

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _myReviewId = widget.myReviewId;
    _loadReviews();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 150) {
        if (_hasMore && !_loading) _loadReviews();
      }
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadReviews({bool reset = false}) async {
    if (_loading && !reset) return;
    setState(() => _loading = true);
    if (reset) {
      _page = 1;
      _reviews.clear();
      _hasMore = true;
    }
    try {
      final resp = await Config.apiGet(
        '/review/get?reviewed_id=${widget.reviewedId}&page=$_page&page_size=$_pageSize',
        context,
      );
      if (resp != null && resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final incoming = data['reviews'] as List;
        setState(() {
          _total = data['total'] ?? 0;
          _reviews.addAll(incoming);
          _hasMore = _reviews.length < _total;
          _page++;
        });
      }
    } catch (e) {
      debugPrint("Error loading reviews: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _submitReview() async {
    if (_selectedRating == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select Good or Bad')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final resp = await Config.apiPost(
        '/review/add',
        {
          'reviewer_id': widget.loginUserId,
          'reviewed_id': widget.reviewedId,
          'rating': _selectedRating,
          'comment': _commentController.text.trim(),
        },
        context,
      );
      if (resp != null && resp.statusCode == 201) {
        _commentController.clear();
        setState(() => _selectedRating = null);
        await _loadReviews(reset: true);
        // Refresh myReviewId
        final mine = _reviews.firstWhere(
          (r) => r['reviewer_id'] == widget.loginUserId,
          orElse: () => null,
        );
        setState(() => _myReviewId = mine?['review_id']);
        widget.onReviewChanged();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Review submitted!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      } else {
        final body = jsonDecode(resp?.body ?? '{}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(body['error'] ?? 'Failed to submit review')),
        );
      }
    } catch (e) {
      debugPrint("Error submitting review: $e");
    } finally {
      setState(() => _submitting = false);
    }
  }

  Future<void> _deleteReview() async {
    if (_myReviewId == null) return;
    setState(() => _submitting = true);
    try {
      final resp = await Config.apiPost(
        '/review/delete',
        {'reviewer_id': widget.loginUserId, 'review_id': _myReviewId},
        context,
      );
      if (resp != null && resp.statusCode == 200) {
        setState(() => _myReviewId = null);
        await _loadReviews(reset: true);
        widget.onReviewChanged();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review deleted')),
        );
      }
    } catch (e) {
      debugPrint("Error deleting review: $e");
    } finally {
      setState(() => _submitting = false);
    }
  }

  String _timeAgo(String raw) {
    try {
      raw = raw.replaceAll(',', '').replaceAll('GMT', '').trim();
      final dt = DateFormat('EEE dd MMM yyyy HH:mm:ss').parseUtc(raw);
      final diff = DateTime.now().toUtc().difference(dt);
      if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 30) return '${diff.inDays}d ago';
      return '${(diff.inDays / 30).floor()}mo ago';
    } catch (_) {
      return '';
    }
  }

  Widget _ratingChip(String value, String label, IconData icon, Color color) {
    final selected = _selectedRating == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedRating = selected ? null : value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: selected ? color : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: selected ? color : const Color(0xFF94A3B8)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? color : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOwnProfile = widget.loginUserId == widget.reviewedId;
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(99),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Row(
              children: [
                ClipOval(
                  child: Image.network(
                    widget.reviewedPhoto,
                    width: 38,
                    height: 38,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 38,
                      height: 38,
                      color: const Color(0xFFE2E8F0),
                      child: const Icon(Icons.person, color: Color(0xFF94A3B8)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.reviewedName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Color(0xFF1A2340),
                        ),
                      ),
                      Text(
                        '$_total review${_total == 1 ? '' : 's'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Write review form (hidden for own profile or if already reviewed)
          if (!isOwnProfile) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_myReviewId == null) ...[
                    const Text(
                      'Leave a review',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A2340),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _ratingChip('good', 'Good', Icons.thumb_up_rounded,
                            const Color(0xFF16A34A)),
                        const SizedBox(width: 8),
                        _ratingChip('bad', 'Bad', Icons.thumb_down_rounded,
                            const Color(0xFFDC2626)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _commentController,
                      maxLines: 2,
                      maxLength: 300,
                      decoration: InputDecoration(
                        hintText: 'Write a comment (optional)',
                        hintStyle: const TextStyle(
                            fontSize: 13, color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: Color(0xFF1A56DB), width: 1.5),
                        ),
                        counterStyle: const TextStyle(
                            fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _submitReview,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A56DB),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          textStyle: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Text('Submit Review'),
                      ),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            size: 16, color: Color(0xFF16A34A)),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            'You have already reviewed this user.',
                            style: TextStyle(
                                fontSize: 13, color: Color(0xFF64748B)),
                          ),
                        ),
                        TextButton(
                          onPressed: _submitting ? null : _deleteReview,
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFDC2626),
                            textStyle: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
          ],

          // Review list
          Flexible(
            child: _loading && _reviews.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _reviews.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            'No reviews yet. Be the first!',
                            style: TextStyle(
                                fontSize: 14, color: Color(0xFF94A3B8)),
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: _scrollController,
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                        itemCount: _reviews.length + (_hasMore ? 1 : 0),
                        separatorBuilder: (_, __) =>
                            const Divider(height: 16),
                        itemBuilder: (_, i) {
                          if (i == _reviews.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              ),
                            );
                          }
                          final r = _reviews[i];
                          final isGood = r['rating'] == 'good';
                          final isMyReview =
                              r['review_id'] == _myReviewId;

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipOval(
                                child: Image.network(
                                  r['reviewer_photo'] ?? '',
                                  width: 36,
                                  height: 36,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 36,
                                    height: 36,
                                    color: const Color(0xFFE2E8F0),
                                    child: const Icon(Icons.person,
                                        size: 18,
                                        color: Color(0xFF94A3B8)),
                                  ),
                                ),
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
                                            r['reviewer_name'] ?? '',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                              color: Color(0xFF1A2340),
                                            ),
                                          ),
                                        ),
                                        if (isMyReview)
                                          const Text(
                                            'You',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF1A56DB),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isGood
                                                ? const Color(0xFFF0FDF4)
                                                : const Color(0xFFFEF2F2),
                                            borderRadius:
                                                BorderRadius.circular(99),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                isGood
                                                    ? Icons.thumb_up_rounded
                                                    : Icons
                                                        .thumb_down_rounded,
                                                size: 11,
                                                color: isGood
                                                    ? const Color(0xFF16A34A)
                                                    : const Color(
                                                        0xFFDC2626),
                                              ),
                                              const SizedBox(width: 3),
                                              Text(
                                                isGood ? 'Good' : 'Bad',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: isGood
                                                      ? const Color(
                                                          0xFF16A34A)
                                                      : const Color(
                                                          0xFFDC2626),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    if ((r['comment'] ?? '').toString().isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        r['comment'],
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF475569),
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 4),
                                    Text(
                                      _timeAgo(r['created_at'] ?? ''),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _NoPostsBanner extends StatefulWidget {
  const _NoPostsBanner();

  @override
  State<_NoPostsBanner> createState() => _NoPostsBannerState();
}

class _NoPostsBannerState extends State<_NoPostsBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final glow = 0.25 + (_c.value * 0.35); // 0.25 → 0.60

        return Container(
          height: 200,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.blue.shade50,
                Colors.white,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.blue.shade100),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.shade200.withValues(alpha: glow),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.blue.shade100),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.shade100.withValues(alpha: glow),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.north_east_outlined, // ✅ good "No advertisement" icon
                  size: 34,
                  color: const Color(0xFF1A56DB),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "No Advertisement",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "This user has no posts to show right now.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

