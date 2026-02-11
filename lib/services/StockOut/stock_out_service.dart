import '../../models/product.dart';
import '../../models/stock_out.dart';
import '../Database/database_service.dart';

/// Chyba pri nedostatočnom stave skladu pre výdaj.
class InsufficientStockException implements Exception {
  final String productName;
  final String plu;
  final int requested;
  final int available;

  InsufficientStockException({
    required this.productName,
    required this.plu,
    required this.requested,
    required this.available,
  });

  @override
  String toString() =>
      'Na sklade je nedostatočné množstvo: $productName (PLU: $plu). Požadované: $requested, dostupné: $available.';
}

class StockOutService {
  final DatabaseService _db = DatabaseService();

  Future<List<StockOut>> getAllStockOuts() async {
    return await _db.getStockOuts();
  }

  Future<StockOut?> getStockOutById(int id) async {
    return await _db.getStockOutById(id);
  }

  Future<List<StockOutItem>> getStockOutItems(int stockOutId) async {
    return await _db.getStockOutItems(stockOutId);
  }

  /// Validuje, že pre každú položku je na sklade dostatok kusov. Vyhodí [InsufficientStockException] ak nie.
  Future<void> _validateStock(List<StockOutItem> items) async {
    for (final item in items) {
      final product = await _db.getProductByUniqueId(item.productUniqueId);
      if (product == null) {
        throw Exception('Produkt ${item.productName ?? item.productUniqueId} nebol nájdený.');
      }
      if (product.qty < item.qty) {
        throw InsufficientStockException(
          productName: product.name,
          plu: product.plu,
          requested: item.qty,
          available: product.qty,
        );
      }
    }
  }

  /// Zníži stav skladu podľa položiek výdajky.
  Future<void> _applyStockOutToProducts(int stockOutId) async {
    final items = await _db.getStockOutItems(stockOutId);
    for (final item in items) {
      final product = await _db.getProductByUniqueId(item.productUniqueId);
      if (product != null && product.qty >= item.qty) {
        final updated = Product(
          uniqueId: product.uniqueId,
          name: product.name,
          plu: product.plu,
          category: product.category,
          qty: product.qty - item.qty,
          unit: product.unit,
          price: product.price,
          withoutVat: product.withoutVat,
          vat: product.vat,
          discount: product.discount,
          lastPurchasePrice: product.lastPurchasePrice,
          lastPurchasePriceWithoutVat: product.lastPurchasePriceWithoutVat,
          lastPurchaseDate: product.lastPurchaseDate,
          currency: product.currency,
          location: product.location,
          purchasePrice: product.purchasePrice,
          purchasePriceWithoutVat: product.purchasePriceWithoutVat,
          purchaseVat: product.purchaseVat,
          recyclingFee: product.recyclingFee,
          productType: product.productType,
          supplierName: product.supplierName,
          kindId: product.kindId,
          warehouseId: product.warehouseId,
        );
        await _db.updateProduct(updated);
      }
    }
  }

  /// Vráti stav skladu späť (pri úprave alebo zrušení výdajky).
  Future<void> _revertStockOutFromProducts(int stockOutId) async {
    final items = await _db.getStockOutItems(stockOutId);
    for (final item in items) {
      final product = await _db.getProductByUniqueId(item.productUniqueId);
      if (product != null) {
        final updated = Product(
          uniqueId: product.uniqueId,
          name: product.name,
          plu: product.plu,
          category: product.category,
          qty: product.qty + item.qty,
          unit: product.unit,
          price: product.price,
          withoutVat: product.withoutVat,
          vat: product.vat,
          discount: product.discount,
          lastPurchasePrice: product.lastPurchasePrice,
          lastPurchasePriceWithoutVat: product.lastPurchasePriceWithoutVat,
          lastPurchaseDate: product.lastPurchaseDate,
          currency: product.currency,
          location: product.location,
          purchasePrice: product.purchasePrice,
          purchasePriceWithoutVat: product.purchasePriceWithoutVat,
          purchaseVat: product.purchaseVat,
          recyclingFee: product.recyclingFee,
          productType: product.productType,
          supplierName: product.supplierName,
          kindId: product.kindId,
          warehouseId: product.warehouseId,
        );
        await _db.updateProduct(updated);
      }
    }
  }

  /// Vytvorí výdajku. Pri vykázaní (nie draft) validuje množstvá a zníži sklad.
  Future<void> createStockOut({
    required StockOut stockOut,
    required List<StockOutItem> items,
    bool isDraft = false,
  }) async {
    String number = stockOut.documentNumber;
    if (number.trim().isEmpty) {
      number = await _db.getNextStockOutNumber();
    }

    final status = isDraft ? StockOutStatus.rozpracovany : StockOutStatus.vykazana;
    final toInsert = stockOut.copyWith(documentNumber: number, status: status);

    final stockOutId = await _db.insertStockOut(toInsert);

    for (final item in items) {
      final dbItem = StockOutItem(
        id: null,
        stockOutId: stockOutId,
        productUniqueId: item.productUniqueId,
        productName: item.productName,
        plu: item.plu,
        qty: item.qty,
        unit: item.unit,
        unitPrice: item.unitPrice,
      );
      await _db.insertStockOutItem(dbItem);
    }

    // Zásoby sa odpisujú až po schválení výdajky, nie pri vykázaní.
  }

  /// Aktualizuje výdajku. Zásoby sa neodpisujú – až pri schválení.
  /// Aktualizuje výdajku. Pri schválených najprv vráti zásoby, uloží zmeny a znova odpočíta.
  Future<void> updateStockOut({
    required StockOut stockOut,
    required List<StockOutItem> items,
  }) async {
    if (stockOut.id == null) return;
    final existing = await _db.getStockOutById(stockOut.id!);
    if (existing == null || existing.isStorned) return;

    final wasApproved = existing.isApproved;
    if (wasApproved) {
      await _revertStockOutFromProducts(stockOut.id!);
    }

    await _db.deleteStockOutItemsByStockOutId(stockOut.id!);
    await _db.updateStockOut(stockOut);

    for (final item in items) {
      final dbItem = StockOutItem(
        id: null,
        stockOutId: stockOut.id!,
        productUniqueId: item.productUniqueId,
        productName: item.productName,
        plu: item.plu,
        qty: item.qty,
        unit: item.unit,
        unitPrice: item.unitPrice,
      );
      await _db.insertStockOutItem(dbItem);
    }

    if (wasApproved && items.isNotEmpty) {
      final itemsWithId = await _db.getStockOutItems(stockOut.id!);
      await _validateStock(itemsWithId);
      await _applyStockOutToProducts(stockOut.id!);
    }
  }

  /// Schváli výdajku a odpočíta zásoby zo skladu (až teraz sa množstvo odpisuje).
  Future<void> approveStockOut(int stockOutId) async {
    final stockOut = await _db.getStockOutById(stockOutId);
    if (stockOut == null || stockOut.isApproved || stockOut.isStorned) return;
    final items = await _db.getStockOutItems(stockOutId);
    if (items.isNotEmpty) {
      await _validateStock(items);
      await _applyStockOutToProducts(stockOutId);
    }
    await _db.updateStockOutStatus(stockOutId, StockOutStatus.schvalena);
  }

  /// Zruší alebo stornuje výdajku. Pri schválených: voliteľne vráti zásoby na sklad.
  Future<void> stornoStockOut(int stockOutId, {required bool returnToStock}) async {
    final stockOut = await _db.getStockOutById(stockOutId);
    if (stockOut == null || stockOut.isStorned) return;
    if (stockOut.isApproved && returnToStock) {
      await _revertStockOutFromProducts(stockOutId);
    }
    await _db.updateStockOutStatus(stockOutId, StockOutStatus.stornovana);
  }
}
