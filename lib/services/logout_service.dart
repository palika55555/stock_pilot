import 'package:flutter/material.dart';
import 'api_sync_service.dart';
import 'Database/database_service.dart';
import 'user_session.dart';
import 'sync_check_service.dart';
import 'sync_service.dart';
import '../screens/Login/login_page.dart';

/// Centralizované odhlásenie: vymaže tokeny a session, zastaví sync, presmeruje na login.
/// Lokálna DB a jej dáta sa NEMAŽÚ – sú základom; pri ďalšom prihlásení sú k dispozícii.
class LogoutService {
  static Future<void> logout(BuildContext context) async {
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
