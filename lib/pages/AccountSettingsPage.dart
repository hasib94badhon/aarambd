import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:aaram_bd/config.dart';
import 'package:aaram_bd/widgets/app_toast.dart';

const Color _brand = Color(0xFF1A56DB);

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

  bool _obscureCurrentPw = true;
  bool _obscureNewPw = true;
  bool _obscureConfirmPw = true;

  static final RegExp _emailRegex =
      RegExp(r'^[\w\.\-]+@[\w\-]+\.[a-zA-Z]{2,}$');

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

    final wantsPwChange =
        curPw.isNotEmpty || newPw.isNotEmpty || confPw.isNotEmpty;

    if (!wantsEmailUpdate && !wantsPwChange) {
      _showSnack('Nothing to update');
      return;
    }

    // Quick local validations — catch obvious mistakes before hitting the network.
    if (wantsEmailUpdate && newEmail.isNotEmpty && !_emailRegex.hasMatch(newEmail)) {
      _showSnack('Enter a valid email address', isError: true);
      return;
    }
    if (wantsPwChange) {
      if (curPw.isEmpty || newPw.isEmpty || confPw.isEmpty) {
        _showSnack('Please fill all password fields', isError: true);
        return;
      }
      if (newPw.length < 6) {
        _showSnack('New password must be at least 6 characters', isError: true);
        return;
      }
      if (newPw != confPw) {
        _showSnack('New password and confirmation do not match', isError: true);
        return;
      }
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
            _extractMessage(emailResp?.body ?? '') ?? 'Failed to update email';
        _showSnack(msg, isError: true);
        setState(() => _loading = false);
        return;
      }

      // 2) Change password, if requested
      if (wantsPwChange) {
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
    showAppToast(context, msg,
        icon: isError
            ? Icons.error_outline_rounded
            : Icons.check_circle_outline_rounded);
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _cardHeader(IconData icon, Color color, String title, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration:
                BoxDecoration(color: color.withValues(alpha: 0.10), shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.w500, color: Color(0xFF6B7280))),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    bool isPassword = false,
    bool enabled = true,
    VoidCallback? onToggleObscure,
    bool obscured = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: enabled ? const Color(0xFFF9FAFB) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: TextField(
        enabled: enabled,
        controller: controller,
        obscureText: isPassword ? obscured : false,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          icon: Icon(icon, size: 20, color: enabled ? _brand : Colors.black38),
          labelText: label,
          labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
          border: InputBorder.none,
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    obscured ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                    size: 19,
                    color: Colors.black38,
                  ),
                  onPressed: onToggleObscure,
                )
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FF),
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          _buildHeader(context),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
                16, 16, 16, 20 + MediaQuery.of(context).padding.bottom),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildCard(children: [
                  _cardHeader(Icons.phone_android_rounded, _brand, 'Phone Number',
                      subtitle: 'Contact AaramBD support to change this'),
                  _buildTextField(
                    label: "Phone Number",
                    icon: Icons.phone_android_rounded,
                    controller: phoneController,
                    enabled: false,
                  ),
                ]),
                _buildCard(children: [
                  _cardHeader(
                    Icons.email_rounded,
                    const Color(0xFF7C3AED),
                    emailExists ? 'Change Email' : 'Add Email',
                    subtitle: emailExists
                        ? 'Used for account recovery'
                        : 'Add an email for account recovery',
                  ),
                  _buildTextField(
                    label: emailExists ? "New Email Address" : "Email Address",
                    icon: Icons.email_outlined,
                    controller: emailController,
                  ),
                ]),
                _buildCard(children: [
                  _cardHeader(Icons.lock_rounded, const Color(0xFFD97706), 'Change Password',
                      subtitle: 'Leave blank if you don\'t want to change it'),
                  _buildTextField(
                    label: "Current Password",
                    icon: Icons.lock_outline_rounded,
                    controller: currentPasswordController,
                    isPassword: true,
                    obscured: _obscureCurrentPw,
                    onToggleObscure: () =>
                        setState(() => _obscureCurrentPw = !_obscureCurrentPw),
                  ),
                  _buildTextField(
                    label: "New Password",
                    icon: Icons.lock_rounded,
                    controller: newPasswordController,
                    isPassword: true,
                    obscured: _obscureNewPw,
                    onToggleObscure: () => setState(() => _obscureNewPw = !_obscureNewPw),
                  ),
                  _buildTextField(
                    label: "Confirm New Password",
                    icon: Icons.lock_rounded,
                    controller: confirmPasswordController,
                    isPassword: true,
                    obscured: _obscureConfirmPw,
                    onToggleObscure: () =>
                        setState(() => _obscureConfirmPw = !_obscureConfirmPw),
                  ),
                ]),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save_alt_rounded, color: Colors.white, size: 19),
                    label: const Text("Save Changes",
                        style: TextStyle(
                            color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brand,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _loading ? null : _saveAccountSettings,
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        padding:
            EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 14, 16, 22),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1040B0), _brand],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        ),
        child: Stack(
          children: [
            Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => Navigator.pop(context),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.manage_accounts_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Account Settings',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Phone, email, password',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_loading)
              const Positioned(
                right: 0,
                top: 0,
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
