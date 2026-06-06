import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_localizations.dart';

class LanguageProvider extends ChangeNotifier {
  String _languageCode = 'bn';

  String get languageCode => _languageCode;
  bool get isBangla => _languageCode == 'bn';
  AppLocalizations get l10n => AppLocalizations(_languageCode);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _languageCode = prefs.getString('language_code') ?? 'bn';
    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    if (_languageCode == code) return;
    _languageCode = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', code);
    notifyListeners();
  }

  Future<void> toggleLanguage() async {
    await setLanguage(_languageCode == 'bn' ? 'en' : 'bn');
  }
}
