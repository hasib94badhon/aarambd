import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aaram_bd/config.dart';
import 'package:aaram_bd/screens/advert_screen.dart';
import 'package:aaram_bd/widgets/app_toast.dart';
import 'package:aaram_bd/widgets/thoughtsection.dart' show CatTheme, themeFor;

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

/* ========= Shared helpers used by both the post page and the comment sheet ========= */

Widget avatarWithPreview(BuildContext context, String? url,
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

// Opens AdvertScreen for a service/shop/user profile — shared by the poster
// header, the comments button's poster, and each comment bubble's author.
void openProfileForEntity(
  BuildContext context, {
  required String userId,
  dynamic serviceId,
  dynamic shopId,
  bool isService = false,
}) {
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
      builder: (_) => AdvertScreen(
        userId: userId,
        isService: isService,
        advertData: AdvertData(
          userId: userId,
          isService: isService,
          additionalData: additionalData,
        ),
      ),
    ),
  );
}

/* ===================================== PAGE ===================================== */

class _ThoughtDetailsState extends State<ThoughtDetails> {
  Map<String, dynamic>? thought;
  String? currentUserId;

  // Same per-category color/icon system used by description_landing_page.dart's
  // feed and thoughtsection.dart's composer, so a post carries its color
  // through from feed → detail instead of falling back to plain blue.
  CatTheme get _theme => themeFor((thought?['des_cat_id'] as num?)?.toInt());

  @override
  void initState() {
    super.initState();
    Config.getLoggedInUser().then((id) {
      setState(() => currentUserId = id);
      fetchThought();
      increaseThoughtView();
    });
  }

  /* -------------------- Backend calls (UNCHANGED) -------------------- */

  Future<void> fetchThought() async {
    final res =
        await Config.apiGet('/get_thought?des_id=${widget.desId}', context);
    if (res != null && res.statusCode == 200) {
      final data = json.decode(res.body);
      if (mounted) setState(() => thought = data['thought']);
    }
  }

  Future<void> increaseThoughtView() async {
    await Config.apiPost(
      '/increase_thought_view',
      {'des_id': widget.desId, 'user_id': currentUserId},
      context,
    );
  }

  /* -------------------- UI helpers -------------------- */

  Color _darken(Color c, [double amount = 0.16]) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }

  void _openPosterProfile() {
    openProfileForEntity(
      context,
      userId: thought!['user_id'].toString(),
      serviceId: thought!['service_id'],
      shopId: thought!['shop_id'],
      isService: (thought!['service_id'] as int? ?? 0) != 0,
    );
  }

  void _openCommentsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentChatSheet(
        desId: widget.desId,
        theme: _theme,
        currentUserId: currentUserId,
        onCommentsChanged: fetchThought,
      ),
    );
  }

  // ─── Hero header: back button + poster info on a themed gradient ─────────
  Widget _buildHeroHeader(BuildContext context) {
    if (thought == null) return const SizedBox.shrink();

    final userPhoto = thought!["user_photo"]?.toString() ?? '';
    final userName = thought!["user_name"]?.toString() ?? 'User';
    final catName = thought!["cat_name"]?.toString() ?? '';
    final t = _theme;

    return Container(
      padding: EdgeInsets.fromLTRB(
          14, MediaQuery.of(context).padding.top + 12, 14, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_darken(t.primary), t.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(26),
          bottomRight: Radius.circular(26),
        ),
        boxShadow: [
          BoxShadow(
            color: t.primary.withValues(alpha: 0.30),
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
                    child: avatarWithPreview(context, userPhoto, radius: 24),
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
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            if (catName.isNotEmpty) ...[
                              Flexible(
                                child: Text(
                                  catName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.78),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(t.emoji,
                                        style: const TextStyle(fontSize: 9.5)),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                        t.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
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

  // ─── Content card: full-width image + description + views/time footer ────
  Widget _buildContentCard() {
    final hasImage = (thought!["des_photo"]?.toString().isNotEmpty ?? false);
    final text = (thought!["des"] ?? '').toString();
    final imageUrl = hasImage ? thought!["des_photo"].toString() : '';
    final heroTag = 'thought-image-${imageUrl.hashCode}';

    return Container(
      margin: const EdgeInsets.only(top: 5),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border(left: BorderSide(color: _theme.primary, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasImage)
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) =>
                      FullscreenImageView(imageUrl: imageUrl, heroTag: heroTag),
                  transitionsBuilder: (_, anim, __, child) =>
                      FadeTransition(opacity: anim, child: child),
                ),
              ),
              child: Hero(
                tag: heroTag,
                child: Image.network(
                  imageUrl,
                  width: double.infinity,
                  height: 220,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, err, st) => Container(
                    height: 180,
                    alignment: Alignment.center,
                    color: Colors.grey.shade100,
                    child: const Icon(Icons.broken_image,
                        color: Colors.grey, size: 48),
                  ),
                ),
              ),
            ),
          if (text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: ExpandableText(
                text: text,
                maxLines: 6,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A2340),
                  height: 1.6,
                ),
                moreLabel: 'Read more',
                lessLabel: 'Show less',
                linkStyle: TextStyle(
                  fontSize: 13,
                  color: _theme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Divider(
              height: 1,
              thickness: 1,
              color: Colors.grey.shade100,
              indent: 16,
              endIndent: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Row(
              children: [
                Icon(Icons.visibility_outlined,
                    size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 5),
                Text(
                  '${Config.formatLargeNumber(thought!['des_view'] ?? 0)} views',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Icon(Icons.access_time_rounded,
                    size: 13, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  Config.getTimeDifference(thought!["time"]),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Button that opens the comment chat as a modal sheet ─────────────────
  Widget _buildCommentsButton() {
    final commentsRaw = thought!['des_com'];
    final count = commentsRaw is num
        ? commentsRaw.toInt()
        : int.tryParse('$commentsRaw') ?? 0;

    return InkWell(
      onTap: _openCommentsSheet,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: _theme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.chat_bubble_rounded,
                  color: _theme.primary, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    count > 0
                        ? '$count ${count == 1 ? 'Comment' : 'Comments'}'
                        : 'No comments yet',
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    count > 0
                        ? 'Tap to join the conversation'
                        : 'Be the first to comment',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 13, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  /* -------------------- Build -------------------- */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: thought == null
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1A56DB)))
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeroHeader(context),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                    child: Column(
                      children: [
                        _buildContentCard(),
                        const SizedBox(height: 12),
                        _buildCommentsButton(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/* ============================= COMMENT CHAT SHEET ============================= */
// A modal bottom sheet holding the full chat-style comment thread: newest at
// the bottom, older comments load as you scroll up, tap/long-press a bubble
// to quote-reply to it. Fully self-contained — the parent page only needs to
// know when to refresh its comment count (onCommentsChanged).

class _CommentChatSheet extends StatefulWidget {
  final String desId;
  final CatTheme theme;
  final String? currentUserId;
  final VoidCallback onCommentsChanged;

  const _CommentChatSheet({
    required this.desId,
    required this.theme,
    required this.currentUserId,
    required this.onCommentsChanged,
  });

  @override
  State<_CommentChatSheet> createState() => _CommentChatSheetState();
}

class _CommentChatSheetState extends State<_CommentChatSheet> {
  List<dynamic> comments = [];
  bool _initialLoading = true;

  final TextEditingController commentController = TextEditingController();
  final FocusNode _commentFocus = FocusNode();
  bool _commentFieldFocused = false;

  String? editingCommentId;
  final TextEditingController editingController = TextEditingController();

  String? _replyToId;
  String? _replyToAuthor;
  String? _replyToText;

  int _commentsPage = 0;
  final int _commentsPageSize = 10;
  bool _commentsLoading = false;
  bool _commentsHasMore = true;

  late final ScrollController _commentsScrollController;

  CatTheme get _theme => widget.theme;

  @override
  void initState() {
    super.initState();
    _commentsScrollController = ScrollController();
    _commentsScrollController.addListener(_onCommentsScroll);
    _commentFocus.addListener(() {
      if (mounted)
        setState(() => _commentFieldFocused = _commentFocus.hasFocus);
    });
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    await fetchComments(page: 1);
    if (mounted) setState(() => _initialLoading = false);
  }

  @override
  void dispose() {
    _commentsScrollController.removeListener(_onCommentsScroll);
    _commentsScrollController.dispose();
    commentController.dispose();
    editingController.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  void _onCommentsScroll() {
    try {
      if (!_commentsHasMore) return;
      if (_commentsLoading) return;
      if (!_commentsScrollController.hasClients) return;

      final pos = _commentsScrollController.position;
      if (pos.pixels >= pos.maxScrollExtent - 200) {
        _loadMoreComments();
      }
    } catch (e) {
      // ignore scroll errors
    }
  }

  Future<void> fetchComments({required int page}) async {
    if (_commentsLoading) return;
    _commentsLoading = true;
    if (mounted) setState(() {});

    final uri =
        '/get_thought_comments?des_id=${widget.desId}&page=$page&page_size=$_commentsPageSize';

    try {
      final res = await Config.apiGet(uri, context);
      if (res != null && res.statusCode == 200) {
        final data = json.decode(res.body);
        final List<dynamic> newComments =
            (data['comments'] ?? []) as List<dynamic>;

        if (page == 1) {
          comments = newComments;
        } else {
          comments = [...comments, ...newComments];
        }

        _commentsPage = page;
        _commentsHasMore =
            !(newComments.isEmpty || newComments.length < _commentsPageSize);
      } else {
        debugPrint(
            'Failed to load comments: ${res?.statusCode ?? 'No response'}');
      }
    } catch (e) {
      debugPrint('Error fetching comments page $page: $e');
    } finally {
      _commentsLoading = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _loadMoreComments() async {
    if (!_commentsHasMore) return;
    final nextPage = (_commentsPage == 0) ? 1 : _commentsPage + 1;
    await fetchComments(page: nextPage);
  }

  Future<void> _refreshComments() async {
    _commentsHasMore = true;
    await fetchComments(page: 1);
  }

  Future<bool> submitComment(String text,
      {String? commentId, String? replyToId}) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId == null) return false;

    final payload = {
      'com_text': text,
      'com_user_id': userId,
      'des_id': widget.desId.toString(),
      if (commentId != null) 'com_id': commentId,
      if (replyToId != null) 'reply_to_com_id': replyToId,
    };

    final res = await Config.apiPost("/submit_thought", payload, context);
    if (res != null && (res.statusCode == 201 || res.statusCode == 200)) {
      commentController.clear();
      if (mounted) setState(() => editingCommentId = null);
      fetchComments(page: 1);
      widget.onCommentsChanged();
      return true;
    }
    return false;
  }

  Future<void> submitCommentAndShowNew(String text,
      {String? commentId, String? replyToId}) async {
    bool ok = false;
    try {
      ok =
          await submitComment(text, commentId: commentId, replyToId: replyToId);
    } catch (e) {
      ok = false;
    }

    if (!ok) {
      if (mounted) {
        showAppToast(context, 'Could not post comment. Please try again.',
            icon: Icons.error_outline_rounded);
      }
      return;
    }

    commentController.clear();
    _cancelReply();
    if (mounted) FocusScope.of(context).unfocus();

    _commentsPage = 0;
    _commentsHasMore = true;
    await fetchComments(page: 1);

    // With the list reversed (newest at the bottom, like a chat), offset 0
    // IS the bottom, so this scrolls to reveal the just-sent message.
    await Future.delayed(const Duration(milliseconds: 80));
    if (_commentsScrollController.hasClients) {
      _commentsScrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

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

  void _startEdit(dynamic comment) {
    setState(() {
      editingCommentId = comment['com_id'].toString();
      editingController.text = (comment['com_text'] ?? '').toString();
    });
  }

  void _openCommenterProfile(dynamic comment) {
    openProfileForEntity(
      context,
      userId: comment['user_id'].toString(),
      serviceId: comment['service_id'],
      shopId: comment['shop_id'],
      isService: comment['is_service'] ?? false,
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
              child: Icon(Icons.chat_bubble_outline_rounded,
                  size: 34, color: _theme.primary),
            ),
            const SizedBox(height: 14),
            const Text('No comments yet',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827))),
            const SizedBox(height: 6),
            Text(
              'Be the first to share your thoughts!',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: Colors.grey.shade600, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Inline edit bubble ────────────────────────────────────────────────────
  Widget _buildEditBubble(String comId) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _theme.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _theme.primary.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: editingController,
              maxLines: null,
              decoration: InputDecoration(
                hintText: 'Edit your comment',
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
                  borderSide: BorderSide(color: _theme.primary, width: 1.6),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => setState(() => editingCommentId = null),
                  style: TextButton.styleFrom(foregroundColor: Colors.blueGrey),
                  child: const Text('Cancel',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    submitComment(editingController.text.trim(),
                        commentId: comId);
                    _refreshComments();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _theme.primary,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Save',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Chat bubble for a single comment, with optional quoted reply ────────
  Widget _buildChatBubble(dynamic comment) {
    final comId = comment['com_id'].toString();
    final comUserId = comment['user_id'].toString();
    final isOwn = comUserId == widget.currentUserId;

    if (editingCommentId == comId) return _buildEditBubble(comId);

    final replyText = (comment['reply_text'] ?? '').toString();
    final replyAuthor = (comment['reply_author_name'] ?? '').toString();
    final hasReply = comment['reply_to_com_id'] != null && replyText.isNotEmpty;

    final bubbleColor = isOwn ? _theme.primary : Colors.white;
    final textColor = isOwn ? Colors.white : const Color(0xFF1A2340);
    final align = isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final quoteBg =
        (isOwn ? Colors.white : _theme.primary).withValues(alpha: 0.12);
    final quoteAccent = isOwn ? Colors.white : _theme.primary;
    final quoteTextColor = isOwn ? Colors.white70 : Colors.black54;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Row(
            mainAxisAlignment:
                isOwn ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isOwn) ...[
                GestureDetector(
                  onTap: () => _openCommenterProfile(comment),
                  child: avatarWithPreview(
                    context,
                    comment['photo'],
                    radius: 15,
                    heroTag:
                        'comment-avatar-${comment['photo']}-${comment['com_id']}',
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment: align,
                  children: [
                    if (!isOwn)
                      Padding(
                        padding: const EdgeInsets.only(left: 11, bottom: 2),
                        child: Text(
                          comment['commenter_name'] ?? 'Anonymous',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: _theme.primary,
                          ),
                        ),
                      ),
                    GestureDetector(
                      onTap: () => _openCommenterProfile(comment),
                      onLongPress: () => _startReply(comment),
                      child: Container(
                        constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.72),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 13, vertical: 9),
                        decoration: BoxDecoration(
                          color: bubbleColor,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(isOwn ? 16 : 4),
                            bottomRight: Radius.circular(isOwn ? 4 : 16),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (hasReply)
                              Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: quoteBg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border(
                                      left: BorderSide(
                                          color: quoteAccent, width: 3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      replyAuthor.isNotEmpty
                                          ? replyAuthor
                                          : 'Comment',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: quoteAccent,
                                      ),
                                    ),
                                    Text(
                                      replyText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 11.5,
                                          color: quoteTextColor),
                                    ),
                                  ],
                                ),
                              ),
                            Text(
                              (comment['com_text'] ?? '').toString(),
                              style: TextStyle(
                                  fontSize: 14.5,
                                  height: 1.4,
                                  color: textColor),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(
                top: 3, left: isOwn ? 0 : 39, right: isOwn ? 2 : 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  Config.getTimeDifference(comment['com_time'] ?? ''),
                  style: const TextStyle(
                      fontSize: 10.5,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _startReply(comment),
                  child: Icon(Icons.reply_rounded,
                      size: 13, color: Colors.grey.shade400),
                ),
                if (isOwn) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _startEdit(comment),
                    child: Icon(Icons.edit_rounded,
                        size: 12.5, color: Colors.grey.shade400),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Reply-preview strip + text field + send button ──────────────────────
  Widget _buildInputBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyToId != null)
              Container(
                margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _theme.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border(left: BorderSide(color: _theme.primary, width: 3)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Replying to ${_replyToAuthor ?? ''}',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _theme.primary),
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
                              ? _theme.primary
                              : const Color(0xFFE2E8F0),
                          width: _commentFieldFocused ? 1.6 : 1.0,
                        ),
                        boxShadow: _commentFieldFocused
                            ? [
                                BoxShadow(
                                  color: _theme.primary.withValues(alpha: 0.16),
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
                              ? 'Write a reply...'
                              : 'Share your thoughts...',
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
                      await submitCommentAndShowNew(text,
                          replyToId: _replyToId);
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _theme.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _theme.primary.withValues(alpha: 0.35),
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
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 100),
      padding: EdgeInsets.only(bottom: viewInsets),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF4F6FB),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 6, 8, 12),
              child: Row(
                children: [
                  Icon(Icons.chat_bubble_rounded,
                      color: _theme.primary, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'Comments',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827)),
                  ),
                  const Spacer(),
                  InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F6FB),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded,
                          size: 18, color: Color(0xFF6B7280)),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (info) {
                  if (_commentsHasMore &&
                      !_commentsLoading &&
                      info.metrics.pixels >=
                          info.metrics.maxScrollExtent - 200) {
                    _loadMoreComments();
                  }
                  return false;
                },
                child: _initialLoading
                    ? Center(
                        child: CircularProgressIndicator(color: _theme.primary))
                    : comments.isEmpty
                        ? _buildNoComments()
                        : ListView.builder(
                            controller: _commentsScrollController,
                            reverse: true,
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                            itemCount:
                                comments.length + (_commentsHasMore ? 1 : 0),
                            itemBuilder: (ctx, i) {
                              if (i < comments.length) {
                                return _buildChatBubble(comments[i]);
                              }
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                child: Center(
                                  child: _commentsLoading
                                      ? CircularProgressIndicator(
                                          color: _theme.primary,
                                          strokeWidth: 2.5,
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              );
                            },
                          ),
              ),
            ),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }
}
