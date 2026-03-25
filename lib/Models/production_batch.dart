/// Šarža výroby betónových výrobkov – dátum, typ výrobku, počet kusov, marža.
class ProductionBatch {
  final int? id;
  final String productionDate; // ISO date YYYY-MM-DD
  final String productType;   // Zamková dlažba, Tvárnice, ...
  final int quantityProduced;
  final String? notes;
  final String? createdAt;   // ISO datetime
  final double? costTotal;
  final double? revenueTotal;
  final int? pavingStoneId;
  final double? requestedM2;
  final double? actualStoredM2;

  ProductionBatch({
    this.id,
    required this.productionDate,
    required this.productType,
    required this.quantityProduced,
    this.notes,
    this.createdAt,
    this.costTotal,
    this.revenueTotal,
    this.pavingStoneId,
    this.requestedM2,
    this.actualStoredM2,
  });

  /// Marža v % z výnosu: (revenue - cost) / revenue * 100. Null ak revenue je 0.
  double? get marginPercent =>
      revenueTotal != null && revenueTotal! > 0 && costTotal != null
          ? ((revenueTotal! - costTotal!) / revenueTotal!) * 100
          : null;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'production_date': productionDate,
      'product_type': productType,
      'quantity_produced': quantityProduced,
      'notes': notes,
      'created_at': createdAt,
      'cost_total': costTotal,
      'revenue_total': revenueTotal,
      'paving_stone_id': pavingStoneId,
      'requested_m2': requestedM2,
      'actual_stored_m2': actualStoredM2,
    };
  }

  static ProductionBatch fromMap(Map<String, Object?> map) {
    return ProductionBatch(
      id: map['id'] as int?,
      productionDate: map['production_date'] as String,
      productType: map['product_type'] as String,
      quantityProduced: map['quantity_produced'] as int? ?? 0,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String?,
      costTotal: (map['cost_total'] as num?)?.toDouble(),
      revenueTotal: (map['revenue_total'] as num?)?.toDouble(),
      pavingStoneId: map['paving_stone_id'] as int?,
      requestedM2: (map['requested_m2'] as num?)?.toDouble(),
      actualStoredM2: (map['actual_stored_m2'] as num?)?.toDouble(),
    );
  }

  ProductionBatch copyWith({
    int? id,
    String? productionDate,
    String? productType,
    int? quantityProduced,
    String? notes,
    String? createdAt,
    double? costTotal,
    double? revenueTotal,
    int? pavingStoneId,
    double? requestedM2,
    double? actualStoredM2,
  }) {
    return ProductionBatch(
      id: id ?? this.id,
      productionDate: productionDate ?? this.productionDate,
      productType: productType ?? this.productType,
      quantityProduced: quantityProduced ?? this.quantityProduced,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      costTotal: costTotal ?? this.costTotal,
      revenueTotal: revenueTotal ?? this.revenueTotal,
      pavingStoneId: pavingStoneId ?? this.pavingStoneId,
      requestedM2: requestedM2 ?? this.requestedM2,
      actualStoredM2: actualStoredM2 ?? this.actualStoredM2,
    );
  }
}
