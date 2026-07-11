import 'dart:convert';
import 'package:aaram_bd/config.dart';
import 'package:aaram_bd/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SubscriptionOfferPage extends StatefulWidget {
  const SubscriptionOfferPage({super.key});

  @override
  State<SubscriptionOfferPage> createState() => _SubscriptionOfferPageState();
}

class _SubscriptionOfferPageState extends State<SubscriptionOfferPage> {
  bool _isLoading = true;
  String? _type; // 'paid' | 'unpaid' | null (never flagged yet)
  int _fee = 0;
  String _catName = '';

  @override
  void initState() {
    super.initState();
    _loadSubscriptionDetails();
  }

  Future<void> _loadSubscriptionDetails() async {
    final response = await Config.apiGet('/get_subscription_details', context);
    if (response != null && response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        _type = data['type'];
        _fee = data['fee'] ?? 0;
        _catName = data['cat_name'] ?? '';
      });
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _contactAaramBD() async {
    try {
      final response = await Config.apiGet('/get_contact_info', context);
      if (response != null && response.statusCode == 200) {
        final data = json.decode(response.body);
        final phone = (data['phone'] ?? '').toString().trim();
        if (phone.isNotEmpty) {
          final telUri = Uri(scheme: 'tel', path: phone);
          if (await canLaunchUrl(telUri)) {
            await launchUrl(telUri);
            return;
          }
        }
      }
    } catch (_) {
      // fall through to the toast below
    }
    if (mounted) {
      showAppToast(context, 'Could not open dialer. Please try again.',
          icon: Icons.error_outline_rounded);
    }
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      title: const Text(
        'AaramBD Premium',
        style: TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w700,
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    );
  }

  Widget _buildGradientCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6D28D9), Color(0xFF9333EA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6D28D9).withValues(alpha: 0.25),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: const [
          SizedBox(height: 6),
          Icon(Icons.workspace_premium_rounded, size: 64, color: Colors.white),
          SizedBox(height: 16),
          Text(
            'Join as Premium Member',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Get stars ⭐⭐⭐ on your profile and unlock an authenticity badge.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 15.5,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, {IconData? icon}) {
    return Row(
      children: [
        if (icon != null)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEDE9FE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF6D28D9)),
          ),
        if (icon != null) const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard() {
    final isPaid = _type == 'paid';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: isPaid ? const Color(0xFFEFFAF1) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPaid ? const Color(0xFF16A34A) : const Color(0xFF3B82F6),
          width: 0.8,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isPaid ? Icons.verified_rounded : Icons.info_outline_rounded,
            color: isPaid ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isPaid
                  ? "You're a verified premium member. Thank you for subscribing!"
                  : _fee > 0
                      ? 'Subscription fee for $_catName: ৳$_fee'
                      : 'Contact AaramBD to learn more about subscribing.',
              style: TextStyle(
                fontSize: 15,
                height: 1.35,
                color: isPaid ? const Color(0xFF065F46) : const Color(0xFF1E3A8A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _contactAaramBD,
        icon: const Icon(Icons.support_agent_rounded),
        label: const Text('Contact AaramBD'),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: const Color(0xFF6D28D9),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      backgroundColor: const Color(0xFFF7F7FB),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildGradientCard(),
                  const SizedBox(height: 26),

                  _buildSectionTitle(
                    'Join Badged Sellers',
                    icon: Icons.store_mall_directory_rounded,
                  ),
                  const SizedBox(height: 12),

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFECECF1)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 14,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: const Column(
                      children: [
                        BenefitTile(
                          icon: Icons.verified_rounded,
                          text: 'Add identification badge to profile',
                        ),
                        Divider(height: 0),
                        BenefitTile(
                          icon: Icons.phone_in_talk_rounded,
                          text:
                              'Attend calls, deals and offers from buyers directly',
                        ),
                        Divider(height: 0),
                        BenefitTile(
                          icon: Icons.handshake_rounded,
                          text: 'Act professional, trustworthy, and reliable',
                        ),
                        Divider(height: 0),
                        BenefitTile(
                          icon: Icons.support_agent_rounded,
                          text: 'Contact to AaramBD team directly',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  _buildStatusCard(),
                  const SizedBox(height: 16),
                  if (_type != 'paid') _buildContactButton(),
                  const SizedBox(height: 20),

                  const Center(
                    child: Text(
                      'Terms and conditions may vary.',
                      style: TextStyle(color: Colors.grey, fontSize: 13.5),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class BenefitTile extends StatelessWidget {
  final IconData icon;
  final String text;

  const BenefitTile({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFEEF2FF), Color(0xFFEDE9FE)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: const Color(0xFF6D28D9), size: 20),
      ),
      minLeadingWidth: 0,
      horizontalTitleGap: 12,
      title: Text(
        text,
        style: const TextStyle(
          fontSize: 15.5,
          height: 1.3,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    );
  }
}
