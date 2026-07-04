import 'dart:async';
import 'dart:convert';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aaram_bd/config.dart';
import 'package:aaram_bd/screens/advert_screen.dart';

/// Handles incoming https://aarambd.com/u/<phone> Android App Links.
///
/// If the viewer isn't logged in yet when the link arrives, the phone is
/// stashed (with a timestamp) so the normal login/signup flow can proceed
/// uninterrupted; [consumePendingShare] is called right after a successful
/// login/auto-login to resume into the shared profile instead of Home.
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  static const _pendingPhoneKey = 'pendingSharedProfilePhone';
  static const _pendingTimestampKey = 'pendingSharedProfileTimestamp';
  static const _pendingTtl = Duration(minutes: 30);

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;
  GlobalKey<NavigatorState>? _navigatorKey;

  Future<void> init(GlobalKey<NavigatorState> navigatorKey) async {
    _navigatorKey = navigatorKey;

    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) await _handleUri(initialUri);

    _subscription ??= _appLinks.uriLinkStream.listen(_handleUri);
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }

  String? _extractPhone(Uri uri) {
    final segments = uri.pathSegments;
    if (segments.length >= 2 && segments[0] == 'u' && segments[1].isNotEmpty) {
      return segments[1];
    }
    return null;
  }

  Future<void> _handleUri(Uri uri) async {
    final phone = _extractPhone(uri);
    if (phone == null) return;

    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    final myPhone = prefs.getString('userPhone');

    if (myPhone != null && myPhone == phone) return; // shared their own link

    if (!isLoggedIn) {
      await prefs.setString(_pendingPhoneKey, phone);
      await prefs.setInt(
          _pendingTimestampKey, DateTime.now().millisecondsSinceEpoch);
      return;
    }

    await _openSharedProfile(phone);
  }

  Future<void> consumePendingShare() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString(_pendingPhoneKey);
    final timestamp = prefs.getInt(_pendingTimestampKey);
    await prefs.remove(_pendingPhoneKey);
    await prefs.remove(_pendingTimestampKey);

    if (phone == null || timestamp == null) return;

    final age =
        DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(timestamp));
    if (age > _pendingTtl) return;

    await _openSharedProfile(phone);
  }

  Future<void> _openSharedProfile(String phone) async {
    final context = _navigatorKey?.currentState?.context;
    if (context == null) return;

    try {
      final response =
          await Config.apiGet('/resolve_shared_profile?phone=$phone', context);
      if (response == null || response.statusCode != 200) return;

      final data = jsonDecode(response.body);
      if (data['success'] != true) return;

      final bool isService = data['is_service'] == true;
      final Map<String, dynamic> additionalData = isService
          ? {'service_id': data['service_id']}
          : (data['shop_id'] != null
              ? {'shop_id': data['shop_id']}
              : {'user_only': data['user_id']});

      final prefs = await SharedPreferences.getInstance();
      final viewerId = prefs.getString('user_id') ?? '';

      final advertData = AdvertData(
        userId: viewerId,
        isService: isService,
        additionalData: additionalData,
      );

      _navigatorKey?.currentState?.push(
        MaterialPageRoute(
          builder: (_) => AdvertScreen(
            advertData: advertData,
            userId: viewerId,
            isService: isService,
          ),
        ),
      );
    } catch (_) {
      // Worst case the shared link just doesn't deep-link this time.
    }
  }
}
