import '../../models/product_kind.dart';
import '../Database/database_service.dart';

class ProductKindService {
  final DatabaseService _db = DatabaseService();

  Future<List<ProductKind>> getKinds() async {
    return await _db.getProductKinds();
  }

  Future<int> createKind(ProductKind kind) async {
    return await _db.insertProductKind(kind);
  }

  Future<int> updateKind(ProductKind kind) async {
    return await _db.updateProductKind(kind);
  }

  Future<int> deleteKind(int id) async {
    return await _db.deleteProductKind(id);
  }
}
