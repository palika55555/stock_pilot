import '../../models/supplier.dart';
import '../Database/database_service.dart';

class SupplierService {
  final DatabaseService _db = DatabaseService();

  Future<List<Supplier>> getAllSuppliers() async {
    return await _db.getSuppliers();
  }

  Future<List<Supplier>> getActiveSuppliers() async {
    return await _db.getActiveSuppliers();
  }

  Future<Supplier?> getSupplierById(int id) async {
    return await _db.getSupplierById(id);
  }

  Future<int> createSupplier(Supplier supplier) async {
    return await _db.insertSupplier(supplier);
  }

  Future<int> updateSupplier(Supplier supplier) async {
    return await _db.updateSupplier(supplier);
  }

  Future<int> deleteSupplier(int id) async {
    return await _db.deleteSupplier(id);
  }
}
