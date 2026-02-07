import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Spravuje tému (svetlá/tmavá) a jazyk aplikácie.
/// Persistuje nastavenia cez SharedPreferences.
class ThemeLocaleProvider extends ChangeNotifier {
  static const String keyDarkMode = 'dark_mode_enabled';
  static const String keyLocale = 'locale';

  bool _isDarkMode = false;
  Locale _locale = const Locale('sk');

  bool get isDarkMode => _isDarkMode;
  Locale get locale => _locale;

  ThemeLocaleProvider({bool? initialDarkMode, String? initialLocale}) {
    if (initialDarkMode != null) _isDarkMode = initialDarkMode;
    if (initialLocale != null) _locale = Locale(initialLocale);
  }

  /// Načíta nastavenia z SharedPreferences. Volať po vytvorení, napr. v main().
  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(keyDarkMode) ?? false;
    final code = prefs.getString(keyLocale) ?? 'sk';
    _locale = Locale(code);
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    if (_isDarkMode == value) return;
    _isDarkMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyDarkMode, value);
    notifyListeners();
  }

  Future<void> setLocale(Locale value) async {
    if (_locale.languageCode == value.languageCode) return;
    _locale = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyLocale, value.languageCode);
    notifyListeners();
  }

  /// Kódy podporovaných jazykov: sk, en, cs
  static const supportedLocales = [Locale('sk'), Locale('en'), Locale('cs')];
}
