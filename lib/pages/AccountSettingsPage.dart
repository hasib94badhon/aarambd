import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:aaram_bd/config.dart';

class AccountSettingsPage extends StatefulWidget {
  @override
  _AccountSettingsPageState createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController additionalPhoneController =
      TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController changeEmailController = TextEditingController();
  final TextEditingController currentPasswordController =
      TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool emailExists = false;
  bool _loading = false;
  String _initialEmail = '';

  @override
  void initState() {
    super.initState();
    _loadAccountSettings();
  }

  Future<void> _loadAccountSettings() async {
    setState(() => _loading = true);
    try {
      final userId = await Config.getLoggedInUser(); // you said this exists
      final uri = '/account_settings?user_id=$userId';
      final resp = await Config.apiGet(uri, context);
      if (resp != null && resp.statusCode == 200) {
        final data = json.decode(resp.body);
        phoneController.text = data['phone'] ?? '';
        final email = data['email'] ?? '';
        emailController.text = email;
        _initialEmail = email;
        emailExists = email.isNotEmpty;
        setState(() {});
      } else {
        _showSnack('Failed to load account settings', isError: true);
      }
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveAccountSettings() async {
    final userId = await Config.getLoggedInUser();
    final String newEmail = emailController.text.trim();
    final wantsEmailUpdate = newEmail != _initialEmail;
    final String curPw = currentPasswordController.text;
    final String newPw = newPasswordController.text;
    final String confPw = confirmPasswordController.text;

    // quick local validations

    final wantsPwChange =
        curPw.isNotEmpty || newPw.isNotEmpty || confPw.isNotEmpty;

    if (!wantsEmailUpdate && !wantsPwChange) {
      _showSnack('Nothing to update');
      return;
    }

    setState(() => _loading = true);

    try {
      // 1) Update email (even empty string is allowed)
      final emailResp = await Config.apiPut(
        "/account_settings",
        {
          'user_id': userId,
          'email': newEmail,
        },
        context,
      );

      if (emailResp == null || emailResp.statusCode != 200) {
        final msg =
            _extractMessage(emailResp!.body) ?? 'Failed to update email';
        _showSnack(msg, isError: true);
        setState(() => _loading = false);
        return;
      }

      // 2) Change password, if requested
      if (wantsPwChange) {
        if (curPw.isEmpty || newPw.isEmpty || confPw.isEmpty) {
          _showSnack('Please fill all password fields', isError: true);
          setState(() => _loading = false);
          return;
        }
        final pwResp = await Config.apiPost(
            "/change_password",
            {
              'user_id': userId,
              'current_password': curPw,
              'new_password': newPw,
              'confirm_password': confPw,
            },
            context);
        if (pwResp == null || pwResp.statusCode != 200) {
          final msg = _extractMessage(pwResp?.body ?? '') ??
              'Failed to change password';
          _showSnack(msg, isError: true);
          setState(() => _loading = false);
          return;
        }

        // Clear password fields on success
        currentPasswordController.clear();
        newPasswordController.clear();
        confirmPasswordController.clear();
      }

      // Refresh UI state (e.g., emailExists) after saving
      emailExists = newEmail.isNotEmpty;
      setState(() {});
      _showSnack('Account settings updated successfully!', isError: false);
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  String? _extractMessage(String body) {
    try {
      final j = json.decode(body);
      return j['message'] ?? j['error'];
    } catch (_) {
      return null;
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Text(title,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }

  Widget _buildTextField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    bool isPassword = false,
    bool enabled = true,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      padding: EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(2, 2)),
        ],
      ),
      child: TextField(
        enabled: enabled,
        controller: controller,
        obscureText: isPassword,
        decoration: InputDecoration(
          icon: Icon(icon),
          labelText: label,
          border: InputBorder.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Account Settings",
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.lightBlue[200],
        elevation: 0,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle("Phone Number"),
                _buildTextField(
                  label: "Current Phone Number",
                  icon: Icons.phone_android,
                  controller: phoneController,
                  enabled: false, // keep your original behavior
                ),
                _buildSectionTitle(emailExists ? "Change Email" : "Add Email"),
                _buildTextField(
                  label: emailExists ? "New Email Address" : "Email Address",
                  icon: Icons.email_outlined,
                  controller: emailController,
                ),
                _buildSectionTitle("Change Password"),
                _buildTextField(
                  label: "Current Password",
                  icon: Icons.lock_outline,
                  controller: currentPasswordController,
                  isPassword: true,
                ),
                _buildTextField(
                  label: "New Password",
                  icon: Icons.lock,
                  controller: newPasswordController,
                  isPassword: true,
                ),
                _buildTextField(
                  label: "Confirm New Password",
                  icon: Icons.lock,
                  controller: confirmPasswordController,
                  isPassword: true,
                ),
                // Align(
                //   alignment: Alignment.centerRight,
                //   child: TextButton(
                //     onPressed: () =>
                //         Navigator.pushNamed(context, '/forgot-password'),
                //     child: Text("Forgot Password?"),
                //   ),
                // ),
                SizedBox(height: 20),
                Center(
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.save_alt, color: Colors.white),
                    label: Text("Save Changes",
                        style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.lightBlue,
                      padding:
                          EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                      elevation: 5,
                      shadowColor: Colors.black38,
                    ),
                    onPressed: _loading ? null : _saveAccountSettings,
                  ),
                ),
                SizedBox(height: 30),
              ],
            ),
          ),
          if (_loading)
            Container(
              color: Colors.black.withValues(alpha: 0.08),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
