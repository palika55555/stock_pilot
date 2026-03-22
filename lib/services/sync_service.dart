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
  /// Fetche bežia paralelne – zrýchľuje initial sync ~3–5×.
  static Future<bool> initialSync(String userId, String accessToken) async {
    try {
      DatabaseService.setCurrentUser(userId);
      final db = DatabaseService();

      // Paralelný fetch všetkých entít naraz
      final results = await Future.wait([
        fetchCustomersFromBackendWithToken(accessToken),       // 0
        fetchProductsFromBackendWithToken(accessToken),        // 1
        fetchBatchesFromBackendWithToken(accessToken),         // 2
        fetchReceiptsFromBackend(accessToken),                 // 3
        fetchStockOutsFromBackend(accessToken),                // 4
        fetchRecipesFromBackend(accessToken),                  // 5
        fetchProductionOrdersFromBackend(accessToken),         // 6
        fetchQuotesFromBackend(accessToken),                   // 7
        fetchTransportsFromBackend(accessToken),               // 8
        fetchCompanyFromBackend(accessToken),                  // 9
      ]);

      final customers  = results[0] as List<Map<String, dynamic>>?;
      final products   = results[1] as List<Map<String, dynamic>>?;
      final batches    = results[2] as List<Map<String, dynamic>>?;
      final receipts   = results[3] as Map<String, dynamic>?;
      final stockOuts  = results[4] as Map<String, dynamic>?;
      final recipes    = results[5] as Map<String, dynamic>?;
      final orders     = results[6] as Map<String, dynamic>?;
      final quotes     = results[7] as Map<String, dynamic>?;
      final transports = results[8] as Map<String, dynamic>?;
      final company    = results[9] as Map<String, dynamic>?;

      if (customers != null && customers.isNotEmpty) {
        await db.mergeCustomersFromBackend(customers);
      }
      if (products != null && products.isNotEmpty) {
        await db.mergeProductsFromBackend(products);
      }
      if (batches != null) await db.replaceBatchesFromBackend(batches);
      if (receipts != null) await db.mergeReceiptsFromBackend(receipts);
      if (stockOuts != null) await db.mergeStockOutsFromBackend(stockOuts);
      if (recipes != null) await db.mergeRecipesFromBackend(recipes);
      if (orders != null) await db.mergeProductionOrdersFromBackend(orders);
      if (quotes != null) await db.mergeQuotesFromBackend(quotes);
      if (transports != null) await db.mergeTransportsFromBackend(transports);
      if (company != null) await db.mergeCompanyFromBackend(company);

      return true;
    } catch (_) {
      return false;
    }
  }
}
