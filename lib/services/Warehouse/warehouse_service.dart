import '../../models/warehouse.dart';
import '../../models/warehouse_movement_record.dart';
import '../../models/warehouse_transfer.dart';
import '../Database/database_service.dart';
import '../monthly_closure_service.dart';

class WarehouseService {
  final DatabaseService _db = DatabaseService();
  final MonthlyClosureService _closures = MonthlyClosureService();

  Future<List<Warehouse>> getAllWarehouses() async {
    return await _db.getWarehouses();
  }

  /// Načíta sklady a doplní počet druhov produktov (itemCount) len pre daný sklad – podľa warehouse_id v produktoch.
  Future<List<Warehouse>> getAllWarehousesWithStats() async {
    final list = await _db.getWarehouses();
    final countByWarehouse = await _db.getProductCountPerWarehouse();
    return list
        .map((w) => w.copyWith(itemCount: w.id != null ? (countByWarehouse[w.id] ?? 0) : 0))
        .toList();
  }

  Future<List<Warehouse>> getActiveWarehouses() async {
    return await _db.getActiveWarehouses();
  }

  Future<Warehouse?> getWarehouseById(int id) async {
    return await _db.getWarehouseById(id);
  }

  Future<int> createWarehouse(Warehouse warehouse) async {
    return await _db.insertWarehouse(warehouse);
  }

  Future<int> updateWarehouse(Warehouse warehouse) async {
    return await _db.updateWarehouse(warehouse);
  }

  Future<int> deleteWarehouse(int id) async {
    return await _db.deleteWarehouse(id);
  }

  Future<List<WarehouseTransfer>> getWarehouseTransfers() async {
    return await _db.getWarehouseTransfers();
  }

  /// Vytvorí presun a aktualizuje zásoby (zdroj −qty, cieľ +qty alebo nová karta).
  Future<int> createWarehouseTransfer(WarehouseTransfer transfer) async {
    await _closures.assertDateOpen(transfer.createdAt);
    return await _db.executeWarehouseTransfer(transfer);
  }

  /// Záznamy knihy skladových pohybov (príjmy, výdaje, presuny). Ak [warehouseId] je zadané, len pohyby daného skladu.
  Future<List<WarehouseMovementRecord>> getWarehouseMovementRecords({int? warehouseId}) async {
    return await _db.getAllWarehouseMovementRecords(warehouseId: warehouseId);
  }
}
