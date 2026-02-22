import 'dart:async';
import '../../models/product.dart';
import '../database/database_service.dart';

class ProductService {
  final DatabaseService _db = DatabaseService();

  Future<List<Product>> getAllProducts() async {
    return await _db.getProducts();
  }

  Future<List<Product>> getProductsByWarehouseId(int warehouseId) async {
    return await _db.getProductsByWarehouseId(warehouseId);
  }

  Future<Product?> getProductById(String uniqueId) async {
    return await _db.getProductByUniqueId(uniqueId);
  }

  Future<void> createProduct(Product product) async {
    await _db.insertProduct(product);
  }

  Future<void> updateProduct(Product product) async {
    await _db.updateProduct(product);
  }

  Future<void> deleteProduct(String uniqueId) async {
    await _db.deleteProduct(uniqueId);
  }

  double calculateWithVat(double priceWithoutVat, int vatPercent) {
    return (priceWithoutVat * (1 + (vatPercent / 100)) * 100).round() / 100;
  }

  double calculateWithoutVat(double priceWithVat, int vatPercent) {
    return (priceWithVat / (1 + (vatPercent / 100)) * 100).round() / 100;
  }
}
