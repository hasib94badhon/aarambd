import 'dart:convert';
import 'package:aaram_bd/screens/advert_screen.dart';
import 'package:aaram_bd/widgets/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:aaram_bd/config.dart'; // Adjust as necessary for your project
import 'package:aaram_bd/widgets/app_toast.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  TextEditingController commentController = TextEditingController();
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
  late final Future<Map<String, dynamic>?> _loggedInUserFuture;

  @override
  void initState() {
    super.initState();

    // cache the future once so FutureBuilder won't recreate it on every rebuild
    _loggedInUserFuture = fetchLoggedInUserData(context);

    // 1. Load the logged-in user ID from Config
    Config.getLoggedInUser().then((id) {
      setState(() {
        currentUserId = id;
      });
    });

    // initialize comments scroll controller
    _commentsScrollController = ScrollController();
    _commentsScrollController.addListener(_onCommentsScroll);

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
    super.dispose();
  }

  Future<bool> submitComment(String commentText, BuildContext context,
      {String? commentId}) async {
    print("Submitting comment: $commentText");
    try {
      final resp = await Config.apiPost(
        "/submit_comment?com_user_id=$userId",
        {
          'post_id': postId,
          'com_text': commentText,
          'com_user_id': userId,
          if (commentId != null) 'com_id': commentId,
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

  Future<Map<String, dynamic>?> fetchLoggedInUserData(
      BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('user_id');
    if (userId == null) return null;

    final response =
        await Config.apiGet('/get_user_info?user_id=$userId', context);

    if (response != null && response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      print("Failed to fetch user info");
      return null;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F3F8),
      appBar: AppBar(
        title: const Text('পোস্ট বিবরণ'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFEAEDF2)),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      final serviceId = service_id;
                      final shopId = shop_id;
                      final userId = post_user;

                      Map<String, String> additionalData;

                      if (serviceId != 0) {
                        additionalData = {'service_id': serviceId.toString()};
                      } else if (shopId != 0) {
                        additionalData = {'shop_id': shopId.toString()};
                      } else {
                        additionalData = {'user_only': userId.toString()};
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
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0D000000),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                        border: Border.all(color: const Color(0xFFE8EDF5)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: const Color(0xFFEFF4FF),
                            backgroundImage: profilePic.isNotEmpty
                                ? NetworkImage(profilePic)
                                : null,
                            child: profilePic.isEmpty
                                ? const Icon(Icons.person,
                                    size: 28, color: Color(0xFF5B8DEF))
                                : null,
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
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1A2340),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  userCategory,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF5B8DEF),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded,
                              color: Color(0xFFB0B7C3), size: 22),
                        ],
                      ),
                    ),
                  ),

                  if (mainDescription.trim().isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(top: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE8EDF5)),
                      ),
                      child: Text(
                        mainDescription,
                        textAlign: TextAlign.justify,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1A2340),
                          height: 1.6,
                        ),
                      ),
                    ),

                  // Post Description
                  if (mediaList.isNotEmpty || descriptionList.isNotEmpty)
                    MediaSlider(
                      mediaList: mediaList,
                      descriptionList: descriptionList,
                    ),

                  // Interaction buttons (Like, Share, Comments)
                  Container(
                    margin:
                        const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0D000000),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                      border: Border.all(color: const Color(0xFFE8EDF5)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _StatItem(
                          icon: Icons.remove_red_eye,
                          label: Config.formatLargeNumber(postViewed),
                          color: Colors.blueAccent,
                          onTap: () {},
                        ),
                        _StatItem(
                          icon: Icons.comment_rounded,
                          label: Config.formatLargeNumber(postComments),
                          color: Colors.green,
                          onTap: () {},
                        ),
                        _StatItem(
                          icon: Icons.access_time,
                          label: formattedTime,
                          color: Colors.orange,
                        ),
                      ],
                    ),
                  ),

                  // Comment Section Header
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Insert Comment Box (Moved to top)
                      // ── Comment input ──
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                        child: FutureBuilder<Map<String, dynamic>?>(
                          future: _loggedInUserFuture,
                          builder: (_, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                  child: Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              ));
                            } else if (snapshot.hasError ||
                                !snapshot.hasData) {
                              return const SizedBox.shrink();
                            }

                            final userData = snapshot.data!;
                            final String name = userData['name'];
                            final String photoUrl =
                                userData['photo'] ?? '';

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: const Color(0xFFE8EDF5)),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x0A000000),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor:
                                        const Color(0xFFEFF4FF),
                                    backgroundImage: photoUrl.isNotEmpty
                                        ? NetworkImage(photoUrl)
                                        : null,
                                    child: photoUrl.isEmpty
                                        ? const Icon(Icons.person,
                                            size: 20,
                                            color: Color(0xFF5B8DEF))
                                        : null,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      controller: commentController,
                                      minLines: 1,
                                      maxLines: 4,
                                      decoration: InputDecoration(
                                        hintText:
                                            '$name হিসেবে মন্তব্য করুন…',
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                vertical: 10,
                                                horizontal: 12),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                              color: Color(0xFFE8EDF5)),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                              color: Color(0xFFE8EDF5)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                              color: Color(0xFF5B8DEF),
                                              width: 1.5),
                                        ),
                                        filled: true,
                                        fillColor: const Color(0xFFF7F9FC),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () async {
                                      final text =
                                          commentController.text.trim();
                                      if (text.isEmpty) return;

                                      final ok = await submitComment(
                                          text, context);
                                      if (!mounted) return;
                                      if (ok) {
                                        handleAction(post_user, 'comment',
                                            int.parse(postId));
                                        commentController.clear();
                                        FocusScope.of(context).unfocus();
                                        _commentsPage = 0;
                                        _commentsHasMore = true;
                                        await fetchComments(
                                            page: 1, context: context);
                                        if (!mounted) return;
                                        await fetchPostData(context);
                                        if (!mounted) return;
                                        await Future.delayed(const Duration(
                                            milliseconds: 80));
                                        if (_commentsScrollController
                                            .hasClients) {
                                          _commentsScrollController
                                              .animateTo(
                                            0.0,
                                            duration: const Duration(
                                                milliseconds: 300),
                                            curve: Curves.easeOut,
                                          );
                                        }
                                      } else {
                                        if (!mounted) return;
                                        showAppToast(
                                            context,
                                            'মন্তব্য পাঠানো যায়নি। আবার চেষ্টা করুন।',
                                            icon: Icons
                                                .error_outline_rounded);
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF5B8DEF),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                          Icons.send_rounded,
                                          color: Colors.white,
                                          size: 18),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                      /// Comment List
                      // Comment List (paginated auto-load)
                      SizedBox(
                        // give a height so the inner list can scroll independently inside the page
                        // adjust the multiplier if you want more/less visible height
                        height: MediaQuery.of(context).size.height * 0.45,
                        child: _commentsLoading && comments.isEmpty
                            ? const Center(child: CircularProgressIndicator())
                            : comments.isEmpty
                                ? SingleChildScrollView(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    child: Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(24.0),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                                Icons.chat_bubble_outline,
                                                size: 36,
                                                color: Colors.grey),
                                            const SizedBox(height: 8),
                                            const Text('No comments available'),
                                            const SizedBox(height: 12),
                                            TextButton.icon(
                                              onPressed: () => fetchComments(
                                                  page: 1, context: context),
                                              icon: const Icon(Icons.refresh),
                                              label: const Text('Refresh'),
                                            )
                                          ],
                                        ),
                                      ),
                                    ),
                                  )
                                : NotificationListener<ScrollNotification>(
                                    onNotification: (scrollInfo) {
                                      if (!_commentsHasMore || _commentsLoading)
                                        return false;
                                      if (scrollInfo.metrics.pixels >=
                                          scrollInfo.metrics.maxScrollExtent -
                                              200) {
                                        _loadMoreComments();
                                      }
                                      return false;
                                    },
                                    child: ListView.builder(
                                      controller: _commentsScrollController,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 6, horizontal: 8),
                                      itemCount: comments.length +
                                          (_commentsHasMore ? 1 : 0),
                                      itemBuilder: (context, index) {
                                        if (index < comments.length) {
                                          final comment = comments[index];
                                          return _buildComment(comment);
                                        } else {
                                          // bottom loader placeholder while next page loads
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 12),
                                            child: Center(
                                              child: _commentsLoading
                                                  ? const CircularProgressIndicator()
                                                  : const SizedBox.shrink(),
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Comment Input Box - pinned to the bottom
        ],
      ),
    );
  }

  // Helper Widget for Each Comment
  Widget _buildComment(dynamic comment) {
    final comId = comment['com_id'].toString();
    final comUserId = comment['user_id'].toString();
    final isOwn = comUserId == currentUserId;
    final isEditing = editingCommentId == comId;

    Widget _avatar() {
      final url = (comment['photo'] ?? '').toString();
      return CircleAvatar(
        radius: 20,
        backgroundColor: Colors.grey.shade300,
        backgroundImage: url.isNotEmpty ? NetworkImage(url) : null,
        child:
            url.isEmpty ? const Icon(Icons.person, color: Colors.white) : null,
      );
    }

    // ===== EDIT MODE (styling only) =====
    if (isEditing) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
            ],
            border: Border.all(color: const Color(0xFFE8EDF5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: editingController,
                decoration: InputDecoration(
                  hintText: 'Edit your comment',
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                maxLines: null,
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => setState(() => editingCommentId = null),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      submitComment(
                              editingController.text.trim(),
                              commentId: comId,
                              context)
                          .then((_) {
                        setState(() => editingCommentId = null);
                        fetchComments(page: 1, context: context);
                      });
                      handleAction(post_user, 'comment', int.parse(postId));
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // ===== READ MODE (refined layout) =====
    return GestureDetector(
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _avatar(),
            const SizedBox(width: 10),
            // Card bubble
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, 3)),
                  ],
                  border: Border.all(color: const Color(0xFFE8EDF5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: name/category on left, time + (edit) on right
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Name + category
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (comment['commenter_name'] ?? 'Anonymous')
                                    .toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                (comment['cat_name'] ?? '').toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.teal.shade600,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Time + edit icon
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              Config.getTimeDifference(comment['com_time']),
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                            if (isOwn) ...[
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () => setState(() {
                                  editingCommentId = comId;
                                  editingController.text =
                                      (comment['com_text'] ?? '').toString();
                                }),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: Icon(Icons.edit,
                                      size: 18, color: Colors.grey.shade700),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Comment text
                    Text(
                      (comment['com_text'] ?? '').toString(),
                      style: const TextStyle(
                          fontSize: 14, height: 1.45, color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
  PageController _pageController = PageController();
  int currentIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  // ---- In your widget ----
  Widget build(BuildContext context) {
    final hasMedia = widget.mediaList.isNotEmpty;

    return Column(
      children: [
        Container(
          height: 280,
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            // Removed shadow for clearer images
            // boxShadow: [...]
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: hasMedia
                ? PageView.builder(
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
                                  pageBuilder: (_, __, ___) =>
                                      FullscreenGallery(
                                    mediaList: widget.mediaList,
                                    initialIndex: index,
                                    descriptionList: widget.descriptionList,
                                  ),
                                  transitionsBuilder:
                                      (_, animation, __, child) =>
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
                                    fontSize: 15,
                                    height: 1.35,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  )
                : Container(
                    color: Colors.grey[100],
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      widget.descriptionList.isNotEmpty
                          ? widget.descriptionList[0]
                          : 'No content available.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        if (hasMedia)
          Text(
            '${currentIndex + 1} / ${widget.mediaList.length}',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[800],
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
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

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _StatItem({
    Key? key,
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
