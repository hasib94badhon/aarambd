import 'dart:convert';

import 'package:aaram_bd/config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

/// ===== Language + i18n helpers (compile-safe) =====
enum _Lang { en, bn }

class _I18n {
  static final Map<_Lang, String> title = {
    _Lang.en: 'Instructions',
    _Lang.bn: 'নির্দেশাবলী',
  };

  static final Map<_Lang, List<String>> steps = {
    _Lang.en: const [
      'Collect data for the following categories: Electrician, Plumber, Sanitary, etc.',
      'Create accounts using your reference number.',
      'Update each account and select the mentioned categories properly.',
      'Explain AaramBD features clearly to the service provider/shop owner.',
      'Avoid duplication and fake entries. Duplicates or fake accounts may be banned.',
      'Payment per valid account: ৳2 (user) and ৳5 (per category profile).',
      'Payments are processed every 100 valid accounts.',
    ],
    _Lang.bn: const [
      'নিম্নোক্ত ক্যাটাগরির জন্য ডেটা সংগ্রহ করুন: ইলেকট্রিশিয়ান, প্লাম্বার, স্যানিটারি ইত্যাদি।',
      'আপনার রেফারেন্স নম্বর ব্যবহার করে অ্যাকাউন্ট তৈরি করুন।',
      'প্রতিটি অ্যাকাউন্ট আপডেট করুন এবং উল্লেখিত ক্যাটাগরি সঠিকভাবে নির্বাচন করুন।',
      'সার্ভিস প্রোভাইডার/দোকানদারকে AaramBD-এর সুবিধাগুলো পরিষ্কারভাবে বুঝিয়ে দিন।',
      'ডুপ্লিকেট বা ভুয়া এন্ট্রি এড়িয়ে চলুন। ডুপ্লিকেট/ভুয়া অ্যাকাউন্ট ব্যান করা হতে পারে।',
      'প্রতি বৈধ অ্যাকাউন্টে পেমেন্ট: ৳২ (ইউজার) এবং ৳৫ (প্রতি ক্যাটাগরি প্রোফাইল)।',
      'প্রতি ১০০টি বৈধ অ্যাকাউন্ট পূর্ণ হলে পেমেন্ট প্রসেস করা হবে।',
    ],
  };

  static final Map<_Lang, Map<String, String>> contact = {
    _Lang.en: const {
      'title': 'Contact AaramBD',
      'office': 'Office: Uttara, Dhaka',
      'phoneLabel': 'Phone:',
      'phone': '01679-374433',
      'emailLabel': 'Email:',
      'email': 'support@aarambd.com',
    },
    _Lang.bn: const {
      'title': 'যোগাযোগ — AaramBD',
      'office': 'অফিস: উত্তরা, ঢাকা',
      'phoneLabel': 'ফোন:',
      'phone': '01679-374433',
      'emailLabel': 'ইমেইল:',
      'email': 'support@aarambd.com',
    },
  };
}

class DataCollectorLearnMorePage extends StatefulWidget {
  const DataCollectorLearnMorePage({Key? key}) : super(key: key);

  @override
  State<DataCollectorLearnMorePage> createState() =>
      _DataCollectorLearnMorePageState();
}

class _DataCollectorLearnMorePageState
    extends State<DataCollectorLearnMorePage> {
  List<Map<String, dynamic>> _referrals = [];
  String _referenceNumber = '';
  int _totalPoints = 0;
  int _paidPoints = 0;
  int _unpaidPoints = 0;
  String _selectedFilter = 'All';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchReferrals();
  }

  Future<void> _fetchReferrals() async {
    setState(() => _loading = true);

    final userId = await Config.getLoggedInUser();
    if (userId == null) {
      setState(() => _loading = false);
      return;
    }

    final uri = '/get_user_referrals?user_id=$userId';
    try {
      final resp = await Config.apiGet(uri, context);
      if (resp != null && resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        final rawList = (data['referrals'] as List<dynamic>? ?? []);

        final parsed = rawList.map<Map<String, dynamic>>((e) {
          final m = e as Map<String, dynamic>;
          // Safe parse of profile_photo (keeps your logic intent)
          String photo = '';
          final raw = m['profile_photo'];
          if (raw is String && raw.isNotEmpty) {
            photo = raw.split(',').first;
          }

          return {
            'referral_id': (m['referral_id'] ?? '').toString(),
            'referred_name': (m['referred_name'] ?? '').toString(),
            'referred_category': (m['referred_category'] ?? '').toString(),
            'payment_status': (m['payment_status'] ?? '').toString(),
            'points': int.tryParse('${m['points']}') ?? 0,
            'timestamp': (m['timestamp'] ?? '').toString(),
            'profile_photo': photo,
            'verification': (m['verification'] ?? '').toString(),
          };
        }).toList();

        // Sort (unpaid first, then category)
        parsed.sort((a, b) {
          final ap = a['payment_status'];
          final bp = b['payment_status'];
          if (ap != bp) return ap == 'unpaid' ? -1 : 1;
          return (a['referred_category'] as String)
              .compareTo(b['referred_category'] as String);
        });

        setState(() {
          _referrals = parsed;
          _referenceNumber = (data['user_self_referral_id'] ?? '').toString();
          _totalPoints = int.tryParse('${data['total_points']}') ?? 0;
          _paidPoints = int.tryParse('${data['paid_points']}') ?? 0;
          _unpaidPoints = int.tryParse('${data['unpaid_points']}') ?? 0;
        });
      }
    } catch (_) {
      // keep silent; logic unchanged
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showInstructions(BuildContext ctx) {
    // Pick default language from locale
    _Lang current =
        Localizations.localeOf(ctx).languageCode.toLowerCase().startsWith('bn')
            ? _Lang.bn
            : _Lang.en;

    showModalBottomSheet(
      context: ctx,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final steps = _I18n.steps[current]!;
            final contact = _I18n.contact[current]!;

            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 8,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + Language toggle
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _I18n.title[current]!,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF6F7FB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.black12.withValues(alpha: 0.08),
                            ),
                          ),
                          child: ToggleButtons(
                            isSelected: [
                              current == _Lang.en,
                              current == _Lang.bn
                            ],
                            borderRadius: BorderRadius.circular(10),
                            constraints: const BoxConstraints(
                              minHeight: 36,
                              minWidth: 56,
                            ),
                            onPressed: (i) {
                              setModalState(() {
                                current = i == 0 ? _Lang.en : _Lang.bn;
                              });
                            },
                            children: const [
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6),
                                child: Text('EN'),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6),
                                child: Text('বাংলা'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Steps
                    for (int i = 0; i < steps.length; i++)
                      _stepTile(i + 1, steps[i]),

                    const SizedBox(height: 16),

                    // Contact card
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(contact['title']!,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined,
                                  size: 18, color: const Color(0xFF1A56DB)),
                              const SizedBox(width: 6),
                              Expanded(child: Text(contact['office']!)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.phone_outlined,
                                  size: 18, color: const Color(0xFF1A56DB)),
                              const SizedBox(width: 6),
                              Text(
                                  '${contact['phoneLabel']} ${contact['phone']}'),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.email_outlined,
                                  size: 18, color: const Color(0xFF1A56DB)),
                              const SizedBox(width: 6),
                              Text(
                                  '${contact['emailLabel']} ${contact['email']}'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Color _accentFor(String cat) {
    final k = cat.toLowerCase();
    if (k.contains('electric')) return Colors.indigo;
    if (k.contains('plumb')) return Colors.teal;
    if (k.contains('carp')) return Colors.orange;
    if (k.contains('user')) return Colors.purple;
    return Colors.blueGrey;
  }

  Widget _statPill({
    required IconData icon,
    required String label,
    required String value,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: const Color(0xFF1A56DB)),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                value,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final filters = <String>[
      'All',
      'Paid',
      'Unpaid',
      'Waiting',
      'Verified',
      'Unverified',
    ];

    // Apply filter (logic unchanged)
    final displayed = _referrals.where((r) {
      final payStatus = (r['payment_status'] as String).toLowerCase();
      final verStatus = (r['verification'] as String).toLowerCase();
      final sel = _selectedFilter.toLowerCase();

      switch (sel) {
        case 'paid':
          return payStatus == 'paid';
        case 'unpaid':
          return payStatus == 'unpaid';
        case 'waiting':
          return verStatus == 'waiting';
        case 'verified':
          return verStatus == 'verified';
        case 'unverified':
          return verStatus == 'unverified';
        default:
          return true;
      }
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Data Collector')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header card
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.white, Colors.blue.shade50],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.blue.shade100),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            // Reference number
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Reference Number',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _referenceNumber,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 1.1,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Copy',
                                        onPressed: () async {
                                          await Clipboard.setData(
                                            ClipboardData(
                                                text: _referenceNumber),
                                          );
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(const SnackBar(
                                                  content: Text(
                                                      'Reference number copied')));
                                        },
                                        icon: const Icon(Icons.copy_rounded),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            FilledButton.icon(
                              onPressed: () => _showInstructions(context),
                              icon: const Icon(Icons.menu_book_outlined,
                                  size: 18),
                              label: const Text('Instructions'),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Stats
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _statPill(
                                icon: Icons.collections_bookmark_outlined,
                                label: 'Total Points',
                                value: _totalPoints.toString().padLeft(2, '0'),
                              ),
                              const SizedBox(width: 8),
                              _statPill(
                                icon: Icons.collections_bookmark_outlined,
                                label: 'Paid Points',
                                value: _paidPoints.toString().padLeft(2, '0'),
                              ),
                              const SizedBox(width: 8),
                              _statPill(
                                icon: Icons.collections_bookmark_outlined,
                                label: 'Unpaid Points',
                                value: _unpaidPoints.toString().padLeft(2, '0'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Filter dropdown
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Text('Filter by status:',
                          style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _selectedFilter,
                          items: filters
                              .map((f) =>
                                  DropdownMenuItem(value: f, child: Text(f)))
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _selectedFilter = value);
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Section title
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Referral History',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),

                // Referral list
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: displayed.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final r = displayed[index];
                      final accent =
                          _accentFor(r['referred_category'] as String);
                      final isUnpaid =
                          (r['payment_status'] as String) == 'unpaid';
                      final timeAgo =
                          Config.getTimeDifference(r['timestamp'] as String);
                      final photo = (r['profile_photo'] as String?) ?? '';

                      return Container(
                        decoration: BoxDecoration(
                          color: isUnpaid ? Colors.red.shade50 : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: accent.withValues(alpha: 0.3)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          leading: CircleAvatar(
                            radius: 26,
                            backgroundColor: accent.withValues(alpha: 0.1),
                            foregroundImage:
                                photo.isNotEmpty ? NetworkImage(photo) : null,
                            child: photo.isEmpty
                                ? Icon(Icons.person, color: accent)
                                : null,
                          ),
                          title: Text(
                            r['referred_name'] as String,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r['referred_category'] as String,
                                  style: TextStyle(color: accent)),
                              const SizedBox(height: 4),
                              Text(
                                'Verification: ${r['verification']}',
                                style: const TextStyle(
                                  color: Color.fromARGB(179, 0, 0, 0),
                                  fontSize: 13,
                                ),
                              ),
                              Text('Time: $timeAgo'),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('${r['points']} pts',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isUnpaid
                                      ? Colors.red.shade100
                                      : Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  (r['payment_status'] as String).toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isUnpaid ? Colors.red : Colors.green,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _stepTile(int n, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1A56DB),
            ),
            child: Text(
              '$n',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
