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

/// Shared modern dialog shell for all three subscription-status states:
/// a colored icon badge, bold title, friendly body copy, and a stack of
/// styled action buttons -- with a scale+fade pop-in instead of the
/// default flat AlertDialog transition.
void _showStatusDialog({
  required BuildContext context,
  required IconData icon,
  required Color color,
  required String title,
  required String message,
  required List<Widget> actions,
}) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: title,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (dialogCtx, _, __) => const SizedBox.shrink(),
    transitionBuilder: (dialogCtx, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
      return Opacity(
        opacity: animation.value.clamp(0, 1),
        child: Transform.scale(
          scale: 0.85 + (0.15 * curved.value.clamp(0, 1.2)),
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 30),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 30, 24, 22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 30,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          color.withValues(alpha: 0.18),
                          color.withValues(alpha: 0.05),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 38),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14.5,
                      height: 1.5,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 22),
                  ...actions,
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

Widget _primaryDialogButton({
  required BuildContext dialogCtx,
  required String label,
  required Color color,
  required VoidCallback onTap,
  IconData? icon,
}) {
  return SizedBox(
    width: double.infinity,
    height: 50,
    child: ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18),
            const SizedBox(width: 8),
          ],
          Text(label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        ],
      ),
    ),
  );
}

Widget _secondaryDialogButton({
  required String label,
  required Color color,
  required VoidCallback onTap,
  IconData? icon,
}) {
  return SizedBox(
    width: double.infinity,
    height: 46,
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 17),
            const SizedBox(width: 8),
          ],
          Text(label,
              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
        ],
      ),
    ),
  );
}

Widget _textDialogButton({
  required BuildContext dialogCtx,
  required String label,
}) {
  return Padding(
    padding: const EdgeInsets.only(top: 4),
    child: TextButton(
      onPressed: () => Navigator.pop(dialogCtx),
      child: Text(
        label,
        style: const TextStyle(
            fontSize: 13.5, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600),
      ),
    ),
  );
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
      debugPrint('Failed to parse lastPay: $e');
    }
  }

  // Default values
  icon = const Icon(Icons.info_outline, color: Colors.grey, size: 20);
  iconColor = Colors.grey;
  tooltip = 'Subscription Info';

  if (subscriptionType == 'paid') {
    const color = Color(0xFF2563EB);
    icon = const Icon(Icons.verified, color: color, size: 20);
    iconColor = color;
    tooltip = 'You are a paid subscriber';
    onTap = () {
      _showStatusDialog(
        context: context,
        icon: Icons.verified_rounded,
        color: color,
        title: "You're Verified!",
        message: lastPay != null
            ? 'Subscribed since ${DateFormat('d MMM, yyyy').format(lastPay)}. Your profile shows the verified badge to everyone.'
            : 'Your profile shows the verified badge to everyone.',
        actions: [
          Builder(builder: (dialogCtx) {
            return _primaryDialogButton(
              dialogCtx: dialogCtx,
              label: 'Got it',
              color: color,
              icon: Icons.check_rounded,
              onTap: () => Navigator.pop(dialogCtx),
            );
          }),
        ],
      );
    };
  } else if (subscriptionType == 'unpaid') {
    const color = Color(0xFFDC2626);
    icon = const Icon(Icons.lock_outline, color: color, size: 20);
    iconColor = color;
    tooltip = 'Unpaid - Subscription inactive';
    onTap = () {
      _showStatusDialog(
        context: context,
        icon: Icons.lock_rounded,
        color: color,
        title: 'Subscription Inactive',
        message:
            "You're not subscribed right now. Contact AaramBD to activate your verified badge, or see what's included.",
        actions: [
          Builder(builder: (dialogCtx) {
            return _primaryDialogButton(
              dialogCtx: dialogCtx,
              label: 'View Subscription Details',
              color: color,
              icon: Icons.workspace_premium_rounded,
              onTap: () {
                Navigator.pop(dialogCtx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SubscriptionOfferPage()),
                );
              },
            );
          }),
          const SizedBox(height: 10),
          Builder(builder: (dialogCtx) {
            return _secondaryDialogButton(
              label: 'Contact AaramBD',
              color: color,
              icon: Icons.call_rounded,
              onTap: () => _contactAaramBD(dialogCtx),
            );
          }),
          Builder(builder: (dialogCtx) {
            return _textDialogButton(dialogCtx: dialogCtx, label: 'Cancel');
          }),
        ],
      );
    };
  } else {
    // No subscribers row exists for this user at all -- they haven't crossed
    // the call/view threshold yet (see maybe_notify_subscription on the
    // backend). Point them at the full offer page instead of a dead-end toast.
    const color = Color(0xFFD97706);
    icon = const Icon(Icons.workspace_premium_outlined, color: color, size: 20);
    iconColor = color;
    tooltip = 'Not a premium member yet';
    onTap = () {
      _showStatusDialog(
        context: context,
        icon: Icons.workspace_premium_rounded,
        color: color,
        title: 'Become a Premium Member',
        message:
            'Get a verified badge, stand out to buyers, and unlock priority support from AaramBD.',
        actions: [
          Builder(builder: (dialogCtx) {
            return _primaryDialogButton(
              dialogCtx: dialogCtx,
              label: 'Learn More',
              color: color,
              icon: Icons.arrow_forward_rounded,
              onTap: () {
                Navigator.pop(dialogCtx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SubscriptionOfferPage()),
                );
              },
            );
          }),
          Builder(builder: (dialogCtx) {
            return _textDialogButton(dialogCtx: dialogCtx, label: 'Maybe Later');
          }),
        ],

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
