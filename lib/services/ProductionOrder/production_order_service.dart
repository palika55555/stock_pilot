import '../../models/production_order.dart';
import '../../models/stock_out.dart';
import '../../models/receipt.dart';
import '../../models/product.dart';
import '../Database/database_service.dart';
import '../Recipe/recipe_service.dart';
import '../StockOut/stock_out_service.dart';
import '../Receipt/receipt_service.dart';
import '../Notifications/notification_service.dart';

class ProductionOrderService {
  final DatabaseService _db = DatabaseService();
  final StockOutService _stockOutService = StockOutService();
  final ReceiptService _receiptService = ReceiptService();
  final NotificationService _notificationService = NotificationService();

  Future<String> getNextOrderNumber() async => _db.getNextProductionOrderNumber();

  Future<List<ProductionOrder>> getOrders({
    int? recipeId,
    String? status,
    int? warehouseId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? createdBy,
  }) async {
    return _db.getProductionOrders(
      recipeId: recipeId,
      status: status,
      warehouseId: warehouseId,
      dateFrom: dateFrom,
      dateTo: dateTo,
      createdBy: createdBy,
    );
  }

  Future<ProductionOrder?> getOrderById(int id) async => _db.getProductionOrderById(id);

  Future<int> createOrder({
    required ProductionOrder order,
  }) async {
    return _db.insertProductionOrder(order);
  }

  Future<void> updateOrder(ProductionOrder order) async {
    if (order.id != null) await _db.updateProductionOrder(order);
  }

  /// Submit for approval (draft -> pending). Notifies managers.
  Future<void> submitForApproval(int orderId, String creatorName) async {
    final order = await _db.getProductionOrderById(orderId);
    if (order == null || !order.status.isDraft || !order.requiresApproval) return;
    final updated = order.copyWith(
      status: ProductionOrderStatus.pending,
      submittedAt: DateTime.now(),
    );
    await _db.updateProductionOrder(updated);
    await _notificationService.createForProductionSubmitted(
      orderNumber: order.orderNumber,
      plannedQuantity: order.plannedQuantity,
      orderId: orderId,
    );
  }

  /// Approve (pending -> approved). Notifies creator.
  Future<void> approveOrder(int orderId, String approverUsername) async {
    final order = await _db.getProductionOrderById(orderId);
    if (order == null || !order.status.isPending) return;
    final updated = order.copyWith(
      status: ProductionOrderStatus.approved,
      approvedAt: DateTime.now(),
      approverUsername: approverUsername,
      rejectionReason: null,
      rejectedAt: null,
    );
    await _db.updateProductionOrder(updated);
    if (order.createdByUsername != null) {
      await _notificationService.createForProductionApproved(
        orderNumber: order.orderNumber,
        orderId: orderId,
        targetUsername: order.createdByUsername!,
      );
    }
  }

  /// Reject (pending -> draft conceptually; we keep status rejected and creator can edit and resubmit).
  Future<void> rejectOrder(int orderId, String rejectionReason) async {
    final order = await _db.getProductionOrderById(orderId);
    if (order == null || !order.status.isPending) return;
    final updated = order.copyWith(
      status: ProductionOrderStatus.rejected,
      rejectedAt: DateTime.now(),
      rejectionReason: rejectionReason,
    );
    await _db.updateProductionOrder(updated);
    if (order.createdByUsername != null) {
      await _notificationService.createForProductionRejected(
        orderNumber: order.orderNumber,
        rejectionReason: rejectionReason,
        orderId: orderId,
        targetUsername: order.createdByUsername!,
      );
    }
  }

  /// Set order back to draft after rejection so creator can edit and resubmit.
  Future<void> setOrderBackToDraft(int orderId) async {
    final order = await _db.getProductionOrderById(orderId);
    if (order == null || order.status != ProductionOrderStatus.rejected) return;
    final updated = order.copyWith(
      status: ProductionOrderStatus.draft,
      submittedAt: null,
      rejectionReason: null,
      rejectedAt: null,
    );
    await _db.updateProductionOrder(updated);
  }

  /// Start production (approved or draft when no approval needed -> in_progress).
  Future<void> startProduction(int orderId) async {
    final order = await _db.getProductionOrderById(orderId);
    if (order == null || !order.status.canStartProduction) return;
    final updated = order.copyWith(
      status: ProductionOrderStatus.inProgress,
      startedAt: DateTime.now(),
    );
    await _db.updateProductionOrder(updated);
  }

  /// Complete production: create výdajka (raw materials), príjemka (finished product), update costs and product avg price.
  Future<void> completeProduction({
    required int orderId,
    required double actualQuantity,
    required String completedByUsername,
    double? laborCost,
    double? energyCost,
    double? overheadCost,
    double? otherCost,
  }) async {
    final order = await _db.getProductionOrderById(orderId);
    if (order == null || !order.status.canComplete) return;
    final recipe = await _db.getRecipeById(order.recipeId);
    if (recipe == null) return;
    final ingredients = await _db.getRecipeIngredients(order.recipeId);
    final sourceWh = order.sourceWarehouseId;
    final destWh = order.destinationWarehouseId;
    if (sourceWh == null || destWh == null) throw Exception('Sklad surovín a sklad výrobku musia byť zadané.');

    final factor = recipe.outputQuantity > 0 ? actualQuantity / recipe.outputQuantity : 0.0;
    double materialCostTotal = 0;

    // 1) Výdajka surovín
    final stockOutNumber = await _db.getNextStockOutNumber();
    final now = DateTime.now();
    final stockOut = StockOut(
      documentNumber: stockOutNumber,
      createdAt: now,
      notes: 'Výrobný príkaz ${order.orderNumber}',
      warehouseId: sourceWh,
      issueType: StockOutIssueType.production,
      vatRate: 0,
    );
    final stockOutItems = <StockOutItem>[];
    final sourceProducts = await _db.getProductsByWarehouseId(sourceWh);
    for (final ing in ingredients) {
      final qty = (ing.quantity * factor).round();
      if (qty <= 0) continue;
      Product? product;
      try {
        product = sourceProducts.firstWhere((p) => p.uniqueId == ing.productUniqueId);
      } catch (_) {
        product = await _db.getProductByUniqueId(ing.productUniqueId);
        if (product != null && product.warehouseId != sourceWh) product = null;
      }
      if (product == null) {
        throw Exception('Surovina ${ing.productName ?? ing.productUniqueId} nie je v sklade surovín.');
      }
      materialCostTotal += qty * product.purchasePrice;
      stockOutItems.add(StockOutItem(
        stockOutId: 0,
        productUniqueId: product.uniqueId!,
        productName: product.name,
        plu: product.plu,
        qty: qty,
        unit: ing.unit,
        unitPrice: product.purchasePrice,
      ));
    }
    int? rawMaterialsStockOutId;
    if (stockOutItems.isNotEmpty) {
      rawMaterialsStockOutId = await _db.insertStockOut(stockOut);
      for (final item in stockOutItems) {
        await _db.insertStockOutItem(StockOutItem(
          stockOutId: rawMaterialsStockOutId,
          productUniqueId: item.productUniqueId,
          productName: item.productName,
          plu: item.plu,
          qty: item.qty,
          unit: item.unit,
          unitPrice: item.unitPrice,
        ));
      }
      await _stockOutService.approveStockOut(rawMaterialsStockOutId);
    }

    // 2) Náklady a cost per unit
    final labor = laborCost ?? 0;
    final energy = energyCost ?? 0;
    final overhead = overheadCost ?? 0;
    final other = otherCost ?? 0;
    final totalCost = materialCostTotal + labor + energy + overhead + other;
    final costPerUnit = actualQuantity > 0 ? totalCost / actualQuantity : 0.0;

    // 3) Príjemka výrobku (finished product)
    Product? finishedProduct = await _db.getProductByUniqueId(recipe.finishedProductUniqueId);
    if (finishedProduct == null) {
      final inDest = await _db.getProductsByWarehouseId(destWh);
      finishedProduct = inDest.cast<Product?>().where((p) => p?.uniqueId == recipe.finishedProductUniqueId).firstOrNull;
    }
    if (finishedProduct == null) throw Exception('Výsledný produkt receptúry nebol nájdený v cieľovom sklade.');
    if (finishedProduct.warehouseId != destWh) {
      final inDest = await _db.getProductsByWarehouseId(destWh);
      try {
        final fp = inDest.firstWhere((p) => p.uniqueId == recipe.finishedProductUniqueId);
        finishedProduct = fp;
      } catch (_) {}
    }

    final receiptNumber = await _db.getNextReceiptNumber();
    final inboundReceipt = InboundReceipt(
      receiptNumber: receiptNumber,
      createdAt: now,
      supplierName: 'Výroba',
      notes: 'Výrobný príkaz ${order.orderNumber}',
      warehouseId: destWh,
      status: InboundReceiptStatus.schvalena,
      movementTypeCode: 'STANDARD',
      stockApplied: false,
    );
    final receiptId = await _db.insertInboundReceipt(inboundReceipt);
    await _db.insertInboundReceiptItem(InboundReceiptItem(
      receiptId: receiptId,
      productUniqueId: finishedProduct?.uniqueId ?? recipe.finishedProductUniqueId,
      productName: finishedProduct?.name ?? recipe.finishedProductName ?? '',
      plu: finishedProduct?.plu ?? '',
      qty: actualQuantity.round(),
      unit: recipe.unit,
      unitPrice: costPerUnit,
      vatPercent: finishedProduct?.vat ?? 20,
      allocatedCost: 0,
    ));
    await _receiptService.applyReceiptToStock(receiptId);
    await _db.setReceiptStockApplied(receiptId, applied: true);

    // 4) Update production order
    final variance = order.plannedQuantity - actualQuantity;
    final updatedOrder = order.copyWith(
      status: ProductionOrderStatus.completed,
      completedAt: now,
      completedByUsername: completedByUsername,
      actualQuantity: actualQuantity,
      variance: variance,
      materialCost: materialCostTotal,
      laborCost: labor,
      energyCost: energy,
      overheadCost: overhead,
      otherCost: other,
      totalCost: totalCost,
      costPerUnit: costPerUnit,
      rawMaterialsStockOutId: rawMaterialsStockOutId,
      finishedGoodsReceiptId: receiptId,
    );
    await _db.updateProductionOrder(updatedOrder);

    await _notificationService.createForProductionCompleted(
      orderNumber: order.orderNumber,
      actualQuantity: actualQuantity,
      orderId: orderId,
    );
  }

  Future<int> getCountByStatus(String status) => _db.getProductionOrderCountByStatus(status);
  Future<int> getCountForDate(String dateYyyyMmDd) => _db.getProductionOrderCountForDate(dateYyyyMmDd);
  Future<double?> getTotalProductionCostThisMonth() => _db.getTotalProductionCostThisMonth();
}
