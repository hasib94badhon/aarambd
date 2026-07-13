// advert_screen.dart
// UI-only improvements for reliable image fitting without touching backend logic.

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:aaram_bd/config.dart';
import 'package:aaram_bd/screens/post_details.dart';
import 'package:aaram_bd/services/app_location.dart';
import 'package:aaram_bd/widgets/notification_service.dart';
import 'package:aaram_bd/widgets/post_sorting_buttons.dart';
import 'package:aaram_bd/widgets/profile_picture_dialog.dart';
import 'package:aaram_bd/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:latlong2/latlong.dart' hide Path;
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
  final double? lat;
  final double? lon;

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
    this.lat,
    this.lon,
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
      lat: (json['lat'] as num?)?.toDouble(),
      lon: (json['lon'] as num?)?.toDouble(),
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

  void _openMapSheet(BuildContext context, UserDetail user) {
    if (user.lat == null || user.lon == null) {
      showAppToast(context, 'Location unavailable for this user',
          icon: Icons.error_outline_rounded);
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AdvertMapSheet(
        advertUser: user,
        viewerLat: AppLocation().lat,
        viewerLon: AppLocation().lon,
      ),
    );
  }

  void _showReviewSheet(UserDetail user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReviewSheet(
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


  // ─────────────────────────────────────────────────────────────────────────────

  // Checks the cached admin-inactive flag (kept fresh by
  // NavigationScreen._checkUserStatus) before letting the user contact
  // someone — the actual dialer/WhatsApp launch happens client-side and
  // can't be stopped by a server-side rejection alone.
  Future<bool> _blockedByInactiveStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final status = prefs.getInt('user_status') ?? 1;
    if (status != 0) return false;

    if (!mounted) return true;
    await showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Account Inactive'),
        content: const Text(
          'You have been made inactive by AaramBD. Please contact AaramBD.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final response =
                  await Config.apiGet('/get_contact_info', context);
              if (response != null && response.statusCode == 200) {
                final data = jsonDecode(response.body);
                final phone = (data['phone'] ?? '').toString().trim();
                if (phone.isNotEmpty) {
                  final telUri = Uri(scheme: 'tel', path: phone);
                  if (await canLaunchUrl(telUri)) await launchUrl(telUri);
                }
              }
            },
            child: const Text('Contact AaramBD'),
          ),
        ],
      ),
    );
    return true;
  }

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
    required String userPhone,
    required BuildContext context,
  }) async {
    try {
      final type = isService ? 'Service' : 'Shop';

      // Same aarambd.com/u/<phone> App Link used by user_profile.dart's
      // share — DeepLinkService resolves it straight to this AdvertScreen
      // when the app is installed, instead of the old raw Play Store link
      // (which also pointed at the wrong package id).
      final profileLink = 'https://aarambd.com/u/$userPhone';

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
          profileLink;

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
      showAppToast(context, 'Error sharing: $e',
          icon: Icons.error_outline_rounded);
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

  // ── Star count replication of UserStarWidget.calculateStars() ───────────────
  int _calcUserStars(UserDetail user) {
    int stars = 0;
    if (user.phone.isNotEmpty &&
        user.businessName.isNotEmpty &&
        user.photo.isNotEmpty) stars++;
    if ((user.tin ?? '').isNotEmpty || (user.nid ?? '').isNotEmpty) stars++;
    if (user.user_viewed >= 1500 && user.user_called > 500) stars++;
    if (user.posts.length >= 150) stars++;
    if (user.sub_type == 'paid') stars++;
    return stars;
  }

  // Single star dot for the curved arc
  Widget _arcStarDot(bool lit) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: lit ? Colors.amber.shade50 : const Color(0xFFF1F5F9),
        border: Border.all(
          color: lit ? Colors.amber.shade300 : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: lit
            ? [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.45),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Icon(
        Icons.star_rounded,
        size: 13,
        color: lit ? Colors.amber.shade500 : const Color(0xFFCBD5E1),
        shadows: lit
            ? [Shadow(color: Colors.amber.withValues(alpha: 0.6), blurRadius: 8)]
            : null,
      ),
    );
  }

  // Compact review panel shown to the right of the avatar in the header
  Widget _buildHeader(UserDetail user) {
    final bool isActive = user.call_status?.toLowerCase() == 'active';
    const double avatarSz = 140.0;
    const double starRadius = 84.0;
    const double starSz = 20.0;
    final int starCount = _calcUserStars(user);
    final bool isOwn =
        loginUserId != null && int.tryParse(loginUserId!) == user.user_id;
    final double avgRating = (_reviewSummary?['avg_rating'] ?? 0).toDouble();
    final int total = _reviewSummary?['total'] ?? 0;
    final List<dynamic> topTags = _reviewSummary?['top_tags'] ?? [];

    // 5 stars in a 64° arc (122° → 58°, 16° steps) centred at 12 o'clock (90°)
    final List<Widget> arcStars = List.generate(5, (i) {
      final double theta = (122.0 - 16.0 * i) * math.pi / 180.0;
      return Positioned(
        left: avatarSz / 2 + starRadius * math.cos(theta) - starSz / 2,
        top: avatarSz / 2 - starRadius * math.sin(theta) - starSz / 2,
        child: _arcStarDot(i < starCount),
      );
    });

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Avatar ──────────────────────────────────────────────────────
          Container(
            color: const Color(0xFFF8FAFF),
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 18),
            child: Center(
              child: SizedBox(
                width: avatarSz,
                height: avatarSz,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: avatarSz,
                      height: avatarSz,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 18,
                            spreadRadius: 2,
                            offset: const Offset(0, 4),
                          ),
                          BoxShadow(
                            color: const Color(0xFF1A56DB)
                                .withValues(alpha: 0.08),
                            blurRadius: 24,
                            spreadRadius: 4,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ProfilePictureDialog(
                          photoUrl: user.photo, size: avatarSz),
                    ),
                    ...arcStars,
                    if (user.sub_type != null)
                      Positioned(
                        bottom: 5,
                        right: 5,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: user.sub_type == 'paid'
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF1A56DB)
                                          .withValues(alpha: 0.35),
                                      blurRadius: 8,
                                    )
                                  ]
                                : [],
                          ),
                          padding: const EdgeInsets.all(3),
                          child: Icon(
                            Icons.verified_rounded,
                            size: 18,
                            color: user.sub_type == 'paid'
                                ? const Color(0xFF1A56DB)
                                : const Color(0xFFCBD5E1),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // ─── Name / Category / Status / Address ──────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  user.businessName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 21,
                    color: Color(0xFF0F172A),
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDF4FF),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                        color:
                            const Color(0xFF93C5FD).withValues(alpha: 0.6)),
                  ),
                  child: Text(
                    user.category,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A56DB),
                    ),
                  ),
                ),
                if (user.address.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on_rounded,
                          size: 13, color: Color(0xFF9CA3AF)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          user.address,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if ((user.user_distance ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _openMapSheet(context, user);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1A56DB), Color(0xFF2563EB)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1A56DB)
                                  .withValues(alpha: 0.30),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on_rounded,
                                size: 15, color: Colors.white),
                            const SizedBox(width: 6),
                            const Text(
                              'View on Map',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color:
                                    Colors.white.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.near_me_rounded,
                                      size: 10, color: Colors.white),
                                  const SizedBox(width: 3),
                                  Text(
                                    user.user_distance!,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right_rounded,
                                size: 16, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ─── Call Now + WhatsApp ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: _actionBtn(
                    label: isActive ? 'Call Now' : 'Unavailable',
                    icon: Icons.call_rounded,
                    faIcon: null,
                    gradient: isActive
                        ? const LinearGradient(
                            colors: [Color(0xFF16A34A), Color(0xFF15803D)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    glowColor: const Color(0xFF16A34A),
                    isActive: isActive,
                    onTap: isActive
                        ? () async {
                            if (await _blockedByInactiveStatus()) return;
                            handleAction(user.user_id, 'call', 0);
                            updateUserCalled(
                                user.service_or_shop_id.toString(),
                                user.is_service);
                            final Uri telUri =
                                Uri(scheme: 'tel', path: user.phone);
                            if (await canLaunchUrl(telUri)) {
                              await launchUrl(telUri);
                            }
                          }
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _actionBtn(
                    label: 'WhatsApp',
                    icon: null,
                    faIcon: FontAwesomeIcons.whatsapp,
                    gradient: isActive
                        ? const LinearGradient(
                            colors: [Color(0xFF25D366), Color(0xFF128C7E)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    glowColor: const Color(0xFF25D366),
                    isActive: isActive,
                    onTap: isActive
                        ? () async {
                            if (await _blockedByInactiveStatus()) return;
                            handleAction(user.user_id, 'call', 0);
                            updateUserCalled(
                                user.service_or_shop_id.toString(),
                                user.is_service);
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
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1, color: Color(0xFFF0F3FA)),

          // ─── Reviews + Fav + Share ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Reviews',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => toggleFavorite(user),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isFavorited(user)
                          ? const Color(0xFFFEF2F2)
                          : const Color(0xFFF8FAFC),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isFavorited(user)
                            ? const Color(0xFFFECACA)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Icon(
                      isFavorited(user)
                          ? Icons.favorite_rounded
                          : Icons.favorite_outline_rounded,
                      size: 18,
                      color: isFavorited(user)
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => shareAdvertProfile(
                    id: user.is_service ? user.serviceId : user.shopId,
                    isService: user.is_service,
                    userName: user.businessName,
                    userCategory: user.category,
                    userAddress: user.location,
                    userPhone: user.phone,
                    context: context,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Icon(Icons.share_outlined,
                        size: 18, color: Color(0xFF94A3B8)),
                  ),
                ),
              ],
            ),
          ),
          // ── Rating summary row ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Star score
                    if (total > 0) ...[
                      Text(
                        avgRating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A2340),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Row(
                        children: List.generate(5, (i) {
                          final filled = i < avgRating.round();
                          return Icon(
                            filled ? Icons.star_rounded : Icons.star_outline_rounded,
                            size: 16,
                            color: filled ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1),
                          );
                        }),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '($total)',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ] else
                      const Text(
                        'No reviews yet',
                        style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      ),
                    const Spacer(),
                    if (!isOwn)
                      GestureDetector(
                        onTap: () => _showReviewSheet(user),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1A56DB), Color(0xFF3B82F6)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(99),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1A56DB).withValues(alpha: 0.28),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _myReviewId != null
                                    ? Icons.edit_outlined
                                    : Icons.rate_review_outlined,
                                size: 13,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _myReviewId != null ? 'Edit Review' : 'Write Review',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                // Top tags
                if (topTags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: topTags.take(4).map<Widget>((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F4FF),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: const Color(0xFFBFD0FF)),
                        ),
                        child: Text(
                          tag.toString(),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF1A56DB),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1, color: Color(0xFFF0F3FA)),

          // ─── Stats ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                _buildStatBlock(
                  icon: Icons.phone_in_talk_rounded,
                  value: Config.formatLargeNumber(user.user_called),
                  label: 'Calls',
                  color: const Color(0xFF1A56DB),
                  bg: const Color(0xFFEDF4FF),
                ),
                Container(
                    width: 1, height: 40, color: const Color(0xFFF0F3FA)),
                _buildStatBlock(
                  icon: Icons.visibility_rounded,
                  value: Config.formatLargeNumber(user.user_viewed),
                  label: 'Views',
                  color: const Color(0xFFDB2777),
                  bg: const Color(0xFFFDF2F8),
                ),
                Container(
                    width: 1, height: 40, color: const Color(0xFFF0F3FA)),
                _buildStatBlock(
                  icon: Icons.article_rounded,
                  value: user.totalpost ?? '0',
                  label: 'Posts',
                  color: const Color(0xFF0D9488),
                  bg: const Color(0xFFF0FDFA),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1, color: Color(0xFFF0F3FA)),
          const SizedBox(height: 14),

          // ─── Description ─────────────────────────────────────────────────
          if (user.description.trim().isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: ExpandableDescription(text: user.description.trim()),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFF0F3FA)),
            const SizedBox(height: 14),
          ],

        ],
      ),
    );
  }




  Widget _buildStatBlock({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required Color bg,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required String label,
    required IconData? icon,
    required IconData? faIcon,
    required LinearGradient? gradient,
    required Color glowColor,
    required bool isActive,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: gradient,
          color: gradient == null ? const Color(0xFFE2E8F0) : null,
          borderRadius: BorderRadius.circular(13),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: glowColor.withValues(alpha: 0.30),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null)
              Icon(icon,
                  size: 17,
                  color: isActive ? Colors.white : const Color(0xFF94A3B8)),
            if (faIcon != null)
              FaIcon(faIcon,
                  size: 16,
                  color: isActive ? Colors.white : const Color(0xFF94A3B8)),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isActive ? Colors.white : const Color(0xFF94A3B8),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSlider(List<PostDetail> posts, int userId) {
    final items = posts
        .map((p) {
          final urls = _parseMediaToList(p.postMedia);
          if (urls.isNotEmpty) return {'url': urls.first, 'postId': p.postId};
          return null;
        })
        .whereType<Map<String, dynamic>>()
        .toList();

    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: _NoPostsBanner(),
      );
    }

    return _BillboardSlider(items: items, userId: userId);
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

        return Scaffold(
          backgroundColor: const Color(0xFFF3F7FF),
          body: Stack(
            children: [
              CustomScrollView(
            controller: _scrollController,
            slivers: [
              // HEADER
              SliverToBoxAdapter(
                child: _buildHeader(user),
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
              // Floating back button – always visible at top-left
              SafeArea(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12, top: 8),
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.14),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                  ),
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

class ReviewSheet extends StatefulWidget {
  final int reviewedId;
  final String reviewedName;
  final String reviewedPhoto;
  final int? myReviewId;
  final int? loginUserId;
  final VoidCallback onReviewChanged;

  const ReviewSheet({
    required this.reviewedId,
    required this.reviewedName,
    required this.reviewedPhoto,
    required this.myReviewId,
    required this.loginUserId,
    required this.onReviewChanged,
  });

  @override
  State<ReviewSheet> createState() => _ReviewSheetState();
}

// Tags: positive shown for rating ≥ 3, negative for ≤ 2
const _kPosTags = [
  'Trusted', 'Fast Service', 'Good Quality', 'Affordable',
  'Skilled', 'Punctual', 'Friendly', 'Honest',
];
const _kNegTags = [
  'Delayed', 'Rude Behavior', 'Overpriced', 'Poor Work',
  'Unreliable', 'Unresponsive',
];

class _ReviewSheetState extends State<ReviewSheet> {
  List<dynamic> _reviews   = [];
  int  _total              = 0;
  int  _page               = 1;
  final int _pageSize      = 10;
  bool _loading            = false;
  bool _hasMore            = true;
  bool _submitting         = false;

  // Write-review form state
  int            _starRating  = 0;   // 0 = not set yet
  final Set<String> _selTags  = {};
  final _commentController    = TextEditingController();
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
    if (_starRating == 0) {
      showAppToast(context, 'Please select a star rating first',
          icon: Icons.error_outline_rounded);
      return;
    }
    setState(() => _submitting = true);
    try {
      final resp = await Config.apiPost(
        '/review/add',
        {
          'reviewer_id': widget.loginUserId,
          'reviewed_id': widget.reviewedId,
          'rating':      _starRating,
          'comment':     _commentController.text.trim(),
          'tags':        _selTags.toList(),
        },
        context,
      );
      if (resp != null && resp.statusCode == 201) {
        _commentController.clear();
        setState(() { _starRating = 0; _selTags.clear(); });
        await _loadReviews(reset: true);
        final mine = _reviews.firstWhere(
          (r) => r['reviewer_id'] == widget.loginUserId,
          orElse: () => null,
        );
        setState(() => _myReviewId = mine?['review_id']);
        widget.onReviewChanged();
        showAppToast(context, 'Review submitted! Thank you.',
            icon: Icons.check_circle_outline_rounded);
      } else {
        final body = jsonDecode(resp?.body ?? '{}');
        showAppToast(context, body['error'] ?? 'Failed to submit review',
            icon: Icons.error_outline_rounded);
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
        showAppToast(context, 'Review deleted');
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

  // ── Star picker row ────────────────────────────────────────────────────────
  Widget _starPicker() {
    const labels = ['', 'Very Poor', 'Poor', 'Fair', 'Good', 'Excellent'];
    const colors = [
      Colors.transparent,
      Color(0xFFEF4444), Color(0xFFF97316),
      Color(0xFFF59E0B), Color(0xFF22C55E), Color(0xFF16A34A),
    ];
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final star = i + 1;
            final filled = star <= _starRating;
            return GestureDetector(
              onTap: () => setState(() => _starRating = star),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Icon(
                  filled ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 38,
                  color: filled ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1),
                ),
              ),
            );
          }),
        ),
        if (_starRating > 0)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              labels[_starRating],
              key: ValueKey(_starRating),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: colors[_starRating],
              ),
            ),
          ),
      ],
    );
  }

  // ── Tag chips ──────────────────────────────────────────────────────────────
  Widget _tagChips() {
    final tags = _starRating >= 3 ? _kPosTags : _kNegTags;
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: tags.map((tag) {
        final sel = _selTags.contains(tag);
        return GestureDetector(
          onTap: () => setState(() => sel ? _selTags.remove(tag) : _selTags.add(tag)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: sel ? const Color(0xFF1A56DB) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                color: sel ? const Color(0xFF1A56DB) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Text(
              tag,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: sel ? Colors.white : const Color(0xFF475569),
              ),
            ),
          ),
        );
      }).toList(),
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
                    // Star rating
                    const Text(
                      'Rate this user',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A2340),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(child: _starPicker()),
                    // Tags (show after star selected)
                    if (_starRating > 0) ...[
                      const SizedBox(height: 14),
                      const Text(
                        'Select tags (optional)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _tagChips(),
                      const SizedBox(height: 14),
                      // Opinion text
                      TextField(
                        controller: _commentController,
                        maxLines: 2,
                        maxLength: 300,
                        decoration: InputDecoration(
                          hintText: 'Share your experience (optional)',
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
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submitting ? null : _submitReview,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A56DB),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            textStyle: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          child: _submitting
                              ? const SizedBox(
                                  width: 18, height: 18,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Text('Submit Review'),
                        ),
                      ),
                    ],
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
                          final r          = _reviews[i];
                          final rating     = (r['rating'] as int?) ?? 3;
                          final isMyReview = r['review_id'] == _myReviewId;
                          final tags       = (r['tags'] as List?) ?? [];

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isMyReview
                                  ? const Color(0xFFF0F4FF)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isMyReview
                                    ? const Color(0xFFBFD0FF)
                                    : const Color(0xFFF1F5F9),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipOval(
                                  child: Image.network(
                                    r['reviewer_photo'] ?? '',
                                    width: 38, height: 38,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 38, height: 38,
                                      color: const Color(0xFFE2E8F0),
                                      child: const Icon(Icons.person,
                                          size: 18, color: Color(0xFF94A3B8)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Name + "You" badge
                                      Row(children: [
                                        Expanded(
                                          child: Text(
                                            r['reviewer_name'] ?? '',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                              color: Color(0xFF1A2340),
                                            ),
                                          ),
                                        ),
                                        if (isMyReview)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF1A56DB),
                                              borderRadius: BorderRadius.circular(99),
                                            ),
                                            child: const Text('You',
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w700)),
                                          ),
                                      ]),
                                      const SizedBox(height: 4),
                                      // Stars
                                      Row(children: [
                                        ...List.generate(5, (i) => Icon(
                                          i < rating
                                              ? Icons.star_rounded
                                              : Icons.star_outline_rounded,
                                          size: 14,
                                          color: i < rating
                                              ? const Color(0xFFF59E0B)
                                              : const Color(0xFFCBD5E1),
                                        )),
                                        const SizedBox(width: 6),
                                        Text(
                                          _timeAgo(r['created_at'] ?? ''),
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF94A3B8)),
                                        ),
                                      ]),
                                      // Tags
                                      if (tags.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 5, runSpacing: 4,
                                          children: tags.map<Widget>((tag) =>
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF0F4FF),
                                                borderRadius: BorderRadius.circular(99),
                                                border: Border.all(
                                                    color: const Color(0xFFBFD0FF)),
                                              ),
                                              child: Text(tag.toString(),
                                                  style: const TextStyle(
                                                      fontSize: 11,
                                                      color: Color(0xFF1A56DB),
                                                      fontWeight: FontWeight.w600)),
                                            ),
                                          ).toList(),
                                        ),
                                      ],
                                      // Comment
                                      if ((r['comment'] ?? '').toString().isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          r['comment'],
                                          style: const TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF475569),
                                              height: 1.4),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
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

class _BillboardSlider extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final int userId;

  const _BillboardSlider({required this.items, required this.userId});

  @override
  State<_BillboardSlider> createState() => _BillboardSliderState();
}

class _BillboardSliderState extends State<_BillboardSlider> {
  late final PageController _pc;
  int _active = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pc = PageController(viewportFraction: 0.9);
    if (widget.items.length > 1) {
      _timer = Timer.periodic(const Duration(milliseconds: 3500), (_) {
        if (!mounted) return;
        final next = (_active + 1) % widget.items.length;
        _pc.animateToPage(
          next,
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeInOutCubic,
        );
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 280,
          child: PageView.builder(
                controller: _pc,
                itemCount: widget.items.length,
                onPageChanged: (i) => setState(() => _active = i),
                itemBuilder: (ctx, i) {
                  final item = widget.items[i];
                  final url = item['url'] as String;
                  final postId = item['postId'] as int;
                  final isActive = i == _active;

                  return AnimatedScale(
                    scale: isActive ? 1.0 : 0.93,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PostDetails(
                            postId: postId.toString(),
                            userId: widget.userId.toString(),
                          ),
                        ),
                      ),
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: isActive ? 0.28 : 0.10,
                              ),
                              blurRadius: isActive ? 24 : 10,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Full-bleed image
                              Image.network(
                                url,
                                fit: BoxFit.cover,
                                frameBuilder:
                                    (ctx, child, frame, wasSyncLoaded) {
                                  if (wasSyncLoaded) return child;
                                  return AnimatedOpacity(
                                    opacity: frame == null ? 0 : 1,
                                    duration:
                                        const Duration(milliseconds: 300),
                                    curve: Curves.easeIn,
                                    child: child,
                                  );
                                },
                                errorBuilder: (ctx, err, stack) => Container(
                                  color: const Color(0xFFF1F5F9),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.broken_image_rounded,
                                    size: 48,
                                    color: Color(0xFFCBD5E1),
                                  ),
                                ),
                              ),
                              // Bottom gradient vignette
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        Colors.black.withValues(alpha: 0.58),
                                        Colors.transparent,
                                      ],
                                      stops: const [0.0, 0.52],
                                    ),
                                  ),
                                ),
                              ),
                              // Slide counter chip
                              Positioned(
                                right: 12,
                                bottom: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        Colors.black.withValues(alpha: 0.48),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${i + 1} / ${widget.items.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
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
        // Animated pill-dot indicators
        if (widget.items.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.items.length, (i) {
                final isActive = i == _active;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOut,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isActive ? 22.0 : 6.0,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFF1A56DB)
                        : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
      ],
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

// ─────────────────────────────────────────────────────────────────────────────
// Map bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _AdvertMapSheet extends StatefulWidget {
  final UserDetail advertUser;
  final double? viewerLat;
  final double? viewerLon;

  const _AdvertMapSheet({
    required this.advertUser,
    required this.viewerLat,
    required this.viewerLon,
  });

  @override
  State<_AdvertMapSheet> createState() => _AdvertMapSheetState();
}

class _AdvertMapSheetState extends State<_AdvertMapSheet>
    with SingleTickerProviderStateMixin {
  final MapController _mapCtrl = MapController();
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _mapCtrl.dispose();
    super.dispose();
  }

  Future<void> _openDirections() async {
    final lat = widget.advertUser.lat!;
    final lon = widget.advertUser.lon!;
    final gMapsApp = Uri.parse('google.navigation:q=$lat,$lon');
    final gMaps = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lon&travelmode=driving');
    if (await canLaunchUrl(gMapsApp)) {
      await launchUrl(gMapsApp);
    } else if (await canLaunchUrl(gMaps)) {
      await launchUrl(gMaps, mode: LaunchMode.externalApplication);
    }
  }

  LatLngBounds _computeBounds(LatLng a, LatLng b) {
    return LatLngBounds(
      LatLng(math.min(a.latitude, b.latitude),
          math.min(a.longitude, b.longitude)),
      LatLng(math.max(a.latitude, b.latitude),
          math.max(a.longitude, b.longitude)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final advertLL = LatLng(widget.advertUser.lat!, widget.advertUser.lon!);
    final hasViewer = widget.viewerLat != null && widget.viewerLon != null;
    final viewerLL =
        hasViewer ? LatLng(widget.viewerLat!, widget.viewerLon!) : null;
    final distance = widget.advertUser.user_distance ?? '';
    final address = widget.advertUser.address;
    final name = widget.advertUser.businessName;

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD1D5DB),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 12, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDF4FF),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.map_rounded,
                      size: 18, color: Color(0xFF1A56DB)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isNotEmpty ? name : 'View Location',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (distance.isNotEmpty)
                        Text(
                          distance,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF16A34A),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded,
                      size: 20, color: Color(0xFF6B7280)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          // Map
          Expanded(
            child: FlutterMap(
              mapController: _mapCtrl,
              options: MapOptions(
                initialCenter: advertLL,
                initialZoom: 14.0,
                minZoom: 4.0,
                maxZoom: 19.0,
                onMapReady: () {
                  if (viewerLL != null) {
                    final bounds = _computeBounds(advertLL, viewerLL);
                    _mapCtrl.fitCamera(
                      CameraFit.bounds(
                        bounds: bounds,
                        padding: const EdgeInsets.all(64),
                      ),
                    );
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.aarambd.android',
                ),
                MarkerLayer(markers: [
                  // Advert user pin
                  Marker(
                    point: advertLL,
                    width: 56,
                    height: 68,
                    alignment: Alignment.bottomCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A56DB),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1A56DB)
                                    .withValues(alpha: 0.45),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.person_rounded,
                              size: 20, color: Colors.white),
                        ),
                        CustomPaint(
                          size: const Size(14, 8),
                          painter: _MapPinTip(const Color(0xFF1A56DB)),
                        ),
                      ],
                    ),
                  ),
                  // Viewer pulsing dot
                  if (viewerLL != null)
                    Marker(
                      point: viewerLL,
                      width: 52,
                      height: 52,
                      child: AnimatedBuilder(
                        animation: _pulseCtrl,
                        builder: (_, __) =>
                            _PulsingDot(pulse: _pulseCtrl.value),
                      ),
                    ),
                ]),
              ],
            ),
          ),
          // Bottom info card
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Color(0x10000000),
                  blurRadius: 16,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (address.isNotEmpty)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Icon(Icons.location_on_rounded,
                            size: 15, color: Color(0xFF6B7280)),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          address,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF374151),
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                if (!hasViewer)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 14, color: Color(0xFFF97316)),
                        SizedBox(width: 5),
                        Text(
                          'Your location is unavailable',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFFF97316)),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _openDirections,
                    icon: const Icon(Icons.directions_rounded, size: 18),
                    label: const Text(
                      'Get Directions',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A56DB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
                SizedBox(
                    height:
                        MediaQuery.of(context).padding.bottom + 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatelessWidget {
  final double pulse;
  const _PulsingDot({required this.pulse});

  @override
  Widget build(BuildContext context) {
    final ripple = 16.0 + pulse * 18.0;
    final opacity = (1.0 - pulse).clamp(0.0, 1.0);
    return Stack(alignment: Alignment.center, children: [
      Container(
        width: ripple,
        height: ripple,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF1A56DB)
              .withValues(alpha: opacity * 0.22),
        ),
      ),
      Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF1A56DB),
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1A56DB).withValues(alpha: 0.4),
              blurRadius: 6,
            ),
          ],
        ),
      ),
    ]);
  }
}

class _MapPinTip extends CustomPainter {
  final Color color;
  const _MapPinTip(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_MapPinTip old) => old.color != color;
}

