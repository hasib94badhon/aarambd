import 'dart:async';
import 'dart:convert';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aaram_bd/config.dart';
import 'package:aaram_bd/screens/advert_screen.dart';

/// Handles incoming https://aarambd.com/u/<user_id> Android App Links.
///
/// If the viewer isn't logged in yet when the link arrives, the id is
/// stashed (with a timestamp) so the normal login/signup flow can proceed
/// uninterrupted; [consumePendingShare] is called right after a successful
/// login/auto-login to resume into the shared profile instead of Home.
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  static const _pendingUserIdKey = 'pendingSharedProfileUserId';
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

  String? _extractUserId(Uri uri) {
    final segments = uri.pathSegments;
    if (segments.length >= 2 && segments[0] == 'u' && segments[1].isNotEmpty) {
      return segments[1];
    }
    return null;
  }

  Future<void> _handleUri(Uri uri) async {
    final sharedId = _extractUserId(uri);
    if (sharedId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    final myUserId = prefs.getString('user_id');

    if (myUserId != null && myUserId == sharedId) return; // shared their own link

    if (!isLoggedIn) {
      await prefs.setString(_pendingUserIdKey, sharedId);
      await prefs.setInt(
          _pendingTimestampKey, DateTime.now().millisecondsSinceEpoch);
      return;
    }

    await _openSharedProfile(sharedId);
  }

  Future<void> consumePendingShare() async {
    final prefs = await SharedPreferences.getInstance();
    final sharedId = prefs.getString(_pendingUserIdKey);
    final timestamp = prefs.getInt(_pendingTimestampKey);
    await prefs.remove(_pendingUserIdKey);
    await prefs.remove(_pendingTimestampKey);

    if (sharedId == null || timestamp == null) return;

    final age =
        DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(timestamp));
    if (age > _pendingTtl) return;

    await _openSharedProfile(sharedId);
  }

  Future<void> _openSharedProfile(String sharedId) async {
    final context = _navigatorKey?.currentState?.context;
    if (context == null) return;

    try {
      final response = await Config.apiGet(
          '/resolve_shared_profile?user_id=$sharedId', context);
      if (response == null || response.statusCode != 200) return;

      final data = jsonDecode(response.body);
      if (data['success'] != true) return;

      final bool isService = data['is_service'] == true;
      final Map<String, dynamic> additionalData = isService
          ? {'service_id': data['service_id']}
          : (data['shop_id'] != null
              ? {'shop_id': data['shop_id']}
              : {'user_only': data['user_id']});

      // The AdvertScreen's userId is the profile being VIEWED (it drives
      // fetchViewList/_fetchReviewSummary for that profile) — not whoever
      // clicked the link. The backend already resolved+confirmed this id.
      final targetId = data['user_id'].toString();

      final advertData = AdvertData(
        userId: targetId,
        isService: isService,
        additionalData: additionalData,
      );

      _navigatorKey?.currentState?.push(
        MaterialPageRoute(
          builder: (_) => AdvertScreen(
            advertData: advertData,
            userId: targetId,
            isService: isService,
          ),
        ),
      );
    } catch (_) {
      // Worst case the shared link just doesn't deep-link this time.
    }
  }
}
