import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:aaram_bd/config.dart';
import 'package:aaram_bd/localization/app_localizations.dart';
import 'package:aaram_bd/localization/language_provider.dart';
import 'package:aaram_bd/screens/otp_screen.dart';
import 'package:aaram_bd/services/fcm_service.dart';
import 'package:flutter/material.dart';
import 'package:aaram_bd/screens/signup_screen.dart';
import 'package:aaram_bd/screens/navigation_screen.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final String host = Config.host;

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;

  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  static const Color _primaryBlue = Color(0xFF1A56DB);
  static const Color _lightBlue   = Color(0xFF3B82F6);
  static const Color _deepBlue    = Color(0xFF1040B0);
  static const Color _fieldBg     = Color(0xFFF8FAFF);
  static const Color _borderColor = Color(0xFFE8ECF4);
  static const Color _labelColor  = Color(0xFF6B7280);

  AppLocalizations get _l10n =>
      Provider.of<LanguageProvider>(context, listen: false).l10n;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.07),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _loadSavedCredentials() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final savedPhone    = prefs.getString('savedPhone');
    final savedPassword = prefs.getString('savedPassword');
    final rememberMe    = prefs.getBool('rememberMe') ?? false;
    if (rememberMe && savedPhone != null && savedPassword != null) {
      setState(() {
        _phoneController.text    = savedPhone;
        _passwordController.text = savedPassword;
        _rememberMe              = true;
      });
    }
  }

  Future<void> loginUser() async {
    final l10n = _l10n;
    final String apiUrl = '$host/login';
    final Map<String, dynamic> requestData = {
      'phone':    _phoneController.text,
      'password': _passwordController.text.trim(),
    };

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(requestData),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final userPhone    = responseData['user']['phone'];
        final userId       = responseData['user']['user_id'].toString();
        final accessToken  = responseData['access_token'];
        final refreshToken = responseData['refresh_token'];

        await Config.saveTokens(accessToken, refreshToken);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded,
                    color: Colors.greenAccent, size: 20),
                const SizedBox(width: 10),
                Text(
                  l10n.loginSuccess,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF111827),
            behavior: SnackBarBehavior.floating,
            elevation: 6.0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            margin: const EdgeInsets.all(14),
            duration: const Duration(seconds: 3),
          ),
        );

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('userPhone', userPhone);
        await prefs.setString('user_id', userId);

        if (_rememberMe) {
          await prefs.setBool('rememberMe', true);
          await prefs.setString('savedPhone',    _phoneController.text.trim());
          await prefs.setString('savedPassword', _passwordController.text.trim());
        } else {
          await prefs.remove('rememberMe');
          await prefs.remove('savedPhone');
          await prefs.remove('savedPassword');
        }

        if (!mounted) return;
        if (Platform.isAndroid) await FCMService().init(context);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => NavigationScreen(userPhone: userPhone)),
        );
      } else {
        final data      = json.decode(response.body);
        String errorMsg = data['error'] ?? data['message'] ?? l10n.loginFailed;
        _showErrorDialog(errorMsg);
      }
    } catch (e) {
      debugPrint('Login exception: $e');
      if (mounted) _showErrorDialog(l10n.loginUnexpectedError);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String message) {
    final l10n = _l10n;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline_rounded,
                    color: Color(0xFFDC2626), size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.loginErrorTitle,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14, color: Color(0xFF6B7280), height: 1.45),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: Text(
                    l10n.loginOkButton,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
          color: Color(0xFFCBD5E1), fontSize: 14, fontWeight: FontWeight.w400),
      filled: true,
      fillColor: _fieldBg,
      prefixIcon: Icon(icon, color: _primaryBlue, size: 19),
      suffixIcon: suffix,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _borderColor)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _borderColor)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primaryBlue, width: 1.5)),
    );
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF374151)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LanguageProvider>().l10n;
    final screenHeight = MediaQuery.of(context).size.height;

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xFFF0F4FF),
        body: Stack(
          children: [
            Positioned(
              top: 0, left: 0, right: 0,
              height: screenHeight * 0.42,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_deepBlue, _primaryBlue, _lightBlue],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft:  Radius.circular(40),
                    bottomRight: Radius.circular(40),
                  ),
                ),
              ),
            ),
            Positioned(top: -50,  right: -50,  child: _glowCircle(190, 0.07)),
            Positioned(top: 70,   left: -55,   child: _glowCircle(150, 0.05)),
            Positioned(bottom: screenHeight * 0.08, right: -60,
                child: _glowCircle(200, 0.06)),
            SafeArea(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white))
                  : SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: Column(
                        children: [
                          const SizedBox(height: 28),
                          _buildBrandHeader(l10n),
                          const SizedBox(height: 30),
                          FadeTransition(
                            opacity: _fadeAnim,
                            child: SlideTransition(
                              position: _slideAnim,
                              child: _buildFormCard(l10n),
                            ),
                          ),
                          const SizedBox(height: 28),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandHeader(AppLocalizations l10n) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 28,
                  offset: const Offset(0, 10)),
            ],
          ),
          child: Image.asset('images/call1.png',
              height: 60, width: 60, fit: BoxFit.contain),
        ),
        const SizedBox(height: 14),
        Text(
          l10n.appName,
          style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 0.3),
        ),
        const SizedBox(height: 5),
        Text(
          l10n.appTagline,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.75),
              letterSpacing: 0.2),
        ),
      ],
    );
  }

  Widget _buildFormCard(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: _primaryBlue.withValues(alpha: 0.09),
                blurRadius: 32,
                offset: const Offset(0, 14)),
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(22, 28, 22, 26),
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 4, height: 24,
                    decoration: BoxDecoration(
                        color: _primaryBlue,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.loginWelcome,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.loginSubtitle,
                        style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF9CA3AF),
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 26),

              _fieldLabel(l10n.loginMobileLabel),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.w500),
                decoration: _inputDecoration(
                  label: l10n.loginMobileLabel,
                  icon: Icons.phone_android_rounded,
                  hint: '01XXXXXXXXX',
                ),
              ),

              const SizedBox(height: 18),

              _fieldLabel(l10n.loginPasswordLabel),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                autofillHints: const [AutofillHints.password],
                style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.w500),
                decoration: _inputDecoration(
                  label: l10n.loginPasswordLabel,
                  icon: Icons.lock_outline_rounded,
                  hint: '••••••••',
                  suffix: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: _labelColor,
                      size: 19,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _rememberMe = !_rememberMe),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 20, height: 20,
                            decoration: BoxDecoration(
                              color: _rememberMe
                                  ? _primaryBlue
                                  : Colors.transparent,
                              border: Border.all(
                                color: _rememberMe
                                    ? _primaryBlue
                                    : const Color(0xFFCBD5E1),
                                width: 1.6,
                              ),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: _rememberMe
                                ? const Icon(Icons.check,
                                    size: 13, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.loginRememberMe,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF4A5568)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      final userPhone = _phoneController.text.trim();
                      if (userPhone.isEmpty) {
                        _showErrorDialog(_l10n.loginEnterPhone);
                        return;
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                OTPScreen(userPhone: userPhone)),
                      );
                    },
                    child: Text(
                      l10n.loginForgotPassword,
                      style: const TextStyle(
                          color: _primaryBlue,
                          fontSize: 13,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              Container(
                width: double.infinity, height: 54,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_deepBlue, _primaryBlue, _lightBlue],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: _primaryBlue.withValues(alpha: 0.32),
                        blurRadius: 18,
                        offset: const Offset(0, 6)),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: loginUser,
                    child: Center(
                      child: Text(
                        l10n.loginButton,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.3),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 22),

              Row(
                children: [
                  Expanded(
                      child: Divider(
                          color: Colors.black.withValues(alpha: 0.09),
                          thickness: 1)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      l10n.loginOr,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black.withValues(alpha: 0.30),
                          letterSpacing: 0.5),
                    ),
                  ),
                  Expanded(
                      child: Divider(
                          color: Colors.black.withValues(alpha: 0.09),
                          thickness: 1)),
                ],
              ),

              const SizedBox(height: 16),

              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.loginNoAccount,
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.black.withValues(alpha: 0.50)),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => SignUpScreen()),
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        l10n.loginSignUp,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _primaryBlue),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _glowCircle(double size, double opacity) {
    return Container(
      height: size, width: size,
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: opacity)),
    );
  }
}
