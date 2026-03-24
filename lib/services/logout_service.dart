import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_sync_service.dart';
import 'Database/database_service.dart';
import 'user_session.dart';
import 'sync_check_service.dart';
import 'sync_service.dart';
import 'auto_push_service.dart';
import 'sync/sync_manager.dart';
import 'product_cache.dart';
import 'auto_lock_service.dart';
import '../screens/Login/login_page.dart';
import '../widgets/welcome/logout_farewell_screen.dart';

/// Centralizované odhlásenie: vymaže tokeny a session, zastaví sync, presmeruje na login.
/// Lokálna DB a jej dáta sa NEMAŽÚ – sú základom; pri ďalšom prihlásení sú k dispozícii.
class LogoutService {
  /// Zobrazí rozlúčkovú obrazovku, potom vyčistí session a otvorí prihlásenie.
  static void beginLogoutFlow(
    BuildContext context, {
    bool idleTimeout = false,
  }) {
    if (!context.mounted) return;
    final displayName = UserSession.username ?? '';
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (context) => LogoutFarewellScreen(
          idleTimeout: idleTimeout,
          displayName: displayName,
        ),
      ),
    );
  }

  /// Volá sa z [LogoutFarewellScreen] po animácii – dokončí odhlásenie a presmeruje na login.
  static Future<void> finalizeLogout(BuildContext context) async {
    SyncCheckService.instance.stop();
    SyncService.stopSync();
    AutoPushService.instance.stop();
    AutoLockService.instance.stop();

    SyncManager.instance.disposeForLogout();

    ProductCache.instance.clear();
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
