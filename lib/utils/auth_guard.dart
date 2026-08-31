import 'package:aaram_bd/screens/login_screen.dart';
import 'package:aaram_bd/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gate for account-based actions (posting, saving favorites, calling or
/// messaging a listing, viewing/editing the user's own profile) reached from
/// a screen guests can otherwise browse freely.
///
/// Returns true if the user is (or just became) logged in. If not logged in,
/// shows a toast and pushes LoginScreen — the user can back out to return
/// exactly where they were, or sign in and get popped straight back here,
/// in which case this returns true and the caller can proceed with the
/// original action immediately.
Future<bool> requireLogin(
  BuildContext context, {
  String message = 'Please sign in to continue',
}) async {
  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  if (isLoggedIn) return true;

  if (!context.mounted) return false;
  showAppToast(context, message, icon: Icons.lock_outline_rounded);
  final loggedIn = await Navigator.push<bool>(
    context,
    MaterialPageRoute(builder: (_) => LoginScreen(popOnSuccess: true)),
  );
  return loggedIn ?? false;
}
