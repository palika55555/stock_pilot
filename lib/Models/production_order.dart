/// Stav výrobného príkazu (VP).
enum ProductionOrderStatus {
  draft('draft', 'Rozpracovaný', 0xFF9E9E9E),
  pending('pending', 'Čaká na schválenie', 0xFF2196F3),
  approved('approved', 'Schválený', 0xFF4CAF50),
  inProgress('in_progress', 'Prebieha výroba', 0xFFFFC107),
  completed('completed', 'Dokončený', 0xFF4CAF50),
  rejected('rejected', 'Zamietnutý', 0xFFF44336),
  cancelled('cancelled', 'Zrušený', 0xFFF44336);

  final String value;
  final String label;
  final int colorValue;
  const ProductionOrderStatus(this.value, this.label, this.colorValue);

  static ProductionOrderStatus fromString(String? s) {
    if (s == null) return ProductionOrderStatus.draft;
    for (final e in ProductionOrderStatus.values) {
      if (e.value == s) return e;
    }
    return ProductionOrderStatus.draft;
  }

  bool get isDraft => this == ProductionOrderStatus.draft;
  bool get isPending => this == ProductionOrderStatus.pending;
  bool get isApproved => this == ProductionOrderStatus.approved;
  bool get isInProgress => this == ProductionOrderStatus.inProgress;
  bool get isCompleted => this == ProductionOrderStatus.completed;
  bool get isRejected => this == ProductionOrderStatus.rejected;
  bool get isCancelled => this == ProductionOrderStatus.cancelled;
  bool get canStartProduction => this == ProductionOrderStatus.approved || this == ProductionOrderStatus.draft;
  bool get canComplete => this == ProductionOrderStatus.inProgress;
}

/// Výrobný príkaz (VP).
class ProductionOrder {
  final int? id;
  final String orderNumber;
  final int recipeId;
  final String? recipeName;
  final double plannedQuantity;
  final DateTime productionDate;
  final int? sourceWarehouseId;
  final int? destinationWarehouseId;
  final String? notes;
  final ProductionOrderStatus status;
  final bool requiresApproval;
  final String? createdByUsername;
  final DateTime? createdAt;
  final DateTime? submittedAt;
  final String? approverUsername;
  final DateTime? approvedAt;
  final String? rejectionReason;
  final DateTime? rejectedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? completedByUsername;
  final double? actualQuantity;
  final double? variance;
  /// Náklady
  final double? materialCost;
  final double? laborCost;
  final double? energyCost;
  final double? overheadCost;
  final double? otherCost;
  final double? totalCost;
  final double? costPerUnit;
  /// Prepojenie na doklady (výdajka surovín, príjemka výrobku)
  final int? rawMaterialsStockOutId;
  final int? finishedGoodsReceiptId;

  const ProductionOrder({
    this.id,
    required this.orderNumber,
    required this.recipeId,
    this.recipeName,
    required this.plannedQuantity,
    required this.productionDate,
    this.sourceWarehouseId,
    this.destinationWarehouseId,
    this.notes,
    this.status = ProductionOrderStatus.draft,
    this.requiresApproval = false,
    this.createdByUsername,
    this.createdAt,
    this.submittedAt,
    this.approverUsername,
    this.approvedAt,
    this.rejectionReason,
    this.rejectedAt,
    this.startedAt,
    this.completedAt,
    this.completedByUsername,
    this.actualQuantity,
    this.variance,
    this.materialCost,
    this.laborCost,
    this.energyCost,
    this.overheadCost,
    this.otherCost,
    this.totalCost,
    this.costPerUnit,
    this.rawMaterialsStockOutId,
    this.finishedGoodsReceiptId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_number': orderNumber,
      'recipe_id': recipeId,
      'recipe_name': recipeName,
      'planned_quantity': plannedQuantity,
      'production_date': productionDate.toIso8601String().split('T').first,
      'source_warehouse_id': sourceWarehouseId,
      'destination_warehouse_id': destinationWarehouseId,
      'notes': notes,
      'status': status.value,
      'requires_approval': requiresApproval ? 1 : 0,
      'created_by_username': createdByUsername,
      'created_at': createdAt?.toIso8601String(),
      'submitted_at': submittedAt?.toIso8601String(),
      'approver_username': approverUsername,
      'approved_at': approvedAt?.toIso8601String(),
      'rejection_reason': rejectionReason,
      'rejected_at': rejectedAt?.toIso8601String(),
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'completed_by_username': completedByUsername,
      'actual_quantity': actualQuantity,
      'variance': variance,
      'material_cost': materialCost,
      'labor_cost': laborCost,
      'energy_cost': energyCost,
      'overhead_cost': overheadCost,
      'other_cost': otherCost,
      'total_cost': totalCost,
      'cost_per_unit': costPerUnit,
      'raw_materials_stock_out_id': rawMaterialsStockOutId,
      'finished_goods_receipt_id': finishedGoodsReceiptId,
    };
  }

  factory ProductionOrder.fromMap(Map<String, dynamic> map) {
    return ProductionOrder(
      id: map['id'] as int?,
      orderNumber: map['order_number'] as String? ?? '',
      recipeId: map['recipe_id'] as int? ?? 0,
      recipeName: map['recipe_name'] as String?,
      plannedQuantity: (map['planned_quantity'] as num?)?.toDouble() ?? 0,
      productionDate: map['production_date'] != null
          ? DateTime.parse(map['production_date'] as String)
          : DateTime.now(),
      sourceWarehouseId: map['source_warehouse_id'] as int?,
      destinationWarehouseId: map['destination_warehouse_id'] as int?,
      notes: map['notes'] as String?,
      status: ProductionOrderStatus.fromString(map['status'] as String?),
      requiresApproval: (map['requires_approval'] as int?) == 1,
      createdByUsername: map['created_by_username'] as String?,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'] as String) : null,
      submittedAt: map['submitted_at'] != null ? DateTime.tryParse(map['submitted_at'] as String) : null,
      approverUsername: map['approver_username'] as String?,
      approvedAt: map['approved_at'] != null ? DateTime.tryParse(map['approved_at'] as String) : null,
      rejectionReason: map['rejection_reason'] as String?,
      rejectedAt: map['rejected_at'] != null ? DateTime.tryParse(map['rejected_at'] as String) : null,
      startedAt: map['started_at'] != null ? DateTime.tryParse(map['started_at'] as String) : null,
      completedAt: map['completed_at'] != null ? DateTime.tryParse(map['completed_at'] as String) : null,
      completedByUsername: map['completed_by_username'] as String?,
      actualQuantity: (map['actual_quantity'] as num?)?.toDouble(),
      variance: (map['variance'] as num?)?.toDouble(),
      materialCost: (map['material_cost'] as num?)?.toDouble(),
      laborCost: (map['labor_cost'] as num?)?.toDouble(),
      energyCost: (map['energy_cost'] as num?)?.toDouble(),
      overheadCost: (map['overhead_cost'] as num?)?.toDouble(),
      otherCost: (map['other_cost'] as num?)?.toDouble(),
      totalCost: (map['total_cost'] as num?)?.toDouble(),
      costPerUnit: (map['cost_per_unit'] as num?)?.toDouble(),
      rawMaterialsStockOutId: map['raw_materials_stock_out_id'] as int?,
      finishedGoodsReceiptId: map['finished_goods_receipt_id'] as int?,
    );
  }

  ProductionOrder copyWith({
    int? id,
    String? orderNumber,
    int? recipeId,
    String? recipeName,
    double? plannedQuantity,
    DateTime? productionDate,
    int? sourceWarehouseId,
    int? destinationWarehouseId,
    String? notes,
    ProductionOrderStatus? status,
    bool? requiresApproval,
    String? createdByUsername,
    DateTime? createdAt,
    DateTime? submittedAt,
    String? approverUsername,
    DateTime? approvedAt,
    String? rejectionReason,
    DateTime? rejectedAt,
    DateTime? startedAt,
    DateTime? completedAt,
    String? completedByUsername,
    double? actualQuantity,
    double? variance,
    double? materialCost,
    double? laborCost,
    double? energyCost,
    double? overheadCost,
    double? otherCost,
    double? totalCost,
    double? costPerUnit,
    int? rawMaterialsStockOutId,
    int? finishedGoodsReceiptId,
  }) {
    return ProductionOrder(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      recipeId: recipeId ?? this.recipeId,
      recipeName: recipeName ?? this.recipeName,
      plannedQuantity: plannedQuantity ?? this.plannedQuantity,
      productionDate: productionDate ?? this.productionDate,
      sourceWarehouseId: sourceWarehouseId ?? this.sourceWarehouseId,
      destinationWarehouseId: destinationWarehouseId ?? this.destinationWarehouseId,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      requiresApproval: requiresApproval ?? this.requiresApproval,
      createdByUsername: createdByUsername ?? this.createdByUsername,
      createdAt: createdAt ?? this.createdAt,
      submittedAt: submittedAt ?? this.submittedAt,
      approverUsername: approverUsername ?? this.approverUsername,
      approvedAt: approvedAt ?? this.approvedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      completedByUsername: completedByUsername ?? this.completedByUsername,
      actualQuantity: actualQuantity ?? this.actualQuantity,
      variance: variance ?? this.variance,
      materialCost: materialCost ?? this.materialCost,
      laborCost: laborCost ?? this.laborCost,
      energyCost: energyCost ?? this.energyCost,
      overheadCost: overheadCost ?? this.overheadCost,
      otherCost: otherCost ?? this.otherCost,
      totalCost: totalCost ?? this.totalCost,
      costPerUnit: costPerUnit ?? this.costPerUnit,
      rawMaterialsStockOutId: rawMaterialsStockOutId ?? this.rawMaterialsStockOutId,
      finishedGoodsReceiptId: finishedGoodsReceiptId ?? this.finishedGoodsReceiptId,
    );
  }
}
