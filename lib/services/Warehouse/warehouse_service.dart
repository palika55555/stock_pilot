import '../../models/warehouse.dart';
import '../database/database_service.dart';

class WarehouseService {
  final DatabaseService _db = DatabaseService();

  Future<List<Warehouse>> getAllWarehouses() async {
    return await _db.getWarehouses();
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
}
