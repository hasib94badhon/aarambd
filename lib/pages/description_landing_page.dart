import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:aaram_bd/config.dart';
import 'package:aaram_bd/screens/thoughtdetails.dart';
import 'package:aaram_bd/widgets/thoughtsection.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  ExpandableText
// ─────────────────────────────────────────────────────────────────────────────
class ExpandableText extends StatefulWidget {
  final String text;
  final int maxLines;
  final TextStyle? style;
  final TextStyle linkStyle;

  const ExpandableText({
    super.key,
    required this.text,
    this.maxLines = 3,
    this.style,
    this.linkStyle = const TextStyle(
        fontSize: 12.5,
        color: Color(0xFF1A56DB),
        fontWeight: FontWeight.w600),
  });

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _expanded = false;
  final Map<double, bool> _cache = {};

  bool _overflows(double w) => _cache.putIfAbsent(w, () {
        final tp = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          maxLines: widget.maxLines,
          textDirection: TextDirection.ltr,
          ellipsis: '…',
        )..layout(maxWidth: w);
        return tp.didExceedMaxLines;
      });

  @override
  void didUpdateWidget(ExpandableText o) {
    super.didUpdateWidget(o);
    if (o.text != widget.text || o.maxLines != widget.maxLines) {
      _cache.clear();
      _expanded = false;
    }
  }

  @override
  Widget build(BuildContext ctx) => LayoutBuilder(builder: (_, box) {
        final over = _overflows(box.maxWidth);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.text,
              style: widget.style,
              maxLines: _expanded ? null : widget.maxLines,
              overflow:
                  _expanded ? TextOverflow.visible : TextOverflow.ellipsis),
          if (over)
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                    _expanded ? 'কম দেখুন' : 'আরও দেখুন',
                    style: widget.linkStyle),
              ),
            ),
        ]);
      });
}

// ─────────────────────────────────────────────────────────────────────────────
//  DescriptionLandingPage
// ─────────────────────────────────────────────────────────────────────────────
class DescriptionLandingPage extends StatefulWidget {
  final VoidCallback? onLoaded;
  const DescriptionLandingPage({super.key, this.onLoaded});

  @override
  State<DescriptionLandingPage> createState() =>
      _DescriptionLandingPageState();
}

class _DescriptionLandingPageState extends State<DescriptionLandingPage>
    with SingleTickerProviderStateMixin {
  // ── data ─────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _categories = [];
  final Map<String, List> _posts = {};
  final Map<String, int> _page = {};
  final Map<String, bool> _loading = {};
  final Map<String, bool> _hasMore = {};
  final Map<String, ScrollController> _scrollCtrl = {};
  final Map<String, List<Map<String, dynamic>>> _subCats = {};

  String? _selectedCatId;
  String? _selectedSubCatId;
  bool _initialLoading = true;
  bool _didNotifyLoaded = false;

  // ── UI state ─────────────────────────────────────────────────────────────
  bool _popupOpen = false;
  late AnimationController _popupAnim;

  static const int    _pageSize = 10;
  static const Color  _bg       = Color(0xFFF2F5FB);
  static const Color  _navBg    = Color(0xFF0F1225);
  static const double _catBarH  = 62.0;
  static const double _stripH   = 74.0; // statusBar excluded; 10+52+12

  CatTheme get _theme => themeFor(int.tryParse(_selectedCatId ?? ''));

  String _key(String catId, [String? subId]) => '$catId::${subId ?? 'all'}';

  String get _selCatName {
    if (_selectedCatId == null) return '';
    return _categories
            .firstWhere(
                (c) => c['des_cat_id'].toString() == _selectedCatId,
                orElse: () => {})['des_cat_name']
            ?.toString() ??
        '';
  }

  // ─── lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _popupAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _init();
  }

  @override
  void dispose() {
    _popupAnim.dispose();
    for (final c in _scrollCtrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ─── popup control ────────────────────────────────────────────────────────

  void _openPopup() {
    if (_popupOpen) return;
    setState(() => _popupOpen = true);
    _popupAnim.forward();
  }

  void _closePopup() {
    _popupAnim.reverse().then((_) {
      if (mounted) setState(() => _popupOpen = false);
    });
  }

  void _onCatTap(String catId) {
    HapticFeedback.lightImpact();
    // Toggle popup if same cat tapped while open
    if (_selectedCatId == catId && _popupOpen) {
      _closePopup();
      return;
    }
    if (_selectedCatId != catId) {
      _selectCat(catId);
    } else {
      _fetchSubCats(catId);
    }
    _openPopup();
  }

  // ─── data loading ─────────────────────────────────────────────────────────

  Future<void> _init() async {
    try {
      final res = await Config.apiGet('/get_description_categories', context);
      if (!mounted) return;
      if (res != null && res.statusCode == 200) {
        final cats = List<Map<String, dynamic>>.from(
            (jsonDecode(res.body)['categories'] ?? []));
        _categories = cats;
        if (cats.isNotEmpty) {
          _selectedCatId = cats.first['des_cat_id'].toString();
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _initialLoading = false);
    _notifyLoaded();
    if (_selectedCatId != null) {
      _fetchSubCats(_selectedCatId!);
      await _load(_selectedCatId!, replace: true);
    }
  }

  void _notifyLoaded() {
    if (_didNotifyLoaded) return;
    _didNotifyLoaded = true;
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => mounted ? widget.onLoaded?.call() : null);
  }

  Future<void> _fetchSubCats(String catId) async {
    if (_subCats.containsKey(catId)) return;
    try {
      final res = await Config.apiGet(
          '/get_des_sub_categories?des_cat_id=$catId', context);
      if (!mounted) return;
      if (res != null && res.statusCode == 200) {
        setState(() => _subCats[catId] = List<Map<String, dynamic>>.from(
            jsonDecode(res.body)['sub_categories'] ?? []));
      } else {
        if (mounted) setState(() => _subCats[catId] = []);
      }
    } catch (_) {
      if (mounted) setState(() => _subCats[catId] = []);
    }
  }

  void _ensureKey(String key, String catId, String? subId) {
    _posts.putIfAbsent(key, () => []);
    _page.putIfAbsent(key, () => 0);
    _loading.putIfAbsent(key, () => false);
    _hasMore.putIfAbsent(key, () => true);
    if (!_scrollCtrl.containsKey(key)) {
      final ctrl = ScrollController();
      ctrl.addListener(() {
        if (!(_hasMore[key] ?? true)) return;
        if (_loading[key] == true) return;
        if (!ctrl.hasClients) return;
        if (ctrl.position.pixels >= ctrl.position.maxScrollExtent - 320) {
          _loadMore(catId, subId: subId);
        }
      });
      _scrollCtrl[key] = ctrl;
    }
  }

  Future<void> _load(String catId,
      {String? subId, bool replace = false}) async {
    final key = _key(catId, subId);
    _ensureKey(key, catId, subId);
    if (_loading[key] == true) return;
    _loading[key] = true;
    if (mounted) setState(() {});
    try {
      var uri =
          '/get_description_by_cat?des_cat_id=$catId&description_status=live&page=1&page_size=$_pageSize';
      if (subId != null) uri += '&des_sub_cat_id=$subId';
      final res = await Config.apiGet(uri, context);
      if (!mounted) return;
      if (res != null && res.statusCode == 200) {
        final items = List.from(jsonDecode(res.body)['descriptions'] ?? []);
        _posts[key] = replace ? items : [...(_posts[key] ?? []), ...items];
        _page[key] = 1;
        _hasMore[key] = items.length >= _pageSize;
      }
    } catch (_) {}
    if (mounted) {
      _loading[key] = false;
      setState(() {});
    }
  }

  Future<void> _loadMore(String catId, {String? subId}) async {
    final key = _key(catId, subId);
    if (!(_hasMore[key] ?? false)) return;
    if (_loading[key] == true) return;
    _loading[key] = true;
    if (mounted) setState(() {});
    try {
      final nextPage = (_page[key] ?? 1) + 1;
      var uri =
          '/get_description_by_cat?des_cat_id=$catId&description_status=live&page=$nextPage&page_size=$_pageSize';
      if (subId != null) uri += '&des_sub_cat_id=$subId';
      final res = await Config.apiGet(uri, context);
      if (!mounted) return;
      if (res != null && res.statusCode == 200) {
        final items = List.from(jsonDecode(res.body)['descriptions'] ?? []);
        _posts[key] = [...(_posts[key] ?? []), ...items];
        _page[key] = nextPage;
        _hasMore[key] = items.length >= _pageSize;
      }
    } catch (_) {}
    if (mounted) {
      _loading[key] = false;
      setState(() {});
    }
  }

  Future<void> _selectCat(String catId) async {
    if (_selectedCatId == catId) return;
    setState(() {
      _selectedCatId = catId;
      _selectedSubCatId = null;
    });
    _fetchSubCats(catId);
    final key = _key(catId);
    if ((_posts[key] ?? []).isEmpty) await _load(catId, replace: true);
  }

  Future<void> _selectSubCat(String? subId) async {
    if (_selectedSubCatId == subId) return;
    setState(() => _selectedSubCatId = subId);
    final catId = _selectedCatId!;
    final key = _key(catId, subId);
    if ((_posts[key] ?? []).isEmpty) {
      await _load(catId, subId: subId, replace: true);
    }
  }

  Future<void> _refresh() async {
    if (_selectedCatId == null) return;
    await _load(_selectedCatId!, subId: _selectedSubCatId, replace: true);
  }

  // ─── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final mq      = MediaQuery.of(context);
    final statusH = mq.padding.top;
    final safeB   = mq.padding.bottom;
    final topH    = statusH + _stripH;

    if (_initialLoading) {
      return Scaffold(
        backgroundColor: _navBg,
        body: Center(child: CircularProgressIndicator(color: Colors.white.withValues(alpha: 0.6), strokeWidth: 2)),
      );
    }

    final catId  = _selectedCatId;
    final t      = _theme;
    final key    = catId == null ? '' : _key(catId, _selectedSubCatId);
    final posts  = _posts[key] ?? [];
    final loading = _loading[key] ?? false;
    final hasMore = _hasMore[key] ?? false;
    final ctrl   = _scrollCtrl[key];

    final subCats      = catId == null ? <Map<String, dynamic>>[] : (_subCats[catId] ?? []);
    final subCatsReady = catId != null && _subCats.containsKey(catId);

    final popupSlide = CurvedAnimation(parent: _popupAnim, curve: Curves.easeOutCubic);

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // ── Feed ──────────────────────────────────────────────────────
          Positioned.fill(
            child: RefreshIndicator(
              onRefresh: _refresh,
              color: t.primary,
              displacement: topH + 16,
              child: _buildFeed(posts, loading, hasMore, ctrl, t, topH,
                  safeB + _catBarH + 8),
            ),
          ),

          // ── Popup backdrop ────────────────────────────────────────────
          if (_popupOpen)
            Positioned(
              top: topH, left: 0, right: 0,
              bottom: safeB + _catBarH,
              child: GestureDetector(
                onTap: _closePopup,
                behavior: HitTestBehavior.opaque,
                child: AnimatedBuilder(
                  animation: _popupAnim,
                  builder: (_, __) => Container(
                    color: Colors.black
                        .withValues(alpha: 0.28 * _popupAnim.value),
                  ),
                ),
              ),
            ),

          // ── Sub-cat popup ─────────────────────────────────────────────
          if (_popupOpen && catId != null)
            Positioned(
              bottom: safeB + _catBarH,
              left: 0,
              right: 0,
              child: SlideTransition(
                position: Tween(
                        begin: const Offset(0, 1), end: Offset.zero)
                    .animate(popupSlide),
                child: _SubCatPopup(
                  subCats: subCats,
                  loading: !subCatsReady,
                  selectedSubCatId: _selectedSubCatId,
                  catName: _selCatName,
                  theme: t,
                  onSelect: (id) {
                    _selectSubCat(id);
                    _closePopup();
                  },
                  onClose: _closePopup,
                ),
              ),
            ),

          // ── Post prompt bar (replaces header) ────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: _PostPromptBar(
              statusH: statusH,
              onTap: catId == null
                  ? null
                  : () {
                      HapticFeedback.mediumImpact();
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  NeedBuilderPage(initialCatId: catId)));
                    },
            ),
          ),

          // ── Bottom category bar ───────────────────────────────────────
          Positioned(
            bottom: safeB, left: 0, right: 0, height: _catBarH,
            child: _CatBar(
              categories: _categories,
              selectedCatId: _selectedCatId,
              onSelect: _onCatTap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeed(List posts, bool loading, bool hasMore,
      ScrollController? ctrl, CatTheme t, double topPad, double bottomPad) {
    if (loading && posts.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(top: topPad + 16, bottom: bottomPad),
        children: [
          const SizedBox(height: 60),
          Center(
              child: CircularProgressIndicator(
                  color: t.primary, strokeWidth: 2.5)),
        ],
      );
    }
    if (!loading && posts.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20, topPad + 40, 20, bottomPad),
        children: [
          Column(children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                  color: t.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle),
              child: Icon(t.icon, color: t.primary, size: 30),
            ),
            const SizedBox(height: 16),
            const Text('এখানে এখনো কোনো পোস্ট নেই',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700,
                    color: Color(0xFF1A2340))),
            const SizedBox(height: 8),
            Text('উপরের "পোস্ট করুন" বোতামে চাপুন।',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.black.withValues(alpha: 0.38))),
          ]),
        ],
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      controller: ctrl,
      padding: EdgeInsets.fromLTRB(12, topPad + 12, 12, bottomPad),
      itemCount: posts.length + (hasMore ? 1 : 0),
      itemBuilder: (_, i) {
        if (i < posts.length) {
          return _PostCard(item: posts[i] as Map, theme: t);
        }
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: loading
              ? Center(
                  child: SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          color: t.primary, strokeWidth: 2)))
              : const SizedBox.shrink(),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Post prompt bar — the entry point into AaramBD's AI posting assistant
//  (NeedBuilderPage / thoughtsection.dart): tell it what you need, in any
//  words, and it helps turn that into a proper post. Styled to read as an
//  "AI assistant" trigger, not a plain fake textfield.
// ─────────────────────────────────────────────────────────────────────────────
class _PostPromptBar extends StatefulWidget {
  final double statusH;
  final VoidCallback? onTap;

  const _PostPromptBar({required this.statusH, this.onTap});

  @override
  State<_PostPromptBar> createState() => _PostPromptBarState();
}

class _PostPromptBarState extends State<_PostPromptBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  static const _aiColors = [
    Color(0xFF4F46E5), // indigo
    Color(0xFF7C3AED), // violet
    Color(0xFFDB2777), // pink
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(14, widget.statusH + 10, 14, 0),
      child: AnimatedBuilder(
        animation: _pulseCtrl,
        builder: (context, child) {
          final glow = 0.35 + (_pulseCtrl.value * 0.25);
          return GestureDetector(
            onTap: widget.onTap,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: _aiColors,
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withValues(alpha: glow),
                    blurRadius: 22,
                    spreadRadius: -2,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(width: 12),
                  Transform.scale(
                    scale: 0.94 + (_pulseCtrl.value * 0.12),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: glow * 0.6),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.auto_awesome_rounded,
                          size: 17, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'কি লাগবে?',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.1,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'AaramBD AI দিয়ে সহজে পোস্ট করুন',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.80),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 13, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.bolt_rounded,
                          size: 13, color: Color(0xFF7C3AED)),
                      const SizedBox(width: 3),
                      const Text('GO LIVE',
                          style: TextStyle(
                              color: Color(0xFF4F46E5),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6)),
                    ]),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Bottom category bar — horizontal scroll, auto-scrolls to selected
// ─────────────────────────────────────────────────────────────────────────────
class _CatBar extends StatefulWidget {
  final List<Map<String, dynamic>> categories;
  final String? selectedCatId;
  final void Function(String id) onSelect;

  const _CatBar({
    required this.categories,
    required this.selectedCatId,
    required this.onSelect,
  });

  @override
  State<_CatBar> createState() => _CatBarState();
}

class _CatBarState extends State<_CatBar> {
  final Map<String, GlobalKey> _keys = {};

  GlobalKey _keyFor(String id) =>
      _keys.putIfAbsent(id, GlobalKey.new);

  @override
  void didUpdateWidget(_CatBar old) {
    super.didUpdateWidget(old);
    if (old.selectedCatId != widget.selectedCatId) {
      _scrollToSelected();
    }
  }

  void _scrollToSelected() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final id  = widget.selectedCatId;
      if (id == null) return;
      final ctx = _keys[id]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
            alignment: 0.5,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        physics: const BouncingScrollPhysics(),
        itemCount: widget.categories.length,
        itemBuilder: (_, i) {
          final cat  = widget.categories[i];
          final id   = cat['des_cat_id'].toString();
          final name = cat['des_cat_name']?.toString() ?? '';
          final sel  = id == widget.selectedCatId;
          final t    = themeFor(int.tryParse(id));

          return Padding(
            key: _keyFor(id),
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => widget.onSelect(id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: sel
                      ? Colors.blue.shade900
                      : Colors.blue.shade100  ,
                  borderRadius: BorderRadius.circular(22),
                  border: sel
                      ? null
                      : Border.all(
                          color:
                              Colors.white.withAlpha(25),),
                  boxShadow: sel
                      ? [
                          BoxShadow(
                              color: t.primary
                                  .withValues(alpha: 0.45),
                              blurRadius: 12,
                              offset: const Offset(0, 4))
                        ]
                      : [],
                ),
                child: Center(
                  child: Text(name,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: sel
                              ? FontWeight.w700
                              : FontWeight.bold,
                          color: sel
                              ? Colors.white
                              : Colors.black
                                  )),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Sub-cat popup — slides up from bottom, chip grid, minimize arrow
// ─────────────────────────────────────────────────────────────────────────────
class _SubCatPopup extends StatefulWidget {
  final List<Map<String, dynamic>> subCats;
  final bool loading;
  final String? selectedSubCatId;
  final String catName;
  final CatTheme theme;
  final void Function(String? id) onSelect;
  final VoidCallback onClose;

  const _SubCatPopup({
    required this.subCats,
    required this.loading,
    required this.selectedSubCatId,
    required this.catName,
    required this.theme,
    required this.onSelect,
    required this.onClose,
  });

  @override
  State<_SubCatPopup> createState() => _SubCatPopupState();
}

class _SubCatPopupState extends State<_SubCatPopup> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.subCats;
    return widget.subCats.where((it) {
      final bn = (it['name_bn'] ?? '').toString().toLowerCase();
      final en = (it['name_en'] ?? '').toString().toLowerCase();
      return bn.contains(q) || en.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.theme.primary;
    final mq     = MediaQuery.of(context);
    final results = _filtered;
    final searching = _query.trim().isNotEmpty;

    return ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: mq.size.height * 0.58),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(22)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 24,
                offset: const Offset(0, -6))
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            const SizedBox(height: 10),
            Container(
              width: 38, height: 4,
              decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 14),

            // Header row
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18),
              child: Row(children: [
                Container(
                  width: 6, height: 18,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(3)),
                ),
                Expanded(
                  child: Text(
                    widget.catName.isNotEmpty ? widget.catName : 'উপ-বিভাগ',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: accent),
                  ),
                ),
                if (!widget.loading)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('${widget.subCats.length}',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: accent)),
                  ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: widget.onClose,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: const Icon(Icons.close_rounded,
                        size: 20, color: Colors.black38),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 12),

            // Search field
            if (!widget.loading)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F6FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: _query.isEmpty
                            ? const Color(0xFFE8EAF0)
                            : accent.withValues(alpha: 0.45)),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _query = v),
                    style: const TextStyle(
                        fontSize: 13.5, color: Color(0xFF1A2340)),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'উপ-বিভাগ খুঁজুন...',
                      hintStyle: const TextStyle(
                          fontSize: 13.5, color: Color(0xFFA0A6B8)),
                      prefixIcon:
                          Icon(Icons.search_rounded, size: 20, color: accent),
                      suffixIcon: _query.isEmpty
                          ? null
                          : GestureDetector(
                              onTap: () => setState(() {
                                _searchCtrl.clear();
                                _query = '';
                              }),
                              child: const Icon(Icons.close_rounded,
                                  size: 18, color: Color(0xFFA0A6B8)),
                            ),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),

            // Chips
            if (widget.loading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(
                    color: accent, strokeWidth: 2),
              )
            else if (results.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Column(children: [
                  Icon(Icons.search_off_rounded,
                      size: 30, color: Colors.black.withValues(alpha: 0.20)),
                  const SizedBox(height: 8),
                  Text('কোনো ফলাফল পাওয়া যায়নি',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.black.withValues(alpha: 0.40))),
                ]),
              )
            else
              Flexible(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  physics: const BouncingScrollPhysics(),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (!searching)
                        _SubChip(
                          label: 'সব',
                          selected: widget.selectedSubCatId == null,
                          accent: accent,
                          onTap: () => widget.onSelect(null),
                        ),
                      ...results.map((it) {
                        final id =
                            it['des_sub_cat_id']?.toString();
                        final name =
                            it['name_bn']?.toString() ?? '';
                        return _SubChip(
                          label: name,
                          selected: id == widget.selectedSubCatId,
                          accent: accent,
                          onTap: () => widget.onSelect(id),
                        );
                      }),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 12),

            // Minimize / down-arrow button
            GestureDetector(
              onTap: widget.onClose,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 6),
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 26,
                    color: Colors.black38),
              ),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

// ─── Sub-cat chip ─────────────────────────────────────────────────────────────
class _SubChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _SubChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); onTap(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? accent
              : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
              color: selected ? accent : Colors.grey.shade300,
              width: selected ? 1.5 : 1),
          boxShadow: selected
              ? [
                  BoxShadow(
                      color: accent.withValues(alpha: 0.28),
                      blurRadius: 8,
                      offset: const Offset(0, 3))
                ]
              : [],
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: selected
                    ? Colors.white
                    : const Color(0xFF1A2340))),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _PostCard
// ─────────────────────────────────────────────────────────────────────────────
class _PostCard extends StatelessWidget {









  final Map item;
  final CatTheme theme;
  const _PostCard({required this.item, required this.theme});

  @override
  Widget build(BuildContext context) {
    final t      = theme;
    final accent = t.catId == 23 ? const Color(0xFF3B82F6) : t.primary;

    final des      = (item['des'] ?? '').toString();
    final note     = (item['special_note'] ?? '').toString();
    final photo    = (item['des_photo'] ?? '').toString();
    final userName = (item['user_name'] ?? 'Unknown').toString();
    final userPhoto = (item['photo'] ?? '').toString();
    final subName  = (item['sub_cat_name_bn'] ?? '').toString();
    final subEmoji = (item['sub_cat_emoji'] ?? '').toString();
    final time     = Config.getTimeDifference(
            (item['time'] ?? '').toString())
        .toString();
    final status = (item['description_status'] ??
            item['status'] ??
            'live')
        .toString();
    final visited =
        status == 'dead' || status == 'solved' || status == 'inactive';
    final desId = item['des_id'].toString();

    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ThoughtDetails(desId: desId))),
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(
            left: BorderSide(
                color: visited ? Colors.grey.shade300 : accent,
                width: 4)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(11, 11, 12, 11),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          // Row 1: sub-cat badge + time
          Row(children: [
            if (subName.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (subEmoji.isNotEmpty && subEmoji != '?') ...[
                    Text(subEmoji,
                        style: const TextStyle(fontSize: 10)),
                    const SizedBox(width: 3),
                  ],
                  Text(subName,
                      style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: accent)),
                ]),
              ),
              const SizedBox(width: 8),
            ],
            if (visited)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(5)),
                child: const Text('✓ RESOLVED',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF16A34A))),
              ),
            const Spacer(),
            Text(time,
                style: const TextStyle(
                    fontSize: 10.5, color: Colors.black38)),
          ]),

          const SizedBox(height: 9),

          ExpandableText(
            text: des,
            maxLines: 4,
            style: TextStyle(
              fontSize: 14,
              height: 1.55,
              color: visited
                  ? Colors.black38
                  : const Color(0xFF1A2340),
              fontWeight: FontWeight.w500,
            ),
            linkStyle: TextStyle(
                fontSize: 12,
                color: accent,
                fontWeight: FontWeight.w700),
          ),

          if (note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 9, vertical: 7),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: accent.withValues(alpha: 0.10)),
              ),
              child: Text(note,
                  style: const TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: Color(0xFF4A5568))),
            ),
          ],

          if (photo.isNotEmpty) ...[
            const SizedBox(height: 9),
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(photo,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const SizedBox()),
              ),
            ),
          ],

          const SizedBox(height: 10),
          Divider(
              height: 1,
              color: Colors.black.withValues(alpha: 0.06)),
          const SizedBox(height: 8),

          // Footer
          Row(crossAxisAlignment: CrossAxisAlignment.center,
              children: [
            userPhoto.isNotEmpty
                ? CircleAvatar(
                    backgroundImage: NetworkImage(userPhoto),
                    radius: 12)
                : CircleAvatar(
                    backgroundColor:
                        accent.withValues(alpha: 0.15),
                    radius: 12,
                    child: Text(
                      userName.isNotEmpty
                          ? userName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                          color: accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w800),
                    )),
            const SizedBox(width: 6),
            Expanded(
              child: Text(userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color:
                          Colors.black.withValues(alpha: 0.50))),
            ),
            Icon(Icons.remove_red_eye_outlined,
                size: 11, color: Colors.black26),
            const SizedBox(width: 3),
            Text(Config.formatLargeNumber(item['des_view'] ?? 0),
                style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.black38)),
            const SizedBox(width: 7),
            Icon(Icons.chat_bubble_outline_rounded,
                size: 10, color: Colors.black26),
            const SizedBox(width: 3),
            Text(Config.formatLargeNumber(item['des_com'] ?? 0),
                style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.black38)),
            const SizedBox(width: 8),
            Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: visited
                      ? Colors.black.withValues(alpha: 0.05)
                      : accent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: visited
                      ? []
                      : [
                          BoxShadow(
                              color:
                                  accent.withValues(alpha: 0.28),
                              blurRadius: 7,
                              offset: const Offset(0, 3))
                        ],
                ),
                child: Text('VISIT',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: visited
                            ? Colors.black26
                            : Colors.white)),
              ),
          ]),
        ]),
      ),
    ),
    );
  }
}
