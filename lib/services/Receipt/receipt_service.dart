import 'dart:async';
import '../../models/product.dart';
import '../../models/receipt.dart';
import '../../models/stock_out.dart';
import '../Database/database_service.dart';
import '../Notifications/notification_service.dart';
import '../api_sync_service.dart' show syncReceiptsToBackend, syncStockOutsToBackend;

class ReceiptService {
  final DatabaseService _db = DatabaseService();
  final NotificationService _notificationService = NotificationService();

  static const String _transferCode = 'TRANSFER';

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

  Future<List<ReceiptAcquisitionCost>> getReceiptAcquisitionCosts(int receiptId) async {
    return await _db.getReceiptAcquisitionCosts(receiptId);
  }

  /// Spracuje uloženie novej príjemky vrátane aktualizácie produktov (alebo ako rozpracovanú).
  /// Pri prevodke (TRANSFER): validuje zdroj/cieľ a zásoby, vytvorí príjemku + výdajku a okamžite vykoná presun.
  /// Pri WITH_COSTS: ukladá obstarávacie náklady a alokáciu na položky.
  /// Vráti id vytvorenej príjemky (pre následné schválenie štandardnej príjemky).
  Future<int> createReceipt({
    required InboundReceipt receipt,
    required List<InboundReceiptItem> items,
    List<ReceiptAcquisitionCost>? acquisitionCosts,
    bool isDraft = false,
  }) async {
    final isTransfer = receipt.movementTypeCode == _transferCode &&
        receipt.sourceWarehouseId != null &&
        receipt.warehouseId != null;

    if (isTransfer && !isDraft) {
      if (receipt.sourceWarehouseId == receipt.warehouseId) {
        throw Exception('Zdrojový a cieľový sklad musia byť rôzne.');
      }
      for (final item in items) {
        final product = await _db.getProductByUniqueId(item.productUniqueId);
        if (product == null) {
          throw Exception(
              'Produkt ${item.productName ?? item.productUniqueId} nebol nájdený.');
        }
        if (product.warehouseId != receipt.sourceWarehouseId) {
          throw Exception(
              'Produkt ${item.productName ?? item.productUniqueId} nie je v zdrojovom sklade.');
        }
        if (product.qty < item.qty) {
          throw Exception(
              'Nedostatočné množstvo: ${item.productName ?? item.productUniqueId}. Požadované: ${item.qty}, dostupné: ${product.qty}.');
        }
      }
    }

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
        allocatedCost: item.allocatedCost,
      );
      await _db.insertInboundReceiptItem(dbItem);
    }

    if (acquisitionCosts != null && acquisitionCosts.isNotEmpty) {
      for (var i = 0; i < acquisitionCosts.length; i++) {
        final c = acquisitionCosts[i];
        await _db.insertReceiptAcquisitionCost(ReceiptAcquisitionCost(
          receiptId: receiptId,
          costType: c.costType,
          description: c.description,
          amountWithoutVat: c.amountWithoutVat,
          vatPercent: c.vatPercent,
          amountWithVat: c.amountWithVat,
          costSupplierName: c.costSupplierName,
          documentNumber: c.documentNumber,
          sortOrder: i,
        ));
      }
    }

    if (isTransfer && !isDraft && items.isNotEmpty) {
      final sourceId = receipt.sourceWarehouseId!;
      final destId = receipt.warehouseId!;
      final stockOutNumber = await _db.getNextStockOutNumber();
      final now = DateTime.now();
      final stockOut = StockOut(
        documentNumber: stockOutNumber,
        createdAt: now,
        notes: 'Prevodka – príjemka $number',
        warehouseId: sourceId,
        issueType: StockOutIssueType.transfer,
        vatRate: 0,
        linkedReceiptId: receiptId,
      );
      final stockOutId = await _db.insertStockOut(stockOut);
      for (final item in items) {
        await _db.insertStockOutItem(
          StockOutItem(
            stockOutId: stockOutId,
            productUniqueId: item.productUniqueId,
            productName: item.productName,
            plu: item.plu,
            qty: item.qty,
            unit: item.unit,
            unitPrice: item.unitPrice,
          ),
        );
      }
      final receiptLoaded = await _db.getInboundReceiptById(receiptId);
      if (receiptLoaded != null) {
        await _db.updateInboundReceipt(
          receiptLoaded.copyWith(linkedStockOutId: stockOutId),
        );
      }
      await _db.applyTransferReceipt(
        sourceWarehouseId: sourceId,
        destWarehouseId: destId,
        items: items,
        stockOutId: stockOutId,
        stockOutDocumentNumber: stockOutNumber,
        stockOutCreatedAt: now,
      );
      await _db.updateInboundReceiptStatus(
        receiptId,
        InboundReceiptStatus.schvalena,
      );
      await _db.updateStockOutStatus(stockOutId, StockOutStatus.schvalena);
    }
    syncReceiptsToBackend().ignore();
    syncStockOutsToBackend().ignore();
    return receiptId;
  }

  /// Aktualizuje existujúcu príjemku. Množstvo sa do skladu pridáva až po schválení.
  Future<void> updateReceipt({
    required InboundReceipt receipt,
    required List<InboundReceiptItem> items,
    List<ReceiptAcquisitionCost>? acquisitionCosts,
  }) async {
    if (receipt.id == null) return;
    final existing = await _db.getInboundReceiptById(receipt.id!);
    if (existing == null || existing.isApproved) return;

    await _db.deleteInboundReceiptItemsByReceiptId(receipt.id!);
    await _db.deleteReceiptAcquisitionCostsByReceiptId(receipt.id!);
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
        allocatedCost: item.allocatedCost,
      );
      await _db.insertInboundReceiptItem(dbItem);
    }
    if (acquisitionCosts != null && acquisitionCosts.isNotEmpty) {
      for (var i = 0; i < acquisitionCosts.length; i++) {
        final c = acquisitionCosts[i];
        await _db.insertReceiptAcquisitionCost(ReceiptAcquisitionCost(
          receiptId: receipt.id!,
          costType: c.costType,
          description: c.description,
          amountWithoutVat: c.amountWithoutVat,
          vatPercent: c.vatPercent,
          amountWithVat: c.amountWithVat,
          costSupplierName: c.costSupplierName,
          documentNumber: c.documentNumber,
          sortOrder: i,
        ));
      }
    }
    syncReceiptsToBackend().ignore();
  }

  /// Odoslí príjemku na schválenie (draft/vykazana -> pending). Notifikuje manažérov/adminov.
  Future<void> submitForApproval(int receiptId, String creatorName) async {
    final receipt = await _db.getInboundReceiptById(receiptId);
    if (receipt == null || receipt.isApproved || receipt.isPendingApproval) return;
    final now = DateTime.now();
    final updated = receipt.copyWith(
      status: InboundReceiptStatus.pending,
      submittedAt: now,
    );
    await _db.updateInboundReceiptFull(updated);
    await _notificationService.createForReceiptSubmitted(receipt: updated, creatorName: creatorName);
    syncReceiptsToBackend().ignore();
  }

  /// Stiahne príjemku zo schválenia (pending -> vykazana). Notifikuje manažérov/adminov.
  Future<void> recallReceipt(int receiptId, String creatorName) async {
    final receipt = await _db.getInboundReceiptById(receiptId);
    if (receipt == null || !receipt.isPendingApproval) return;
    final updated = receipt.copyWith(
      status: InboundReceiptStatus.vykazana,
      submittedAt: null,
    );
    await _db.updateInboundReceiptFull(updated);
    await _notificationService.createForReceiptRecalled(receipt: updated, creatorName: creatorName);
    syncReceiptsToBackend().ignore();
  }

  /// Zamietne príjemku. Notifikuje tvorcu.
  Future<void> rejectReceipt(int receiptId, String rejectionReason) async {
    final receipt = await _db.getInboundReceiptById(receiptId);
    if (receipt == null || !receipt.isPendingApproval) return;
    final now = DateTime.now();
    final updated = receipt.copyWith(
      status: InboundReceiptStatus.rejected,
      rejectedAt: now,
      rejectionReason: rejectionReason,
    );
    await _db.updateInboundReceiptFull(updated);
    await _notificationService.createForReceiptRejected(receipt: updated, rejectionReason: rejectionReason);
    syncReceiptsToBackend().ignore();
  }

  /// Zruší príjemku, ktorá ešte nebola vykázaná (žiadny vplyv na sklad). Nastaví status na cancelled.
  Future<void> cancelReceipt(int receiptId) async {
    final receipt = await _db.getInboundReceiptById(receiptId);
    if (receipt == null || receipt.stockApplied) return;
    final updated = receipt.copyWith(status: InboundReceiptStatus.cancelled);
    await _db.updateInboundReceiptFull(updated);
    syncReceiptsToBackend().ignore();
  }

  /// Stornuje vykázanú príjemku. [deductFromStock] = true odpočíta prijaté množstvá zo skladu, false len zmení status.
  Future<void> reverseReceipt(int receiptId, String userName, String reason, {bool deductFromStock = true}) async {
    final receipt = await _db.getInboundReceiptById(receiptId);
    if (receipt == null) return;
    final isReported = receipt.stockApplied ||
        receipt.isApproved ||
        receipt.status == InboundReceiptStatus.vykazana;
    if (!isReported) return;
    if (deductFromStock && receipt.stockApplied) {
      await _deductReceiptFromStock(receiptId);
    }
    final now = DateTime.now();
    final updated = receipt.copyWith(
      status: InboundReceiptStatus.reversed,
      reversedAt: now,
      reversedByUsername: userName,
      reverseReason: reason,
      stockApplied: deductFromStock ? false : receipt.stockApplied,
    );
    await _db.updateInboundReceiptFull(updated);
    await _notificationService.createForReceiptReversed(receipt: updated, userName: userName, reason: reason);
    syncReceiptsToBackend().ignore();
  }

  /// Odpočíta množstvá položiek príjemky zo skladu (inverzia k _applyReceiptToStock).
  Future<void> _deductReceiptFromStock(int receiptId) async {
    final receipt = await _db.getInboundReceiptById(receiptId);
    if (receipt == null || !receipt.stockApplied) return;
    final items = await _db.getInboundReceiptItems(receiptId);
    for (final item in items) {
      final product = await _db.getProductByUniqueId(item.productUniqueId);
      if (product != null && receipt.warehouseId != null && product.warehouseId == receipt.warehouseId) {
        final newQty = (product.qty - item.qty).clamp(0, double.infinity).round();
        final updated = Product(
          uniqueId: product.uniqueId,
          name: product.name,
          plu: product.plu,
          ean: product.ean,
          category: product.category,
          qty: newQty,
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
    await _db.setReceiptStockApplied(receiptId, applied: false);
  }

  /// Pripočíta množstvá z príjemky na sklad (ak ešte nebolo). Volá sa pri uložení „Vykázaná“, pri „Schváliť“ aj pri výrobe (príjemka výrobku).
  Future<void> applyReceiptToStock(int receiptId) async {
    await _applyReceiptToStock(receiptId);
  }

  Future<void> _applyReceiptToStock(int receiptId) async {
    final receipt = await _db.getInboundReceiptById(receiptId);
    if (receipt == null || receipt.stockApplied) return;
    final items = await _db.getInboundReceiptItems(receiptId);
    final today = DateTime.now().toIso8601String().substring(0, 10);
    for (final item in items) {
      final vatPercent = item.vatPercent ?? receipt.vatRate ?? 20;
      final product = await _db.getProductByUniqueId(item.productUniqueId);
      if (product != null) {
        double itemPriceWithVat = receipt.pricesIncludeVat ? item.unitPrice : calculateWithVat(item.unitPrice, vatPercent);
        double itemPriceWithoutVat = receipt.pricesIncludeVat ? calculateWithoutVat(item.unitPrice, vatPercent) : item.unitPrice;
        final allocated = item.allocatedCost;
        if (allocated > 0 && item.qty > 0) {
          final truePriceWithVat = _roundPrice((itemPriceWithVat * item.qty + allocated) / item.qty);
          itemPriceWithVat = truePriceWithVat;
          itemPriceWithoutVat = calculateWithoutVat(truePriceWithVat, vatPercent);
        }
        final newQty = product.qty + item.qty;
        final weightedPurchasePriceWithVat = product.qty <= 0 ? itemPriceWithVat : _roundPrice((product.qty * product.purchasePrice + item.qty * itemPriceWithVat) / newQty);
        final weightedPurchasePriceWithoutVat = product.qty <= 0 ? itemPriceWithoutVat : _roundPrice((product.qty * product.purchasePriceWithoutVat + item.qty * itemPriceWithoutVat) / newQty);
        final updated = Product(
          uniqueId: product.uniqueId, name: product.name, plu: product.plu, ean: product.ean, category: product.category,
          qty: newQty.round(), unit: product.unit, price: product.price, withoutVat: product.withoutVat, vat: product.vat, discount: product.discount,
          lastPurchasePrice: _roundPrice(itemPriceWithVat), lastPurchasePriceWithoutVat: _roundPrice(itemPriceWithoutVat), lastPurchaseDate: today,
          currency: product.currency, location: product.location, purchasePrice: weightedPurchasePriceWithVat, purchasePriceWithoutVat: weightedPurchasePriceWithoutVat,
          purchaseVat: product.purchaseVat, recyclingFee: product.recyclingFee, productType: product.productType,
          supplierName: receipt.supplierName?.trim().isNotEmpty == true ? receipt.supplierName : product.supplierName,
          kindId: product.kindId, warehouseId: receipt.warehouseId ?? product.warehouseId, linkedProductUniqueId: product.linkedProductUniqueId,
          minQuantity: product.minQuantity, allowAtCashRegister: product.allowAtCashRegister, showInPriceList: product.showInPriceList,
          isActive: product.isActive, temporarilyUnavailable: product.temporarilyUnavailable, stockGroup: product.stockGroup,
          cardType: product.cardType, hasExtendedPricing: product.hasExtendedPricing, ibaCeleMnozstva: product.ibaCeleMnozstva,
        );
        await _db.updateProduct(updated);
      }
    }
    await _db.setReceiptStockApplied(receiptId);
  }

  /// Schváli príjemku a pridá množstvá položiek do skladu (ak ešte neboli). [approverUsername] a [approverNote] pre notifikáciu.
  Future<void> approveReceipt(int receiptId, {String? approverUsername, String? approverNote}) async {
    final receipt = await _db.getInboundReceiptById(receiptId);
    if (receipt == null) return;
    await _applyReceiptToStock(receiptId);
    final items = await _db.getInboundReceiptItems(receiptId);
    final now = DateTime.now();
    final approvedReceipt = receipt.copyWith(
      status: InboundReceiptStatus.schvalena,
      approvedAt: now,
      approverUsername: approverUsername,
      approverNote: approverNote,
    );
    await _db.updateInboundReceiptFull(approvedReceipt);
    if (approverUsername != null) {
      await _notificationService.createForReceiptApproved(
        receipt: approvedReceipt,
        approverName: approverUsername,
      );
    }
    // STOCK_LOW: po schválení skontrolovať produkty pod minQuantity
    final warehouseId = receipt.warehouseId;
    if (warehouseId != null) {
      for (final item in items) {
        final product = await _db.getProductByUniqueId(item.productUniqueId);
        if (product != null &&
            product.minQuantity > 0 &&
            product.qty < product.minQuantity &&
            product.warehouseId == warehouseId) {
          final wh = await _db.getWarehouseById(warehouseId);
          await _notificationService.createForStockLow(
            productName: product.name ?? product.uniqueId ?? '',
            warehouseName: wh?.name ?? 'Sklad',
            currentQty: product.qty,
            minQty: product.minQuantity,
          );
        }
      }
    }
    syncReceiptsToBackend().ignore();
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
