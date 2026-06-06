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
import 'package:provider/provider.dart';
import 'package:aaram_bd/localization/app_localizations.dart';
import 'package:aaram_bd/localization/language_provider.dart';
import 'package:aaram_bd/screens/editprofile_screen.dart';
import 'package:aaram_bd/screens/post_upload.dart';
import 'package:url_launcher/url_launcher.dart';
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

  AppLocalizations get _l10n =>
      Provider.of<LanguageProvider>(context, listen: false).l10n;

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

  // ---------- helpers: styling ----------
  BoxDecoration get _card => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12.withValues(alpha: 0.06)),
        boxShadow: const [
          BoxShadow(
              color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
        ],
      );

  BoxDecoration get _softPill => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black12.withValues(alpha: 0.08)),
      );

  TextStyle get _title => const TextStyle(
        fontFamily: 'Poppins',
        fontWeight: FontWeight.w700,
        fontSize: 22,
        color: Colors.black87,
      );

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
          content: Text('${_l10n.profileErrorSharing}$e'),
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

  Widget _statItem({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLanguageToggle(BuildContext context, AppLocalizations l10n) {
    final provider = context.watch<LanguageProvider>();
    final isBn = provider.isBangla;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12.withValues(alpha: 0.06)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.language_rounded,
                color: Color(0xFF1A56DB), size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            l10n.languageLabel,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4FA),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFE0E8F5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _langPill(
                  label: AppLocalizations.langBangla,
                  selected: isBn,
                  onTap: () => provider.setLanguage('bn'),
                ),
                _langPill(
                  label: AppLocalizations.langEnglish,
                  selected: !isBn,
                  onTap: () => provider.setLanguage('en'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _langPill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1A56DB) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LanguageProvider>().l10n;
    final kbOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F3F8),
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        child: SingleChildScrollView(
          controller: _scrollController,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header / Profile block
              Container(
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 3),
                child: Container(
                  decoration: _card,
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          UserStarWidget(
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
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // LEFT column: star widget + avatar + meta chips
                          Column(
                          
                            children: [
                              // Avatar + verified
                              GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => Dialog(
                                      backgroundColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.all(15),
                                        decoration: BoxDecoration(
                                          color: Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          boxShadow: const [
                                            BoxShadow(
                                                color: Colors.black26,
                                                blurRadius: 20,
                                                offset: Offset(0, 8)),
                                          ],
                                        ),
                                        child: ClipOval(
                                          child: SizedBox(
                                            height: 280,
                                            width: 280,
                                            child: profile_pic.isNotEmpty
                                                ? Image.network(profile_pic,
                                                    fit: BoxFit.cover)
                                                : Container(
                                                    color: Colors.blueAccent,
                                                    child: const Icon(
                                                        Icons.person,
                                                        size: 100,
                                                        color: Colors.white),
                                                  ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                child: Stack(
                                  children: [
                                    Container(
                                      height: 125,
                                      width: 125,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                      ),
                                      child: ClipOval(
                                        child: profile_pic.isNotEmpty
                                            ? Image.network(
                                                profile_pic,
                                                fit: BoxFit.cover,
                                              )
                                            : Container(
                                                color: const Color(0xFF90CAF9),
                                                child: const Icon(
                                                  Icons.person,
                                                  size: 48,
                                                  color: Colors.white,
                                                ),
                                              ),
                                      ),
                                    ),
                                    Positioned(
                                      top: -2,
                                      left: -2,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                        padding: const EdgeInsets.all(5),
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

                              const SizedBox(height: 15),

                              // Calls chip
                              GestureDetector(
                                onTap: () async {
                                  _callPage = 0;
                                  _callHasMore = true;
                                  await fetchCallList(user_id.toString(),
                                      page: 1, context: context);
                                  showCallHistoryBottomSheet(
                                    context: context,
                                    incomingCallList: incomingCallList
                                        .cast<Map<String, dynamic>>(),
                                    outgoingCallList: outgoingCallList
                                        .cast<Map<String, dynamic>>(),
                                    loadMore: () => fetchCallList(
                                        user_id.toString(),
                                        page: _callPage + 1,
                                        context: context),
                                    hasMore: _callHasMore,
                                  );
                                },
                                child: Container(
                                  padding:
                                      const EdgeInsets.fromLTRB(14, 8, 14, 10),
                                  decoration: _softPill.copyWith(
                                    color: const Color(0xFFEDF4FF),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.08),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Handle indicator
                                      Container(
                                        width: 26,
                                        height: 3,
                                        margin:
                                            const EdgeInsets.only(bottom: 6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF64B5F6),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                      ),

                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.call,
                                              color: Color(0xFF1976D2), size: 18),
                                          const SizedBox(width: 6),
                                          Text(
                                            usercall.toString(),
                                            style: const TextStyle(
                                              color: Colors.black,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            l10n.profileCalls,
                                            style: const TextStyle(
                                              color: Colors.black87,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 8),

                              // Views chip
                              GestureDetector(
                                onTap: () async {
                                  // reset paging when opening
                                  _viewPage = 0;
                                  _viewHasMore = true;
                                  await fetchViewList(user_id.toString(),
                                      page: 1, context: context);
                                  showViewHistoryDialog(
                                    context: context,
                                    viewList:
                                        viewList.cast<Map<String, dynamic>>(),
                                    loadMore: () => fetchViewList(
                                        user_id.toString(),
                                        page: _viewPage + 1,
                                        context: context),
                                    hasMore: _viewHasMore,
                                  );
                                },
                                child: Container(
                                  padding:
                                      const EdgeInsets.fromLTRB(14, 8, 14, 10),
                                  decoration: _softPill.copyWith(
                                    color: const Color(0xFFFFF3E8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.08),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Handle indicator
                                      Container(
                                        width: 26,
                                        height: 3,
                                        margin:
                                            const EdgeInsets.only(bottom: 6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFB74D),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                      ),

                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.remove_red_eye,
                                              color: Color(0xFFF57C00), size: 18),
                                          const SizedBox(width: 6),
                                          Text(
                                            userview.toString(),
                                            style: const TextStyle(
                                              color: Colors.black,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            l10n.profileViews,
                                            style: const TextStyle(
                                              color: Colors.black87,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(width: 6),

                          // RIGHT big card with profile info + actions
                          Expanded(
                            child: Container(
                              decoration: _card,
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(userName, style: _title),
                                  const SizedBox(height: 10),
                                  _infoRow(Icons.phone, widget.userPhone,
                                      Colors.teal.shade700,
                                      iconSize: 20, textSize: 15),
                                  const SizedBox(height: 8),
                                  _infoRow(Icons.category, userCategory,
                                      Colors.deepOrange.shade600,
                                      iconSize: 20, textSize: 15),
                                  const SizedBox(height: 8),
                                  _infoRow(Icons.location_on, userAddress,
                                      Colors.purple.shade600,
                                      iconSize: 20, textSize: 15),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      // Edit Profile — primary filled button
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () async {
                                            final result = await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    EditProfileScreen(
                                                  userName: userName,
                                                  userPhone: widget.userPhone,
                                                  userCategory: userCategory,
                                                  userDescription:
                                                      userDescription,
                                                  userAddress: userAddress,
                                                ),
                                              ),
                                            );
                                            if (result == true) {
                                              fetchSortedPosts(
                                                  userPhone.toString(),
                                                  'recent');
                                            }
                                          },
                                          icon: const Icon(
                                              Icons.edit_outlined,
                                              size: 15,
                                              color: Colors.white),
                                          label: Text(
                                            l10n.profileEdit,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF1A56DB),
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 10),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      // New Post — filled teal/green
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () async {
                                            final result = await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    PostUpload(
                                                  postName: userName,
                                                  postPhone: widget.userPhone,
                                                  postCategory: userCategory,
                                                  postDescription: '',
                                                ),
                                              ),
                                            );
                                            if (result == true) {
                                              fetchSortedPosts(
                                                  userPhone.toString(),
                                                  'recent');
                                            }
                                          },
                                          icon: const Icon(
                                              Icons.add_circle_outline,
                                              size: 15,
                                              color: Colors.white),
                                          label: Text(
                                            l10n.profilePost,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF0D9488),
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 10),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      // Share — outlined ghost button
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () {
                                            shareProfile();
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                    l10n.profileLinkSaved),
                                              ),
                                            );
                                          },
                                          icon: const Icon(
                                              Icons.share_outlined,
                                              size: 15,
                                              color: Color(0xFF7C3AED)),
                                          label: Text(
                                            l10n.profileShare,
                                            style: const TextStyle(
                                              color: Color(0xFF7C3AED),
                                              fontWeight: FontWeight.w700,
                                              fontSize: 11,
                                            ),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 10),
                                            side: const BorderSide(
                                                color: Color(0xFF7C3AED),
                                                width: 1.4),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Data collector card
              if (isDataCollector)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  child: Container(
                    decoration: _card,
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.profileTotalCollections,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                totalCollection.toString(),
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const DataCollectorLearnMorePage()),
                            );
                          },
                          icon: const Icon(Icons.open_in_new, size: 18),
                          label: Text(l10n.profileSeeDetails),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            backgroundColor: const Color(0xFF1A56DB),
                            foregroundColor: Colors.white,
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Allow market to reach you (switch)
              Padding(
  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    decoration: _card.copyWith(
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: call_status == 'active'
            ? Colors.green.withValues(alpha: 0.25)
            : Colors.red.withValues(alpha: 0.25),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 10,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Row(
      children: [
        // Left icon indicator
        Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: call_status == 'active'
                ? Colors.green.withValues(alpha: 0.15)
                : Colors.red.withValues(alpha: 0.15),
          ),
          child: Icon(
            Icons.phone_in_talk_rounded,
            color: call_status == 'active'
                ? Colors.green[700]
                : Colors.red[600],
            size: 22,
          ),
        ),

        const SizedBox(width: 12),

        // Text
        Expanded(
          child: Text(
            l10n.profileAllowMarket,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
        ),

        // Status + switch
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: call_status == 'active'
                    ? Colors.green.withValues(alpha: 0.15)
                    : Colors.red.withValues(alpha: 0.15),
              ),
              child: Text(
                call_status == 'active' ? l10n.profileActive : l10n.profileInactive,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: call_status == 'active'
                      ? Colors.green[700]
                      : Colors.red[600],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: call_status == 'active',
              activeColor: Colors.green,
              inactiveThumbColor: Colors.red,
              onChanged: (value) {
                setState(() {
                  call_status = value ? "active" : "inactive";
                });

                updateUserStatus(
                  userId: user_id,
                  status: call_status,
                  context: context,
                );

                final msg = value
                    ? _l10n.profileCallActive
                    : _l10n.profileCallInactive;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      msg,
                      style:
                          const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    backgroundColor:
                        value ? Colors.green[600] : Colors.red[600],
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    ),
  ),
),


              // Language toggle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: _buildLanguageToggle(context, l10n),
              ),

              // Share thought CTA
              Padding(
  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
  child: SizedBox(
    height: 105,
    width: double.infinity,
    child: Material(
      borderRadius: BorderRadius.circular(18),
      elevation: 10,
      shadowColor: Colors.blueAccent.withValues(alpha: 0.25),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) =>NeedBuilderPage()),
          );
        },
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
            ),
          ),
          child: Stack(
            children: [
              // Soft highlight (makes it premium)
              Positioned(
                top: -20,
                right: -30,
                child: Container(
                  height: 120,
                  width: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    // Icon box
                    Container(
                      height: 52,
                      width: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                      ),
                      child: const Icon(
                        Icons.edit_note_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Text
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            l10n.profilePortalTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.profilePortalSubtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 10),

                    // Badge + arrow
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.22),
                            ),
                          ),
                          child: Text(
                            l10n.profilePortalOpen,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white.withValues(alpha: 0.95),
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
  ),
),


              // Sorting + post count
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 2),
                child: Stack(
                  children: [
                    PostSortingButtons(
                      selectedSort: selectedSortValue,
                      onSortSelected: (newSort) {
                        if (newSort != selectedSortValue) {
                          setState(() {
                            selectedSortValue = newSort;
                          });
                          fetchSortedPosts(userPhone.toString(), newSort);
                        }
                      },
                    ),
                    Positioned(
                      right: 6,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: _softPill.copyWith(color: Colors.white),
                        child: Text(
                          "Posts ${Config.formatLargeNumber(posts.length)}",
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 2),
                child: posts.isEmpty && !_postLoading
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            l10n.profileNoPosts,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                      )
                    : GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 1,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 4 / 2.5,
                        ),
                        // ✅ Add one extra slot for spinner
                        itemCount: posts.length + (_postHasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index < posts.length) {
                            final post = posts[index];
                            final List<String> postImages =
                                List<String>.from(post['post_media'] ?? []);
                            final String mainDescription =
                                post['main_description'] ?? '';
                            final createdAt = post['post_time'];
                            final formattedTime =
                                Config.getTimeDifference(createdAt);
                            final bool hasMedia = postImages.isNotEmpty;

                            final String postId =
                                post['post_id'].toString();
                            final PageController _pageController =
                                _postPageControllers[postId] ??
                                    PageController();

                            return Stack(
                              children: [
                                InkWell(
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
                                  child: Container(
                                    decoration: _card.copyWith(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: hasMedia
                                          ? PageView.builder(
                                              itemCount: postImages.length,
                                              controller: _pageController,
                                              itemBuilder: (context, i) {
                                                final image = postImages[i];
                                                return Image.network(
                                                  image,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error,
                                                          stackTrace) =>
                                                      Container(
                                                          color:
                                                              Colors.grey[300]),
                                                );
                                              },
                                            )
                                          : Container(
                                              padding: const EdgeInsets.all(16),
                                              alignment: Alignment.center,
                                              color: const Color(0xFFF0F4FA),
                                              child: Text(
                                                mainDescription.isNotEmpty
                                                    ? mainDescription
                                                    : (post['post_description'] ??
                                                            l10n.profileNoDescription)
                                                        .toString(),
                                                textAlign: TextAlign.center,
                                                maxLines: 5,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.black87,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                    ),
                                  ),
                                ),

                                // time chip
                                Positioned(
                                  top: 10,
                                  left: 14,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.92),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                          color:
                                              Colors.black12.withValues(alpha: 0.06)),
                                    ),
                                    child: Text(
                                      formattedTime.toString(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ),

                                // Views & Comments
                                Positioned(
                                  bottom: 10,
                                  left: 12,
                                  right: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.96),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.06),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        _statItem(
                                          icon: Icons.remove_red_eye_rounded,
                                          iconBg: Colors.green.shade50,
                                          iconColor: Colors.green.shade700,
                                          value: Config.formatLargeNumber(
                                              post['post_viewed']),
                                          label: l10n.profileViewsStat,
                                        ),
                                        Container(
                                          height: 26,
                                          width: 1,
                                          color: Colors.grey.shade300,
                                        ),
                                        _statItem(
                                          icon: Icons.comment_rounded,
                                          iconBg: Colors.orange.shade50,
                                          iconColor: Colors.orange.shade700,
                                          value: Config.formatLargeNumber(
                                              post['post_comments']),
                                          label: l10n.profileCommentsStat,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Menu
                                Positioned(
  top: 8,
  right: 10,
  child: Material(
    color: Colors.transparent,
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            blurRadius: 10,
            color: Colors.black12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: PopupMenuButton<String>(
        tooltip: l10n.profileOptions,
        splashRadius: 22,
        elevation: 12,
        color: Colors.white,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        offset: const Offset(0, 46),

        icon: const Icon(Icons.more_vert, color: Colors.black87),

        onSelected: (value) async {
          if (value == 'delete') {
            final confirmDelete = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                title: Text(l10n.profileConfirmDelete),
                content: Text(l10n.profileDeleteMessage),
                actionsPadding: const EdgeInsets.only(left: 12, right: 12, bottom: 10),
                actions: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(l10n.profileCancel),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(l10n.profileDelete),
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
                  posts.removeWhere((p) => p['post_id'] == post['post_id']);
                  _syncPostControllers();
                });

                showQuickSnack(context, _l10n.profileDeleteSuccess);
              } else {
                showQuickSnack(
                  context,
                  _l10n.profileDeleteFailed,
                  isError: true,
                );
              }
            }
          } else if (value == 'modify') {
            final mediaUrls = post['post_media'] is String
                ? (post['post_media'] as String)
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList()
                : <String>[];

            final mediaCaptions = post['post_des'] is String
                ? (post['post_des'] as String)
                    .split(',')
                    .map((e) => e.trim())
                    .toList()
                : <String>[];

            final mainText = post['post_main_description'] ?? '';

            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => Editpost(
                  postId: post['post_id'].toString(),
                  initialText: mainText,
                  mediaUrls: mediaUrls,
                  mediaCaptions: mediaCaptions,
                ),
              ),
            );

            if (result == true) {
              fetchSortedPosts(userPhone.toString(), selectedSortValue, page: 1);
              showQuickSnack(context, _l10n.profileUpdateSuccess);
            }
          }
        },

        itemBuilder: (context) => [
          PopupMenuItem<String>(
            value: 'modify',
            height: 44,
            child: Row(
              children: [
                const Icon(Icons.edit_outlined, size: 20, color: Colors.blue),
                const SizedBox(width: 10),
                Text(
                  l10n.profileModify,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
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
                    size: 20, color: Colors.redAccent),
                const SizedBox(width: 10),
                Text(
                  l10n.profileDelete,
                  style: const TextStyle(
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
                            );
                          }
                          // ✅ Loading spinner at the end
                          else {
                            // Trigger fetch more
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }
                        }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
