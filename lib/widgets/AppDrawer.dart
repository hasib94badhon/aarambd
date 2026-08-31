import 'dart:convert';

import 'package:aaram_bd/config.dart';
import 'package:aaram_bd/pages/AccountControlPage.dart';
import 'package:aaram_bd/pages/AccountSettingsPage.dart';
import 'package:aaram_bd/pages/NotificationSettingsPage.dart';
import 'package:aaram_bd/screens/FavoriteProfilesPage.dart';
import 'package:aaram_bd/screens/AboutAaramBDPage.dart';
import 'package:aaram_bd/screens/login_screen.dart';
import 'package:aaram_bd/screens/navigation_screen.dart';
import 'package:aaram_bd/utils/auth_guard.dart';
import 'package:aaram_bd/widgets/termsPolicies.dart';
import 'package:aaram_bd/widgets/app_toast.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

final String host = Config.host;

class AppDrawer extends StatefulWidget {
  final String userPhone;

  /// Pushes [page] onto the currently active tab's nested navigator (see
  /// NavigationScreen._pushInCurrentTab), so drawer destinations keep the
  /// outer AppBar and bottom nav dock visible instead of replacing the
  /// whole navigation shell.
  final void Function(Widget page) onNavigate;

  const AppDrawer({Key? key, required this.userPhone, required this.onNavigate})
      : super(key: key);

  @override
  _AppDrawerState createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  String userName     = 'Loading...';
  String userPhotoUrl = '';
  String category     = 'Loading...';
  String userID       = '';
  bool   _isLoading   = true;

  static const Color _blue = Color(0xFF1A56DB);

  bool get _isGuest => widget.userPhone.isEmpty;

  @override
  void initState() {
    super.initState();
    if (_isGuest) {
      _isLoading = false;
    } else {
      _fetchProfile();
    }
  }

  Future<void> _fetchProfile() async {
    try {
      final res = await Config.apiGet(
        '/get_user_by_phone?phone=${widget.userPhone}',
        context,
      );
      if (res != null && res.statusCode == 200 && mounted) {
        final data = json.decode(res.body);
        setState(() {
          userName     = data['name']     ?? 'User Name';
          category     = data['cat_name'] ?? 'Category';
          userID       = data['user_id']?.toString() ?? '';
          userPhotoUrl = data['photo']    ?? '';
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  void _close() => Navigator.pop(context);

  void _push(Widget page) {
    _close();
    widget.onNavigate(page);
  }

  /// Account-based drawer destinations (favorites, settings, account
  /// control) go through here — guests get sent to sign in instead.
  Future<void> _pushIfLoggedIn(Widget page) async {
    if (_isGuest) {
      _close();
      final loggedIn = await requireLogin(context);
      if (loggedIn) await _refreshAsLoggedIn();
      return;
    }
    _push(page);
  }

  void _signIn() async {
    _close();
    final loggedIn = await requireLogin(context, message: 'Sign in to your account');
    if (loggedIn) await _refreshAsLoggedIn();
  }

  /// This drawer's parent NavigationScreen instance still has the old empty
  /// userPhone baked in from construction — swap in a freshly authenticated
  /// shell instead of trying to mutate state that was never meant to change.
  Future<void> _refreshAsLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('userPhone') ?? '';
    if (!mounted || phone.isEmpty) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => NavigationScreen(userPhone: phone)),
    );
  }

  Future<void> _logout() async {
    await Config.clearTokens();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userPhone');
    await prefs.setBool('isLoggedIn', false);
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => LoginScreen()),
      (_) => false,
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Drawer(
        width: MediaQuery.of(context).size.width * 0.88,
        child: Container(
          color: const Color(0xFFF0F4FF),
          child: Stack(children: [
            // Subtle background blobs
            Positioned(
              top: 160, left: -30,
              child: _Blob(size: 110, color: Colors.blue),
            ),
            Positioned(
              top: 310, right: -40,
              child: _Blob(size: 130, color: Colors.indigo),
            ),
            Positioned(
              bottom: 110, left: -25,
              child: _Blob(size: 85, color: Colors.lightBlue),
            ),

            Column(children: [
              _buildHeader(),
              Expanded(
                child: _isLoading
                    ? _buildShimmer()
                    : _buildBody(),
              ),
            ]),
          ]),
        ),
      ),

      // Close handle on right edge
      Positioned(
        right: 0,
        top: MediaQuery.of(context).size.height / 2 - 28,
        child: GestureDetector(
          onTap: _close,
          child: Container(
            width: 28, height: 56,
            decoration: const BoxDecoration(
              color: _blue,
              borderRadius: BorderRadius.only(
                topLeft:    Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(-2, 2))],
            ),
            child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 16),
          ),
        ),
      ),
    ]);
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 52, bottom: 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_blue, Colors.indigo.shade900],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft:  Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16, offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(children: [
        Positioned(
          top: -12, right: -10,
          child: _Blob(size: 70, color: Colors.white, opacity: 0.10),
        ),
        Positioned(
          bottom: -18, left: -12,
          child: _Blob(size: 90, color: Colors.white, opacity: 0.08),
        ),
        Row(children: [
          // Avatar
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.30),
                  blurRadius: 10, spreadRadius: 2,
                ),
              ],
            ),
            child: ClipOval(
              child: _isLoading
                  ? Shimmer.fromColors(
                      baseColor: Colors.grey.shade300,
                      highlightColor: Colors.grey.shade100,
                      child: Container(color: Colors.white))
                  : userPhotoUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: userPhotoUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: Colors.grey.shade200),
                          errorWidget: (_, __, ___) => const _DefaultAvatar(),
                        )
                      : const _DefaultAvatar(),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_isGuest ? 'Guest' : userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 3),
              Text(_isGuest ? 'Sign in to get started' : category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.80))),
            ]),
          ),
        ]),
      ]),
    );
  }

  // ── Body ─────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 24),
      children: [
        // ── Favorite Contacts ─────────────────────────────────────────────
        _DrawerItem(
          icon: Icons.favorite_rounded,
          iconColor: const Color(0xFFDB2777),
          bgColor: const Color(0xFFFFF0F6),
          borderColor: const Color(0xFFFBCFE8),
          title: 'Favorite Contacts',
          onTap: () async {
            if (_isGuest) {
              await requireLogin(context);
              return;
            }
            if (userID.isEmpty) {
              showAppToast(context, 'User ID not loaded yet',
                  icon: Icons.error_outline_rounded);
              return;
            }
            _push(FavoriteProfilesPage(userId: userID));
          },
        ),

        const SizedBox(height: 20),

        // ── Settings section header ───────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Row(children: [
            Container(
              width: 3, height: 16,
              decoration: BoxDecoration(
                  color: _blue, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 8),
            const Text('Settings',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF374151),
                    letterSpacing: 1.1)),
          ]),
        ),

        // ── Account Settings ─────────────────────────────────────────────
        _DrawerItem(
          icon: Icons.manage_accounts_rounded,
          iconColor: _blue,
          bgColor: const Color(0xFFEFF6FF),
          borderColor: const Color(0xFFBFDBFE),
          title: 'Account Settings',
          subtitle: 'Phone, email, password',
          onTap: () => _pushIfLoggedIn(AccountSettingsPage()),
        ),

        // ── Notification Settings ────────────────────────────────────────
        _DrawerItem(
          icon: Icons.notifications_none_rounded,
          iconColor: const Color(0xFFF97316),
          bgColor: const Color(0xFFFFF7ED),
          borderColor: const Color(0xFFFED7AA),
          title: 'Notification Settings',
          subtitle: 'Choose what you get notified about',
          onTap: () => _pushIfLoggedIn(const NotificationSettingsPage()),
        ),

        // ── Terms & Policies ─────────────────────────────────────────────
        _DrawerItem(
          icon: Icons.gavel_rounded,
          iconColor: const Color(0xFF7C3AED),
          bgColor: const Color(0xFFF5F3FF),
          borderColor: const Color(0xFFDDD6FE),
          title: 'Terms & Policies',
          subtitle: 'Terms of service and privacy',
          onTap: () => _push(TermsPolicies()),
        ),

        // ── About AaramBD ─────────────────────────────────────────────────
        _DrawerItem(
          icon: Icons.info_outline_rounded,
          iconColor: const Color(0xFF0891B2),
          bgColor: const Color(0xFFECFEFF),
          borderColor: const Color(0xFFA5F3FC),
          title: 'About AaramBD',
          subtitle: 'Our mission and vision',
          onTap: () => _push(AboutAaramBDPage()),
        ),

        // ── Account Control ──────────────────────────────────────────────
        _DrawerItem(
          icon: Icons.delete_forever_rounded,
          iconColor: const Color(0xFFDC2626),
          bgColor: const Color(0xFFFFF5F5),
          borderColor: const Color(0xFFFECACA),
          title: 'Account Control',
          subtitle: 'Deactivate account',
          onTap: () => _pushIfLoggedIn(AccountControlPage()),
        ),

        const SizedBox(height: 28),

        // ── Log Out / Sign In ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: _isGuest
                  ? const LinearGradient(
                      colors: [Color(0xFF1040B0), _blue],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight)
                  : const LinearGradient(
                      colors: [Color(0xFFEF4444), Color(0xFFEA580C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: (_isGuest ? _blue : const Color(0xFFEF4444))
                        .withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 5)),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _isGuest ? _signIn : _logout,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                          _isGuest
                              ? Icons.login_rounded
                              : Icons.logout_rounded,
                          color: Colors.white,
                          size: 20),
                      const SizedBox(width: 10),
                      Text(_isGuest ? 'Sign In' : 'Log Out',
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.4)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Shimmer ───────────────────────────────────────────────────────────────

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        itemCount: 6,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Drawer item tile
// ─────────────────────────────────────────────────────────────────────────────

class _DrawerItem extends StatelessWidget {
  final IconData  icon;
  final Color     iconColor;
  final Color     bgColor;
  final Color     borderColor;
  final String    title;
  final String?   subtitle;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.borderColor,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: iconColor.withValues(alpha: 0.10),
              blurRadius: 10, offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(children: [
                // Icon bubble
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 14),
                // Text
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827))),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!,
                          style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w500)),
                    ],
                  ]),
                ),
                // Arrow
                Icon(Icons.chevron_right_rounded,
                    size: 20, color: iconColor.withValues(alpha: 0.55)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Helpers
// ─────────────────────────────────────────────────────────────────────────────

class _Blob extends StatelessWidget {
  final double size;
  final Color  color;
  final double opacity;

  const _Blob({required this.size, required this.color, this.opacity = 0.15});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
          color: color.withValues(alpha: opacity), shape: BoxShape.circle),
    );
  }
}

class _DefaultAvatar extends StatelessWidget {
  const _DefaultAvatar();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE0E7FF),
      child: const Icon(Icons.person_rounded, size: 40, color: Color(0xFF6366F1)),
    );
  }
}
