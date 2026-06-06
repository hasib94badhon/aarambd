import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aaram_bd/screens/onboarding.dart';
import 'package:aaram_bd/screens/login_screen.dart';
import 'package:aaram_bd/screens/navigation_screen.dart';

class SplashScreen extends StatefulWidget {
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    // 🔄 One full rotation = 2 seconds
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    // When rotation completes, go to next screen
    _controller.forward().whenComplete(() {
      _navigateBasedOnState();
    });
  }

  Future<void> _navigateBasedOnState() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstTime = prefs.getBool('isFirstTime') ?? true;
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    if (isFirstTime) {
      await prefs.setBool('isFirstTime', false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => Onboarding()),
      );
    } else if (isLoggedIn) {
      final userPhone = prefs.getString('userPhone') ?? '';
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => NavigationScreen(userPhone: userPhone)),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _brand => const Color(0xFF6C78DF); // your brand color

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Material(
      child: Container(
        height: size.height,
        width: size.width,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_brand, const Color(0xFF8A95FF)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo rotates once (0 → 360°)
            RotationTransition(
              turns: Tween(begin: 0.0, end: 1.0).animate(
                CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
              ),
              child: Image.asset(
                "images/app_icon.png",
                width: 120,
                height: 120,
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'In search for everything you need',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              'PoweredBy @ AaramBD',
              style: TextStyle(
                color: Color(0xFF1A56DB),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
