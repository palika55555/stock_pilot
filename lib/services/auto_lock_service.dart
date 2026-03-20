import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'logout_service.dart';

/// Služba automatického uzamknutia / odhlásenia po nečinnosti.
/// Pref kľúč: `auto_lock_minutes` (0 = vypnuté, inak počet minút).
class AutoLockService {
  static final AutoLockService instance = AutoLockService._();
  AutoLockService._();

  static const String _prefKey = 'auto_lock_minutes';

  Timer? _timer;
  int _timeoutMinutes = 0;
  DateTime? _backgroundedAt;
  BuildContext? _context;

  /// Načíta nastavenie z prefs a spustí timer (ak je povolený).
  Future<void> start(BuildContext context) async {
    _context = context;
    final prefs = await SharedPreferences.getInstance();
    _timeoutMinutes = prefs.getInt(_prefKey) ?? 0;
    _resetTimer();
  }

  /// Zastaví timer (pri odhlásení).
  void stop() {
    _timer?.cancel();
    _timer = null;
    _context = null;
    _backgroundedAt = null;
  }

  /// Volaj pri každej interakcii používateľa (PointerDown).
  void resetOnActivity() {
    if (_timeoutMinutes == 0) return;
    _resetTimer();
  }

  /// Aktualizuje timeout za behu (pri zmene v nastaveniach).
  void updateTimeout(int minutes) {
    _timeoutMinutes = minutes;
    _resetTimer();
  }

  /// Volaj pri AppLifecycleState.paused – uloží čas prechodu do pozadia.
  void onAppPaused() {
    _backgroundedAt = DateTime.now();
    _timer?.cancel();
  }

  /// Volaj pri AppLifecycleState.resumed – skontroluje či uplynul timeout.
  void onAppResumed() {
    if (_timeoutMinutes == 0) {
      _resetTimer();
      return;
    }
    final bg = _backgroundedAt;
    if (bg != null) {
      final elapsed = DateTime.now().difference(bg).inMinutes;
      if (elapsed >= _timeoutMinutes) {
        _lock();
        return;
      }
    }
    _resetTimer();
  }

  void _resetTimer() {
    _timer?.cancel();
    if (_timeoutMinutes <= 0) return;
    _timer = Timer(Duration(minutes: _timeoutMinutes), _lock);
  }

  void _lock() {
    _timer?.cancel();
    final ctx = _context;
    if (ctx != null && ctx.mounted) {
      LogoutService.logout(ctx);
    }
  }

  /// Uloží novú hodnotu do SharedPreferences.
  static Future<void> saveTimeout(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKey, minutes);
  }

  /// Načíta uloženú hodnotu (pre zobrazenie v nastaveniach).
  static Future<int> loadTimeout() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefKey) ?? 0;
  }
}
