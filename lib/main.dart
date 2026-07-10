import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aaram_bd/screens/login_screen.dart';
import 'package:aaram_bd/screens/navigation_screen.dart';
import 'package:aaram_bd/screens/splash_screen.dart';
import 'package:aaram_bd/services/fcm_service.dart';
import 'package:aaram_bd/services/deep_link_service.dart';
import 'package:aaram_bd/localization/language_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final langProvider = LanguageProvider();
  await langProvider.init();

  if (Platform.isAndroid) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
  }

  runApp(
    ChangeNotifierProvider.value(
      value: langProvider,
      child: MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DeepLinkService.instance.init(navigatorKey);
    });
  }

  @override
  void dispose() {
    DeepLinkService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      navigatorObservers: [routeObserver],
      theme: ThemeData(
        useMaterial3: false,
        fontFamily: 'Poppins',
        scaffoldBackgroundColor: const Color(0xFFF0F3F8),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF1A56DB),
          secondary: Color(0xFF43C6A3),
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1A2340),
          elevation: 0,
          scrolledUnderElevation: 1,
          surfaceTintColor: Colors.white,
          titleTextStyle: TextStyle(
            inherit: false,
            fontFamily: 'Poppins',
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A2340),
          ),
          iconTheme: IconThemeData(color: Color(0xFF1A2340)),
        ),
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF7F9FC),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE8EDF5)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE8EDF5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1A56DB), width: 1.5),
          ),
          hintStyle: const TextStyle(
              color: Color(0xFFB0B7C3), fontSize: 14.5),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A56DB),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF1A56DB),
            textStyle: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          backgroundColor: const Color(0xFF1A2340),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFFEAEDF2),
          thickness: 1,
          space: 1,
        ),
      ),
      home: InitialScreen(),
    );
  }
}

class InitialScreen extends StatefulWidget {
  @override
  _InitialScreenState createState() => _InitialScreenState();
}

class _InitialScreenState extends State<InitialScreen> {
  final String host = Config.host;
  @override
  void initState() {
    super.initState();
    _navigateBasedOnState();
  }

  Future<void> _navigateBasedOnState() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isFirstTime = prefs.getBool('isFirstTime') ?? true;
    bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    String userPhone = prefs.getString('userPhone') ?? '';

    print("from main.dart userphone $userPhone");

    if (isFirstTime) {
      // prefs.setBool('isFirstTime', false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => SplashScreen()),
      );
    } else if (isLoggedIn && userPhone.isNotEmpty) {
      // Check if the phone exists in the database.
      // null = couldn't reach the server (e.g. no internet) — NOT the same
      // as the server confirming the account is gone, so don't log out.
      final bool? phoneExists = await _checkPhoneInDatabase(userPhone, context);
      if (phoneExists == false) {
        // Server explicitly confirmed this session is no longer valid.
        await prefs.setBool('isLoggedIn', false);
        await prefs.remove('userPhone');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
        );
      } else {
        // true (confirmed) or null (couldn't check, e.g. offline) — both
        // continue into the app using the cached local session.
        if (phoneExists == true) await _updateLoginTime(userPhone);
        if (Platform.isAndroid) {
          await FCMService().init(context, navigatorKey);
        }
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => NavigationScreen(userPhone: userPhone)),
        );
      }
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    }
  }

  Future<void> _updateLoginTime(String phone) async {
    final uri = '/update_login_time';
    try {
      final resp = await Config.apiPost(uri, {'phone': phone}, context);

      if (resp != null && resp.statusCode != 200) {
        debugPrint('Failed to update login time: ${resp.body}');
      }
    } catch (e) {
      debugPrint('Error calling update_login_time: $e');
    }
  }

  /// Returns true/false when the server explicitly confirms the account's
  /// status, or null when it couldn't be determined (no internet, timeout,
  /// server error) — null must NOT be treated as "log the user out".
  Future<bool?> _checkPhoneInDatabase(String phone, BuildContext context) async {
    final String apiUrl = '/check_phone'; // Updated API endpoint
    final Map<String, dynamic> requestData = {
      'phone': phone,
      'password': 'dummy_password' // Update as necessary
    };

    try {
      final response = await Config.apiPost(apiUrl, requestData, context);

      // null here means Config.apiPost couldn't reach the server at all
      // (no internet, or it already handled a forced logout on 401) — not
      // proof the account is invalid.
      if (response == null) return null;

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData[
            'exists']; // Assumes the API returns a JSON object with an 'exists' boolean field
      }
      // A non-200 from a reachable server (e.g. transient 5xx) is also
      // inconclusive — don't punish the user for a backend hiccup.
      return null;
    } catch (e) {
      print("Exception: $e");
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
