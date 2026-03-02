import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'api_sync_service.dart';
import 'Database/database_service.dart';
import 'sync_check_service.dart';

/// Background sync: každých 5 min + pri obnove connectivity. Zastaví sa pri odhlásení.
class SyncService {
  static Timer? _syncTimer;
  static StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  static const Duration _syncInterval = Duration(minutes: 5);

  /// Spustí periodický sync (každých 5 min) a sync pri obnove connectivity. Volaj po prihlásení.
  static void startSync(String userId) {
    stopSync();
    _syncTimer = Timer.periodic(_syncInterval, (_) => _performSync(userId));
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> result) {
      final first = result.isNotEmpty ? result.first : ConnectivityResult.none;
      if (first != ConnectivityResult.none) {
        _performSync(userId);
      }
    });
    _performSync(userId);
  }

  static Future<void> _performSync(String userId) async {
    try {
      final token = getBackendToken();
      if (token == null || token.isEmpty) return;
      await SyncCheckService.instance.triggerCheck();
    } catch (_) {}
  }

  static void stopSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  static Future<void> cancelAllSubscriptions() async {
    stopSync();
  }

  /// Po prihlásení: stiahne dáta používateľa z backendu a uloží do lokálnej DB.
  static Future<bool> initialSync(String userId, String accessToken) async {
    try {
      final customers = await fetchCustomersFromBackendWithToken(accessToken);
      if (customers != null && customers.isNotEmpty) {
        await DatabaseService().replaceCustomersFromBackend(customers);
      }
      final products = await fetchProductsFromBackendWithToken(accessToken);
      if (products != null && products.isNotEmpty) {
        await DatabaseService().updateProductEanFromBackend(products);
      }
      final batches = await fetchBatchesFromBackendWithToken(accessToken);
      if (batches != null) {
        await DatabaseService().replaceBatchesFromBackend(batches);
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
