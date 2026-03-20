import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_sync_service.dart';
import 'Database/database_service.dart';
import 'user_session.dart';
import 'sync_check_service.dart';
import 'sync_service.dart';
import 'auto_push_service.dart';
import 'sync/sync_manager.dart';
import '../screens/Login/login_page.dart';

/// Centralizované odhlásenie: vymaže tokeny a session, zastaví sync, presmeruje na login.
/// Lokálna DB a jej dáta sa NEMAŽÚ – sú základom; pri ďalšom prihlásení sú k dispozícii.
class LogoutService {
  static Future<void> logout(BuildContext context) async {
    final userId = UserSession.userId;

    // Zastav všetky sync služby
    SyncCheckService.instance.stop();
    SyncService.stopSync();
    AutoPushService.instance.stop();

    // Zastav SyncManager – offline fronta sa zachová pre ďalšie prihlásenie
    SyncManager.instance.disposeForLogout();

    await clearTokensAndToken();
    await DatabaseService().clearSavedLogin();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user_owner_name');
    UserSession.clear();

    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (Route<dynamic> route) => false,
    );
  }
}
