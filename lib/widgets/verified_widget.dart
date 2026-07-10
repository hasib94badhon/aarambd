import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:aaram_bd/config.dart';

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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open dialer. Please try again.')),
    );
  }
}

Future<void> _requestSubscription(
  BuildContext dialogContext,
  BuildContext pageContext,
  int userId,
  VoidCallback? onChanged,
) async {
  try {
    final response = await Config.apiPost(
      '/check_and_subscribe_user',
      {'user_id': userId, 'action': 'subscribe_now'},
      pageContext,
    );
    if (dialogContext.mounted) Navigator.pop(dialogContext);

    String message = 'Subscription request sent. Our team will contact you soon.';
    if (response != null) {
      try {
        final data = jsonDecode(response.body);
        message = (data['message'] ?? message).toString();
      } catch (_) {}
    }
    onChanged?.call();
    if (pageContext.mounted) {
      ScaffoldMessenger.of(pageContext).showSnackBar(SnackBar(content: Text(message)));
    }
  } catch (_) {
    if (dialogContext.mounted) Navigator.pop(dialogContext);
    if (pageContext.mounted) {
      ScaffoldMessenger.of(pageContext).showSnackBar(
        const SnackBar(content: Text('No internet. Please check your connection.')),
      );
    }
  }
}

Widget verifiedWidgetIcon({
  required String? subscriptionType,
  required String? lastPayString, // ← this will come as raw string from API
  required BuildContext context,
  required int userId,
  VoidCallback? onChanged,
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
        builder: (dialogCtx) => AlertDialog(
          title: const Text("Subscription Pending"),
          content: Text(
            lastPay != null
                ? '⏳ Waiting since: ${DateFormat('yyyy-MM-dd').format(lastPay)}'
                : '⏳ Subscription is pending...',
          ),
          actions: [
            TextButton(
              onPressed: () => _contactAaramBD(dialogCtx),
              child: const Text('Contact AaramBD'),
            ),
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
      bool isRequesting = false;
      showDialog(
        context: context,
        builder: (dialogCtx) => StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              title: const Text("Subscription Inactive"),
              content: isRequesting
                  ? const SizedBox(
                      height: 40,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : const Text(
                      '🚫 You are not subscribed.\nRequest a subscription or contact the AaramBD team to activate it.',
                    ),
              actions: isRequesting
                  ? []
                  : [
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
                          setDialogState(() => isRequesting = true);
                          _requestSubscription(dialogCtx, context, userId, onChanged);
                        },
                        child: const Text('Request Subscription'),
                      ),
                    ],
            );
          },
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
