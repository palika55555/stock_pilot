import 'dart:async';
import '../../models/product.dart';
import '../../models/receipt.dart';
import '../database/database_service.dart';

class ReceiptService {
  final DatabaseService _db = DatabaseService();

  static double _roundPrice(double v) => (v * 100000).round() / 100000;

  Future<List<InboundReceipt>> getAllReceipts() async {
    return await _db.getInboundReceipts();
  }

  Future<InboundReceipt?> getReceiptById(int id) async {
    return await _db.getInboundReceiptById(id);
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
      );
      await _db.insertInboundReceiptItem(dbItem);
    }

    if (!isDraft && items.isNotEmpty) {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      for (final item in items) {
        final product = await _db.getProductByUniqueId(item.productUniqueId);
        if (product != null) {
          final roundedPrice = _roundPrice(item.unitPrice);
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
            lastPurchasePrice: roundedPrice,
            lastPurchaseDate: today,
            currency: product.currency,
            location: product.location,
            purchasePrice: roundedPrice,
            purchasePriceWithoutVat: product.purchasePriceWithoutVat,
            purchaseVat: product.purchaseVat,
            recyclingFee: product.recyclingFee,
            productType: product.productType,
          );
          await _db.updateProduct(updated);
        }
      }
    }
  }

  /// Aktualizuje existujúcu príjemku. Pri rozpracovanej len ukladá dáta; pri vykázanej alebo dokončení draftu aktualizuje sklad.
  Future<void> updateReceipt({
    required InboundReceipt receipt,
    required List<InboundReceiptItem> items,
  }) async {
    if (receipt.id == null) return;
    final existing = await _db.getInboundReceiptById(receipt.id!);
    if (existing == null || existing.isApproved) return;

    final wasDraft = existing.isDraft;
    final completingDraft =
        wasDraft && receipt.status == InboundReceiptStatus.vykazana;

    if (!wasDraft) {
      await _revertReceiptFromProducts(receipt.id!);
    }

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
      );
      await _db.insertInboundReceiptItem(dbItem);
    }

    if (!wasDraft || completingDraft) {
      if (items.isNotEmpty) {
        final today = DateTime.now().toIso8601String().substring(0, 10);
        for (final item in items) {
          final product = await _db.getProductByUniqueId(item.productUniqueId);
          if (product != null) {
            final roundedPrice = _roundPrice(item.unitPrice);
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
              lastPurchasePrice: roundedPrice,
              lastPurchaseDate: today,
              currency: product.currency,
              location: product.location,
              purchasePrice: roundedPrice,
              purchasePriceWithoutVat: product.purchasePriceWithoutVat,
              purchaseVat: product.purchaseVat,
              recyclingFee: product.recyclingFee,
              productType: product.productType,
            );
            await _db.updateProduct(updated);
          }
        }
      }
    }
  }

  /// Odčíta množstvá položiek príjemky zo skladu.
  Future<void> _revertReceiptFromProducts(int receiptId) async {
    final items = await _db.getInboundReceiptItems(receiptId);
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
          lastPurchaseDate: product.lastPurchaseDate,
          currency: product.currency,
          location: product.location,
          purchasePrice: product.purchasePrice,
          purchasePriceWithoutVat: product.purchasePriceWithoutVat,
          purchaseVat: product.purchaseVat,
          recyclingFee: product.recyclingFee,
          productType: product.productType,
        );
        await _db.updateProduct(updated);
      }
    }
  }

  /// Schváli príjemku.
  Future<void> approveReceipt(int receiptId) async {
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
