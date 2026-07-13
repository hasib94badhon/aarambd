import 'package:aaram_bd/services/notification_prefs_service.dart';
import 'package:aaram_bd/widgets/app_toast.dart';
import 'package:flutter/material.dart';

const Color _brand = Color(0xFF1A56DB);

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({Key? key}) : super(key: key);

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  NotificationPrefs? _prefs;
  bool _loading = true;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    final prefs = await NotificationPrefsService.fetch(context);
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _loadFailed = prefs == null;
      _loading = false;
    });
  }

  Future<void> _toggle(String key, bool value, NotificationPrefs updated) async {
    final previous = _prefs;
    setState(() => _prefs = updated);

    final ok = await NotificationPrefsService.update(context, {key: value});
    if (!mounted) return;

    if (!ok) {
      setState(() => _prefs = previous);
      showAppToast(context, 'Could not save — please try again.',
          icon: Icons.error_outline_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FF),
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          _buildHeader(),
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: _brand)),
            )
          else if (_loadFailed || _prefs == null)
            SliverFillRemaining(child: _buildError())
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                  16, 18, 16, 20 + MediaQuery.of(context).padding.bottom),
              sliver: SliverList(
                delegate: SliverChildListDelegate(_buildToggleTiles()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return SliverToBoxAdapter(
      child: Container(
        padding: EdgeInsets.fromLTRB(
            16, MediaQuery.of(context).padding.top + 14, 16, 22),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1040B0), Color(0xFF1A56DB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        ),
        child: Row(
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
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notification Settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Choose what you get notified about',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
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

  List<Widget> _buildToggleTiles() {
    final prefs = _prefs!;
    return [
      _ToggleTile(
        icon: Icons.visibility_rounded,
        iconColor: const Color(0xFF1A56DB),
        title: 'Profile Activity',
        subtitle: 'Someone viewed or shared your profile',
        value: prefs.profileActivity,
        onChanged: (v) => _toggle('notif_profile_activity', v,
            prefs.copyWith(profileActivity: v)),
      ),
      _ToggleTile(
        icon: Icons.rate_review_rounded,
        iconColor: const Color(0xFF7C3AED),
        title: 'Comments & Reviews',
        subtitle: 'New comments and reviews on your profile',
        value: prefs.social,
        onChanged: (v) => _toggle('notif_social', v, prefs.copyWith(social: v)),
      ),
      _ToggleTile(
        icon: Icons.dashboard_rounded,
        iconColor: const Color(0xFF0891B2),
        title: 'Category Updates',
        subtitle: 'New posts in categories you belong to',
        value: prefs.categoryUpdates,
        onChanged: (v) => _toggle(
            'notif_category_updates', v, prefs.copyWith(categoryUpdates: v)),
      ),
      _ToggleTile(
        icon: Icons.local_offer_rounded,
        iconColor: const Color(0xFFF97316),
        title: 'Offers & Announcements',
        subtitle: 'Promotions, upgrade nudges, and app news',
        value: prefs.promotional,
        onChanged: (v) =>
            _toggle('notif_promotional', v, prefs.copyWith(promotional: v)),
      ),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFBFDBFE)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, size: 18, color: _brand),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Calls and subscription status updates always stay on, so you never miss a lead or an important account change.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF374151),
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: Color(0xFFEDF4FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded, size: 40, color: _brand),
            ),
            const SizedBox(height: 16),
            const Text(
              'Unable to load settings',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Check your internet connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _brand,
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: _brand,
          ),
        ],
      ),
    );
  }
}
