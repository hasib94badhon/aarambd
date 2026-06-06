import 'dart:convert';

import 'package:aaram_bd/pages/Homepage.dart';
import 'package:aaram_bd/pages/ShopsCart.dart';
import 'package:aaram_bd/pages/description_landing_page.dart';
import 'package:aaram_bd/pages/notification_show.dart';
import 'package:aaram_bd/widgets/AppDrawer.dart';
import 'package:aaram_bd/widgets/UpdatePost.dart';
import 'package:aaram_bd/widgets/thoughtsection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aaram_bd/pages/ServiceCart.dart';
import 'package:aaram_bd/screens/user_profile.dart';
import 'package:aaram_bd/localization/app_localizations.dart';
import 'package:aaram_bd/localization/language_provider.dart';
import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aaram_bd/config.dart';

final String host = Config.host;

// ─── Brand tokens ─────────────────────────────────────────────────────────────
const Color _brand = Color(0xFF1A56DB);
const Color _brandDeep = Color(0xFF1040B0);
const Color _inactive = Color(0xFF5A5A5A);

// ─── Notification badge ───────────────────────────────────────────────────────
class _NotificationBadge extends StatelessWidget {
  final int count;
  const _NotificationBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final text = count > 99 ? '99+' : count.toString();
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.95, end: 1.0),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFD5E53), Color(0xFFFF7A59)],
          ),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 5, offset: Offset(0, 2)),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            height: 1.1,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
            inherit: false,
          ),
        ),
      ),
    );
  }
}

// ─── NavigationScreen ─────────────────────────────────────────────────────────
class NavigationScreen extends StatefulWidget {
  final String userPhone;
  final int initialPage;

  const NavigationScreen({
    super.key,
    required this.userPhone,
    this.initialPage = 0,
  });

  @override
  State<NavigationScreen> createState() =>
      _NavigationScreenState(userPhone: userPhone);
}

class _NavigationScreenState extends State<NavigationScreen>
    with RouteAware, WidgetsBindingObserver, TickerProviderStateMixin {
  final String userPhone;

  late AnimationController _bellController;
  late Animation<double> _bellAnimation;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // ── One navigator key per tab (index 0–3) ─────────────────────────────────
  // Sub-pages (ShopsCart, UpdatePost, advert, shops_favorite …) are pushed
  // onto the ACTIVE tab's navigator so the bottom nav stays visible.
  final GlobalKey<NavigatorState> _tab0Key = GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _tab1Key = GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _tab2Key = GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _tab3Key = GlobalKey<NavigatorState>();

  _NavigationScreenState({required this.userPhone});

  AppLocalizations get _l10n =>
      Provider.of<LanguageProvider>(context, listen: false).l10n;

  int pageIndex = 0;
  int unreadCount = 0;
  bool isDescLoading = true;

  late List<Widget> pages;

  // 4 persistent tab pages — satisfies AnimatedBottomNavigationBar (max 5,
  // min 2).  GapLocation.center splits [Feeds, Top | gap+FAB | Experts, Profile]
  final List<UniqueKey> pageKeys = List.generate(4, (_) => UniqueKey());

  dynamic serviceData;
  dynamic userData;

  // ── Bottom nav config ──────────────────────────────────────────────────────
  static const _navIcons = [
    Icons.dashboard_outlined,  // 0  Feeds
    Icons.hive_rounded,        // 1  Top
    Icons.engineering_rounded, // 2  Experts
    Icons.person_rounded,      // 3  Profile
  ];

  // nav labels are built dynamically in build() via l10n

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    pageIndex = widget.initialPage;
    WidgetsBinding.instance.addObserver(this);

    _bellController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _bellAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.1), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.1, end: -0.1), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.1, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _bellController, curve: Curves.easeInOut));

    initializePages();
    fetchPageData(pageIndex);
    getUnreadCount();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bellController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refreshCurrentPage();
  }

  @override
  void didPopNext() => refreshCurrentPage();

  // ── Tab root pages (raw widgets — Navigator wrapping happens in build) ──────
  void initializePages() {
    pages = [
      DescriptionLandingPage(
        onLoaded: () {
          if (!mounted) return;
          setState(() => isDescLoading = false);
        },
      ),
      Homepage(),
      ServiceCart(key: pageKeys[2], dataa: serviceData, userPhone: userPhone),
      UserProfile(key: pageKeys[3], userPhone: userPhone, userData: userData),
    ];
  }

  // ── Refresh ────────────────────────────────────────────────────────────────
  void refreshCurrentPage() {
    fetchPageData(pageIndex);
    getUnreadCount();
  }

  void refreshPage(int index) {
    fetchPageData(index);
    getUnreadCount();
  }

  // ── Auth ───────────────────────────────────────────────────────────────────
  Future<String?> getLoggedInUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id');
  }

  Future<void> markNotificationsRead(String userId) async {
    if (!mounted) return;
    final ctx = context;
    try {
      final resp = await Config.apiPost(
        '/mark_notifications_read',
        {'user_id': userId},
        ctx,
      );
      if (resp != null && resp.statusCode == 200) {
        debugPrint('Notifications marked as read');
      } else {
        debugPrint('Failed: ${resp?.body}');
      }
    } catch (e) {
      debugPrint('Error marking read: $e');
    }
  }

  Future<void> getUnreadCount() async {
    final ctx = context;
    final userId = await getLoggedInUser();
    if (userId == null || !mounted) return;
    try {
      final resp = await Config.apiGet(
        '/get_notifications?user_id=$userId',
        ctx,
      );
      if (resp == null || resp.statusCode != 200) return;
      final body = json.decode(resp.body) as Map<String, dynamic>;
      final notifs = (body['notifications'] as List<dynamic>?) ?? [];
      final count = notifs.where((n) => n['is_read'] == 0).length;
      if (!mounted) return;
      setState(() => unreadCount = count);
      if (unreadCount > 0) {
        if (!_bellController.isAnimating) _bellController.repeat(reverse: true);
      } else {
        _bellController.stop();
      }
    } catch (e) {
      debugPrint('Error loading notifications: $e');
    }
  }

  // ── Page data fetch ────────────────────────────────────────────────────────
  Future<void> fetchPageData(int index) async {
    final ctx = context;
    switch (index) {
      case 0:
        break; // DescriptionLandingPage loads itself
      case 1:
        break; // Homepage loads itself
      case 2:
        final resp = await Config.apiGet('/get_service_data', ctx);
        if (resp != null && resp.statusCode == 200) {
          if (!mounted) return;
          setState(() {
            serviceData = resp.body;
            initializePages();
          });
        }
        break;
      case 3:
        final resp = await Config.apiGet(
          '/get_user_by_phone?phone=$userPhone',
          ctx,
        );
        if (resp != null && resp.statusCode == 200) {
          if (!mounted) return;
          setState(() {
            userData = resp.body;
            initializePages();
          });
        }
        break;
    }
  }

  // ── Nested navigator helpers ───────────────────────────────────────────────

  /// Returns the [NavigatorState] key for the currently visible tab.
  /// pageIndex is always 0–3 (matches the 4 bottom-nav items).
  GlobalKey<NavigatorState> get _currentNavKey {
    switch (pageIndex) {
      case 0: return _tab0Key;
      case 1: return _tab1Key;
      case 2: return _tab2Key;
      default: return _tab3Key;
    }
  }

  /// Wraps [child] in a nested [Navigator] identified by [key].
  /// Any Navigator.push() call made from within [child] (or pages it pushes)
  /// targets this navigator, keeping the outer Scaffold — and its bottom nav —
  /// in place.
  Widget _tabNav(GlobalKey<NavigatorState> key, Widget child) {
    return Navigator(
      key: key,
      onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => child),
    );
  }

  // ── AppBar actions — all push into the active tab's nested navigator ────────

  /// Opens ThoughtSectionPage on the ROOT navigator (full-screen compose flow).
  void _openThoughtSection() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NeedBuilderPage()),
    ).then((_) => refreshCurrentPage());
  }

  /// Opens ShopsCart inside the active tab's navigator so the bottom nav
  /// remains visible while the user browses categories and shops.
  void _openMart() {
    final title = _l10n.navMartTitle;
    _currentNavKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: const Color(0xFFF8FAFF),
          appBar: _buildSimpleAppBar(title, Icons.storefront_rounded),
          body: ShopsCart(userPhone: userPhone),
        ),
      ),
    );
  }

  /// Opens UpdatePost inside the active tab's navigator.
  void _openUpdatePost() {
    final title = _l10n.navUpdatePostTitle;
    _currentNavKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: const Color(0xFFF0F4FA),
          appBar: _buildSimpleAppBar(title, Icons.edit_note_rounded),
          body: UpdatePost(posts: const [], selectedSort: 'recent'),
        ),
      ),
    );
  }

  // ── Shared simple AppBar for nested-navigator screens ─────────────────────
  AppBar _buildSimpleAppBar(String title, IconData titleIcon) {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 0,
      titleSpacing: 0,
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: ColoredBox(
          color: Color(0xFFEAEDF2),
          child: SizedBox(height: 1, width: double.infinity),
        ),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFFEDF4FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(titleIcon, color: _brand, size: 18),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w800,
              fontSize: 17,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // ── AppBar title widget ────────────────────────────────────────────────────
  Widget _buildAppBarTitle(AppLocalizations l10n) {
    return Row(
      children: [
        // ── Drawer trigger ──
        AnimatedHomeIcon(
          onTap: () => _scaffoldKey.currentState?.openDrawer(),
        ),

        const Spacer(),

        // ── Brand logo ──
        RichText(
          text: TextSpan(
            children: [
              const TextSpan(
                text: 'Aaram',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: _brand,
                  shadows: [
                    Shadow(
                        color: Colors.black12,
                        blurRadius: 3,
                        offset: Offset(1, 1)),
                  ],
                  inherit: false,
                ),
              ),
              const WidgetSpan(child: SizedBox(width: 5)),
              WidgetSpan(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _brand,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(1, 2)),
                    ],
                  ),
                  child: const Text(
                    'BD',
                    style: TextStyle(
                      fontFamily: 'BebasNeue',
                      fontSize: 20,
                      color: Colors.white,
                      inherit: false,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const Spacer(),

        // ── Quick action: Mart ──
        _appBarActionBtn(
          icon: Icons.storefront_rounded,
          label: l10n.navMart,
          onTap: _openMart,
        ),

        const SizedBox(width: 6),

        // ── Quick action: Update Post ──
        _appBarActionBtn(
          icon: Icons.edit_note_rounded,
          label: l10n.navPost,
          onTap: _openUpdatePost,
        ),

        const SizedBox(width: 6),

        // ── Notification bell ──
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () async {
            final userId = await getLoggedInUser();
            if (userId == null) return;
            if (unreadCount > 0) {
              await markNotificationsRead(userId);
              if (!mounted) return;
              setState(() => unreadCount = 0);
              _bellController.stop();
            }
            if (!mounted) return;
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationShow()),
            );
            await getUnreadCount();
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedBuilder(
                animation: _bellAnimation,
                builder: (_, child) => Transform.rotate(
                  angle: unreadCount > 0 ? _bellAnimation.value : 0.0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.all(6),
                    decoration: unreadCount > 0
                        ? BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.amber.withValues(alpha: 0.35),
                                spreadRadius: 2,
                                blurRadius: 10,
                              ),
                            ],
                          )
                        : null,
                    child: const Icon(
                      Icons.notifications_none_rounded,
                      color: Colors.black87,
                      size: 28,
                    ),
                  ),
                ),
              ),
              if (unreadCount > 0)
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: _NotificationBadge(count: unreadCount),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Small icon+label pill button in the AppBar.
  Widget _appBarActionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F4FA),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE0E8F5), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: _brand),
            const SizedBox(height: 1),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: _brand,
                fontFamily: 'Poppins',
                inherit: false,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bottom nav item ────────────────────────────────────────────────────────
  Widget _buildNavItem({
    required bool isActive,
    required IconData icon,
    required String label,
  }) {
    final color = isActive ? _brand : _inactive;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: isActive ? 26 : 22, color: color),
        const SizedBox(height: 2),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 180),
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: isActive ? 12 : 11,
            color: color,
            fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
            inherit: false,
          ),
          child: Text(label),
        ),
        const SizedBox(height: 3),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: isActive ? 1.0 : 0.0,
          child: Container(
            width: 14,
            height: 3,
            decoration: BoxDecoration(
              color: _brand,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ],
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LanguageProvider>().l10n;
    final navLabels = [l10n.navFeeds, l10n.navTop, l10n.navExperts, l10n.navProfile];
    // PopScope intercepts hardware back / iOS swipe-back and delegates to the
    // active tab's nested navigator.  If there is nothing to pop on the nested
    // navigator (user is at the tab root) the back event is swallowed so the
    // app stays open — standard Android behaviour.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_currentNavKey.currentState?.canPop() ?? false) {
          _currentNavKey.currentState!.pop();
        }
        // At root of a tab → do nothing (user stays in the app)
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xFFF0F4FA),

        // ── AppBar ────────────────────────────────────────────────────────────
        appBar: AppBar(
          elevation: 0,
          automaticallyImplyLeading: false,
          backgroundColor: Colors.white,
          titleSpacing: 12,
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: ColoredBox(
              color: Color(0xFFEAEDF2),
              child: SizedBox(height: 1, width: double.infinity),
            ),
          ),
          title: _buildAppBarTitle(l10n),
        ),

        drawer: AppDrawer(userPhone: userPhone),

        // ── Body — IndexedStack with 4 nested navigators ──────────────────────
        // Each tab gets its own Navigator so sub-pages (ShopsCart, advert,
        // shops_favorite …) pushed from within a tab stay inside the shell and
        // the bottom nav + AppBar remain visible.
        body: Stack(
          children: [
            IndexedStack(
              index: pageIndex,
              children: [
                _tabNav(_tab0Key, pages[0]),
                _tabNav(_tab1Key, pages[1]),
                _tabNav(_tab2Key, pages[2]),
                _tabNav(_tab3Key, pages[3]),
              ],
            ),
            if (pageIndex == 0 && isDescLoading)
              Positioned.fill(
                child: Container(
                  color: Colors.white.withValues(alpha: 0.80),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: _brand),
                      const SizedBox(height: 14),
                      Text(
                        l10n.loading,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                          inherit: false,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),

        // ── Center FAB → ThoughtSectionPage (root navigator, full-screen) ─────
       floatingActionButton: Container(
  height: 70,
  width: 70,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    gradient: const LinearGradient(
      colors: [
        Color(0xFF00E676), // neon green
        Color(0xFF00C853), // deep green
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF00E676).withOpacity(0.6),
        blurRadius: 22,
        spreadRadius: 2,
        offset: const Offset(0, 6),
      ),
      BoxShadow(
        color: Colors.black.withOpacity(0.25),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  ),
  child: FloatingActionButton(
    elevation: 0,
    backgroundColor: Colors.transparent,
    onPressed: _openThoughtSection,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.bolt_rounded, // more “live” than auto_awesome
          size: 28,
          color: Colors.white,
        ),
        const SizedBox(height: 2),
        const Text(
          "LIVE",
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ],
    ),
  ),
),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

        // ── Bottom nav (4 items, activeIndex always 0–3) ──────────────────────
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 14,
                offset: Offset(0, -4),
              ),
            ],
            border: Border(
              top: BorderSide(color: Color(0xFFEAEDF2), width: 1),
            ),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            child: AnimatedBottomNavigationBar.builder(
              itemCount: _navIcons.length, // 4 — within the 2–5 constraint ✅
              activeIndex: pageIndex,      // always 0–3, no assertion risk ✅
              gapLocation: GapLocation.center,
              notchSmoothness: NotchSmoothness.softEdge,
              notchMargin: 6,
              leftCornerRadius: 20,
              rightCornerRadius: 20,
              backgroundColor: Colors.white,
              elevation: 0,
              height: 68,
              tabBuilder: (int index, bool isActive) => _buildNavItem(
                isActive: isActive,
                icon: _navIcons[index],
                label: navLabels[index],
              ),
              onTap: (index) {
                if (index == pageIndex) {
                  refreshPage(index);
                } else {
                  setState(() => pageIndex = index);
                  fetchPageData(index);
                  getUnreadCount();
                }
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ─── AnimatedHomeIcon ─────────────────────────────────────────────────────────
class AnimatedHomeIcon extends StatefulWidget {
  final VoidCallback onTap;
  const AnimatedHomeIcon({super.key, required this.onTap});

  @override
  State<AnimatedHomeIcon> createState() => _AnimatedHomeIconState();
}

class _AnimatedHomeIconState extends State<AnimatedHomeIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF4B83FF), _brand, _brandDeep],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _brand.withValues(alpha: 0.30),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: const CircleAvatar(
            backgroundColor: Color(0xFFEDF4FF),
            radius: 16,
            child: Icon(Icons.menu_rounded, size: 20, color: _brand),
          ),
        ),
      ),
    );
  }
}
