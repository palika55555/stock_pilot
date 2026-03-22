import 'dart:async';
import '../../models/product.dart';
import '../Database/database_service.dart';
import '../product_cache.dart';

class ProductService {
  final DatabaseService _db = DatabaseService();

  Future<List<Product>> getAllProducts() async {
    return await ProductCache.instance.load();
  }

  Future<int> countWarehouseSuppliesFiltered({
    int? warehouseId,
    String? searchQuery,
    String? statusFilter,
  }) {
    return _db.countWarehouseSuppliesFiltered(
      warehouseId: warehouseId,
      searchQuery: searchQuery,
      statusFilter: statusFilter,
    );
  }

  Future<List<Product>> getWarehouseSuppliesPage({
    int? warehouseId,
    String? searchQuery,
    String? statusFilter,
    required String sortKey,
    required bool ascending,
    required int limit,
    required int offset,
  }) {
    return _db.getWarehouseSuppliesPage(
      warehouseId: warehouseId,
      searchQuery: searchQuery,
      statusFilter: statusFilter,
      sortKey: sortKey,
      ascending: ascending,
      limit: limit,
      offset: offset,
    );
  }

  Future<({double totalQty, double totalValue, int lowStockCount})>
      aggregateWarehouseSuppliesFiltered({
    int? warehouseId,
    String? searchQuery,
    String? statusFilter,
  }) {
    return _db.aggregateWarehouseSuppliesFiltered(
      warehouseId: warehouseId,
      searchQuery: searchQuery,
      statusFilter: statusFilter,
    );
  }

  Future<List<Product>> getWarehouseSuppliesLowStockList({
    int? warehouseId,
    String? searchQuery,
    String? statusFilter,
  }) {
    return _db.getWarehouseSuppliesLowStockList(
      warehouseId: warehouseId,
      searchQuery: searchQuery,
      statusFilter: statusFilter,
    );
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
