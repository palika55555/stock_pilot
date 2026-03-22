import 'dart:async';
import 'api_sync_service.dart';
import 'Database/database_service.dart';
import 'data_change_notifier.dart';
import 'product_cache.dart';

/// Automatically pushes local changes to the backend within ~1 second.
/// Usage: call start() after login and stop() after logout.
/// DatabaseService notifies via DataChangeNotifier; this service debounces
/// and performs a full sync of all entity types.
class AutoPushService {
  static final AutoPushService instance = AutoPushService._();
  AutoPushService._();

  Timer? _debounce;
  bool _isSyncing = false;
  bool _pendingWhileSyncing = false;

  void start() {
    DataChangeNotifier.register(_onDataChanged);
  }

  void stop() {
    DataChangeNotifier.unregister();
    _debounce?.cancel();
    _debounce = null;
  }

  void _onDataChanged() {
    if (_isSyncing) {
      _pendingWhileSyncing = true;
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), _performSync);
  }

  Future<void> _performSync() async {
    final token = getBackendToken();
    if (token == null || token.isEmpty) return;

    _isSyncing = true;
    _pendingWhileSyncing = false;
    try {
      final db = DatabaseService();

      // Master data (need local fetch first)
      final products = await ProductCache.instance.load();
      syncProductsToBackend(products); // fire-and-forget (void)

      final customers = await db.getCustomers();
      await syncCustomersToBackend(customers);

      final warehouses = await db.getWarehouses();
      await syncWarehousesToBackend(warehouses);

      final suppliers = await db.getSuppliers();
      await syncSuppliersToBackend(suppliers);

      // Transactional data (fetch from DB internally)
      await syncReceiptsToBackend();
      await syncStockOutsToBackend();
      await syncRecipesToBackend();
      await syncProductionOrdersToBackend();
      await syncQuotesToBackend();
      await syncTransportsToBackend();
      await syncBatchesToBackend();
      await syncCompanyToBackend();
    } catch (_) {
      // silent – offline or auth error; will retry on next change
    } finally {
      _isSyncing = false;
      if (_pendingWhileSyncing) {
        _pendingWhileSyncing = false;
        _onDataChanged();
      }
    }
  }
}
