/// Položka receptúry šarže – materiál (voda, cement, štrk, frakcie) a množstvo.
class ProductionBatchRecipeItem {
  final int? id;
  final int batchId;
  final String materialName;
  final double quantity;
  final String unit;

  ProductionBatchRecipeItem({
    this.id,
    required this.batchId,
    required this.materialName,
    required this.quantity,
    this.unit = 'kg',
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'batch_id': batchId,
      'material_name': materialName,
      'quantity': quantity,
      'unit': unit,
    };
  }

  static ProductionBatchRecipeItem fromMap(Map<String, Object?> map) {
    return ProductionBatchRecipeItem(
      id: map['id'] as int?,
      batchId: map['batch_id'] as int,
      materialName: map['material_name'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      unit: map['unit'] as String? ?? 'kg',
    );
  }
}
