import 'package:flutter/material.dart';
import 'api_sync_service.dart';
import 'Database/database_service.dart';
import 'user_session.dart';
import 'sync_check_service.dart';
import 'sync_service.dart';
import '../screens/Login/login_page.dart';

/// Centralizované odhlásenie: vymaže tokeny, lokálne uložené prihlásenie, zastaví sync, presmeruje na login.
class LogoutService {
  static Future<void> logout(BuildContext context) async {
    await DatabaseService().clearCurrentUserData();
    await clearTokensAndToken();
    await DatabaseService().clearSavedLogin();
    UserSession.clear();
    SyncCheckService.instance.stop();
    SyncService.stopSync();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (Route<dynamic> route) => false,
    );
  }
}
