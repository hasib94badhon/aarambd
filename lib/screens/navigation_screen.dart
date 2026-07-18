import 'dart:async';
import 'dart:convert';

import 'package:aaram_bd/pages/Homepage.dart';
import 'package:aaram_bd/pages/ShopsCart.dart';
import 'package:aaram_bd/pages/description_landing_page.dart';
import 'package:aaram_bd/pages/notification_show.dart';
import 'package:aaram_bd/widgets/AppDrawer.dart';
import 'package:aaram_bd/widgets/UpdatePost.dart';
import 'package:flutter/material.dart';
import 'package:aaram_bd/pages/ServiceCart.dart';
import 'package:aaram_bd/screens/user_profile.dart';
import 'package:aaram_bd/services/fcm_service.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:aaram_bd/config.dart';
import 'package:aaram_bd/widgets/user_current_location.dart';
import 'package:aaram_bd/widgets/app_toast.dart';

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
            BoxShadow(
                color: Colors.black26, blurRadius: 5, offset: Offset(0, 2)),
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
  late AnimationController _bellGlowController;
  late Animation<double> _bellGlow;

  // Powers the admin panel's "active now" count — a periodic ping while the
  // app is in the foreground, distinct from the one-off login-time update.
  Timer? _heartbeatTimer;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // ── One navigator key per tab (index 0–5) ─────────────────────────────────
  final GlobalKey<NavigatorState> _tab0Key = GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _tab1Key = GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _tab2Key = GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _tab3Key = GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _tab4Key = GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _tab5Key = GlobalKey<NavigatorState>();

  _NavigationScreenState({required this.userPhone});

  int pageIndex = 0;
  int unreadCount = 0;
  bool isDescLoading = true;
  bool isInactive = false; // admin marked this account inactive (users.status = 0)

  late List<Widget> pages;

  // 6 persistent tab pages.
  final List<UniqueKey> pageKeys = List.generate(6, (_) => UniqueKey());

  dynamic serviceData;
  dynamic userData;

  // ── Bottom nav config (6 items) ────────────────────────────────────────────
  static const _navIcons = [
    Icons.cell_tower_rounded,     // 0  Live
    Icons.public_rounded,         // 1  Social
    Icons.photo_library_rounded,  // 2  Gallery
    Icons.storefront_rounded,     // 3  Shops
    Icons.handyman_rounded,       // 4  Services
    Icons.account_circle_rounded, // 5  My Acc
  ];

  // nav labels are built dynamically in build() via l10n

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    pageIndex = widget.initialPage;
    WidgetsBinding.instance.addObserver(this);

    // Decaying multi-swing shake — mimics a struck bell settling, rather than
    // a plain back-and-forth wiggle.
    _bellController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _bellAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.32), weight: 8),
      TweenSequenceItem(tween: Tween(begin: 0.32, end: -0.26), weight: 10),
      TweenSequenceItem(tween: Tween(begin: -0.26, end: 0.18), weight: 9),
      TweenSequenceItem(tween: Tween(begin: 0.18, end: -0.11), weight: 8),
      TweenSequenceItem(tween: Tween(begin: -0.11, end: 0.05), weight: 7),
      TweenSequenceItem(tween: Tween(begin: 0.05, end: 0.0), weight: 6),
    ]).animate(
        CurvedAnimation(parent: _bellController, curve: Curves.easeOutSine));
    // Re-strike the bell every couple seconds while there's something unread,
    // instead of shaking continuously.
    _bellController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 1700), () {
          if (mounted && unreadCount > 0) _bellController.forward(from: 0);
        });
      }
    });

    // Slow ambient glow pulse behind the bell — keeps it eye-catching between
    // the periodic shake bursts, same amber tone as before, just animated.
    // Only runs while there's something unread (started/stopped alongside
    // _bellController in getUnreadCount()).
    _bellGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _bellGlow = CurvedAnimation(
        parent: _bellGlowController, curve: Curves.easeInOut);

    initializePages();
    fetchPageData(pageIndex);
    getUnreadCount();
    _checkUserStatus();
    // Save this user's GPS to the backend so they appear in other users' "Nearby" radar.
    LocationService().updateUserLocationFromStorage();

    // Ring the bell the instant a push arrives while the app is open, rather
    // than waiting for the next manual refresh/lifecycle event.
    FCMService().onForegroundMessage = () {
      if (mounted) getUnreadCount();
    };

    _startHeartbeat();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FCMService().onForegroundMessage = null;
    _bellController.dispose();
    _bellGlowController.dispose();
    _heartbeatTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refreshCurrentPage();
      _startHeartbeat();
    } else {
      _heartbeatTimer?.cancel();
    }
  }

  // ── Activity heartbeat ───────────────────────────────────────────────────
  // Pings the backend every 60s while the app is foregrounded, so the admin
  // panel can show a genuine "active now" count (not just last-login time).
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _sendHeartbeat();
    _heartbeatTimer =
        Timer.periodic(const Duration(seconds: 60), (_) => _sendHeartbeat());
  }

  Future<void> _sendHeartbeat() async {
    if (!mounted) return;
    try {
      await Config.apiPost('/update_activity', {}, context);
    } catch (_) {
      // Best-effort — a missed heartbeat just means one fewer data point,
      // never worth surfacing to the user.
    }
  }

  @override
  void didPopNext() => refreshCurrentPage();

  // ── Tab root pages (raw widgets — Navigator wrapping happens in build) ──────
  void initializePages() {
    pages = [
      // 0 — Live
      DescriptionLandingPage(
        onLoaded: () {
          if (!mounted) return;
          setState(() => isDescLoading = false);
        },
      ),
      // 1 — Social (FB & YT directory)
      Homepage(),
      // 2 — Gallery: UpdatePost wrapped in a bare Scaffold (no AppBar — outer bar handles nav)
      Scaffold(
        backgroundColor: const Color(0xFFF0F4FA),
        body: UpdatePost(posts: const [], selectedSort: 'recent'),
      ),
      // 3 — Shops
      Scaffold(
        backgroundColor: const Color(0xFFF8FAFF),
        body: ShopsCart(userPhone: userPhone),
      ),
      // 4 — Services
      ServiceCart(key: pageKeys[4], dataa: serviceData, userPhone: userPhone),
      // 5 — My Acc
      UserProfile(key: pageKeys[5], userPhone: userPhone, userData: userData),
    ];
  }

  // ── Refresh ────────────────────────────────────────────────────────────────
  void refreshCurrentPage() {
    fetchPageData(pageIndex);
    getUnreadCount();
    _checkUserStatus();
  }

  void refreshPage(int index) {
    fetchPageData(index);
    getUnreadCount();
    _checkUserStatus();
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
        if (!_bellController.isAnimating) _bellController.forward(from: 0);
        if (!_bellGlowController.isAnimating) {
          _bellGlowController.repeat(reverse: true);
        }
      } else {
        _bellController.stop();
        _bellGlowController.stop();
      }
    } catch (e) {
      debugPrint('Error loading notifications: $e');
    }
  }

  // Piggybacks on the same refresh points as getUnreadCount() so an admin
  // marking this account inactive mid-session gets noticed without a
  // dedicated polling timer.
  Future<void> _checkUserStatus() async {
    final ctx = context;
    final userId = await getLoggedInUser();
    if (userId == null || !mounted) return;
    try {
      final resp = await Config.apiGet('/get_user_status?user_id=$userId', ctx);
      if (resp == null || resp.statusCode != 200) return;
      final body = json.decode(resp.body) as Map<String, dynamic>;
      final inactive = body['status'] == 0;
      if (!mounted) return;
      if (inactive != isInactive) setState(() => isInactive = inactive);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('user_status', inactive ? 0 : 1);
    } catch (e) {
      debugPrint('Error checking user status: $e');
    }
  }

  Future<void> _contactAaramBD() async {
    try {
      final response = await Config.apiGet('/get_contact_info', context);
      if (response != null && response.statusCode == 200) {
        final data = json.decode(response.body);
        final String phone = (data['phone'] ?? '').toString().trim();
        if (phone.isNotEmpty) {
          final Uri telUri = Uri(scheme: 'tel', path: phone);
          if (await canLaunchUrl(telUri)) {
            await launchUrl(telUri);
            return;
          }
        }
      }
    } catch (_) {
      // fall through
    }
    if (!mounted) return;
    showAppToast(context, 'Could not open dialer. Please try again.',
        icon: Icons.error_outline_rounded);
  }

  // ── Page data fetch ────────────────────────────────────────────────────────
  Future<void> fetchPageData(int index) async {
    final ctx = context;
    switch (index) {
      case 0: break; // DescriptionLandingPage loads itself
      case 1: break; // Homepage loads itself
      case 2: break; // ShopsCart loads itself
      case 3: break; // UpdatePost loads itself
      case 4:
        final resp = await Config.apiGet('/get_service_data', ctx);
        if (resp != null && resp.statusCode == 200) {
          if (!mounted) return;
          setState(() { serviceData = resp.body; initializePages(); });
        }
        break;
      case 5:
        final resp = await Config.apiGet(
          '/get_user_by_phone?phone=$userPhone', ctx);
        if (resp != null && resp.statusCode == 200) {
          if (!mounted) return;
          setState(() { userData = resp.body; initializePages(); });
        }
        break;
    }
  }

  // ── Nested navigator helpers ───────────────────────────────────────────────

  /// Returns the [NavigatorState] key for the currently visible tab (0–5).
  GlobalKey<NavigatorState> get _currentNavKey {
    switch (pageIndex) {
      case 0: return _tab0Key;
      case 1: return _tab1Key;
      case 2: return _tab2Key;
      case 3: return _tab3Key;
      case 4: return _tab4Key;
      default: return _tab5Key;
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

  /// Pushes [page] onto the currently active tab's nested navigator, so
  /// drawer destinations (Favorites, Account Settings, etc.) render inside
  /// this Scaffold's body — keeping the outer AppBar and bottom nav dock
  /// visible — instead of replacing the whole NavigationScreen shell.
  void _pushInCurrentTab(Widget page) {
    _currentNavKey.currentState
        ?.push(MaterialPageRoute(builder: (_) => page));
  }

  // ── AppBar actions — all push into the active tab's nested navigator ────────

  /// Opens ThoughtSectionPage on the ROOT navigator (full-screen compose flow).


  /// Opens ShopsCart inside the active tab's navigator so the bottom nav
  /// remains visible while the user browses categories and shops.


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
  Widget _buildAppBarTitle() {
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
              _bellGlowController.stop();
            }
            if (!mounted) return;
            await _currentNavKey.currentState?.push(
              MaterialPageRoute(builder: (_) => const NotificationShow()),
            );
            await getUnreadCount();
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedBuilder(
                animation: Listenable.merge([_bellAnimation, _bellGlow]),
                builder: (_, child) {
                  final angle = unreadCount > 0 ? _bellAnimation.value : 0.0;
                  // Icon nudges slightly bigger at the peak of each swing —
                  // reads as a real bell being struck, not just rotating.
                  final scale = 1.0 + angle.abs() * 0.28;
                  final glow = unreadCount > 0 ? _bellGlow.value : 0.0;
                  return Transform.rotate(
                    angle: angle,
                    child: Transform.scale(
                      scale: scale,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: unreadCount > 0
                            ? BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.amber
                                        .withValues(alpha: 0.22 + glow * 0.28),
                                    spreadRadius: 1.5 + glow * 2.5,
                                    blurRadius: 8 + glow * 8,
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
                  );
                },
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

  // ──    nav item ────────────────────────────────────────────────────────
  Widget _buildNavItem({
    required bool isActive,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ── Pseudo-3D icon container ──────────────────────────────────────
          // Active: gradient fill + dual shadow (glow below + specular above)
          //         → appears raised from the surface.
          // Inactive: neutral tinted card + neumorphic shadow pair
          //           → appears slightly recessed.
          AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            width: isActive ? 50 : 42,
            height: isActive ? 36 : 32,
            decoration: isActive
                ? BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF4B80FF), // lighter at top-left (light source)
                        Color(0xFF1A56DB), // mid brand blue
                        Color(0xFF1240BE), // deeper at bottom-right (shadow side)
                      ],
                      stops: [0.0, 0.55, 1.0],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      // Primary coloured glow — creates elevation illusion
                      BoxShadow(
                        color: const Color(0xFF1A56DB).withValues(alpha: 0.46),
                        blurRadius: 18,
                        spreadRadius: 0,
                        offset: const Offset(0, 6),
                      ),
                      // Soft secondary spread for depth
                      BoxShadow(
                        color: const Color(0xFF1A56DB).withValues(alpha: 0.14),
                        blurRadius: 6,
                        spreadRadius: 2,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  )
                : BoxDecoration(
                    color: const Color(0xFFEEF1F8),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      // Dark shadow bottom-right (recessed depth)
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.07),
                        blurRadius: 7,
                        offset: const Offset(2, 3),
                      ),
                      // White highlight top-left (neumorphic lift — very subtle)
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.88),
                        blurRadius: 4,
                        offset: const Offset(-1, -1),
                      ),
                    ],
                  ),
            child: Center(
              child: Icon(
                icon,
                size: isActive ? 20 : 17,
                color: isActive ? Colors.white : const Color(0xFF8896B3),
              ),
            ),
          ),

          const SizedBox(height: 5),

          // ── Premium label ─────────────────────────────────────────────────
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: isActive ? 9.5 : 9.0,
              color: isActive
                  ? const Color(0xFF1A56DB)
                  : const Color(0xFFA0AABF),
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: isActive ? 0.30 : 0.15,
              inherit: false,
            ),
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    const navLabels = ['Live', 'Social', 'Gallery', 'Shops', 'Services', 'My Acc'];
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
          title: _buildAppBarTitle(),
        ),

        drawer: AppDrawer(userPhone: userPhone, onNavigate: _pushInCurrentTab),

        // ── Body — IndexedStack with 6 nested navigators ──────────────────────
        body: Stack(
          children: [
            IndexedStack(
              index: pageIndex,
              children: [
                _tabNav(_tab0Key, pages[0]), // Live
                _tabNav(_tab1Key, pages[1]), // Social
                _tabNav(_tab2Key, pages[2]), // Gallery
                _tabNav(_tab3Key, pages[3]), // Shops
                _tabNav(_tab4Key, pages[4]), // Services
                _tabNav(_tab5Key, pages[5]), // My Acc
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
                        'Loading...',
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
            if (isInactive)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Material(
                    color: const Color(0xFFB91C1C),
                    child: InkWell(
                      onTap: _contactAaramBD,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'You have been made inactive by AaramBD. '
                                'Please contact AaramBD.',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.call_rounded,
                                color: Colors.white, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),


        // ── Floating dock nav bar ─────────────────────────────────────────────
        // Wrapped in Padding to detach it from the screen edges — creates the
        // "floating dock" effect common in premium mobile apps.
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Container(
            decoration: BoxDecoration(
              // Fractionally off-white with a cool blue undertone — not pure
              // white, which reads as flat. This tint harmonises with _brand.
              color: const Color(0xFFFCFDFF),
              borderRadius: BorderRadius.circular(30),
              // Refined 1 px border — separates the dock from the page
              // without a heavy line.
              border: Border.all(
                color: const Color(0xFFE5E9F5),
                width: 1,
              ),
              boxShadow: [
                // Deep diffuse shadow — conveys that the bar floats above
                // the page content.
                BoxShadow(
                  color: const Color(0xFF1A2B6B).withValues(alpha: 0.09),
                  blurRadius: 32,
                  spreadRadius: 0,
                  offset: const Offset(0, 12),
                ),
                // Secondary tighter shadow — adds crispness at the base.
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 14,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
                  child: Row(
                    children: [
                      for (int i = 0; i < _navIcons.length; i++)
                        Expanded(
                          child: _buildNavItem(
                            isActive: pageIndex == i,
                            icon: _navIcons[i],
                            label: navLabels[i],
                            onTap: () {
                              if (pageIndex == i) {
                                refreshPage(i);
                              } else {
                                setState(() => pageIndex = i);
                                fetchPageData(i);
                                getUnreadCount();
                                _checkUserStatus();
                              }
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
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