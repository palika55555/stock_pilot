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

  ProductionBatch({
    this.id,
    required this.productionDate,
    required this.productType,
    required this.quantityProduced,
    this.notes,
    this.createdAt,
    this.costTotal,
    this.revenueTotal,
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
    );
  }
}
