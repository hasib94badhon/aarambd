import 'dart:convert';

import 'package:aaram_bd/config.dart';
import 'package:flutter/material.dart';

class NotificationPrefs {
  final bool profileActivity;
  final bool social;
  final bool categoryUpdates;
  final bool promotional;

  const NotificationPrefs({
    required this.profileActivity,
    required this.social,
    required this.categoryUpdates,
    required this.promotional,
  });

  factory NotificationPrefs.fromJson(Map<String, dynamic> json) {
    return NotificationPrefs(
      profileActivity: json['notif_profile_activity'] ?? true,
      social: json['notif_social'] ?? true,
      categoryUpdates: json['notif_category_updates'] ?? true,
      promotional: json['notif_promotional'] ?? true,
    );
  }

  NotificationPrefs copyWith({
    bool? profileActivity,
    bool? social,
    bool? categoryUpdates,
    bool? promotional,
  }) {
    return NotificationPrefs(
      profileActivity: profileActivity ?? this.profileActivity,
      social: social ?? this.social,
      categoryUpdates: categoryUpdates ?? this.categoryUpdates,
      promotional: promotional ?? this.promotional,
    );
  }
}

class NotificationPrefsService {
  static Future<NotificationPrefs?> fetch(BuildContext context) async {
    final resp = await Config.apiGet('/user/notification_prefs', context);
    if (resp != null && resp.statusCode == 200) {
      return NotificationPrefs.fromJson(json.decode(resp.body));
    }
    return null;
  }

  /// Persists only the changed keys, e.g. {'notif_social': false}.
  static Future<bool> update(
      BuildContext context, Map<String, bool> changes) async {
    final resp =
        await Config.apiPut('/user/notification_prefs', changes, context);
    return resp != null && resp.statusCode == 200;
  }
}
