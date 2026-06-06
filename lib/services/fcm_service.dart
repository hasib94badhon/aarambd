import 'dart:convert';
import 'dart:io';

import 'package:aaram_bd/config.dart';
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

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'aarambd_channel';
  static const _channelName = 'AaramBD Notifications';

  // Guard against registering listeners more than once
  bool _listenersRegistered = false;

  // ── Init ─────────────────────────────────────────────────────────────────

  Future<void> init(BuildContext context) async {
    if (!Platform.isAndroid) return;
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
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('[FCM] Opened from background: ${message.data}');
    });
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
