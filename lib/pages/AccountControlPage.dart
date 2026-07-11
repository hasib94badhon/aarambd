// lib/screens/account_control_page.dart

import 'dart:convert';
import 'package:aaram_bd/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:aaram_bd/config.dart';
import 'package:aaram_bd/widgets/app_toast.dart';

class AccountControlPage extends StatefulWidget {
  @override
  _AccountControlPageState createState() => _AccountControlPageState();
}

class _AccountControlPageState extends State<AccountControlPage> {
  final List<String> deactivateReasons = [
    "I'm taking a break",
    "I get too many notifications",
    "Concerned about privacy",
    "I found an alternative",
  ];
  final Set<String> selectedDeactivateReasons = {};

  bool _isSubmitting = false;

  // ── Delete account state ──────────────────────────────────────────────
  final TextEditingController _deletePasswordCtrl = TextEditingController();
  final TextEditingController _deleteSecretCtrl = TextEditingController();
  bool _useSecretCodeForDelete = false;
  bool _isDeletingAccount = false;

  @override
  void dispose() {
    _deletePasswordCtrl.dispose();
    _deleteSecretCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmDeactivation() async {
    if (selectedDeactivateReasons.isEmpty) {
      showAppToast(context, "Please select at least one reason.",
          icon: Icons.error_outline_rounded);
      return;
    }

    setState(() => _isSubmitting = true);

    // Call your API via Config.apiPost
    final response = await Config.apiPost(
      '/user/deactivate',
      {'reasons': selectedDeactivateReasons.toList()},
      context,
    );

    setState(() => _isSubmitting = false);

    if (response == null) {
      // Config.apiPost returns null if refresh fails and force logout happens
      return;
    }

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final msg = body['message'] ?? 'Account deactivated.';
      showAppToast(context, msg, icon: Icons.check_circle_outline_rounded);

      // Clear tokens & navigate back to login
      await Config.clearTokens();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
            builder: (_) => LoginScreen()), // Assuming you have a LoginPage
        (route) => false,
      );
    } else {
      final body = jsonDecode(response.body);
      final errorMsg =
          body['message'] ?? body['error'] ?? 'Deactivation failed';
      showAppToast(context, errorMsg, icon: Icons.error_outline_rounded);
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final credential = _useSecretCodeForDelete
        ? _deleteSecretCtrl.text.trim()
        : _deletePasswordCtrl.text.trim();

    if (credential.isEmpty) {
      showAppToast(
          context,
          _useSecretCodeForDelete
              ? "Please enter your secret code."
              : "Please enter your password.",
          icon: Icons.error_outline_rounded);
      return;
    }

    setState(() => _isDeletingAccount = true);

    final response = await Config.apiPost(
      '/user/delete_account',
      _useSecretCodeForDelete
          ? {'secret_number': credential}
          : {'password': credential},
      context,
    );

    setState(() => _isDeletingAccount = false);

    if (response == null) return;

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final msg = body['message'] ?? 'Your account has been permanently deleted.';
      showAppToast(context, msg, icon: Icons.check_circle_outline_rounded);

      await Config.clearTokens();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen()),
        (route) => false,
      );
    } else {
      final body = jsonDecode(response.body);
      final errorMsg =
          body['message'] ?? body['error'] ?? 'Account deletion failed';
      showAppToast(context, errorMsg, icon: Icons.error_outline_rounded);
    }
  }

  Widget _buildDeactivateCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        leading: Icon(Icons.pause_circle, color: Colors.amber.shade700),
        title: Text(
          "Deactivate Account",
          style: TextStyle(
            color: Colors.amber.shade700,
            fontWeight: FontWeight.bold,
          ),
        ),
        children: [
          ...deactivateReasons.map((reason) {
            return CheckboxListTile(
              title: Text(reason),
              value: selectedDeactivateReasons.contains(reason),
              activeColor: Colors.amber.shade700,
              onChanged: (checked) {
                setState(() {
                  if (checked == true) {
                    selectedDeactivateReasons.add(reason);
                  } else {
                    selectedDeactivateReasons.remove(reason);
                  }
                });
              },
            );
          }).toList(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: _isSubmitting
                ? Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    icon: Icon(Icons.check_circle_outline),
                    label: Text("Confirm Deactivate"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      padding:
                          EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: StadiumBorder(),
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: Text("Confirm Deactivation"),
                            content: Text(
                              "Are you sure you want to deactivate your account?\n\n"
                              "You can reactivate anytime by simply logging back in "
                              "with your phone and password (or secret code).",
                              style: TextStyle(fontSize: 15),
                            ),
                            actions: [
                              TextButton(
                                child: Text("No",
                                    style: TextStyle(color: Colors.grey[700])),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber.shade700,
                                ),
                                child: Text("Yes"),
                                onPressed: () async {
                                  Navigator.of(context).pop(); // Close dialog
                                  await _confirmDeactivation(); // Proceed with deactivation
                                },
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        leading: Icon(Icons.delete_forever, color: Colors.red.shade700),
        title: Text(
          "Delete Account",
          style: TextStyle(
            color: Colors.red.shade700,
            fontWeight: FontWeight.bold,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              "This permanently deletes your account and everything in it — "
              "posts, reviews, notifications, calls, and listings. "
              "This cannot be undone.",
              style: TextStyle(fontSize: 13.5, color: Colors.grey[700]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _useSecretCodeForDelete
                        ? _deleteSecretCtrl
                        : _deletePasswordCtrl,
                    obscureText: !_useSecretCodeForDelete,
                    keyboardType: _useSecretCodeForDelete
                        ? TextInputType.number
                        : TextInputType.text,
                    decoration: InputDecoration(
                      labelText: _useSecretCodeForDelete
                          ? "Secret Code"
                          : "Password",
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _useSecretCodeForDelete = !_useSecretCodeForDelete;
                  });
                },
                child: Text(
                  _useSecretCodeForDelete
                      ? "Use password instead"
                      : "Use secret code instead",
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: _isDeletingAccount
                ? Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    icon: Icon(Icons.warning_amber_rounded),
                    label: Text("Delete Permanently"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      padding:
                          EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: StadiumBorder(),
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: Text("Permanently Delete Account?"),
                            content: Text(
                              "This is permanent and cannot be undone. All your posts, "
                              "reviews, notifications, calls, and listings will be erased.",
                              style: TextStyle(fontSize: 15),
                            ),
                            actions: [
                              TextButton(
                                child: Text("Cancel",
                                    style: TextStyle(color: Colors.grey[700])),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade700,
                                  foregroundColor: Colors.white,
                                ),
                                child: Text("Delete Permanently"),
                                onPressed: () async {
                                  Navigator.of(context).pop();
                                  await _confirmDeleteAccount();
                                },
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Account Control"),
        backgroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            SizedBox(height: 8),
            _buildDeactivateCard(),
            SizedBox(height: 16),
            _buildDeleteCard(),
          ],
        ),
      ),
    );
  }
}
