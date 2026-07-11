import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:aaram_bd/config.dart';
import 'package:aaram_bd/widgets/app_toast.dart';
import 'package:aaram_bd/pages/subscriptionofferpage.dart';

Future<void> _contactAaramBD(BuildContext context) async {
  try {
    final response = await Config.apiGet('/get_contact_info', context);
    if (response != null && response.statusCode == 200) {
      final data = jsonDecode(response.body);
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
    // fall through to the snackbar below
  }
  if (context.mounted) {
    showAppToast(context, 'Could not open dialer. Please try again.',
        icon: Icons.error_outline_rounded);
  }
}

Widget verifiedWidgetIcon({
  required String? subscriptionType,
  required String? lastPayString, // ← this will come as raw string from API
  required BuildContext context,
  required int userId,
}) {
  Icon icon;
  Color iconColor;
  String tooltip;
  VoidCallback onTap;

  DateTime? lastPay;

  // ✅ Parse lastPay string safely
  if (lastPayString != null && lastPayString.isNotEmpty) {
    try {
      lastPay = DateFormat("EEE, dd MMM yyyy HH:mm:ss 'GMT'").parseUtc(lastPayString).toLocal();
    } catch (e) {
      print('Failed to parse lastPay: $e');
    }
  }

  // Default values
  icon = const Icon(Icons.info_outline, color: Colors.grey, size: 20);
  iconColor = Colors.grey;
  tooltip = 'Subscription Info';

  if (subscriptionType == 'paid') {
    icon = const Icon(Icons.verified, color: Colors.blueAccent, size: 20);
    iconColor = Colors.blueAccent;
    tooltip = 'You are a paid subscriber';
    onTap = () {
      showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text("Subscription Status"),
          content: Text(
            lastPay != null
                ? '✅ Subscribed on: ${DateFormat('yyyy-MM-dd').format(lastPay)}'
                : '✅ Subscribed (date unavailable)',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    };
  } else if (subscriptionType == 'unpaid') {
    icon = const Icon(Icons.lock_outline, color: Colors.redAccent, size: 20);
    iconColor = Colors.redAccent;
    tooltip = 'Unpaid - Subscription inactive';
    onTap = () {
      showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text("Subscription Inactive"),
          content: const Text(
            '🚫 You are not subscribed.\nContact the AaramBD team to activate it, or see the subscription details.',
          ),
          actions: [
            TextButton(
              onPressed: () => _contactAaramBD(dialogCtx),
              child: const Text('Contact AaramBD'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SubscriptionOfferPage()),
                );
              },
              child: const Text('View Details'),
            ),
          ],
        ),
      );
    };
  } else {
    // No subscribers row exists for this user at all -- they haven't crossed
    // the call/view threshold yet (see maybe_notify_subscription on the
    // backend). Point them at the full offer page instead of a dead-end toast.
    icon = const Icon(Icons.workspace_premium_outlined, color: Colors.grey, size: 20);
    iconColor = Colors.grey;
    tooltip = 'Not a premium member yet';
    onTap = () {
      showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Not Subscribed Yet'),
          content: const Text(
            '⭐ Become a premium member to get a verified badge, stand out '
            'to buyers, and unlock priority support.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Later'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SubscriptionOfferPage()),
                );
              },
              child: const Text('Learn More'),
            ),
          ],
        ),
      );
    };
  }

  return GestureDetector(
    onTap: onTap,
    child: Tooltip(
      message: tooltip,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: iconColor.withValues(alpha: 0.6),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
        padding: const EdgeInsets.all(4),
        child: icon,
      ),
    ),
  );
}
