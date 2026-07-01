// ignore_for_file: dead_code

import 'dart:async';
import 'dart:convert';
import 'package:aaram_bd/config.dart';
import 'package:aaram_bd/pages/editpost.dart';
import 'package:aaram_bd/screens/DataCollectorLearnMorePage.dart';
import 'package:aaram_bd/screens/post_details.dart';
import 'package:aaram_bd/widgets/call_history_dialog.dart';
import 'package:aaram_bd/widgets/post_sorting_buttons.dart';
import 'package:aaram_bd/widgets/thoughtsection.dart';
import 'package:aaram_bd/widgets/userstarwidget.dart';
import 'package:aaram_bd/widgets/view_history_dialog.dart';
import 'package:flutter/material.dart';
import 'package:aaram_bd/screens/editprofile_screen.dart';
import 'package:aaram_bd/screens/post_upload.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:readmore/readmore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:aaram_bd/main.dart';
import 'package:aaram_bd/widgets/verified_widget.dart';

String host = Config.host;

class UserProfile extends StatefulWidget with RouteAware {
  final String userPhone;
  final Key? key;
  final dynamic userData;

  UserProfile({required this.userPhone, this.userData, this.key})
      : super(key: key);

  @override
  State<UserProfile> createState() => _UserProfileState(userPhone: userPhone);
}

class _UserProfileState extends State<UserProfile> with RouteAware {
  String? userPhone;
  late PageController _pageController;
  bool _isLoading = false;
  List<dynamic> viewList = [];
  List<dynamic> incomingCallList = [];
  List<dynamic> outgoingCallList = [];

  _UserProfileState({required this.userPhone});

final FocusNode _focusNode = FocusNode();
  late String userID;
  bool isActive = true;
  String selectedSortValue = 'recent';

  List<Map<String, dynamic>> posts = [];
  List descriptions = [];
  bool isloading = true;
  String user_id = '';
  String userName = "User Name";
  String profile_pic = "";
  String userCategory = "Category";
  String userCategoryId = "56";
  String userDescription = "";
  String userAddress = "User Address";
  int userview = 0;
  int usercall = 0;
  int usershare = 0;
  String dt = '';
  String call_status = '';
  String subscription_type = '';
  String last_pay = '';
  String tin = '';
  String nid = "";
  String totalpost = '';
  String totalCollection = '';

  bool get isDataCollector =>
      (userCategory).trim().toLowerCase() == 'data collector';

  bool _isEditingDescription = false;
  late TextEditingController _descriptionController;

  bool isOnline = true;
  bool isLocationOn = true;
  final ScrollController _scrollController = ScrollController();
  final Map<String, PageController> _postPageControllers = {};
  final Map<String, Timer?> _postAutoScrollTimers = {};
  int _callPage = 0;
  final int _callPageSize = 8;
  bool _callLoading = false;
  bool _callHasMore = true;

// Views pagination
  int _viewPage = 0;
  final int _viewPageSize = 8;
  bool _viewLoading = false;
  bool _viewHasMore = true;

  int _postPage = 1;
  final int _postPageSize = 8;
  bool _postLoading = false;
  bool _postHasMore = true;


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void initState() {
    _loadProfile();
    super.initState();
    _getDescriptions();
    _pageController = PageController();
    _descriptionController = TextEditingController(text: userDescription);

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        if (_postHasMore && !_postLoading) {
          fetchSortedPosts(userPhone.toString(), selectedSortValue,
              page: _postPage + 1);
        }
      }
    });
    fetchSortedPosts(userPhone.toString(), selectedSortValue, page: 1);
  }

  void _syncPostControllers() {
    final currentIds = posts.map((p) => p['post_id'].toString()).toSet();
    // Dispose stale controllers and cancel stale timers
    for (final k in _postPageControllers.keys.toList()) {
      if (!currentIds.contains(k)) {
        _postPageControllers.remove(k)?.dispose();
        _postAutoScrollTimers.remove(k)?.cancel();
      }
    }
    // Create new controllers for newly added posts
    for (final post in posts) {
      final id = post['post_id'].toString();
      if (!_postPageControllers.containsKey(id)) {
        final ctrl = PageController();
        _postPageControllers[id] = ctrl;
        final images = List<String>.from(post['post_media'] ?? []);
        if (images.length > 1) {
          _postAutoScrollTimers[id] =
              Timer.periodic(const Duration(seconds: 4), (timer) {
            if (!mounted) {
              timer.cancel();
              return;
            }
            if (ctrl.hasClients) {
              final next = (ctrl.page?.round() ?? 0) + 1;
              ctrl.animateToPage(
                next % images.length,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
              );
            }
          });
        }
      }
    }
  }

  @override
  void dispose() {
    for (final c in _postPageControllers.values) {
      c.dispose();
    }
    for (final t in _postAutoScrollTimers.values) {
      t?.cancel();
    }
    _descriptionController.dispose();
    _pageController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _getDescriptions();
  }



























  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      await fetchSortedPosts(widget.userPhone, selectedSortValue, page: 1);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> fetchSortedPosts(String phone, String sortBy,
      {int page = 1}) async {
    if (_postLoading) return; // prevent duplicate calls
    if (!_postHasMore && page != 1) return; // stop if no more pages

    setState(() {
      _postLoading = true;
      if (page == 1) {
        isloading = true; // only show big loader on first page
      }
    });

    try {
      final uri =
          '/get_user_by_phone?phone=$phone&sort_by=$sortBy&page=$page&page_size=$_postPageSize';
      final response = await Config.apiGet(uri, context);

      if (response != null && response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<Map<String, dynamic>> newPosts =
            List<Map<String, dynamic>>.from(data['posts'] ?? []);

        setState(() {
          if (page == 1) {
            posts = newPosts; // reset on first page
          } else {
            posts.addAll(newPosts); // append on next pages
          }
          _syncPostControllers();

          // update pagination state
          _postPage = page;
          _postHasMore = newPosts.length == _postPageSize;

          // update user info (only needs to be refreshed once, but safe here)
          user_id = data['user_id'];
          userName = data['name'] ?? "User Name";
          userCategory = data['cat_name'] ?? "Category";
          userCategoryId = (data['cat_id'] ?? 56).toString();
          userDescription = data['description'] ?? "User Description";
          userAddress = data['location'] ?? "No location found";
          profile_pic = data['photo'] ?? "No image";
          userview = data['user_viewed'];
          usercall = data['user_called'];
          usershare = data['user_shared'];
          call_status = data['call_status'];
          subscription_type = data['subscription_type'];
          last_pay = data['last_pay'] ?? '';
          tin = data['tin'];
          nid = data['nid'];
          totalpost = data['user_total_post'].toString();
          totalCollection = data['total_collection'];

          isloading = false;
        });
      } else {
        setState(() => isloading = false);
      }
    } catch (e) {
      setState(() => isloading = false);
    } finally {
      setState(() => _postLoading = false);
    }
  }

  Future<bool> postDescription(
      String userId, String description, BuildContext context) async {
    final resp = await Config.apiPost(
      "/update_user_description",
      {'user_id': userId, 'description': description},
      context,
    );

    if (resp != null && resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      return data['success'] == true;
    } else {
      throw Exception('Failed to post description');
    }
  }

  Future<void> _getDescriptions() async {
    String? userId = await Config.getLoggedInUser();
    if (userId == null) return;
    final response =
        await Config.apiGet('/get_user_description?user_id=$userId', context);

    if (response != null && response.statusCode == 200) {
      setState(() {
        descriptions = json.decode(response.body)['descriptions'];
        isloading = false;
      });
    } else {
      setState(() {
        isloading = false;
      });
    }
  }

  Future<void> shareProfile() async {
    try {
      if (host.isEmpty || userPhone == null || userPhone!.isEmpty) {
        throw Exception('Host or userPhone is missing');
      }

      final profileLink = '$host/get_user_by_phone?phone=$userPhone';

      final shareMessage = "👤 Name: $userName\n"
          "📂 Category: $userCategory\n"
          "🔗 Profile: $profileLink\n\n"
          "Check out on AaramBD App! 🚀";

      final overlay =
          Overlay.of(context).context.findRenderObject() as RenderBox?;

      final params = ShareParams(
        text: shareMessage,
        subject: "AaramBD User Profile",
        sharePositionOrigin: overlay != null
            ? overlay.localToGlobal(Offset.zero) & overlay.size
            : const Rect.fromLTWH(0, 0, 1, 1),
      );

      final result = await SharePlus.instance.share(params);

      debugPrint("Share result: ${result.status}");
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sharing: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> fetchViewList(String userId,
      {required int page, required BuildContext context}) async {
    if (_viewLoading) return;
    if (!_viewHasMore && page != 1) return;

    _viewLoading = true;
    setState(() {});

    final uri =
        '/get_view_list?user_id=$userId&page=$page&page_size=$_viewPageSize';
    print('Fetching view list: ${uri.toString()}');

    try {
      final res = await Config.apiGet(uri, context);
      if (res != null && res.statusCode == 200) {
        final data = json.decode(res.body);
        final List<dynamic> newItems =
            (data['view_list'] ?? []) as List<dynamic>;

        if (page == 1) {
          viewList = newItems;
        } else {
          viewList = [...viewList, ...newItems];
        }

        _viewPage = page;
        _viewHasMore = newItems.length == _viewPageSize;
      } else {
        _viewHasMore = false;
      }
    } catch (e) {
      print('Error fetching view list page $page: $e');
      _viewHasMore = false;
    } finally {
      _viewLoading = false;
      setState(() {});
    }
  }
  void showQuickSnack(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars(); // ✅ removes queue + current

  messenger.showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 950), // ✅ fast
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      backgroundColor: isError ? Colors.redAccent : Colors.black87,
    ),
  );
}


  Future<void> fetchCallList(String userId,
      {required int page, required BuildContext context}) async {
    if (_callLoading) return;
    if (!_callHasMore && page != 1) return;

    _callLoading = true;
    setState(() {});

    final uri =
        '/get_call_list?user_id=$userId&page=$page&page_size=$_callPageSize';
    print('Fetching call list: ${uri.toString()}');

    try {
      final res = await Config.apiGet(uri, context);
      if (res != null && res.statusCode == 200) {
        final data = json.decode(res.body);
        final List<dynamic> incoming =
            (data['incoming_calls'] ?? []) as List<dynamic>;
        final List<dynamic> outgoing =
            (data['outgoing_calls'] ?? []) as List<dynamic>;

        if (page == 1) {
          incomingCallList = incoming;
          outgoingCallList = outgoing;
        } else {
          incomingCallList = [...incomingCallList, ...incoming];
          outgoingCallList = [...outgoingCallList, ...outgoing];
        }

        _callPage = page;

        // If both lists returned less than page size, stop. This heuristic is conservative.
        _callHasMore = (incoming.length == _callPageSize) ||
            (outgoing.length == _callPageSize);
      } else {
        _callHasMore = false;
      }
    } catch (e) {
      print('Error fetching call list page $page: $e');
      _callHasMore = false;
    } finally {
      _callLoading = false;
      setState(() {});
    }
  }

  Future<void> updateUserStatus(
      {required String userId,
      required String status,
      required BuildContext context}) async {
    final url = '/update_user_call_status';
    try {
      final response = await Config.apiPost(
          url, {'user_id': userId, 'status': status}, context);

      if (response == null || response.statusCode != 200) {
        // noop UI-wise
      }
    } catch (_) {}
  }

  Future<bool> deletePost(String postId, BuildContext context) async {
    final url = '/delete_post';
    try {
      final response = await Config.apiPost(url, {'post_id': postId}, context);
      if (response != null && response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return true;
      } else {
        return false;
      }
    } catch (_) {
      return false;
    }
  }

  Future<void> _shareOnPlatform(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (_) {}
  }

  Widget _infoRow(IconData icon, String text, Color iconColor,
      {double iconSize = 18, double textSize = 14}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: iconColor, size: iconSize),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: textSize,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
              fontFamily: 'Poppins',
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }



  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final kbOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FF),
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        child: SingleChildScrollView(
          controller: _scrollController,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Profile Hero Card ──────────────────────────────────────────
              Container(
                margin: const EdgeInsets.fromLTRB(5, 5, 5, 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.09),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Gradient cover ──────────────────────────────────
                      SizedBox(
                        height: 84,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(
                              child: Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xFF1040B0),
                                      Color(0xFF1A56DB),
                                      Color(0xFF2563EB),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                              ),
                            ),
                            // Decorative circles
                            Positioned(
                              top: -24,
                              right: -24,
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                            ),
                            Positioned(
                              top: -40,
                              right: 70,
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.05),
                                ),
                              ),
                            ),
                            // UserStarWidget — top right of cover
                            Positioned(
                              top: 8,
                              right: 10,
                              child: UserStarWidget(
                                showEditIcon: true,
                                phone: userPhone,
                                name: userName,
                                profilePicture: profile_pic,
                                tin: tin,
                                nid: nid,
                                postCount: posts.length,
                                view: userview,
                                sub_type: subscription_type,
                                usercall: usercall,
                              ),
                            ),
                            // Avatar — overlapping cover bottom-left
                            Positioned(
                              bottom: -54,
                              left: 16,
                              child: GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => Dialog(
                                      backgroundColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: ClipOval(
                                        child: SizedBox(
                                          height: 300,
                                          width: 300,
                                          child: profile_pic.isNotEmpty
                                              ? Image.network(profile_pic,
                                                  fit: BoxFit.cover)
                                              : Container(
                                                  color: const Color(0xFF1A56DB),
                                                  child: const Icon(Icons.person,
                                                      size: 120,
                                                      color: Colors.white),
                                                ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      width: 110,
                                      height: 110,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white, width: 3.5),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.22),
                                            blurRadius: 18,
                                            offset: const Offset(0, 8),
                                          ),
                                          BoxShadow(
                                            color: const Color(0xFF1A56DB)
                                                .withValues(alpha: 0.18),
                                            blurRadius: 24,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: ClipOval(
                                        child: profile_pic.isNotEmpty
                                            ? Image.network(profile_pic,
                                                fit: BoxFit.cover)
                                            : Container(
                                                color: const Color(0xFF1A56DB),
                                                child: const Icon(Icons.person,
                                                    size: 52,
                                                    color: Colors.white),
                                              ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 2,
                                      right: 2,
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                        child: verifiedWidgetIcon(
                                          subscriptionType: subscription_type,
                                          lastPayString: last_pay,
                                          context: context,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── Profile body ─────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 64, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Name
                            Text(
                              userName,
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF111827),
                                letterSpacing: -0.4,
                                height: 1.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),

                            const SizedBox(height: 10),

                            // ── Action Bar: Status toggle + Edit + Share ──
                            Container(
                              padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                    color: Colors.black
                                        .withValues(alpha: 0.07)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 16,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  // Active / Inactive toggle — gradient pill
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        final newStatus =
                                            call_status == 'active'
                                                ? 'inactive'
                                                : 'active';
                                        setState(
                                            () => call_status = newStatus);
                                        updateUserStatus(
                                          userId: user_id,
                                          status: newStatus,
                                          context: context,
                                        );
                                        showQuickSnack(
                                          context,
                                          newStatus == 'active'
                                              ? 'Everyone can call you now'
                                              : 'No one can call you now.',
                                        );
                                      },
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 280),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 10),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: call_status == 'active'
                                                ? [
                                                    const Color(0xFF15803D),
                                                    const Color(0xFF22C55E),
                                                  ]
                                                : [
                                                    const Color(0xFFB91C1C),
                                                    const Color(0xFFEF4444),
                                                  ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          boxShadow: [
                                            BoxShadow(
                                              color: (call_status == 'active'
                                                      ? const Color(0xFF16A34A)
                                                      : const Color(
                                                          0xFFDC2626))
                                                  .withValues(alpha: 0.34),
                                              blurRadius: 14,
                                              offset: const Offset(0, 5),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 8,
                                                  height: 8,
                                                  decoration: const BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      call_status == 'active'
                                                          ? 'ACTIVE'
                                                          : 'INACTIVE',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        letterSpacing: 0.8,
                                                      ),
                                                    ),
                                                    Text(
                                                      call_status == 'active'
                                                          ? 'Tap to deactivate'
                                                          : 'Tap to activate',
                                                      style: TextStyle(
                                                        color: Colors.white
                                                            .withValues(
                                                                alpha: 0.78),
                                                        fontSize: 9.5,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            AnimatedSwitcher(
                                              duration: const Duration(
                                                  milliseconds: 240),
                                              transitionBuilder: (child,
                                                      anim) =>
                                                  ScaleTransition(
                                                      scale: anim,
                                                      child: child),
                                              child: Icon(
                                                call_status == 'active'
                                                    ? Icons
                                                        .phone_in_talk_rounded
                                                    : Icons
                                                        .phone_disabled_rounded,
                                                key: ValueKey(call_status),
                                                color: Colors.white,
                                                size: 18,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 8),

                                  // Edit profile
                                  GestureDetector(
                                    onTap: () async {
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              EditProfileScreen(
                                            userName: userName,
                                            userPhone: widget.userPhone,
                                            userCategory: userCategory,
                                            userCategoryId: userCategoryId,
                                            userDescription: userDescription,
                                            userAddress: userAddress,
                                          ),
                                        ),
                                      );
                                      if (result == true) {
                                        fetchSortedPosts(
                                            userPhone.toString(), 'recent');
                                      }
                                    },
                                    child: Container(
                                      width: 46,
                                      height: 46,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1A56DB)
                                            .withValues(alpha: 0.09),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(0xFF1A56DB)
                                              .withValues(alpha: 0.22),
                                          width: 1.2,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.edit_rounded,
                                        color: Color(0xFF1A56DB),
                                        size: 18,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 6),

                                  // Share profile
                                  GestureDetector(
                                    onTap: shareProfile,
                                    child: Container(
                                      width: 46,
                                      height: 46,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF7C3AED)
                                            .withValues(alpha: 0.08),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(0xFF7C3AED)
                                              .withValues(alpha: 0.22),
                                          width: 1.2,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.share_rounded,
                                        color: Color(0xFF7C3AED),
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 7),

                            // Category pill
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A56DB)
                                    .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: const Color(0xFF1A56DB)
                                        .withValues(alpha: 0.18)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.category_rounded,
                                      size: 12, color: Color(0xFF1A56DB)),
                                  const SizedBox(width: 5),
                                  Text(
                                    userCategory,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1A56DB),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 10),

                            _infoRow(
                              Icons.location_on_rounded,
                              userAddress,
                              const Color(0xFF7C3AED),
                              iconSize: 16,
                              textSize: 13.5,
                            ),
                            const SizedBox(height: 5),
                            _infoRow(
                              Icons.phone_rounded,
                              widget.userPhone,
                              const Color(0xFF0D9488),
                              iconSize: 16,
                              textSize: 13.5,
                            ),

                            if (userDescription.isNotEmpty &&
                                userDescription != "User Description") ...[
                              const SizedBox(height: 10),
                              ReadMoreText(
                                userDescription,
                                trimLines: 3,
                                trimMode: TrimMode.Line,
                                trimCollapsedText: ' more',
                                trimExpandedText: ' less',
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.45,
                                  color: Color(0xFF6B7280),
                                  fontFamily: 'Poppins',
                                ),
                                moreStyle: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A56DB),
                                ),
                                lessStyle: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A56DB),
                                ),
                              ),
                            ],

                            const SizedBox(height: 16),

                            // ── Stats row ─────────────────────────────────
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F7FF),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color:
                                        Colors.black.withValues(alpha: 0.06)),
                              ),
                              child: Column(
                                children: [
                                  // Interactive stat buttons (Views + Calls)
                                  Row(
                                    children: [
                                      // Views — tappable button
                                      Expanded(
                                        child: Material(
                                          color: Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: InkWell(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            onTap: () async {
                                              _viewPage = 0;
                                              _viewHasMore = true;
                                              await fetchViewList(
                                                  user_id.toString(),
                                                  page: 1,
                                                  context: context);
                                              if (!context.mounted) return;
                                              showViewHistoryDialog(
                                                context: context,
                                                viewList: viewList.cast<
                                                    Map<String, dynamic>>(),
                                                loadMore: () => fetchViewList(
                                                    user_id.toString(),
                                                    page: _viewPage + 1,
                                                    context: context),
                                                hasMore: _viewHasMore,
                                              );
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 10),
                                              decoration: BoxDecoration(
                                                color:
                                                    const Color(0xFFFFF3E8),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                border: Border.all(
                                                    color: const Color(
                                                            0xFFF57C00)
                                                        .withValues(
                                                            alpha: 0.25)),
                                              ),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            5),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                              0xFFF57C00)
                                                          .withValues(
                                                              alpha: 0.15),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              7),
                                                    ),
                                                    child: const Icon(
                                                        Icons
                                                            .remove_red_eye_rounded,
                                                        size: 15,
                                                        color: Color(
                                                            0xFFF57C00)),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          Config
                                                              .formatLargeNumber(
                                                                  userview),
                                                          style:
                                                              const TextStyle(
                                                            fontWeight:
                                                                FontWeight.w800,
                                                            fontSize: 14,
                                                            color: Color(
                                                                0xFF111827),
                                                          ),
                                                        ),
                                                        Text(
                                                          'Views',
                                                          style: TextStyle(
                                                            fontSize: 10.5,
                                                            color: Colors.grey.shade600,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const Icon(
                                                    Icons.chevron_right_rounded,
                                                    size: 16,
                                                    color: Color(0xFFF57C00),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Calls — tappable button
                                      Expanded(
                                        child: Material(
                                          color: Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: InkWell(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            onTap: () async {
                                              _callPage = 0;
                                              _callHasMore = true;
                                              await fetchCallList(
                                                  user_id.toString(),
                                                  page: 1,
                                                  context: context);
                                              if (!context.mounted) return;
                                              showCallHistoryBottomSheet(
                                                context: context,
                                                incomingCallList: incomingCallList
                                                    .cast<
                                                        Map<String, dynamic>>(),
                                                outgoingCallList: outgoingCallList
                                                    .cast<
                                                        Map<String, dynamic>>(),
                                                loadMore: () => fetchCallList(
                                                    user_id.toString(),
                                                    page: _callPage + 1,
                                                    context: context),
                                                hasMore: _callHasMore,
                                              );
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 10),
                                              decoration: BoxDecoration(
                                                color:
                                                    const Color(0xFFEDF4FF),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                border: Border.all(
                                                    color: const Color(
                                                            0xFF1976D2)
                                                        .withValues(
                                                            alpha: 0.25)),
                                              ),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            5),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                              0xFF1976D2)
                                                          .withValues(
                                                              alpha: 0.15),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              7),
                                                    ),
                                                    child: const Icon(
                                                        Icons.call_rounded,
                                                        size: 15,
                                                        color: Color(
                                                            0xFF1976D2)),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          Config
                                                              .formatLargeNumber(
                                                                  usercall),
                                                          style:
                                                              const TextStyle(
                                                            fontWeight:
                                                                FontWeight.w800,
                                                            fontSize: 14,
                                                            color: Color(
                                                                0xFF111827),
                                                          ),
                                                        ),
                                                        Text(
                                                          'Calls',
                                                          style: TextStyle(
                                                            fontSize: 10.5,
                                                            color: Colors.grey.shade600,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const Icon(
                                                    Icons.chevron_right_rounded,
                                                    size: 16,
                                                    color: Color(0xFF1976D2),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 10),
                                  Divider(
                                      height: 1,
                                      thickness: 1,
                                      color: Colors.black
                                          .withValues(alpha: 0.07)),
                                  const SizedBox(height: 10),

                                  // Pure stat chips (Posts + Shares — not interactive)
                                  // Row(
                                  //   mainAxisAlignment:
                                  //       MainAxisAlignment.spaceEvenly,
                                  //   children: [
                                  //     // Posts
                                  //     Row(
                                  //       mainAxisSize: MainAxisSize.min,
                                  //       children: [
                                  //         Container(
                                  //           padding: const EdgeInsets.all(5),
                                  //           decoration: BoxDecoration(
                                  //             color: const Color(0xFFF0FDF4),
                                  //             borderRadius:
                                  //                 BorderRadius.circular(7),
                                  //           ),
                                  //           child: const Icon(
                                  //               Icons.article_rounded,
                                  //               size: 14,
                                  //               color: Color(0xFF16A34A)),
                                  //         ),
                                  //         const SizedBox(width: 7),
                                  //         Column(
                                  //           crossAxisAlignment:
                                  //               CrossAxisAlignment.start,
                                  //           children: [
                                  //             Text(
                                  //               Config.formatLargeNumber(
                                  //                   posts.length),
                                  //               style: const TextStyle(
                                  //                 fontWeight: FontWeight.w800,
                                  //                 fontSize: 13,
                                  //                 color: Color(0xFF111827),
                                  //               ),
                                  //             ),
                                  //             Text(
                                  //               l10n.profilePost,
                                  //               style: TextStyle(
                                  //                 fontSize: 10.5,
                                  //                 color: Colors.grey.shade500,
                                  //               ),
                                  //             ),
                                  //           ],
                                  //         ),
                                  //       ],
                                  //     ),
                                  //     Container(
                                  //         width: 1,
                                  //         height: 28,
                                  //         color: Colors.black
                                  //             .withValues(alpha: 0.08)),
                                  //     // Shares
                                  //     Row(
                                  //       mainAxisSize: MainAxisSize.min,
                                  //       children: [
                                  //         Container(
                                  //           padding: const EdgeInsets.all(5),
                                  //           decoration: BoxDecoration(
                                  //             color: const Color(0xFFF5F0FF),
                                  //             borderRadius:
                                  //                 BorderRadius.circular(7),
                                  //           ),
                                  //           child: const Icon(
                                  //               Icons.share_rounded,
                                  //               size: 14,
                                  //               color: Color(0xFF7C3AED)),
                                  //         ),
                                  //         const SizedBox(width: 7),
                                  //         Column(
                                  //           crossAxisAlignment:
                                  //               CrossAxisAlignment.start,
                                  //           children: [
                                  //             Text(
                                  //               Config.formatLargeNumber(
                                  //                   usershare),
                                  //               style: const TextStyle(
                                  //                 fontWeight: FontWeight.w800,
                                  //                 fontSize: 13,
                                  //                 color: Color(0xFF111827),
                                  //               ),
                                  //             ),
                                  //             Text(
                                  //               l10n.profileShare,
                                  //               style: TextStyle(
                                  //                 fontSize: 10.5,
                                  //                 color: Colors.grey.shade500,
                                  //               ),
                                  //             ),
                                  //           ],
                                  //         ),
                                  //       ],
                                  //     ),
                                  //   ],
                                  // ),
                                  // ── Share Thought CTA ─────────────────────────
                            Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF0D2578),
                                    Color(0xFF1040B0),
                                    Color(0xFF1A56DB),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF1040B0)
                                        .withValues(alpha: 0.35),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  splashColor:
                                      Colors.white.withValues(alpha: 0.12),
                                  highlightColor:
                                      Colors.white.withValues(alpha: 0.06),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              NeedBuilderPage()),
                                    );
                                  },
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Stack(
                                      children: [
                                        Positioned(
                                          top: -20,
                                          right: -20,
                                          child: Container(
                                            width: 110,
                                            height: 110,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.white
                                                  .withValues(alpha: 0.07),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          bottom: -18,
                                          left: -18,
                                          child: Container(
                                            width: 80,
                                            height: 80,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.white
                                                  .withValues(alpha: 0.04),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          top: 0,
                                          left: 0,
                                          right: 0,
                                          child: Container(
                                            height: 1,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.transparent,
                                                  Colors.white
                                                      .withValues(alpha: 0.25),
                                                  Colors.transparent,
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                              14, 14, 12, 14),
                                          child: Row(
                                            children: [
                                              Container(
                                                height: 48,
                                                width: 48,
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  border: Border.all(
                                                    color: Colors.white
                                                        .withValues(alpha: 0.28),
                                                    width: 1.5,
                                                  ),
                                                ),
                                                child: const Icon(
                                                  Icons.edit_note_rounded,
                                                  color: Colors.white,
                                                  size: 28,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      'Share a Need',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.w900,
                                                        letterSpacing: -0.2,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 3),
                                                    Text(
                                                      'Write thoughts • Discuss • Explore',
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        color: Colors.white
                                                            .withValues(
                                                                alpha: 0.72),
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 9),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withValues(
                                                              alpha: 0.15),
                                                      blurRadius: 8,
                                                      offset:
                                                          const Offset(0, 3),
                                                    ),
                                                  ],
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      'Open',
                                                      style: const TextStyle(
                                                        color:
                                                            Color(0xFF1040B0),
                                                        fontSize: 11.5,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    const Icon(
                                                        Icons
                                                            .arrow_forward_rounded,
                                                        color: Color(0xFF1040B0),
                                                        size: 12),
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
                            ),
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

              // Data collector card
              if (isDataCollector)
                Container(
                  margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFF1A56DB).withValues(alpha: 0.18)),
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
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A56DB).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(Icons.data_object_rounded,
                            color: Color(0xFF1A56DB), size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Collections',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.black.withValues(alpha: 0.50),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              totalCollection.toString(),
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF111827),
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) =>
                                    const DataCollectorLearnMorePage()),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1040B0), Color(0xFF1A56DB)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1A56DB)
                                    .withValues(alpha: 0.32),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'See details',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                ),
                              ),
                              const SizedBox(width: 5),
                              const Icon(Icons.arrow_forward_rounded,
                                  size: 13, color: Colors.white),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Sorting + post count ────────────────────────────────────
              Container(
                margin: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header row
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFF),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(18)),
                        border: Border(
                          bottom: BorderSide(
                              color: Colors.black.withValues(alpha: 0.06)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A56DB)
                                  .withValues(alpha: 0.09),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.article_rounded,
                                size: 14, color: Color(0xFF1A56DB)),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'My Posts',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A56DB),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              Config.formatLargeNumber(posts.length),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PostUpload(
                                    postName: userName,
                                    postPhone: widget.userPhone,
                                    postCategory: userCategory,
                                    postDescription: '',
                                  ),
                                ),
                              );
                              if (result == true) {
                                fetchSortedPosts(
                                    userPhone.toString(), 'recent');
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D9488),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF0D9488)
                                        .withValues(alpha: 0.28),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.add_rounded,
                                      size: 13, color: Colors.white),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'New Post',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Sorting buttons
                    PostSortingButtons(
                      selectedSort: selectedSortValue,
                      onSortSelected: (newSort) {
                        if (newSort != selectedSortValue) {
                          setState(() => selectedSortValue = newSort);
                          fetchSortedPosts(userPhone.toString(), newSort);
                        }
                      },
                    ),
                  ],
                ),
              ),

              // ── Posts grid ──────────────────────────────────────────────
              if (posts.isEmpty && !_postLoading)
                Container(
                  margin: const EdgeInsets.fromLTRB(14, 4, 14, 16),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 32),
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
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A56DB)
                                .withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(Icons.article_outlined,
                              color: Color(0xFF1A56DB), size: 28),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No posts found',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF374151),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 1,
                      mainAxisSpacing: 12,
                      childAspectRatio: 4 / 2.5,
                    ),
                    itemCount: posts.length + (_postHasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= posts.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                              child: CircularProgressIndicator(
                                  color: Color(0xFF1A56DB))),
                        );
                      }

                      final post = posts[index];
                      final List<String> postImages =
                          List<String>.from(post['post_media'] ?? []);
                      final String mainDescription =
                          post['main_description'] ?? '';
                      final createdAt = post['post_time'];
                      final formattedTime =
                          Config.getTimeDifference(createdAt);
                      final bool hasMedia = postImages.isNotEmpty;
                      final String postId = post['post_id'].toString();
                      final PageController pageCtrl =
                          _postPageControllers[postId] ?? PageController();

                      return Container(
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
                          child: Stack(
                            children: [
                              // ── Image / text fill ────────────────────
                              Positioned.fill(
                                child: InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => PostDetails(
                                          postId: post['post_id'],
                                          userId: user_id,
                                        ),
                                      ),
                                    );
                                  },
                                  child: hasMedia
                                      ? PageView.builder(
                                          itemCount: postImages.length,
                                          controller: pageCtrl,
                                          itemBuilder: (context, i) =>
                                              Image.network(
                                            postImages[i],
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                Container(
                                                    color: Colors.grey[200]),
                                          ),
                                        )
                                      : Container(
                                          decoration: const BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Color(0xFF1040B0),
                                                Color(0xFF1A56DB),
                                                Color(0xFF2563EB),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                          ),
                                          child: Stack(
                                            children: [
                                              Center(
                                                child: Icon(
                                                  Icons.article_rounded,
                                                  size: 72,
                                                  color: Colors.white
                                                      .withValues(alpha: 0.10),
                                                ),
                                              ),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.fromLTRB(
                                                        16, 44, 16, 52),
                                                child: Center(
                                                  child: Text(
                                                    mainDescription.isNotEmpty
                                                        ? mainDescription
                                                        : (post['post_description'] ??
                                                                'No description')
                                                            .toString(),
                                                    textAlign: TextAlign.center,
                                                    maxLines: 4,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 15,
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      height: 1.5,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                ),
                              ),

                              // ── Time chip — top left ──────────────────
                              Positioned(
                                top: 10,
                                left: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 9, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1A56DB),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF1A56DB)
                                            .withValues(alpha: 0.35),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.access_time_rounded,
                                          size: 11, color: Colors.white),
                                      const SizedBox(width: 4),
                                      Text(
                                        formattedTime,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // ── Stats bar — bottom ────────────────────
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 13, vertical: 9),
                                  decoration: BoxDecoration(
                                    color:
                                        Colors.white.withValues(alpha: 0.97),
                                    border: Border(
                                      top: BorderSide(
                                        color: Colors.black
                                            .withValues(alpha: 0.07),
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                          Icons.remove_red_eye_outlined,
                                          size: 14,
                                          color: Color(0xFF1A56DB)),
                                      const SizedBox(width: 4),
                                      Text(
                                        Config.formatLargeNumber(
                                            post['post_viewed']),
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF374151),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      const Icon(
                                          Icons.chat_bubble_outline_rounded,
                                          size: 13,
                                          color: Color(0xFF1A56DB)),
                                      const SizedBox(width: 4),
                                      Text(
                                        Config.formatLargeNumber(
                                            post['post_comments']),
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF374151),
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF1040B0),
                                              Color(0xFF1A56DB),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF1A56DB)
                                                  .withValues(alpha: 0.30),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'View',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                            SizedBox(width: 4),
                                            Icon(Icons.arrow_forward_rounded,
                                                size: 11, color: Colors.white),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // ── Popup menu — top right ────────────────
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Material(
                                  color: Colors.transparent,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white
                                          .withValues(alpha: 0.95),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.12),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: PopupMenuButton<String>(
                                      tooltip: 'Options',
                                      splashRadius: 20,
                                      elevation: 12,
                                      color: Colors.white,
                                      shadowColor: Colors.black26,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16),
                                      ),
                                      offset: const Offset(0, 44),
                                      icon: const Icon(Icons.more_vert,
                                          color: Color(0xFF374151), size: 20),
                                      onSelected: (value) async {
                                        if (value == 'delete') {
                                          final confirmDelete =
                                              await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(18),
                                              ),
                                              title: const Text('Confirm Delete'),
                                              content: const Text(
                                                  'Are you sure you want to delete this post?'),
                                              actionsPadding:
                                                  const EdgeInsets.only(
                                                      left: 12,
                                                      right: 12,
                                                      bottom: 10),
                                              actions: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: OutlinedButton(
                                                        onPressed: () =>
                                                            Navigator.of(
                                                                    context)
                                                                .pop(false),
                                                        style: OutlinedButton
                                                            .styleFrom(
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12),
                                                          ),
                                                        ),
                                                        child: const Text('Cancel'),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: ElevatedButton(
                                                        onPressed: () =>
                                                            Navigator.of(
                                                                    context)
                                                                .pop(true),
                                                        style: ElevatedButton
                                                            .styleFrom(
                                                          backgroundColor:
                                                              Colors.redAccent,
                                                          foregroundColor:
                                                              Colors.white,
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12),
                                                          ),
                                                        ),
                                                        child: const Text('Delete'),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirmDelete == true) {
                                            final result = await deletePost(
                                              post['post_id'].toString(),
                                              context,
                                            );
                                            if (result) {
                                              setState(() {
                                                posts.removeWhere((p) =>
                                                    p['post_id'] ==
                                                    post['post_id']);
                                                _syncPostControllers();
                                              });
                                              showQuickSnack(context,
                                                  'Post deleted successfully!');
                                            } else {
                                              showQuickSnack(
                                                context,
                                                "Couldn't delete the post. Try again!",
                                                isError: true,
                                              );
                                            }
                                          }
                                        } else if (value == 'modify') {
                                          final mediaUrls =
                                              post['post_media'] is String
                                                  ? (post['post_media']
                                                          as String)
                                                      .split(',')
                                                      .map((e) => e.trim())
                                                      .where(
                                                          (e) => e.isNotEmpty)
                                                      .toList()
                                                  : <String>[];
                                          final mediaCaptions =
                                              post['post_des'] is String
                                                  ? (post['post_des'] as String)
                                                      .split(',')
                                                      .map((e) => e.trim())
                                                      .toList()
                                                  : <String>[];
                                          final mainText =
                                              post['post_main_description'] ??
                                                  '';
                                          final result =
                                              await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => Editpost(
                                                postId:
                                                    post['post_id'].toString(),
                                                initialText: mainText,
                                                mediaUrls: mediaUrls,
                                                mediaCaptions: mediaCaptions,
                                              ),
                                            ),
                                          );
                                          if (result == true) {
                                            fetchSortedPosts(
                                                userPhone.toString(),
                                                selectedSortValue,
                                                page: 1);
                                            showQuickSnack(context,
                                                'Post updated successfully!');
                                          }
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        PopupMenuItem<String>(
                                          value: 'modify',
                                          height: 44,
                                          child: Row(
                                            children: [
                                              const Icon(Icons.edit_outlined,
                                                  size: 20,
                                                  color: Color(0xFF1A56DB)),
                                              const SizedBox(width: 10),
                                              const Text('Modify',
                                                  style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w600)),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuDivider(height: 8),
                                        PopupMenuItem<String>(
                                          value: 'delete',
                                          height: 44,
                                          child: Row(
                                            children: [
                                              const Icon(Icons.delete_outline,
                                                  size: 20,
                                                  color: Colors.redAccent),
                                              const SizedBox(width: 10),
                                              const Text(
                                                'Delete',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.redAccent,
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
  }
}