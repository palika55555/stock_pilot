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
      DatabaseService.setCurrentUser(userId);
      final db = DatabaseService();

      // --- Master dáta ---
      final customers = await fetchCustomersFromBackendWithToken(accessToken);
      if (customers != null && customers.isNotEmpty) {
        await db.mergeCustomersFromBackend(customers);
      }
      final products = await fetchProductsFromBackendWithToken(accessToken);
      if (products != null && products.isNotEmpty) {
        await db.mergeProductsFromBackend(products);
      }
      final batches = await fetchBatchesFromBackendWithToken(accessToken);
      if (batches != null) {
        await db.replaceBatchesFromBackend(batches);
      }

      // --- Transakčné dáta ---
      final receiptsData = await fetchReceiptsFromBackend(accessToken);
      if (receiptsData != null) {
        await db.mergeReceiptsFromBackend(receiptsData);
      }
      final stockOutsData = await fetchStockOutsFromBackend(accessToken);
      if (stockOutsData != null) {
        await db.mergeStockOutsFromBackend(stockOutsData);
      }
      final recipesData = await fetchRecipesFromBackend(accessToken);
      if (recipesData != null) {
        await db.mergeRecipesFromBackend(recipesData);
      }
      final ordersData = await fetchProductionOrdersFromBackend(accessToken);
      if (ordersData != null) {
        await db.mergeProductionOrdersFromBackend(ordersData);
      }
      final quotesData = await fetchQuotesFromBackend(accessToken);
      if (quotesData != null) {
        await db.mergeQuotesFromBackend(quotesData);
      }
      final transportsData = await fetchTransportsFromBackend(accessToken);
      if (transportsData != null) {
        await db.mergeTransportsFromBackend(transportsData);
      }
      final companyData = await fetchCompanyFromBackend(accessToken);
      if (companyData != null) {
        await db.mergeCompanyFromBackend(companyData);
      }

      return true;
    } catch (_) {
      return false;
    }
  }
}
