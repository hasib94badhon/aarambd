import 'dart:convert';
import 'package:aaram_bd/config.dart';
import 'package:aaram_bd/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

final String host = Config.host;

class RecoveryScreen extends StatefulWidget {
  final String phone;
  const RecoveryScreen({super.key, required this.phone});

  @override
  State<RecoveryScreen> createState() => _ForgotScreenState();
}

class _ForgotScreenState extends State<RecoveryScreen> {
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  // ✅ Separate visibility controls
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.92),
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.black12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFF1A56DB),
          width: 1.6,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Reset Password',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Stack(
        children: [
          // ✅ Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF0F4FA),
                  Color(0xFFF4F8FF),
                  Color(0xFFEDF2FF),
                ],
              ),
            ),
          ),
          // ✅ Soft circles
          Positioned(
            top: -80,
            left: -60,
            child: Container(
              height: 230,
              width: 230,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1A56DB).withValues(alpha: 0.18),
              ),
            ),
          ),
          Positioned(
            bottom: -90,
            right: -70,
            child: Container(
              height: 270,
              width: 270,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1A56DB).withValues(alpha: 0.08),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              child: Column(
                children: [
                  const SizedBox(height: 10),

                  // ✅ Top Info Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.80),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.black12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          height: 68,
                          width: 68,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A56DB)
                                .withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.lock_reset,
                            size: 34,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "Reset Password",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Create a strong new password to secure your account.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.35,
                            color: Colors.black.withValues(alpha: 0.60),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ✅ Form Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.80),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.black12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                    child: Column(
                      children: [
                        // ✅ New Password
                        TextFormField(
                          controller: passwordController,
                          obscureText: _obscureNewPassword,
                          decoration: _inputDecoration(
                            label: "New Password",
                            icon: Icons.lock,
                            hint: "Enter new password",
                            suffix: IconButton(
                              icon: Icon(
                                _obscureNewPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureNewPassword = !_obscureNewPassword;
                                });
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // ✅ Confirm Password
                        TextFormField(
                          controller: confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          decoration: _inputDecoration(
                            label: "Confirm Password",
                            icon: Icons.lock_outline,
                            hint: "Re-enter new password",
                            suffix: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword;
                                });
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        // ✅ Reset Button
                        SizedBox(
                          width: double.infinity,
                          height: 58,
                          child: ElevatedButton(
                            onPressed: () async {
                              String newPass = passwordController.text.trim();
                              String confirmPass =
                                  confirmPasswordController.text.trim();

                              if (newPass.isEmpty || confirmPass.isEmpty) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text("Password fields cannot be empty"),
                                      backgroundColor: Colors.red,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                                return;
                              }

                              if (newPass != confirmPass) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Passwords do not match"),
                                      backgroundColor: Colors.red,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                                return;
                              }

                              try {
                                final response = await http.post(
                                  Uri.parse('$host/reset_password'),
                                  headers: {'Content-Type': 'application/json'},
                                  body: jsonEncode({
                                    'phone': widget.phone,
                                    'password': newPass,
                                  }),
                                );

                                final data = jsonDecode(response.body);

                                if (response.statusCode == 200 &&
                                    data['status'] == 'success') {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            "Password reset successfully"),
                                        backgroundColor: Colors.green,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );

                                    Navigator.pushAndRemoveUntil(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => LoginScreen(),
                                      ),
                                      (Route<dynamic> route) => false,
                                    );
                                  }
                                } else {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(data['message'] ??
                                            'Failed to reset password'),
                                        backgroundColor: Colors.red,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'An error occurred. Please try again.'),
                                      backgroundColor: Colors.red,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              elevation: 0,
                              backgroundColor:
                                  const Color(0xFF1A56DB),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              "Reset Password",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ✅ Footer tip
                  Text(
                    "Tip: Use a password with letters, numbers & symbols.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black.withValues(alpha: 0.55),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
