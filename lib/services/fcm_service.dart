import 'dart:convert';
import 'dart:io';

import 'package:aaram_bd/config.dart';
import 'package:aaram_bd/screens/advert_screen.dart';
import 'package:aaram_bd/screens/post_details.dart';
import 'package:aaram_bd/screens/thoughtdetails.dart';
import 'package:aaram_bd/screens/user_profile.dart';
import 'package:aaram_bd/pages/subscriptionofferpage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background message: ${message.messageId}');
}

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  // Lazy, not a field initializer — FirebaseMessaging.instance requires
  // Firebase.initializeApp() to have already run, which only happens on
  // Android today. Evaluating this eagerly would crash the instant anything
  // references FCMService() at all (even just to set a callback), before
  // init()'s own Platform.isAndroid guard ever gets a chance to run.
  FirebaseMessaging get _fcm => FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'aarambd_channel';
  static const _channelName = 'AaramBD Notifications';

  // Guard against registering listeners more than once
  bool _listenersRegistered = false;

  GlobalKey<NavigatorState>? _navigatorKey;

  /// Set by NavigationScreen so the bell can react the instant a push
  /// arrives while the app is open, instead of only on the next manual
  /// refresh/lifecycle event.
  VoidCallback? onForegroundMessage;

  // ── Init ─────────────────────────────────────────────────────────────────

  Future<void> init(
    BuildContext context, [
    GlobalKey<NavigatorState>? navigatorKey,
  ]) async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    if (navigatorKey != null) _navigatorKey = navigatorKey;
    await _requestPermission();
    await _setupLocalNotifications();

    // Register stream listeners only once across the app lifetime
    if (!_listenersRegistered) {
      _listenersRegistered = true;
      _listenForeground();
      _listenOnTap();
      _listenTokenRefresh();
    }

    // Save token — context is only needed here, right now, while widget is alive
    await saveTokenToBackend(context);
  }

  // ── Permission ───────────────────────────────────────────────────────────

  Future<void> _requestPermission() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('[FCM] Permission: ${settings.authorizationStatus}');
  }

  // ── Local notifications setup ─────────────────────────────────────────────

Future<void> _setupLocalNotifications() async {
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings();

  await _localNotif.initialize(
    InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    ),
  );

  if (Platform.isAndroid) {
    await _localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            importance: Importance.high,
            enableVibration: true,
            playSound: true,
          ),
        );
  }
}

  // ── Foreground messages → show local notification ─────────────────────────

  void _listenForeground() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[FCM] Foreground: ${message.notification?.title}');
      _showLocalNotification(message);
      onForegroundMessage?.call();
    });
  }

  void _showLocalNotification(RemoteMessage message) {
    final notif = message.notification;
    if (notif == null) return;

    _localNotif.show(
      message.hashCode,
      notif.title,
      notif.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }

  // ── Notification tap (app in background / terminated) ────────────────────

  void _listenOnTap() {
    _fcm.getInitialMessage().then((message) {
      if (message != null) {
        debugPrint('[FCM] Opened from terminated: ${message.data}');
        _dispatchTap(message.data);
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('[FCM] Opened from background: ${message.data}');
      _dispatchTap(message.data);
    });
  }

  /// Mirrors NotificationShow's tap routing so a push behaves the same as
  /// tapping the equivalent row in the in-app notification list.
  void _dispatchTap(Map<String, dynamic> data) {
    final navState = _navigatorKey?.currentState;
    if (navState == null) return;

    final type = (data['type'] ?? '').toString();

    if (type == 'subscription_approved') {
      SharedPreferences.getInstance().then((prefs) {
        final phone = prefs.getString('userPhone');
        if (phone == null || phone.isEmpty) return;
        navState.push(MaterialPageRoute(
          builder: (_) => UserProfile(userPhone: phone),
        ));
      });
      return;
    }

    if (type == 'subscription_notice') {
      navState.push(MaterialPageRoute(
        builder: (_) => const SubscriptionOfferPage(),
      ));
      return;
    }

    if (type == 'new_post') {
      final desId = (data['des_id'] ?? '').toString();
      if (desId.isEmpty) return;
      navState.push(MaterialPageRoute(
        builder: (_) => ThoughtDetails(desId: desId),
      ));
      return;
    }

    final userId = (data['detail_user'] ?? '').toString();
    if (userId.isEmpty) return; // broadcast / subscription_usage — no per-user target yet

    if (type == 'comment') {
      final postId = (data['detail_post_id'] ?? '0').toString();
      navState.push(MaterialPageRoute(
        builder: (_) => PostDetails(postId: postId, userId: userId),
      ));
    } else if (type == 'view' || type == 'call' || type == 'share' || type == 'review') {
      final isService = data['is_service'] == '1';
      final serviceId = int.tryParse((data['service_id'] ?? '0').toString()) ?? 0;
      final shopId = int.tryParse((data['shop_id'] ?? '0').toString()) ?? 0;

      navState.push(MaterialPageRoute(
        builder: (_) => AdvertScreen(
          advertData: AdvertData(
            userId: userId,
            isService: isService,
            additionalData:
                isService ? {'service_id': serviceId} : {'shop_id': shopId},
          ),
          userId: userId,
          isService: isService,
        ),
      ));
    }
  }

  // ── Token management ──────────────────────────────────────────────────────

  Future<String?> getToken() async {
    try {
      return await _fcm.getToken();
    } catch (e) {
      debugPrint('[FCM] getToken error: $e');
      return null;
    }
  }

  // Saves FCM token using a direct authenticated request — no BuildContext stored.
  Future<void> saveTokenToBackend(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId == null) return;

    final token = await getToken();
    if (token == null) return;

    final savedToken = prefs.getString('fcm_token');
    if (savedToken == token) return;

    try {
      final accessToken = await Config.getAccessToken();
      if (accessToken == null) return;

      final resp = await http.post(
        Uri.parse('${Config.host}/user/save_fcm_token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({'user_id': userId, 'fcm_token': token}),
      );

      if (resp.statusCode == 200) {
        await prefs.setString('fcm_token', token);
        debugPrint('[FCM] Token saved to backend');
      } else {
        debugPrint('[FCM] Save token failed: ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('[FCM] Failed to save token: $e');
    }
  }

  // Token refresh saves directly without needing a context.
  void _listenTokenRefresh() {
    _fcm.onTokenRefresh.listen((newToken) async {
      debugPrint('[FCM] Token refreshed');
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (userId == null) return;

      final accessToken = await Config.getAccessToken();
      if (accessToken == null) return;

      try {
        final resp = await http.post(
          Uri.parse('${Config.host}/user/save_fcm_token'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode({'user_id': userId, 'fcm_token': newToken}),
        );
        if (resp.statusCode == 200) {
          await prefs.setString('fcm_token', newToken);
          debugPrint('[FCM] Refreshed token saved');
        }
      } catch (e) {
        debugPrint('[FCM] Failed to save refreshed token: $e');
      }
    });
  }
}
