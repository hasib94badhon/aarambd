import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aaram_bd/config.dart';
import 'package:aaram_bd/screens/advert_screen.dart';

class ThoughtDetails extends StatefulWidget {
  final String desId;
  ThoughtDetails({required this.desId});

  @override
  _ThoughtDetailsState createState() => _ThoughtDetailsState();
}

/* ===================== Reusable UI bits (UI only; no backend changes) ===================== */

class ExpandableText extends StatefulWidget {
  final String text;
  final int maxLines;
  final TextStyle? style;
  final String moreLabel;
  final String lessLabel;
  final TextStyle linkStyle;

  const ExpandableText({
    Key? key,
    required this.text,
    this.maxLines = 3,
    this.style,
    this.moreLabel = 'See more',
    this.lessLabel = 'See less',
    this.linkStyle = const TextStyle(
      fontSize: 14,
      color: Colors.blue,
      fontWeight: FontWeight.w600,
    ),
  }) : super(key: key);

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _expanded = false;
  bool _isOverflow = false;

  bool _computeOverflow(double maxWidth) {
    if (widget.text.isEmpty) return false;
    final span = TextSpan(text: widget.text, style: widget.style);
    final tp = TextPainter(
      text: span,
      maxLines: widget.maxLines,
      textDirection: TextDirection.ltr,
      ellipsis: '…',
    );
    tp.layout(maxWidth: maxWidth);
    return tp.didExceedMaxLines;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final measuredOverflow = _computeOverflow(constraints.maxWidth);
        if (measuredOverflow != _isOverflow) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _isOverflow = measuredOverflow);
          });
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              style: widget.style,
              maxLines: _expanded ? null : widget.maxLines,
              overflow:
                  _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
            if (_isOverflow)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Text(
                    _expanded ? widget.lessLabel : widget.moreLabel,
                    style: widget.linkStyle,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Pill extends StatelessWidget {
  final Widget child;
  const _Pill({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
        ],
        border: Border.all(color: Colors.black12.withValues(alpha: 0.06)),
      ),
      child: child,
    );
  }
}

/* ========= Fullscreen Image Viewer (UI only; pinch to zoom) ========= */

class FullscreenImageView extends StatelessWidget {
  final String imageUrl;
  final String heroTag;
  const FullscreenImageView(
      {Key? key, required this.imageUrl, required this.heroTag})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final img = Image.network(
      imageUrl,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const Center(
        child: Icon(Icons.broken_image, size: 64, color: Colors.blueGrey),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Hero(
                tag: heroTag,
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 5.0,
                  panEnabled: true,
                  child: img,
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ===================================== PAGE ===================================== */

class _ThoughtDetailsState extends State<ThoughtDetails> {
  Map<String, dynamic>? thought;
  List<dynamic> comments = [];

  TextEditingController commentController = TextEditingController();

  String? currentUserId;
  String? editingCommentId;
  final TextEditingController editingController = TextEditingController();

  // NEW: current user's profile photo (from local prefs if available; optional)
  String _currentUserPhoto = '';

  // Pagination state for comments
  int _commentsPage = 0; // 0 = not loaded yet
  final int _commentsPageSize = 10;
  bool _commentsLoading = false;
  bool _commentsHasMore = true; // assume more until empty page arrives

  late final ScrollController _commentsScrollController;

  @override
  void initState() {
    super.initState();
    _commentsScrollController = ScrollController();
    _commentsScrollController.addListener(_onCommentsScroll);

    Config.getLoggedInUser().then((id) async {
      setState(() => currentUserId = id);

      //Load optional photo URL from SharedPreferences (UI-only; no backend change)
      // try {
      //   final prefs = await SharedPreferences.getInstance();
      //   final photo = prefs.getString('user_photo'); // if your app saves it
      //   if (mounted) setState(() => _currentUserPhoto = photo);
      // } catch (_) {
      //   // ignore if not available
      // }

      fetchThought();
      fetchComments(page: 1); // load first page
      increaseThoughtView(); // ← unchanged logic
    });
  }

  @override
  void dispose() {
    _commentsScrollController.removeListener(_onCommentsScroll);
    _commentsScrollController.dispose();
    commentController.dispose();
    editingController.dispose();
    super.dispose();
  }

  void _onCommentsScroll() {
    try {
      if (!_commentsHasMore) return;
      if (_commentsLoading) return;
      if (!_commentsScrollController.hasClients) return;

      final pos = _commentsScrollController.position;
      // threshold: 200 pixels from bottom
      if (pos.pixels >= pos.maxScrollExtent - 200) {
        _loadMoreComments();
      }
    } catch (e) {
      // ignore scroll errors
    }
  }

  /* -------------------- Backend calls (UNCHANGED) -------------------- */

  Future<void> fetchThought() async {
    final res =
        await Config.apiGet('/get_thought?des_id=${widget.desId}', context);
    if (res != null && res.statusCode == 200) {
      final data = json.decode(res.body);
      setState(() => thought = data['thought']);
    }
  }

  // Modified fetchComments with pagination. Call fetchComments(page: 1) to reset.
  Future<void> fetchComments({required int page}) async {
    if (_commentsLoading) return;
    _commentsLoading = true;
    setState(() {});

    final uri =
        '/get_thought_comments?des_id=${widget.desId}&page=$page&page_size=$_commentsPageSize';
    // print the full URL so you can confirm which page is requested
    print('Fetching comments: ${uri.toString()}');

    try {
      final res = await Config.apiGet(uri, context);
      if (res != null && res.statusCode == 200) {
        final data = json.decode(res.body);
        final List<dynamic> newComments =
            (data['comments'] ?? []) as List<dynamic>;

        if (page == 1) {
          // first page — replace
          comments = newComments;
        } else {
          // append
          comments = [...comments, ...newComments];
        }

        // update page and hasMore
        _commentsPage = page;
        if (newComments.isEmpty || newComments.length < _commentsPageSize) {
          _commentsHasMore = false;
        } else {
          _commentsHasMore = true;
        }
      } else {
        debugPrint(
            'Failed to load comments: ${res?.statusCode ?? 'No response'}');
      }
    } catch (e) {
      debugPrint('Error fetching comments page $page: $e');
    } finally {
      _commentsLoading = false;
      setState(() {});
    }
  }

  // convenience method to load next page
  Future<void> _loadMoreComments() async {
    if (!_commentsHasMore) return;
    final nextPage = (_commentsPage == 0) ? 1 : _commentsPage + 1;
    await fetchComments(page: nextPage);
  }

  // Optionally call this after posting a new comment to refresh first page
  Future<void> _refreshComments() async {
    _commentsHasMore = true;
    await fetchComments(page: 1);
  }

  Future<void> increaseThoughtView() async {
    await Config.apiPost(
      '/increase_thought_view',
      {'des_id': widget.desId, 'user_id': currentUserId},
      context,
    );
  }

  // Accept optional commentId (edit/new) — UNCHANGED
  Future<bool> submitComment(String text, {String? commentId}) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId == null) return false;

    final payload = {
      'com_text': text,
      'com_user_id': userId,
      'des_id': widget.desId.toString(),
      if (commentId != null) 'com_id': commentId,
    };

    final res = await Config.apiPost("/submit_thought", payload, context);
    if (res != null && (res.statusCode == 201 || res.statusCode == 200)) {
      commentController.clear();
      setState(() => editingCommentId = null);
      fetchComments(page: 1);
      fetchThought();
      return true;
    }
    return false;
  }

  Future<void> submitCommentAndShowNew(String text, {String? commentId}) async {
    // Optionally disable input or show a loading indicator here
    // Submit comment (your existing submitComment should return true on success)
    bool ok = false;
    try {
      final result = await submitComment(text, commentId: commentId);
      // If submitComment returns bool
      if (result is bool) {
        ok = result;
      } else {
        // If your submitComment doesn't return bool, treat HTTP 200/201 as success by parsing response
        // Try to parse response if submitComment returned the http.Response
        ok = true; // fallback assume success
      }
    } catch (e) {
      ok = false;
    }

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not post comment. Please try again.')),
      );
      return;
    }

    // Clear input and dismiss keyboard
    commentController.clear();
    FocusScope.of(context).unfocus();

    // Reset pagination state so we reload from page 1
    _commentsPage = 0;
    _commentsHasMore = true;

    // Reload first page (server authoritative)
    await fetchComments(page: 1);

    // Optionally refresh other data (counts)
    // await fetchThought();

    // Wait briefly for list to rebuild, then animate to top so new comment is visible
    await Future.delayed(const Duration(milliseconds: 80));
    if (_commentsScrollController.hasClients) {
      _commentsScrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  /* -------------------- UI helpers -------------------- */

  // Reusable avatar with optional full-screen preview
  Widget _avatarWithPreview(String? url,
      {double radius = 26, String? heroTag}) {
    final hasUrl = (url?.isNotEmpty ?? false);

    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: hasUrl ? Colors.grey.shade200 : Colors.blueGrey.shade300,
      backgroundImage: hasUrl ? NetworkImage(url!) : null,
      child: hasUrl ? null : const Icon(Icons.person, color: Colors.white),
    );

    if (!hasUrl) return avatar;

    final tag = heroTag ?? 'avatar-${url.hashCode}-${radius.toString()}';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) =>
                FullscreenImageView(imageUrl: url!, heroTag: tag),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
          ),
        );
      },
      child: Hero(tag: tag, child: avatar),
    );
  }

  Widget _buildAvatar(String? url, {double radius = 26}) {
    // kept for existing usage (no logic change), now calls the new preview-enabled one
    return _avatarWithPreview(url, radius: radius);
  }

  Widget _headerCard(BuildContext context) {
    if (thought == null) return const SizedBox.shrink();

    final userPhoto = thought!["user_photo"]?.toString() ?? '';
    final userName = thought!["user_name"]?.toString() ?? 'User';
    final catName = thought!["cat_name"]?.toString() ?? '';

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        final int serviceId = thought!['service_id'] as int? ?? 0;
        final int shopId = thought!['shop_id'] as int? ?? 0;
        final String userId = thought!['user_id'].toString();

        late final Map<String, String> additionalData;
        late final bool isService;
        late final String targetId;

        if (serviceId != 0) {
          isService = true;
          targetId = serviceId.toString();
          additionalData = {'service_id': targetId};
        } else if (shopId != 0) {
          isService = false;
          targetId = shopId.toString();
          additionalData = {'shop_id': targetId};
        } else {
          isService = false;
          targetId = userId;
          additionalData = {'user_only': targetId};
        }

        Navigator.push(
          context,
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
      child: Container(
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(
    gradient: const LinearGradient(
      colors: [
        Color(0xFFFFFFFF),
        Colors.lightBlue, // soft off-white
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(30),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.06),
        blurRadius: 14,
        offset: const Offset(0, 8),
      ),
    ],
    border: Border.all(
      color: Colors.grey.withValues(alpha: 0.12),
    ),
  ),
  child: Row(
    children: [
      _buildAvatar(userPhoto, radius: 28),
      const SizedBox(width: 14),
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
                fontSize: 16,
                color: Color(0xFF111827), // rich dark
              ),
            ),
            const SizedBox(height: 4),
            Text(
              catName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: const Color(0xFF1A56DB),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.chevron_right,
          size: 20,
          color: Colors.black45,
        ),
      ),
    ],
  ),
),

    );
  }

  Widget _thoughtImage() {
    final url = thought!["des_photo"]?.toString() ?? '';
    if (url.isEmpty) return const SizedBox.shrink();

    final tag = 'thought-image-${url.hashCode}';

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) =>
                  FullscreenImageView(imageUrl: url, heroTag: tag),
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
            ),
          );
        },
        child: Hero(
          tag: tag,
          child: Image.network(
            url,
            width: double.infinity,
            height: 220,
            fit: BoxFit.cover,
            errorBuilder: (ctx, err, st) => Container(
              height: 200,
              alignment: Alignment.center,
              color: Colors.grey.shade200,
              child: const Icon(Icons.broken_image, color: Colors.grey),
            ),
          ),
        ),
      ),
    );
  }

  Widget _descriptionCard() {
    final text = (thought!["des"] ?? '').toString();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        //border: Border.all(color: Colors.black12.withValues(alpha: 0.05)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ExpandableText(
        text: text,
        maxLines: 5,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
          height: 1.5,
        ),
        moreLabel: 'See more',
        lessLabel: 'See less',
        linkStyle: const TextStyle(
          fontSize: 14,
          color: Colors.blue,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _statsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _Pill(
          child: Row(
            children: [
              const Icon(Icons.remove_red_eye, size: 18, color: Colors.blueGrey),
              const SizedBox(width: 6),
              Text(
                Config.formatLargeNumber(thought!['des_view'] ?? 0),
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
        _Pill(
          child: Row(
            children: [
              const Icon(Icons.comment, size: 18, color: Colors.blueGrey),
              const SizedBox(width: 6),
              Text(
                Config.formatLargeNumber(thought!['des_com'] ?? 0),
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
        _Pill(
          child: Row(
            children: [
              const Icon(Icons.access_time, size: 18, color: Colors.blueGrey),
              const SizedBox(width: 6),
              Text(
                Config.getTimeDifference(thought!["time"]),
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Builds each comment, with inline edit for the author (UI only)
  Widget _buildComment(dynamic comment) {
    final comId = comment['com_id'].toString();
    final comUserId = comment['user_id'].toString();
    final isOwn = comUserId == currentUserId;
    final isEditing = editingCommentId == comId;

    // —— EDIT MODE —— (UI only)
    if (isEditing) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.blue.shade100,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade100.withValues(alpha: 0.5),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Text Field
          TextField(
            controller: editingController,
            maxLines: null,
            decoration: InputDecoration(
              hintText: 'Edit your comment',
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => setState(() => editingCommentId = null),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blueGrey,
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  submitComment(
                    editingController.text.trim(),
                    commentId: comId,
                  );
                  _refreshComments();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A56DB),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}


    // —— READ-ONLY MODE —— (UI only)
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(18),
        
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          final serviceId = comment["service_id"];
          final shopId = comment["shop_id"];
          final userId = comment["user_id"].toString();

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
                isService: comment["is_service"] ?? false,
                advertData: AdvertData(
                  userId: userId,
                  isService: comment["is_service"] ?? false,
                  additionalData: additionalData,
                ),
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Avatar with FULLSCREEN preview on tap
                  _avatarWithPreview(
                    comment['photo'],
                    radius: 24,
                    heroTag:
                        'comment-avatar-${comment['photo']}-${comment['com_id']}',
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          comment['commenter_name'] ?? 'Anonymous',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          comment['cat_name'] ?? '',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.blueAccent,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    // Time chip
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        Config.getTimeDifference(comment['com_time'] ?? ''),
        style: TextStyle(
          fontSize: 11,
          color: Colors.grey.shade600,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),

    if (isOwn) ...[
      const SizedBox(width: 8),

      // Edit button
      InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          setState(() {
            editingCommentId = comId;
            editingController.text = comment['com_text'] ?? '';
          });
        },
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.edit_rounded,
            size: 16,
            color: const Color(0xFF1A56DB),
          ),
        ),
      ),
    ],
  ],
)

                ],
              ),
              const SizedBox(height: 8),
              // Body
              ExpandableText(
                text: (comment['com_text'] ?? '').toString(),
                maxLines: 3,
                style: const TextStyle(fontSize: 14, height: 1.4),
                moreLabel: 'See more',
                lessLabel: 'See less',
                linkStyle: const TextStyle(
                  fontSize: 13,
                  color: Colors.blue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // NEW: Small row to show the current commenter avatar before the input
  Widget _commenterAvatarRow() {
    return Row(
      children: [
        // _avatarWithPreview(
        //   _currentUserPhoto,
        //   radius: 30,
        //   heroTag: 'current-user-avatar-${_currentUserPhoto ?? 'placeholder'}',
        // ),
        const SizedBox(width: 10),
        Expanded(
          child: _commentInput(), // keep your original input here
        ),
      ],
    );
  }

  Widget _commentInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
        border: Border.all(color: Colors.blue.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: TextField(
        controller: commentController,
        decoration: InputDecoration(
          hintText: "Write a comment...",
          
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          suffixIcon: IconButton(
            icon: const Icon(Icons.send, color: Colors.blueAccent),
            onPressed: () async {
              final text = commentController.text.trim();
              if (text.isEmpty) return;
              // call helper to submit and show newly created comment
              await submitCommentAndShowNew(text);
            },
          ),
        ),
        maxLines: null,
        textInputAction: TextInputAction.newline,
      ),
    );
  }

  /* -------------------- Build -------------------- */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FA),
      appBar: AppBar(
        title: const Text("Discussion Details"),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFEAEDF2)),
        ),
      ),

      body: thought == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _headerCard(context),
                  const SizedBox(height: 12),
                  if ((thought!["des_photo"]?.toString().isNotEmpty ?? false))
                    _thoughtImage(),
                  if ((thought!["des_photo"]?.toString().isNotEmpty ?? false))
                    const SizedBox(height: 12),
                  _descriptionCard(),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 10)
                      ],
                      border:
                          Border.all(color: Colors.black12.withValues(alpha: 0.05)),
                    ),
                    child: _statsRow(),
                  ),
                  const SizedBox(height: 10),

                  // ====== NEW: Commenter avatar + input combined row ======
                  _commenterAvatarRow(),
                  // ========================================================

                  const SizedBox(height: 8),

                  // COMMENTS SECTION (paginated, auto-load)
                  SizedBox(
                    // give a fixed height for comment area so inner ListView can scroll
                    // you can adjust this height or compute dynamically
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: _buildCommentsList(),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  // Builds the scrollable comments list with auto-loading
  Widget _buildCommentsList() {
    if (_commentsLoading && comments.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (comments.isEmpty) {
      return SingleChildScrollView(
  physics: const AlwaysScrollableScrollPhysics(),
  child: Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.blue.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.shade100.withValues(alpha: 0.5),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 34,
                color: const Color(0xFF1A56DB),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "No comments yet",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Be the first to comment and start the discussion!",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () => fetchComments(page: 1),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text(
                "Refresh",
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A56DB),
                foregroundColor: Colors.white,
                elevation: 2,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);

    }

    return NotificationListener<ScrollNotification>(
      onNotification: (scrollInfo) {
        // additional safety: if user scrolls (e.g., via single child scroll), trigger load
        if (!_commentsHasMore || _commentsLoading) return false;
        if (scrollInfo.metrics.pixels >=
            scrollInfo.metrics.maxScrollExtent - 200) {
          _loadMoreComments();
        }
        return false;
      },
      child: ListView.builder(
        controller: _commentsScrollController,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        itemCount: comments.length + (_commentsHasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index < comments.length) {
            final c = comments[index];
            return _buildComment(c);
          } else {
            // bottom loader
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: _commentsLoading
                    ? const CircularProgressIndicator()
                    : const SizedBox.shrink(),
              ),
            );
          }
        },
      ),
    );
  }
}
