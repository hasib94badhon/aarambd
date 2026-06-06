import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

Widget verifiedWidgetIcon({
 required String? subscriptionType,
  required String? lastPayString, // ← this will come as raw string from API
  required BuildContext context,
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
        builder: (_) => AlertDialog(
          title: const Text("Subscription Status"),
          content: Text(
            lastPay != null
                ? '✅ Subscribed on: ${DateFormat('yyyy-MM-dd').format(lastPay)}'
                : '✅ Subscribed (date unavailable)',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    };
  } else if (subscriptionType == 'waiting') {
    icon = const Icon(Icons.hourglass_bottom, color: Colors.orangeAccent, size: 20);
    iconColor = Colors.orangeAccent;
    tooltip = 'Subscription pending confirmation';
    onTap = () {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Subscription Pending"),
          content: Text(
            lastPay != null
                ? '⏳ Waiting since: ${DateFormat('yyyy-MM-dd').format(lastPay)}'
                : '⏳ Subscription is pending...',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
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
        builder: (_) => AlertDialog(
          title: const Text("Subscription Inactive"),
          content: const Text(
            '🚫 You are not subscribed.\nPlease contact the AaramBD team to activate your subscription.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Contact'),
            ),
          ],
        ),
      );
    };
  } else {
    onTap = () {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No subscription info available.')),
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
