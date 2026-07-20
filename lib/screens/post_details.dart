import 'dart:convert';
import 'package:aaram_bd/screens/advert_screen.dart';
import 'package:aaram_bd/screens/thoughtdetails.dart' show ExpandableText;
import 'package:aaram_bd/widgets/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:aaram_bd/config.dart'; // Adjust as necessary for your project
import 'package:aaram_bd/widgets/app_toast.dart';
import 'package:intl/intl.dart';

final String host = Config.host;

class PostDetails extends StatefulWidget {
  final String postId;
  final String userId;

  final Key? key;

  PostDetails({required this.postId, required this.userId, this.key})
      : super(key: key);

  @override
  State<PostDetails> createState() =>
      _PostDetailsState(postId: postId, userId: userId);
}

class _PostDetailsState extends State<PostDetails> {
  static const Color _primary = Color(0xFF1A56DB);

  TextEditingController commentController = TextEditingController();
  final FocusNode _commentFocus = FocusNode();
  bool _commentFieldFocused = false;
  final String userId;
  final String postId;
  int shop_id = 0;
  int service_id = 0;
  bool isservice = false;

  // Pagination state for post comments
  int _commentsPage = 0; // 0 = not loaded yet
  final int _commentsPageSize = 10;
  bool _commentsLoading = false;
  bool _commentsHasMore = true; // assume more until server returns empty page

  // Scroll controller for automatic loading of comments
  late final ScrollController _commentsScrollController;

  _PostDetailsState({required this.postId, required this.userId});

  List<String> mediaList = [];
  List<String> descriptionList = [];

  String postDescription = "Post Description";
  String mainDescription = "";
  String postMedia = "";
  String userName = "User Name";
  String profilePic = "";
  String userCategory = "Category";
  int postLiked = 0;
  int postViewed = 0;
  int postComments = 0;
  int postShared = 0;
  String postTime = '';
  int post_user = 0;
  int total_comment = 0;
  List<dynamic> comments = [];
  String formattedTime = '';

  String? currentUserId;
  String? editingCommentId;
  final TextEditingController editingController = TextEditingController();

  // Reply-to state — set when the user taps a comment's reply action,
  // cleared on send/cancel.
  String? _replyToId;
  String? _replyToAuthor;
  String? _replyToText;

  void _startReply(dynamic comment) {
    setState(() {
      _replyToId = comment['com_id'].toString();
      _replyToAuthor = (comment['commenter_name'] ?? 'Someone').toString();
      _replyToText = (comment['com_text'] ?? '').toString();
    });
    _commentFocus.requestFocus();
  }

  void _cancelReply() {
    if (_replyToId == null) return;
    setState(() {
      _replyToId = null;
      _replyToAuthor = null;
      _replyToText = null;
    });
  }

  @override
  void initState() {
    super.initState();

    // 1. Load the logged-in user ID from Config
    Config.getLoggedInUser().then((id) {
      setState(() {
        currentUserId = id;
      });
    });

    // initialize comments scroll controller
    _commentsScrollController = ScrollController();
    _commentsScrollController.addListener(_onCommentsScroll);
    _commentFocus.addListener(() {
      if (mounted)
        setState(() => _commentFieldFocused = _commentFocus.hasFocus);
    });

    fetchPostData(context);

    // load first page of comments
    fetchComments(page: 1, context: context);

    increse_post_view(int.parse(postId));
  }

  @override
  void dispose() {
    _commentsScrollController.removeListener(_onCommentsScroll);
    _commentsScrollController.dispose();
    editingController.dispose();
    commentController.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  Future<bool> submitComment(String commentText, BuildContext context,
      {String? commentId, String? replyToId}) async {
    print("Submitting comment: $commentText");
    try {
      final resp = await Config.apiPost(
        "/submit_comment?com_user_id=$userId",
        {
          'post_id': postId,
          'com_text': commentText,
          'com_user_id': userId,
          if (commentId != null) 'com_id': commentId,
          if (replyToId != null) 'reply_to_com_id': replyToId,
        },
        context,
      );

      if (resp != null && (resp.statusCode == 201 || resp.statusCode == 200)) {
        print(resp.statusCode == 201
            ? "Comment submitted successfully"
            : "Comment updated successfully");
        return true;
      } else {
        print("Failed to submit comment: ${resp?.statusCode}");
        print("Response body: ${resp?.body}");
        return false;
      }
    } catch (e) {
      print("submitComment error: $e");
      return false;
    }
  }

  Future<void> increse_post_view(int postId) async {
    print("🔼 increasePostView: $postId");

    // Call your POST /increase_post_view endpoint via Config.apiPost
    final response = await Config.apiPost(
      '/increase_post_view', // or '/increase_post_view' if you didn’t prefix with /api
      {'post_id': postId},
      context,
    );

    // If null, Config forced a logout (refresh failed)
    if (response == null) return;

    // Success is 200 in your Flask code
    if (response.statusCode == 200) {
      print("Post view incremented for post $postId");
    } else {
      // Parse error message from the server
      final body = json.decode(response.body);
      final msg = body['error'] ?? body['message'] ?? 'Could not increase view';
      print("increasePostView failed: $msg");
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text(msg)),
      // );
    }
  }

  Future<void> fetchComments(
      {required int page, required BuildContext context}) async {
    if (_commentsLoading) return;
    _commentsLoading = true;
    setState(() {});

    final uri =
        '/get_comments?post_id=$postId&page=$page&page_size=$_commentsPageSize';
    print('Fetching comments: ${uri.toString()}');

    try {
      final response = await Config.apiGet(uri, context);

      if (response != null && response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> newComments =
            (data['comments'] ?? []) as List<dynamic>;

        if (page == 1) {
          comments = newComments;
        } else {
          comments = [...comments, ...newComments];
        }

        _commentsPage = page;

        // If server returned fewer than page size or empty, assume no more pages
        if (newComments.isEmpty || newComments.length < _commentsPageSize) {
          _commentsHasMore = false;
        } else {
          _commentsHasMore = true;
        }

        // optional: if server still returns old total_comment, you may update
        total_comment = data['total_comments'] ?? total_comment;
      } else {
        print("Failed to fetch comments: ${response?.statusCode}");
      }
    } catch (e) {
      print("Error fetching comments page $page: $e");
    } finally {
      _commentsLoading = false;
      setState(() {});
    }
  }

  void _onCommentsScroll() {
    try {
      if (!_commentsHasMore || _commentsLoading) return;
      if (!_commentsScrollController.hasClients) return;
      final pos = _commentsScrollController.position;
      if (pos.pixels >= pos.maxScrollExtent - 200) {
        _loadMoreComments();
      }
    } catch (e) {
      // ignore scroll errors
    }
  }

  Future<void> _loadMoreComments() async {
    if (!_commentsHasMore) return;
    final nextPage = (_commentsPage == 0) ? 1 : _commentsPage + 1;
    await fetchComments(page: nextPage, context: context);
  }

  Future<void> fetchPostData(BuildContext context) async {
    print("Fetching post data for postId: $postId");

    try {
      final response =
          await Config.apiGet('/get_post?post_id=$postId', context);

      if (response != null && response.statusCode == 200) {
        final data = json.decode(response.body);
        print(data);

        // Log the entire response body to check its structure
        print("Fetched post data: $data");
        setState(() {
          postDescription = data['post']['post_des'] ?? "";
          postMedia = data['post']['post_media'] ?? "";

          userName = data['post']['user_name'] ?? "No name available";
          userCategory = data['post']['cat_name'] ?? "No category available";
          profilePic = data['post']['user_photo'] ?? "";
          postLiked = data['post']['post_liked'] ?? 0;
          postViewed = data['post']['post_viewed'] ?? 0;
          postComments = data['post']['post_comments'] ?? 0;
          postShared = data['post']['post_shared'] ?? 0;
          postTime = data['post']['post_time'] ?? '';
          print("🕒 Raw time string: $postTime");
          formattedTime = Config.getTimeDifference(postTime);

          post_user = data['post']['post_user'] ?? 0;
          service_id = data['post']['service_id'] ?? 0;
          shop_id = data['post']['shop_id'] ?? 0;
          isservice = data['post']['is_service'] == true ||
              data['post']['is_service'] == 'true';
          mainDescription = data['post']['post_main_description'] ?? "";

          // Safely split and trim postMedia and postDescription
          mediaList = postMedia.isNotEmpty
              ? postMedia.split(',').map((e) => e.trim()).toList()
              : [];

          descriptionList = postDescription.isNotEmpty
              ? postDescription.split(',').map((e) => e.trim()).toList()
              : [];
        });
      } else {
        print("Failed to fetch post data: ${response?.statusCode}");
      }
    } catch (e) {
      print("Error fetching post data: $e");
    }
  }

  // add notification for comments
  void handleAction(int user_id, String actionType, int detail_post_id) async {
    NotificationService notificationService = NotificationService();
    await notificationService.sendNotificationWithLoggedInUser(
        user_id, // Target user's ID
        actionType, // Action type: 'comment'
        detail_post_id,
        context);
  }

  Color _darken(Color c, [double amount = 0.16]) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }

  void _openPosterProfile() {
    final serviceId = service_id;
    final shopId = shop_id;
    final targetUserId = post_user;

    Map<String, String> additionalData;
    if (serviceId != 0) {
      additionalData = {'service_id': serviceId.toString()};
    } else if (shopId != 0) {
      additionalData = {'shop_id': shopId.toString()};
    } else {
      additionalData = {'user_only': targetUserId.toString()};
    }
    handleAction(post_user, 'view', 0);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdvertScreen(
          userId: post_user.toString(),
          isService: isservice,
          advertData: AdvertData(
            userId: post_user.toString(),
            isService: isservice,
            additionalData: additionalData,
          ),
        ),
      ),
    );
  }

  // ─── Hero header: back button + poster info on a themed gradient ─────────
  Widget _buildHeroHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          14, MediaQuery.of(context).padding.top + 12, 14, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_darken(_primary), _primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(26),
          bottomRight: Radius.circular(26),
        ),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.30),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => Navigator.pop(context),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _openPosterProfile,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.55),
                          width: 1.6),
                    ),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.white24,
                      backgroundImage: profilePic.isNotEmpty
                          ? NetworkImage(profilePic)
                          : null,
                      child: profilePic.isEmpty
                          ? const Icon(Icons.person,
                              color: Colors.white, size: 24)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16.5,
                            color: Colors.white,
                          ),
                        ),
                        if (userCategory.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            userCategory,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.78),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      size: 22, color: Colors.white.withValues(alpha: 0.85)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Post content card: media (if any) + main text (if any) ──────────────
  Widget _buildPostCard() {
    final hasMedia = mediaList.isNotEmpty;
    final hasText = mainDescription.trim().isNotEmpty;
    if (!hasMedia && !hasText) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasMedia)
            MediaSlider(mediaList: mediaList, descriptionList: descriptionList),
          if (hasText)
            Padding(
              padding: const EdgeInsets.all(16),
              child: ExpandableText(
                text: mainDescription,
                maxLines: 6,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A2340),
                  height: 1.6,
                ),
                moreLabel: 'আরও দেখুন',
                lessLabel: 'কম দেখুন',
                linkStyle: const TextStyle(
                  fontSize: 13,
                  color: _primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Stats bar ───────────────────────────────────────────────────────────
  Widget _buildStatsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          _statChip(
              Icons.visibility_outlined,
              Config.formatLargeNumber(postViewed),
              'views',
              const Color(0xFF3B82F6)),
          const SizedBox(width: 10),
          _statChip(
              Icons.chat_bubble_outline_rounded,
              Config.formatLargeNumber(postComments),
              'comments',
              const Color(0xFF10B981)),
          const Spacer(),
          Row(
            children: [
              const Icon(Icons.access_time_rounded,
                  size: 13, color: Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Text(
                formattedTime,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(value,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(width: 3),
          Text(label,
              style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildNoComments() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded,
                  size: 34, color: _primary),
            ),
            const SizedBox(height: 14),
            const Text('কোনো মন্তব্য নেই',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827))),
            const SizedBox(height: 6),
            Text(
              'প্রথম মন্তব্যকারী হন!',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: Colors.grey.shade600, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Fixed bottom comment input, with a reply-preview strip when active ──
  Widget _buildCommentBar() {
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyToId != null)
              Container(
                margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border(left: BorderSide(color: _primary, width: 3)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'উত্তর দিচ্ছেন ${_replyToAuthor ?? ''}',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _primary),
                          ),
                          Text(
                            _replyToText ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: _cancelReply,
                      child: Icon(Icons.close_rounded,
                          size: 18, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Row(
                children: [
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: _commentFieldFocused
                            ? Colors.white
                            : const Color(0xFFF4F6FB),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: _commentFieldFocused
                              ? _primary
                              : const Color(0xFFE2E8F0),
                          width: _commentFieldFocused ? 1.6 : 1.0,
                        ),
                        boxShadow: _commentFieldFocused
                            ? [
                                BoxShadow(
                                  color: _primary.withValues(alpha: 0.16),
                                  blurRadius: 12,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : [],
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: TextField(
                        controller: commentController,
                        focusNode: _commentFocus,
                        decoration: InputDecoration(
                          hintText: _replyToId != null
                              ? 'উত্তর লিখুন...'
                              : 'মন্তব্য লিখুন...',
                          hintStyle: const TextStyle(
                              color: Color(0xFF94A3B8), fontSize: 14),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 8),
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.newline,
                        style: const TextStyle(
                            fontSize: 14, color: Color(0xFF1A2340)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () async {
                      final text = commentController.text.trim();
                      if (text.isEmpty) return;

                      final replyId = _replyToId;
                      final ok = await submitComment(text, context,
                          replyToId: replyId);
                      if (!mounted) return;
                      if (ok) {
                        handleAction(post_user, 'comment', int.parse(postId));
                        commentController.clear();
                        _cancelReply();
                        FocusScope.of(context).unfocus();
                        _commentsPage = 0;
                        _commentsHasMore = true;
                        await fetchComments(page: 1, context: context);
                        if (!mounted) return;
                        await fetchPostData(context);
                        if (!mounted) return;
                        await Future.delayed(const Duration(milliseconds: 80));
                        if (_commentsScrollController.hasClients) {
                          _commentsScrollController.animateTo(
                            0.0,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          );
                        }
                      } else {
                        if (!mounted) return;
                        showAppToast(
                            context, 'মন্তব্য পাঠানো যায়নি। আবার চেষ্টা করুন।',
                            icon: Icons.error_outline_rounded);
                      }
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _primary.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.send_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      resizeToAvoidBottomInset: true,
      bottomNavigationBar: _buildCommentBar(),
      body: NotificationListener<ScrollNotification>(
        onNotification: (info) {
          if (_commentsHasMore &&
              !_commentsLoading &&
              info.metrics.pixels >= info.metrics.maxScrollExtent - 200) {
            _loadMoreComments();
          }
          return false;
        },
        child: CustomScrollView(
          controller: _commentsScrollController,
          slivers: [
            // Themed gradient hero: back button + poster info
            SliverToBoxAdapter(child: _buildHeroHeader(context)),

            // Post content (media + text, adapting to what's present)
            if (mainDescription.trim().isNotEmpty || mediaList.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                  child: _buildPostCard(),
                ),
              ),

            // Stats (views · comments · time)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
                child: _buildStatsBar(),
              ),
            ),

            // Comment list
            if (_commentsLoading && comments.isEmpty)
              SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: _primary),
                  ),
                ),
              )
            else if (comments.isEmpty)
              SliverToBoxAdapter(child: _buildNoComments())
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    if (i < comments.length) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                        child: _buildComment(comments[i]),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: _commentsLoading
                            ? CircularProgressIndicator(
                                color: _primary, strokeWidth: 2.5)
                            : const SizedBox.shrink(),
                      ),
                    );
                  },
                  childCount: comments.length + (_commentsHasMore ? 1 : 0),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  // ─── Individual comment card ──────────────────────────────────────────────
  Widget _buildComment(dynamic comment) {
    final comId = comment['com_id'].toString();
    final comUserId = comment['user_id'].toString();
    final isOwn = comUserId == currentUserId;
    final isEditing = editingCommentId == comId;

    Widget avatar() {
      final url = (comment['photo'] ?? '').toString();
      return Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: _primary.withValues(alpha: 0.22)),
        ),
        child: CircleAvatar(
          radius: 20,
          backgroundColor: Colors.grey.shade200,
          backgroundImage: url.isNotEmpty ? NetworkImage(url) : null,
          child: url.isEmpty
              ? const Icon(Icons.person, color: Colors.white, size: 20)
              : null,
        ),
      );
    }

    // Edit mode
    if (isEditing) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _primary.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: _primary.withValues(alpha: 0.14),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: editingController,
                maxLines: null,
                decoration: InputDecoration(
                  hintText: 'মন্তব্য সম্পাদনা করুন',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: _primary, width: 1.6),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => setState(() => editingCommentId = null),
                    style:
                        TextButton.styleFrom(foregroundColor: Colors.blueGrey),
                    child: const Text('বাতিল',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      submitComment(editingController.text.trim(), context,
                              commentId: comId)
                          .then((_) {
                        setState(() => editingCommentId = null);
                        _commentsPage = 0;
                        _commentsHasMore = true;
                        fetchComments(page: 1, context: context);
                      });
                      handleAction(post_user, 'comment', int.parse(postId));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('সংরক্ষণ',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Read-only mode
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          final serviceId = comment['service_id'];
          final shopId = comment['shop_id'];
          final userId = comment['user_id'].toString();

          Map<String, String> additionalData;
          if (serviceId != null && serviceId != 0) {
            additionalData = {'service_id': serviceId.toString()};
          } else if (shopId != null && shopId != 0) {
            additionalData = {'shop_id': shopId.toString()};
          } else {
            additionalData = {'user_only': userId};
          }

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AdvertScreen(
                userId: userId,
                isService: comment['is_service'] ?? false,
                advertData: AdvertData(
                  userId: userId,
                  isService: comment['is_service'] ?? false,
                  additionalData: additionalData,
                ),
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  avatar(),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (comment['commenter_name'] ?? 'Anonymous').toString(),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Color(0xFF111827)),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if ((comment['cat_name'] ?? '').toString().isNotEmpty)
                          Text(
                            comment['cat_name'].toString(),
                            style: TextStyle(
                                fontSize: 12,
                                color: _primary,
                                fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F6FB),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          Config.getTimeDifference(comment['com_time'] ?? ''),
                          style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _startReply(comment),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F6FB),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.reply_rounded,
                              size: 15, color: Colors.grey.shade600),
                        ),
                      ),
                      if (isOwn) ...[
                        const SizedBox(width: 8),
                        InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            setState(() {
                              editingCommentId = comId;
                              editingController.text =
                                  (comment['com_text'] ?? '').toString();
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: _primary.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.edit_rounded,
                                size: 15, color: _primary),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (comment['reply_to_com_id'] != null &&
                  (comment['reply_text'] ?? '').toString().isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border(left: BorderSide(color: _primary, width: 3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        (comment['reply_author_name'] ?? 'মন্তব্য').toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: _primary),
                      ),
                      Text(
                        comment['reply_text'].toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11.5, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ExpandableText(
                text: (comment['com_text'] ?? '').toString(),
                maxLines: 3,
                style: const TextStyle(
                    fontSize: 14, height: 1.45, color: Color(0xFF374151)),
                moreLabel: 'আরও দেখুন',
                lessLabel: 'কম দেখুন',
                linkStyle: TextStyle(
                    fontSize: 13, color: _primary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MediaSlider extends StatefulWidget {
  final List<String> mediaList;
  final List<String> descriptionList;

  const MediaSlider({
    required this.mediaList,
    required this.descriptionList,
    super.key,
  });

  @override
  State<MediaSlider> createState() => _MediaSliderState();
}

class _MediaSliderState extends State<MediaSlider> {
  final PageController _pageController = PageController();
  int currentIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Caller (post_details.dart's _buildPostCard) only renders this when
    // mediaList is non-empty, so it always has at least one image here —
    // flush to the card's top edge, only the top corners rounded.
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(18),
        topRight: Radius.circular(18),
      ),
      child: SizedBox(
        height: 280,
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: widget.mediaList.length,
              onPageChanged: (index) {
                setState(() => currentIndex = index);
              },
              itemBuilder: (context, index) {
                final mediaUrl = widget.mediaList[index];
                final description = index < widget.descriptionList.length
                    ? widget.descriptionList[index]
                    : "";

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // Tap to open full-screen zoomable gallery
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          PageRouteBuilder(
                            opaque: false,
                            pageBuilder: (_, __, ___) => FullscreenGallery(
                              mediaList: widget.mediaList,
                              initialIndex: index,
                              descriptionList: widget.descriptionList,
                            ),
                            transitionsBuilder: (_, animation, __, child) =>
                                FadeTransition(
                                    opacity: animation, child: child),
                          ),
                        );
                      },
                      child: Hero(
                        tag: mediaUrl, // unique per image
                        child: Image.network(
                          mediaUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(color: Colors.grey[300]),
                        ),
                      ),
                    ),

                    // Caption chip (only when exists) — no full overlay dim
                    if (description.isNotEmpty)
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black87.withValues(alpha: 0.60),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            description,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              height: 1.35,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),

            // Page counter, overlaid — only shown when there's more than one image
            if (widget.mediaList.length > 1)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${currentIndex + 1}/${widget.mediaList.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class FullscreenGallery extends StatefulWidget {
  final List<String> mediaList;
  final int initialIndex;
  final List<String> descriptionList;

  const FullscreenGallery({
    Key? key,
    required this.mediaList,
    required this.initialIndex,
    required this.descriptionList,
  }) : super(key: key);

  @override
  State<FullscreenGallery> createState() => _FullscreenGalleryState();
}

class _FullscreenGalleryState extends State<FullscreenGallery> {
  late PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '${_index + 1} / ${widget.mediaList.length}',
          style: const TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.mediaList.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              final url = widget.mediaList[i];

              return Center(
                child: Hero(
                  tag: url,
                  child: InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 4.0,
                    boundaryMargin: const EdgeInsets.all(20),
                    child: Image.network(
                      url,
                      fit: BoxFit.contain, // show full image clearly
                      errorBuilder: (context, error, stackTrace) =>
                          Container(color: Colors.grey[800]),
                    ),
                  ),
                ),
              );
            },
          ),

          // Optional caption (bottom)
          if (_index < widget.descriptionList.length &&
              widget.descriptionList[_index].trim().isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 20,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  widget.descriptionList[_index],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    height: 1.4,
                    fontSize: 14.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
