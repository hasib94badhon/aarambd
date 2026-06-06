import 'package:aaram_bd/config.dart';
import 'package:flutter/material.dart';

class NotificationService {
  // Always get the logged-in user the same way the rest of the app does
  Future<String?> getLoggedInUser() async {
    try {
      final id = await Config.getLoggedInUser();
      if (id == null || id.toString().isEmpty) {
        debugPrint('[Notif] No logged-in user found via Config.getLoggedInUser()');
        return null;
      }
      return id.toString();
    } catch (e) {
      debugPrint('[Notif] Error reading logged-in user: $e');
      return null;
    }
  }

  Future<void> sendNotificationWithLoggedInUser(
    int targetUserId,
    String notifType,
    int targetPostId,
    BuildContext context,
  ) async {
    final detailUser = await getLoggedInUser();
    if (detailUser == null) {
      debugPrint('[Notif] Aborting send: detailUser == null');
      return;
    }

    final ok = await sendNotification(
      userId: targetUserId,
      notifType: notifType,
      detailUser: detailUser,       // server expects a string? keep it string; else int.parse
      detail_post_id: targetPostId,
      context: context,
    );

    debugPrint(ok
        ? '[Notif] Sent ($notifType) to $targetUserId for post $targetPostId (by $detailUser)'
        : '[Notif] FAILED sending ($notifType) to $targetUserId');
  }

  Future<bool> sendNotification({
    required int userId,
    required String notifType,
    required String detailUser,
    required int detail_post_id,
    required BuildContext context,
  }) async {
    const url = '/add_notification';

    final body = {
      'user_id': userId,
      'type': notifType,
      'detail_user': detailUser,       // ensure your backend expects a string here; if int then int.parse(detailUser)
      'detail_post_id': detail_post_id
    };
    debugPrint('[Notif] POST $url  body=$body');

    try {
      final response = await Config.apiPost(url, body, context);

      if (response == null) {
        debugPrint('[Notif] response == null (token refresh/logout?)');
        return false;
      }

      debugPrint('[Notif] Response ${response.statusCode}: ${response.body}');
      // Accept 200 or 201
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('[Notif] Exception: $e');
      return false;
    }
  }
}
