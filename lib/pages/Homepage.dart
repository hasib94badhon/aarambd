import 'dart:async';
import 'dart:convert';
import 'package:aaram_bd/config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class _FbPage {
  final int pageId;
  final String name;
  final String cat;
  final String photo;
  final String link;
  final int visitCount;

  const _FbPage({
    required this.pageId,
    required this.name,
    required this.cat,
    required this.photo,
    required this.link,
    required this.visitCount,
  });

  factory _FbPage.fromJson(Map<String, dynamic> j) => _FbPage(
        pageId: j['page_id'] ?? 0,
        name: (j['name'] ?? '').toString(),
        cat: (j['cat'] ?? '').toString(),
        photo: (j['photo'] ?? '').toString(),
        link: (j['link'] ?? '').toString(),
        visitCount: j['visit_count'] ?? 0,
      );
}

class _YtChannel {
  final int channelId;
  final String name;
  final String cat;
  final String photo;
  final String link;
  final int visitCount;

  const _YtChannel({
    required this.channelId,
    required this.name,
    required this.cat,
    required this.photo,
    required this.link,
    required this.visitCount,
  });

  factory _YtChannel.fromJson(Map<String, dynamic> j) => _YtChannel(
        channelId: j['channel_id'] ?? 0,
        name: (j['name'] ?? '').toString(),
        cat: (j['cat'] ?? '').toString(),
        photo: (j['photo'] ?? '').toString(),
        link: (j['link'] ?? '').toString(),
        visitCount: j['visit_count'] ?? 0,
      );
}

// ── Page ──────────────────────────────────────────────────────────────────────

class Homepage extends StatefulWidget {
  const Homepage({Key? key}) : super(key: key);

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> with TickerProviderStateMixin {
  String _platform = 'fb'; // 'fb' | 'yt'

  String _search = '';
  String _selectedCat = '';
  String _sort = 'views'; // 'views' | 'name'

  List<_FbPage> _fbPages = [];
  List<_YtChannel> _ytChannels = [];
  List<String> _fbCats = [];
  List<String> _ytCats = [];

  bool _loading = false;
  bool _hasError = false;

  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  static const _fbBlue = Color(0xFF1877F2);
  static const _ytRed  = Color(0xFFFF0000);
  static const _bg     = Color(0xFFF0F4FA);

  @override
  void initState() {
    super.initState();
    _fetchFb();
    _fetchYt();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ── Fetchers ───────────────────────────────────────────────────────────────

  Future<void> _fetchFb() async {
    setState(() { _loading = true; _hasError = false; });
    try {
      final params = <String, String>{'sort': _sort};
      if (_selectedCat.isNotEmpty) params['category'] = _selectedCat;
      if (_search.isNotEmpty) params['search'] = _search;
      final q = params.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');

      final res = await Config.apiGet('/get_fb_page?$q', context);
      if (res != null && res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final pages = (data['fb_page'] as List)
            .map((e) => _FbPage.fromJson(e as Map<String, dynamic>))
            .toList();
        final cats = (data['categories'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        if (mounted) setState(() { _fbPages = pages; _fbCats = cats; });
      } else {
        if (mounted) setState(() => _hasError = true);
      }
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchYt() async {
    setState(() { _loading = true; _hasError = false; });
    try {
      final params = <String, String>{'sort': _sort};
      if (_selectedCat.isNotEmpty) params['category'] = _selectedCat;
      if (_search.isNotEmpty) params['search'] = _search;
      final q = params.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');

      final res = await Config.apiGet('/get_yt_channels?$q', context);
      if (res != null && res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final channels = (data['yt_channels'] as List)
            .map((e) => _YtChannel.fromJson(e as Map<String, dynamic>))
            .toList();
        final cats = (data['categories'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        if (mounted) setState(() { _ytChannels = channels; _ytCats = cats; });
      } else {
        if (mounted) setState(() => _hasError = true);
      }
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _reload() {
    setState(() { _search = ''; _selectedCat = ''; });
    _searchCtrl.clear();
    _fetchFb();
    _fetchYt();
  }

  void _applyFilters() {
    if (_platform == 'fb') _fetchFb(); else _fetchYt();
  }

  void _onSearchChanged(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      setState(() => _search = val);
      _applyFilters();
    });
  }

  void _switchPlatform(String p) {
    if (_platform == p) return;
    HapticFeedback.selectionClick();
    setState(() {
      _platform = p;
      _search = '';
      _selectedCat = '';
      _searchCtrl.clear();
    });
  }

  void _selectCat(String cat) {
    HapticFeedback.selectionClick();
    setState(() => _selectedCat = cat == _selectedCat ? '' : cat);
    _applyFilters();
  }

  void _toggleSort(String s) {
    if (_sort == s) return;
    HapticFeedback.selectionClick();
    setState(() => _sort = s);
    _applyFilters();
  }

  // ── Visit tracking ─────────────────────────────────────────────────────────

  Future<void> _openFb(_FbPage page) async {
    Config.apiPost('/fb_page_visit', {'page_id': page.pageId}, context).ignore();
    final uri = Uri.parse(page.link);
    final fb  = Uri.parse('fb://facewebmodal/f?href=${Uri.encodeFull(page.link)}');
    if (await canLaunchUrl(fb)) {
      await launchUrl(fb, mode: LaunchMode.externalApplication);
    } else if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open page.')));
    }
  }

  Future<void> _openYt(_YtChannel ch) async {
    Config.apiPost('/yt_channel_visit', {'channel_id': ch.channelId}, context).ignore();
    final uri = Uri.parse(ch.link);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open channel.')));
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isFb   = _platform == 'fb';
    final accent = isFb ? _fbBlue : _ytRed;
    final cats   = isFb ? _fbCats : _ytCats;

    // local filter on top of server results
    final items = isFb ? _filterFb() : _filterYt();

    return Scaffold(
      backgroundColor: _bg,
      body: RefreshIndicator(
        color: accent,
        onRefresh: () async => _reload(),
        child: CustomScrollView(
          slivers: [
            // ── Header ────────────────────────────────────────────────────
            SliverToBoxAdapter(child: _buildHeader(accent, isFb, cats)),

            // ── Sort bar ───────────────────────────────────────────────────
            SliverToBoxAdapter(child: _buildSortBar(accent)),

            // ── Content ────────────────────────────────────────────────────
            if (_loading && items.isEmpty)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_hasError)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wifi_off_rounded,
                          size: 48, color: Colors.black26),
                      const SizedBox(height: 12),
                      const Text('Could not load data',
                          style: TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 16),
                      TextButton(
                          onPressed: _reload,
                          child: const Text('Retry')),
                    ],
                  ),
                ),
              )
            else if (items.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FaIcon(
                        isFb
                            ? FontAwesomeIcons.facebookF
                            : FontAwesomeIcons.youtube,
                        size: 40,
                        color: Colors.black12,
                      ),
                      const SizedBox(height: 16),
                      const Text('Nothing found',
                          style: TextStyle(
                              color: Colors.black38,
                              fontWeight: FontWeight.w600,
                              fontSize: 15)),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => isFb
                        ? _FbCard(page: items[i] as _FbPage, onTap: _openFb)
                        : _YtCard(
                            channel: items[i] as _YtChannel,
                            onTap: _openYt),
                    childCount: items.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Header widget ──────────────────────────────────────────────────────────

  Widget _buildHeader(Color accent, bool isFb, List<String> cats) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // platform toggle
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4FA),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E9F5)),
            ),
            child: Row(children: [
              _PlatformBtn(
                label: 'Facebook Pages',
                icon: FontAwesomeIcons.facebookF,
                color: _fbBlue,
                selected: isFb,
                onTap: () => _switchPlatform('fb'),
              ),
              const SizedBox(width: 6),
              _PlatformBtn(
                label: 'YouTube Channels',
                icon: FontAwesomeIcons.youtube,
                color: _ytRed,
                selected: !isFb,
                onTap: () => _switchPlatform('yt'),
              ),
            ]),
          ),
          const SizedBox(height: 10),

          // search bar
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF6F8FC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E9F5)),
            ),
            child: Row(children: [
              const SizedBox(width: 12),
              Icon(Icons.search_rounded, size: 20, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  style: const TextStyle(
                      fontSize: 14, color: Color(0xFF1E293B)),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: isFb
                        ? 'Search Facebook pages…'
                        : 'Search YouTube channels…',
                    hintStyle: const TextStyle(
                        fontSize: 13, color: Color(0xFF94A3B8)),
                    isDense: true,
                  ),
                ),
              ),
              if (_search.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _searchCtrl.clear();
                    setState(() => _search = '');
                    _applyFilters();
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(Icons.close_rounded,
                        size: 18, color: Color(0xFF94A3B8)),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 10),

          // category chips
          if (cats.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: 4),
                children: [
                  _CatChip(
                    label: 'All',
                    selected: _selectedCat.isEmpty,
                    accent: accent,
                    onTap: () => _selectCat(''),
                  ),
                  ...cats.map((c) => _CatChip(
                        label: c,
                        selected: _selectedCat == c,
                        accent: accent,
                        onTap: () => _selectCat(c),
                      )),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Sort bar ───────────────────────────────────────────────────────────────

  Widget _buildSortBar(Color accent) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Row(children: [
        const Text('Sort:',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B))),
        const SizedBox(width: 8),
        _SortBtn(
          label: 'Most Visited',
          icon: Icons.remove_red_eye_rounded,
          selected: _sort == 'views',
          accent: accent,
          onTap: () => _toggleSort('views'),
        ),
        const SizedBox(width: 6),
        _SortBtn(
          label: 'A → Z',
          icon: Icons.sort_by_alpha_rounded,
          selected: _sort == 'name',
          accent: accent,
          onTap: () => _toggleSort('name'),
        ),
        const Spacer(),
        if (_loading)
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: accent),
          ),
      ]),
    );
  }

  // ── Local filter (instant for typed search) ────────────────────────────────

  List<dynamic> _filterFb() {
    if (_search.isEmpty) return _fbPages;
    final q = _search.toLowerCase();
    return _fbPages
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            p.cat.toLowerCase().contains(q))
        .toList();
  }

  List<dynamic> _filterYt() {
    if (_search.isEmpty) return _ytChannels;
    final q = _search.toLowerCase();
    return _ytChannels
        .where((c) =>
            c.name.toLowerCase().contains(q) ||
            c.cat.toLowerCase().contains(q))
        .toList();
  }
}

// ── Platform toggle button ────────────────────────────────────────────────────

class _PlatformBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _PlatformBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.28),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    )
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FaIcon(icon,
                  size: 13,
                  color: selected ? Colors.white : const Color(0xFF64748B)),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color:
                      selected ? Colors.white : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Category chip ─────────────────────────────────────────────────────────────

class _CatChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _CatChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? accent : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? accent : const Color(0xFFE5E9F5),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.22),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}

// ── Sort button ───────────────────────────────────────────────────────────────

class _SortBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _SortBtn({
    required this.label,
    required this.icon,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.40)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 13,
                color: selected ? accent : const Color(0xFF94A3B8)),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? accent : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Facebook page card ────────────────────────────────────────────────────────

class _FbCard extends StatelessWidget {
  final _FbPage page;
  final void Function(_FbPage) onTap;

  const _FbCard({required this.page, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EDF5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => onTap(page),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              // accent bar
              Container(
                width: 3,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF1877F2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              _Avatar(
                url: page.photo,
                fallbackIcon: FontAwesomeIcons.facebookF,
                color: const Color(0xFF1877F2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      page.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Row(children: [
                      Flexible(child: _CatBadge(
                          label: page.cat,
                          color: const Color(0xFF1877F2))),
                      const SizedBox(width: 8),
                      const Icon(Icons.remove_red_eye_outlined,
                          size: 11, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 3),
                      Text(
                        Config.formatLargeNumber(page.visitCount),
                        style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w600),
                      ),
                    ]),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _OpenBtn(
                  color: const Color(0xFF1877F2),
                  icon: FontAwesomeIcons.facebookF),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── YouTube channel card ──────────────────────────────────────────────────────

class _YtCard extends StatelessWidget {
  final _YtChannel channel;
  final void Function(_YtChannel) onTap;

  const _YtCard({required this.channel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EDF5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => onTap(channel),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              // accent bar
              Container(
                width: 3,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF0000),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              _Avatar(
                url: channel.photo,
                fallbackIcon: FontAwesomeIcons.youtube,
                color: const Color(0xFFFF0000),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channel.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Row(children: [
                      _CatBadge(
                          label: channel.cat,
                          color: const Color(0xFFFF0000)),
                      const SizedBox(width: 8),
                      const Icon(Icons.remove_red_eye_outlined,
                          size: 11, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 3),
                      Text(
                        Config.formatLargeNumber(channel.visitCount),
                        style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w600),
                      ),
                    ]),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _OpenBtn(
                  color: const Color(0xFFFF0000),
                  icon: FontAwesomeIcons.youtube),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Shared small widgets ──────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String url;
  final IconData fallbackIcon;
  final Color color;

  const _Avatar(
      {required this.url,
      required this.fallbackIcon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.08),
        border:
            Border.all(color: color.withValues(alpha: 0.18), width: 1.5),
      ),
      child: url.isNotEmpty
          ? ClipOval(
              child: Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    _fallback(color, fallbackIcon),
              ),
            )
          : _fallback(color, fallbackIcon),
    );
  }

  Widget _fallback(Color c, IconData ico) =>
      Center(child: FaIcon(ico, size: 22, color: c));
}

class _CatBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _CatBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _OpenBtn extends StatelessWidget {
  final Color color;
  final IconData icon;

  const _OpenBtn({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.80)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.28),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(icon, size: 11, color: Colors.white),
          const SizedBox(width: 5),
          const Text(
            'Open',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
