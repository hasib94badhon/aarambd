import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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

  // Same per-category color/icon system used by description_landing_page.dart's
  // feed and thoughtsection.dart's composer, so a post carries its color
  // through from feed → detail instead of falling back to plain blue.
  CatTheme get _theme =>
      themeFor((thought?['des_cat_id'] as num?)?.toInt());

  TextEditingController commentController = TextEditingController();
  final FocusNode _commentFocus = FocusNode();
  bool _commentFieldFocused = false;

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
    _commentFocus.addListener(() {
      if (mounted) setState(() => _commentFieldFocused = _commentFocus.hasFocus);
    });

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
    _commentFocus.dispose();
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
      showAppToast(context, 'Could not post comment. Please try again.',
          icon: Icons.error_outline_rounded);
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

  Color _darken(Color c, [double amount = 0.16]) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
  }

  void _openPosterProfile() {
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
                    child: _buildAvatar(userPhoto, radius: 24),
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

  // ─── Content card: full-width image + description ───────────────────────
  Widget _buildContentCard() {
    final hasImage =
        (thought!["des_photo"]?.toString().isNotEmpty ?? false);
    final text = (thought!["des"] ?? '').toString();
    if (!hasImage && text.isEmpty) return const SizedBox.shrink();

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
                  pageBuilder: (_, __, ___) => FullscreenImageView(
                      imageUrl: imageUrl, heroTag: heroTag),
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
            Config.formatLargeNumber(thought!['des_view'] ?? 0),
            'views',
            const Color(0xFF3B82F6),
          ),
          const SizedBox(width: 10),
          _statChip(
            Icons.chat_bubble_outline_rounded,
            Config.formatLargeNumber(thought!['des_com'] ?? 0),
            'comments',
            const Color(0xFF10B981),
          ),
          const Spacer(),
          Row(
            children: [
              const Icon(Icons.access_time_rounded,
                  size: 13, color: Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Text(
                Config.getTimeDifference(thought!["time"]),
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

  Widget _statChip(
      IconData icon, String value, String label, Color color) {
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

  // ─── Individual comment card ──────────────────────────────────────────────
  Widget _buildComment(dynamic comment) {
    final comId = comment['com_id'].toString();
    final comUserId = comment['user_id'].toString();
    final isOwn = comUserId == currentUserId;
    final isEditing = editingCommentId == comId;

    // Edit mode
    if (isEditing) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _theme.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _theme.primary.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: _theme.primary.withValues(alpha: 0.14),
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
                  hintText: 'Edit your comment',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
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
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () =>
                        setState(() => editingCommentId = null),
                    style: TextButton.styleFrom(
                        foregroundColor: Colors.blueGrey),
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
          padding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: _theme.primary.withValues(alpha: 0.22)),
                    ),
                    child: _avatarWithPreview(
                      comment['photo'],
                      radius: 20,
                      heroTag:
                          'comment-avatar-${comment['photo']}-${comment['com_id']}',
                    ),
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
                              fontSize: 14,
                              color: Color(0xFF111827)),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if ((comment['cat_name'] ?? '').isNotEmpty)
                          Text(
                            comment['cat_name'],
                            style: TextStyle(
                                fontSize: 12,
                                color: _theme.primary,
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
                          Config.getTimeDifference(
                              comment['com_time'] ?? ''),
                          style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500),
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
                                  comment['com_text'] ?? '';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: _theme.primary.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.edit_rounded,
                                size: 15, color: _theme.primary),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ExpandableText(
                text: (comment['com_text'] ?? '').toString(),
                maxLines: 3,
                style: const TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: Color(0xFF374151)),
                moreLabel: 'See more',
                lessLabel: 'See less',
                linkStyle: TextStyle(
                    fontSize: 13,
                    color: _theme.primary,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Fixed bottom comment input ───────────────────────────────────────────
  Widget _buildCommentBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: commentController,
                  focusNode: _commentFocus,
                  decoration: const InputDecoration(
                    hintText: 'Share your thoughts...',
                    hintStyle: TextStyle(
                        color: Color(0xFF94A3B8), fontSize: 14),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
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
                await submitCommentAndShowNew(text);
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
    );
  }

  /* -------------------- Build -------------------- */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      resizeToAvoidBottomInset: true,
      bottomNavigationBar: thought != null ? _buildCommentBar() : null,
      body: thought == null
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1A56DB)))
          : NotificationListener<ScrollNotification>(
              onNotification: (info) {
                if (_commentsHasMore &&
                    !_commentsLoading &&
                    info.metrics.pixels >=
                        info.metrics.maxScrollExtent - 200) {
                  _loadMoreComments();
                }
                return false;
              },
              child: CustomScrollView(
                controller: _commentsScrollController,
                slivers: [
                  // Themed gradient hero: back button + poster info
                  SliverToBoxAdapter(child: _buildHeroHeader(context)),

                  // Post content (image + description)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                      child: _buildContentCard(),
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
                          child: CircularProgressIndicator(
                              color: _theme.primary),
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
                              padding:
                                  const EdgeInsets.fromLTRB(14, 0, 14, 8),
                              child: _buildComment(comments[i]),
                            );
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
                        childCount:
                            comments.length + (_commentsHasMore ? 1 : 0),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            ),

    );
  }
}
