import 'dart:convert';

import 'package:aaram_bd/config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─── Colours ────────────────────────────────────────────────────────────────
const _kPrimary     = Color(0xFF2563EB);
const _kPrimaryDark = Color(0xFF1E40AF);
const _kBg          = Color(0xFFF1F5F9);
const _kSurface     = Colors.white;
const _kSuccess     = Color(0xFF059669);
const _kWarning     = Color(0xFFF59E0B);
const _kError       = Color(0xFFDC2626);
const _kMuted       = Color(0xFF94A3B8);
const _kText        = Color(0xFF0F172A);
const _kSubtext     = Color(0xFF475569);

class DataCollectorLearnMorePage extends StatefulWidget {
  const DataCollectorLearnMorePage({Key? key}) : super(key: key);

  @override
  State<DataCollectorLearnMorePage> createState() =>
      _DataCollectorLearnMorePageState();
}

class _DataCollectorLearnMorePageState
    extends State<DataCollectorLearnMorePage> {
  // ── Referral state ──────────────────────────────────────────────────────
  List<Map<String, dynamic>> _referrals = [];
  String _referenceNumber = '';
  int _totalPoints  = 0;
  int _paidPoints   = 0;
  int _unpaidPoints = 0;
  String _selectedFilter = 'All';
  bool _loadingReferrals = true;

  // ── Instructions state ──────────────────────────────────────────────────
  String _instrEnglish = '';
  String _instrBangla  = '';
  bool _loadingInstructions = true;

  // ── Contact info state ───────────────────────────────────────────────────
  Map<String, String> _contact = {
    'phone':    '01679-374433',
    'email':    'support@aarambd.com',
    'address':  'Uttara, Dhaka',
    'website':  '',
    'facebook': '',
  };

  @override
  void initState() {
    super.initState();
    _fetchReferrals();
    _fetchInstructions();
    _fetchContact();
  }

  // ── Data fetching ───────────────────────────────────────────────────────

  Future<void> _fetchReferrals() async {
    setState(() => _loadingReferrals = true);
    final userId = await Config.getLoggedInUser();
    if (!mounted) return;
    if (userId == null) {
      setState(() => _loadingReferrals = false);
      return;
    }
    try {
      final resp = await Config.apiGet('/get_user_referrals?user_id=$userId', context);
      if (resp != null && resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        final rawList = (data['referrals'] as List<dynamic>? ?? []);

        final parsed = rawList.map<Map<String, dynamic>>((e) {
          final m = e as Map<String, dynamic>;
          String photo = '';
          final raw = m['profile_photo'];
          if (raw is String && raw.isNotEmpty) photo = raw.split(',').first;
          return {
            'referral_id':       (m['referral_id']       ?? '').toString(),
            'referred_name':     (m['referred_name']     ?? '').toString(),
            'referred_category': (m['referred_category'] ?? '').toString(),
            'payment_status':    (m['payment_status']    ?? '').toString(),
            'points':            int.tryParse('${m['points']}') ?? 0,
            'timestamp':         (m['timestamp']         ?? '').toString(),
            'profile_photo':     photo,
            'verification':      (m['verification']      ?? '').toString(),
          };
        }).toList();

        parsed.sort((a, b) {
          final ap = a['payment_status'] as String;
          final bp = b['payment_status'] as String;
          if (ap != bp) return ap == 'unpaid' ? -1 : 1;
          return (a['referred_category'] as String)
              .compareTo(b['referred_category'] as String);
        });

        if (mounted) {
          setState(() {
            _referrals       = parsed;
            _referenceNumber = (data['user_self_referral_id'] ?? '').toString();
            _totalPoints     = int.tryParse('${data['total_points']}') ?? 0;
            _paidPoints      = int.tryParse('${data['paid_points']}')  ?? 0;
            _unpaidPoints    = int.tryParse('${data['unpaid_points']}') ?? 0;
          });
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingReferrals = false);
  }

  Future<void> _fetchInstructions() async {
    setState(() => _loadingInstructions = true);
    try {
      final resp = await Config.apiGet('/get_data_collector_instructions', context);
      if (resp != null && resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _instrEnglish = (data['english'] ?? '').toString();
            _instrBangla  = (data['bangla']  ?? '').toString();
          });
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingInstructions = false);
  }

  Future<void> _fetchContact() async {
    try {
      final resp = await Config.apiGet('/get_contact_info', context);
      if (resp != null && resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _contact = {
              'phone':    (data['phone']    ?? '').toString(),
              'email':    (data['email']    ?? '').toString(),
              'address':  (data['address']  ?? '').toString(),
              'website':  (data['website']  ?? '').toString(),
              'facebook': (data['facebook'] ?? '').toString(),
            };
          });
        }
      }
    } catch (_) {}
  }

  // ── Instructions bottom sheet ───────────────────────────────────────────

  void _openInstructions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _InstructionsSheet(
        english:       _instrEnglish,
        bangla:        _instrBangla,
        isLoading:     _loadingInstructions,
        referenceCode: _referenceNumber,
        contact:       _contact,
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> get _displayed {
    final sel = _selectedFilter.toLowerCase();
    return _referrals.where((r) {
      final pay = (r['payment_status'] as String).toLowerCase();
      final ver = (r['verification']   as String).toLowerCase();
      switch (sel) {
        case 'paid':       return pay == 'paid';
        case 'unpaid':     return pay == 'unpaid';
        case 'waiting':    return ver == 'waiting';
        case 'verified':   return ver == 'verified';
        case 'unverified': return ver == 'unverified';
        default:           return true;
      }
    }).toList();
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Data Collector',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              _fetchReferrals();
              _fetchInstructions();
            },
          ),
        ],
      ),
      body: _loadingReferrals
          ? const Center(child: CircularProgressIndicator(color: _kPrimary))
          : RefreshIndicator(
              color: _kPrimary,
              onRefresh: () async {
                await Future.wait([_fetchReferrals(), _fetchInstructions()]);
              },
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        _HeroCard(
                          referenceNumber: _referenceNumber,
                          totalPoints:     _totalPoints,
                          paidPoints:      _paidPoints,
                          unpaidPoints:    _unpaidPoints,
                          loadingInstr:    _loadingInstructions,
                          onInstructions:  _openInstructions,
                        ),
                        _FilterBar(
                          selected:  _selectedFilter,
                          onChanged: (f) => setState(() => _selectedFilter = f),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                          child: Row(
                            children: [
                              const Text(
                                'Referral History',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: _kText,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _kPrimary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${_displayed.length}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _kPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  _displayed.isEmpty
                      ? SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.group_off_rounded,
                                    size: 56, color: _kMuted),
                                const SizedBox(height: 12),
                                const Text(
                                  'No referrals yet',
                                  style: TextStyle(
                                    color: _kSubtext,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Share your referral code to get started',
                                  style: TextStyle(
                                      color: _kMuted, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SliverPadding(
                          padding:
                              const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, i) =>
                                  _ReferralCard(data: _displayed[i]),
                              childCount: _displayed.length,
                            ),
                          ),
                        ),
                ],
              ),
            ),
    );
  }
}

// ─── Hero card ──────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final String       referenceNumber;
  final int          totalPoints;
  final int          paidPoints;
  final int          unpaidPoints;
  final bool         loadingInstr;
  final VoidCallback onInstructions;

  const _HeroCard({
    required this.referenceNumber,
    required this.totalPoints,
    required this.paidPoints,
    required this.unpaidPoints,
    required this.loadingInstr,
    required this.onInstructions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kPrimary, _kPrimaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _kPrimary.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Reference number row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your Referral Code',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              referenceNumber.isEmpty ? '—' : referenceNumber,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (referenceNumber.isNotEmpty)
                            IconButton(
                              tooltip: 'Copy code',
                              icon: const Icon(Icons.copy_rounded,
                                  size: 18, color: Colors.white70),
                              onPressed: () async {
                                await Clipboard.setData(
                                    ClipboardData(text: referenceNumber));
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Referral code copied'),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Instructions button
                GestureDetector(
                  onTap: onInstructions,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        loadingInstr
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white),
                              )
                            : const Icon(Icons.menu_book_rounded,
                                size: 16, color: Colors.white),
                        const SizedBox(width: 6),
                        const Text(
                          'Instructions',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          Divider(
            color: Colors.white.withValues(alpha: 0.2),
            height: 1,
            indent: 20,
            endIndent: 20,
          ),

          // Points pills
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
            child: Row(
              children: [
                _PointPill(
                  label: 'Total',
                  value: totalPoints,
                  icon: Icons.stars_rounded,
                  color: Colors.white,
                ),
                const SizedBox(width: 10),
                _PointPill(
                  label: 'Paid',
                  value: paidPoints,
                  icon: Icons.check_circle_rounded,
                  color: const Color(0xFF6EE7B7),
                ),
                const SizedBox(width: 10),
                _PointPill(
                  label: 'Pending',
                  value: unpaidPoints,
                  icon: Icons.hourglass_top_rounded,
                  color: const Color(0xFFFDE68A),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PointPill extends StatelessWidget {
  final String   label;
  final int      value;
  final IconData icon;
  final Color    color;

  const _PointPill({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(
              '$value pts',
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color.withValues(alpha: 0.8),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Filter bar ─────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final String                 selected;
  final ValueChanged<String>   onChanged;

  const _FilterBar({required this.selected, required this.onChanged});

  static const _filters = [
    'All', 'Unpaid', 'Paid', 'Waiting', 'Verified', 'Unverified',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final f      = _filters[i];
          final active = selected == f;
          return GestureDetector(
            onTap: () => onChanged(f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: active ? _kPrimary : _kSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: active ? _kPrimary : const Color(0xFFE2E8F0)),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: _kPrimary.withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : [],
              ),
              child: Text(
                f,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : _kSubtext,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Referral card ───────────────────────────────────────────────────────────

class _ReferralCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ReferralCard({required this.data});

  Color _verColor(String v) {
    switch (v.toLowerCase()) {
      case 'verified':   return _kSuccess;
      case 'unverified': return _kError;
      default:           return _kWarning;
    }
  }

  IconData _verIcon(String v) {
    switch (v.toLowerCase()) {
      case 'verified':   return Icons.verified_rounded;
      case 'unverified': return Icons.cancel_rounded;
      default:           return Icons.hourglass_top_rounded;
    }
  }

  Color _catColor(String cat) {
    final k = cat.toLowerCase();
    if (k.contains('electric'))  return Colors.indigo;
    if (k.contains('plumb'))     return Colors.teal;
    if (k.contains('carp'))      return Colors.orange;
    if (k.contains('user'))      return Colors.purple;
    return _kPrimary;
  }

  String _cap(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}';

  @override
  Widget build(BuildContext context) {
    final photo      = (data['profile_photo'] as String?) ?? '';
    final name       = (data['referred_name'] as String?) ?? '—';
    final category   = (data['referred_category'] as String?) ?? '—';
    final payStatus  = (data['payment_status'] as String?) ?? '';
    final verStatus  = (data['verification'] as String?) ?? '';
    final points     = data['points'] as int;
    final timeAgo    = Config.getTimeDifference(data['timestamp'] as String);

    final isPaid     = payStatus.toLowerCase() == 'paid';
    final catColor   = _catColor(category);
    final verColor   = _verColor(verStatus);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Accent strip
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: isPaid ? _kSuccess : _kWarning,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 26,
                  backgroundColor: catColor.withValues(alpha: 0.1),
                  foregroundImage:
                      photo.isNotEmpty ? NetworkImage(photo) : null,
                  child: photo.isEmpty
                      ? Icon(Icons.person_rounded,
                          color: catColor, size: 26)
                      : null,
                ),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _kText,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: catColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: catColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded,
                              size: 12, color: _kMuted),
                          const SizedBox(width: 4),
                          Text(timeAgo,
                              style: const TextStyle(
                                  fontSize: 12, color: _kMuted)),
                        ],
                      ),
                    ],
                  ),
                ),

                // Right: points + badges
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_kPrimary, _kPrimaryDark],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$points pts',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_verIcon(verStatus),
                            size: 12, color: verColor),
                        const SizedBox(width: 4),
                        Text(
                          _cap(verStatus),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: verColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isPaid
                            ? _kSuccess.withValues(alpha: 0.1)
                            : _kError.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isPaid
                              ? _kSuccess.withValues(alpha: 0.3)
                              : _kError.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Text(
                        isPaid ? 'PAID' : 'UNPAID',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isPaid ? _kSuccess : _kError,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Instructions bottom sheet ───────────────────────────────────────────────

class _InstructionsSheet extends StatefulWidget {
  final String              english;
  final String              bangla;
  final bool                isLoading;
  final String              referenceCode;
  final Map<String, String> contact;

  const _InstructionsSheet({
    required this.english,
    required this.bangla,
    required this.isLoading,
    required this.referenceCode,
    required this.contact,
  });

  @override
  State<_InstructionsSheet> createState() => _InstructionsSheetState();
}

class _InstructionsSheetState extends State<_InstructionsSheet> {
  bool _showBangla = false;

  @override
  void initState() {
    super.initState();
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    _showBangla = locale.languageCode.toLowerCase().startsWith('bn');
  }

  List<String> _lines(String text) {
    // Try newline split first (preferred format)
    final byNewline = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (byNewline.length > 1) return byNewline;

    // Fallback: split on "., " or ".," which separates steps stored as one line
    final byComma = text
        .split(RegExp(r'\.,\s*'))
        .map((l) => l.trim().replaceAll(RegExp(r'^,\s*'), ''))
        .where((l) => l.isNotEmpty)
        .toList();
    if (byComma.length > 1) return byComma;

    // Last resort: return as single item
    return [text.trim()];
  }

  @override
  Widget build(BuildContext context) {
    final content = _showBangla ? widget.bangla : widget.english;
    final lines   = _lines(content);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          // Sheet header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 16, 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _kPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.menu_book_rounded,
                      size: 18, color: _kPrimary),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Data Collector Instructions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _kText,
                        ),
                      ),
                      Text(
                        'Guidelines from AaramBD',
                        style: TextStyle(fontSize: 12, color: _kMuted),
                      ),
                    ],
                  ),
                ),
                // Language toggle
                Container(
                  decoration: BoxDecoration(
                    color: _kBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: ToggleButtons(
                    isSelected: [!_showBangla, _showBangla],
                    borderRadius: BorderRadius.circular(9),
                    selectedColor: Colors.white,
                    fillColor: _kPrimary,
                    color: _kSubtext,
                    constraints:
                        const BoxConstraints(minWidth: 48, minHeight: 34),
                    onPressed: (i) =>
                        setState(() => _showBangla = i == 1),
                    children: const [
                      Text('EN',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                      Text('বাংলা',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Content area
          Expanded(
            child: widget.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: _kPrimary))
                : content.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.info_outline_rounded,
                                size: 40, color: _kMuted),
                            SizedBox(height: 8),
                            Text(
                              'Instructions not available yet',
                              style: TextStyle(color: _kSubtext),
                            ),
                          ],
                        ),
                      )
                    : ListView(
                        controller: controller,
                        padding:
                            const EdgeInsets.fromLTRB(20, 16, 20, 24),
                        children: [
                          if (widget.referenceCode.isNotEmpty)
                            _CodeReminder(code: widget.referenceCode),
                          const SizedBox(height: 16),
                          ...List.generate(
                            lines.length,
                            (i) => _StepTile(
                                number: i + 1, text: lines[i]),
                          ),
                          const SizedBox(height: 20),
                          _ContactCard(contact: widget.contact),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

// ─── Code reminder chip ──────────────────────────────────────────────────────

class _CodeReminder extends StatelessWidget {
  final String code;
  const _CodeReminder({required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _kPrimary.withValues(alpha: 0.08),
            _kPrimary.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kPrimary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.badge_rounded, color: _kPrimary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Referral Code',
                  style: TextStyle(
                    fontSize: 11,
                    color: _kPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  code,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _kText,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copy',
            icon:
                const Icon(Icons.copy_rounded, size: 18, color: _kPrimary),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Code copied'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

// ─── Step tile ───────────────────────────────────────────────────────────────

class _StepTile extends StatelessWidget {
  final int    number;
  final String text;
  const _StepTile({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: _kPrimary,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 14,
                  color: _kSubtext,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Contact card ────────────────────────────────────────────────────────────

class _ContactCard extends StatelessWidget {
  final Map<String, String> contact;
  const _ContactCard({required this.contact});

  @override
  Widget build(BuildContext context) {
    final rows = <({IconData icon, String text})>[];
    if ((contact['address'] ?? '').isNotEmpty) {
      rows.add((icon: Icons.location_on_outlined, text: contact['address']!));
    }
    if ((contact['phone'] ?? '').isNotEmpty) {
      rows.add((icon: Icons.phone_outlined, text: contact['phone']!));
    }
    if ((contact['email'] ?? '').isNotEmpty) {
      rows.add((icon: Icons.email_outlined, text: contact['email']!));
    }
    if ((contact['website'] ?? '').isNotEmpty) {
      rows.add((icon: Icons.language_outlined, text: contact['website']!));
    }
    if ((contact['facebook'] ?? '').isNotEmpty) {
      rows.add((icon: Icons.facebook_outlined, text: contact['facebook']!));
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.support_agent_rounded, size: 18, color: _kPrimary),
              SizedBox(width: 8),
              Text(
                'Contact AaramBD',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _kText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...rows.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _ContactRow(icon: r.icon, text: r.text),
              )),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String   text;
  const _ContactRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _kPrimary),
        const SizedBox(width: 8),
        Flexible(
          child: Text(text,
              style: const TextStyle(fontSize: 13, color: _kSubtext)),
        ),
      ],
    );
  }
}
