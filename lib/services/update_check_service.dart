import 'dart:convert';
import 'dart:io';

import 'package:aaram_bd/config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

const Color _brand = Color(0xFF1A56DB);

/// Compares two dotted version strings, e.g. "1.2.10" vs "1.3.0".
/// Returns <0 if [a] < [b], 0 if equal, >0 if [a] > [b].
int compareVersions(String a, String b) {
  final pa = a.split('.').map((s) => int.tryParse(s) ?? 0).toList();
  final pb = b.split('.').map((s) => int.tryParse(s) ?? 0).toList();
  final len = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < len; i++) {
    final va = i < pa.length ? pa[i] : 0;
    final vb = i < pb.length ? pb[i] : 0;
    if (va != vb) return va - vb;
  }
  return 0;
}

class UpdateCheckService {
  /// Fetches the server-side version config and, if the installed build is
  /// out of date, shows either a blocking "force update" dialog (installed
  /// < min_version) or a dismissible "update available" dialog (installed <
  /// latest_version). Silently does nothing on any network/parsing failure —
  /// a broken version check must never block app launch.
  static Future<void> checkForUpdate(BuildContext context) async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    final platform = Platform.isAndroid ? 'android' : 'ios';

    try {
      final info = await PackageInfo.fromPlatform();
      final installedVersion = info.version;

      final uri =
          Uri.parse('${Config.host}/get_app_version?platform=$platform');
      final resp = await http.get(uri).timeout(const Duration(seconds: 6));
      if (resp.statusCode != 200) return;

      final data = json.decode(resp.body) as Map<String, dynamic>;
      final latestVersion = data['latest_version']?.toString() ?? '';
      final minVersion = data['min_version']?.toString() ?? '';
      final storeUrl = data['store_url']?.toString() ?? '';
      final message = data['update_message']?.toString() ??
          'A new version is available with improvements and bug fixes.';

      if (latestVersion.isEmpty || storeUrl.isEmpty) return;

      final forceUpdate = minVersion.isNotEmpty &&
          compareVersions(installedVersion, minVersion) < 0;
      final softUpdate =
          !forceUpdate && compareVersions(installedVersion, latestVersion) < 0;

      if (!forceUpdate && !softUpdate) return;
      if (!context.mounted) return;

      await _showUpdateDialog(
        context,
        storeUrl: storeUrl,
        message: message,
        forceUpdate: forceUpdate,
      );
    } catch (_) {
      // Network hiccup, JSON shape mismatch, etc. — never block launch.
    }
  }

  static Future<void> _showUpdateDialog(
    BuildContext context, {
    required String storeUrl,
    required String message,
    required bool forceUpdate,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (dialogContext) => PopScope(
        canPop: !forceUpdate,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1040B0), Color(0xFF1A56DB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _brand.withValues(alpha: 0.32),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.system_update_alt_rounded,
                      color: Colors.white, size: 30),
                ),
                const SizedBox(height: 18),
                Text(
                  forceUpdate ? 'Update Required' : 'Update Available',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  forceUpdate
                      ? 'Please update the app to continue using it. $message'
                      : message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF6B7280),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _openStore(storeUrl),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brand,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Update Now',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                if (!forceUpdate) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text(
                      'Later',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> _openStore(String storeUrl) async {
    final uri = Uri.tryParse(storeUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
