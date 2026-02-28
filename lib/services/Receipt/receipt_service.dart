import 'dart:async';
import '../../models/product.dart';
import '../../models/receipt.dart';
import '../database/database_service.dart';

class ReceiptService {
  final DatabaseService _db = DatabaseService();

  Future<List<ReceiptMovementType>> getReceiptMovementTypes() async {
    return await _db.getReceiptMovementTypes();
  }

  static double _roundPrice(double v) => (v * 100000).round() / 100000;

  /// Ak [warehouseId] je zadané, vráti len príjemky daného skladu.
  Future<List<InboundReceipt>> getAllReceipts({int? warehouseId}) async {
    return await _db.getInboundReceipts(warehouseId: warehouseId);
  }

  Future<InboundReceipt?> getReceiptById(int id) async {
    return await _db.getInboundReceiptById(id);
  }

  /// Vymaže neschválenú príjemku a jej položky.
  Future<bool> deleteReceipt(int receiptId) async {
    final n = await _db.deleteInboundReceipt(receiptId);
    return n > 0;
  }

  Future<List<InboundReceiptItem>> getReceiptItems(int receiptId) async {
    return await _db.getInboundReceiptItems(receiptId);
  }

  /// Spracuje uloženie novej príjemky vrátane aktualizácie produktov (alebo ako rozpracovanú).
  Future<void> createReceipt({
    required InboundReceipt receipt,
    required List<InboundReceiptItem> items,
    bool isDraft = false,
  }) async {
    String number = receipt.receiptNumber;
    if (number.trim().isEmpty) {
      number = await _db.getNextReceiptNumber();
    }

    final status = isDraft
        ? InboundReceiptStatus.rozpracovany
        : InboundReceiptStatus.vykazana;
    final receiptToInsert = receipt.copyWith(
      receiptNumber: number,
      status: status,
    );

    final receiptId = await _db.insertInboundReceipt(receiptToInsert);

    for (final item in items) {
      final dbItem = InboundReceiptItem(
        id: null,
        receiptId: receiptId,
        productUniqueId: item.productUniqueId,
        productName: item.productName,
        plu: item.plu,
        qty: item.qty,
        unit: item.unit,
        unitPrice: item.unitPrice,
        vatPercent: item.vatPercent,
      );
      await _db.insertInboundReceiptItem(dbItem);
    }
    // Množstvo sa pridá do skladu až po schválení príjemky (v approveReceipt).
  }

  /// Aktualizuje existujúcu príjemku. Množstvo sa do skladu pridáva až po schválení.
  Future<void> updateReceipt({
    required InboundReceipt receipt,
    required List<InboundReceiptItem> items,
  }) async {
    if (receipt.id == null) return;
    final existing = await _db.getInboundReceiptById(receipt.id!);
    if (existing == null || existing.isApproved) return;

    await _db.deleteInboundReceiptItemsByReceiptId(receipt.id!);
    await _db.updateInboundReceipt(receipt);

    for (final item in items) {
      final dbItem = InboundReceiptItem(
        id: null,
        receiptId: receipt.id!,
        productUniqueId: item.productUniqueId,
        productName: item.productName,
        plu: item.plu,
        qty: item.qty,
        unit: item.unit,
        unitPrice: item.unitPrice,
        vatPercent: item.vatPercent,
      );
      await _db.insertInboundReceiptItem(dbItem);
    }
  }

  /// Schváli príjemku a pridá množstvá položiek do skladu. Nákupná cena = vážený aritmetický priemer.
  Future<void> approveReceipt(int receiptId) async {
    final receipt = await _db.getInboundReceiptById(receiptId);
    if (receipt == null) return;
    final items = await _db.getInboundReceiptItems(receiptId);
    final today = DateTime.now().toIso8601String().substring(0, 10);

    for (final item in items) {
      final vatPercent = item.vatPercent ?? receipt.vatRate ?? 20;
      final product = await _db.getProductByUniqueId(item.productUniqueId);
      if (product != null) {
        final itemPriceWithVat = receipt.pricesIncludeVat
            ? item.unitPrice
            : calculateWithVat(item.unitPrice, vatPercent);
        final itemPriceWithoutVat = receipt.pricesIncludeVat
            ? calculateWithoutVat(item.unitPrice, vatPercent)
            : item.unitPrice;

        final newQty = product.qty + item.qty;
        final weightedPurchasePriceWithVat = product.qty <= 0
            ? itemPriceWithVat
            : _roundPrice((product.qty * product.purchasePrice + item.qty * itemPriceWithVat) / newQty);
        final weightedPurchasePriceWithoutVat = product.qty <= 0
            ? itemPriceWithoutVat
            : _roundPrice((product.qty * product.purchasePriceWithoutVat + item.qty * itemPriceWithoutVat) / newQty);

        final updated = Product(
          uniqueId: product.uniqueId,
          name: product.name,
          plu: product.plu,
          ean: product.ean,
          category: product.category,
          qty: newQty.round(),
          unit: product.unit,
          price: product.price,
          withoutVat: product.withoutVat,
          vat: product.vat,
          discount: product.discount,
          lastPurchasePrice: _roundPrice(itemPriceWithVat),
          lastPurchasePriceWithoutVat: _roundPrice(itemPriceWithoutVat),
          lastPurchaseDate: today,
          currency: product.currency,
          location: product.location,
          purchasePrice: weightedPurchasePriceWithVat,
          purchasePriceWithoutVat: weightedPurchasePriceWithoutVat,
          purchaseVat: product.purchaseVat,
          recyclingFee: product.recyclingFee,
          productType: product.productType,
          supplierName: receipt.supplierName?.trim().isNotEmpty == true
              ? receipt.supplierName
              : product.supplierName,
          kindId: product.kindId,
          warehouseId: receipt.warehouseId ?? product.warehouseId,
          linkedProductUniqueId: product.linkedProductUniqueId,
          minQuantity: product.minQuantity,
          allowAtCashRegister: product.allowAtCashRegister,
          showInPriceList: product.showInPriceList,
          isActive: product.isActive,
          temporarilyUnavailable: product.temporarilyUnavailable,
          stockGroup: product.stockGroup,
          cardType: product.cardType,
          hasExtendedPricing: product.hasExtendedPricing,
          ibaCeleMnozstva: product.ibaCeleMnozstva,
        );
        await _db.updateProduct(updated);
      }
    }
    await _db.updateInboundReceiptStatus(
      receiptId,
      InboundReceiptStatus.schvalena,
    );
  }

  /// Vypočíta cenu s DPH.
  double calculateWithVat(double priceWithoutVat, int vatPercent) {
    return _roundPrice(priceWithoutVat * (1 + (vatPercent / 100)));
  }

  /// Vypočíta cenu bez DPH.
  double calculateWithoutVat(double priceWithVat, int vatPercent) {
    return _roundPrice(priceWithVat / (1 + (vatPercent / 100)));
  }
}
