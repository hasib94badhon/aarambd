import 'dart:convert';
import 'package:aaram_bd/config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class SubscriptionOfferPage extends StatefulWidget {
  const SubscriptionOfferPage({super.key});

  @override
  State<SubscriptionOfferPage> createState() => _SubscriptionOfferPageState();
}

class _SubscriptionOfferPageState extends State<SubscriptionOfferPage> {
  String? _subscriptionMessage;
  bool _showSubscribeButton = false;
  bool _isSubscribed = false;
  bool _isLoading = false;

  Future<void> _sendSubscriptionRequest() async {
    final userId = await Config.getLoggedInUser();
    if (userId == null) return;

    try {
      final response = await Config.apiPost(
        '/check_and_subscribe_user',
        {'user_id': userId, 'action': 'subscribe_now'},
        context,
      );
      if (response != null && response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData;
      }
    } catch (e) {
      print('Subscription error: $e');
    }
  }

  Future<void> _checkSubscriptionEligibility(BuildContext context) async {
    setState(() {
      _isLoading = true;
    });

    final userId = await Config.getLoggedInUser();
    if (userId == null) {
      _showSnackbar('User not logged in.');
      setState(() => _isLoading = false);
      return;
    }

    try {
      final String apiUrl = '/check_and_subscribe_user';
      final response = await Config.apiPost(apiUrl, {'user_id': userId}, context);

      if (response == null) {
        // Config.apiPost returns null if refresh fails and force logout happens
        return;
      }
      final data = json.decode(response.body);
      final message = (data['message'] ?? data['error'] ?? 'Unknown response')
          .toString()
          .toLowerCase();

      setState(() {
        _subscriptionMessage = message;

        if (message.contains('you need to make the account subscribed') ||
            message.contains('subscribe again')) {
          _showSubscribeButton = true;
          _isSubscribed = false;
        } else if (message.contains('subscribed')) {
          _showSubscribeButton = false;
          _isSubscribed = true;
          _showSubscribedDialog();
        } else {
          _showSubscribeButton = false;
          _isSubscribed = false;
        }
      });

      _showSnackbar(message);
    } catch (e) {
      _showSnackbar('Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.blueGrey.shade800,
      ),
    );
  }

  void _showSubscribedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('🎉 Subscription Active'),
        content: const Text(
          'You are already subscribed to AaramBD Premium Services.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ===== UI: Polished widgets (visual-only; no logic changes) =====

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
            'Get stars ⭐⭐⭐ on your profile and unlock an authenticity badge by submitting a subscription request.',
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

  Widget _buildEligibilityStatus() {
    if (_subscriptionMessage == null) return const SizedBox.shrink();

    final isPositive = _subscriptionMessage!.contains('subscribed');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        decoration: BoxDecoration(
          color: isPositive ? const Color(0xFFEFFAF1) : const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPositive ? const Color(0xFF16A34A) : const Color(0xFF3B82F6),
            width: 0.8,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isPositive ? Icons.verified_rounded : Icons.info_outline_rounded,
              color: isPositive ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _subscriptionMessage!,
                style: TextStyle(
                  fontSize: 15.5,
                  height: 1.35,
                  color: isPositive ? const Color(0xFF065F46) : const Color(0xFF1E3A8A),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showThankYouModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "🎉 Thank You!",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "AaramBD team will contact you shortly regarding your subscription module.\n\nStay connected with us!",
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close", style: TextStyle(color: Color(0xFF6D28D9))),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final canCheck = !_showSubscribeButton && !_isSubscribed && !_isLoading;
    final canRequest = _showSubscribeButton && !_isSubscribed;

    return Column(
      children: [
        // Primary action: Check Eligibility
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: canCheck ? () => _checkSubscriptionEligibility(context) : null,
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                  )
                : const Icon(Icons.verified_user),
            label: Text(_isLoading ? 'Checking...' : 'Check Eligibility'),
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: canCheck ? const Color(0xFF6D28D9) : Colors.grey.shade400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Secondary action: Request Subscription
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: canRequest
              ? () {
                  _sendSubscriptionRequest();
                  _showThankYouModal(context);
                }
              : null,
          child: Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: canRequest
                  ? const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: canRequest ? null : Colors.grey.shade400,
              boxShadow: canRequest
                  ? [
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha: 0.28),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : [],
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.lock_open, color: Colors.white),
                SizedBox(width: 10),
                Text(
                  'Request for Subscription',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===== Page =====

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      backgroundColor: const Color(0xFFF7F7FB),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildGradientCard(),
            const SizedBox(height: 26),

            _buildSectionTitle(
              'Join Bedged Sellers',
              icon: Icons.store_mall_directory_rounded,
            ),
            const SizedBox(height: 12),

            // Benefits Card
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
            _buildEligibilityStatus(),
            const SizedBox(height: 4),
            _buildActionButtons(),
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
