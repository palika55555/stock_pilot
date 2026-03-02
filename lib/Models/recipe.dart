/// Receptúra (Bill of Materials / Production Recipe).
class Recipe {
  final int? id;
  final String name;
  final String finishedProductUniqueId;
  final String? finishedProductName;
  final double outputQuantity;
  final String unit;
  final int? productionWarehouseId;
  final int? outputWarehouseId;
  final int? productionTimeMinutes;
  final String? note;
  final bool isActive;
  /// Minimálne množstvo pre schválenie – nad touto hranicou musí VP ísť na schválenie.
  final double minApprovalQuantity;

  const Recipe({
    this.id,
    required this.name,
    required this.finishedProductUniqueId,
    this.finishedProductName,
    required this.outputQuantity,
    this.unit = 'ks',
    this.productionWarehouseId,
    this.outputWarehouseId,
    this.productionTimeMinutes,
    this.note,
    this.isActive = true,
    this.minApprovalQuantity = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'finished_product_unique_id': finishedProductUniqueId,
      'finished_product_name': finishedProductName,
      'output_quantity': outputQuantity,
      'unit': unit,
      'production_warehouse_id': productionWarehouseId,
      'output_warehouse_id': outputWarehouseId,
      'production_time_minutes': productionTimeMinutes,
      'note': note,
      'is_active': isActive ? 1 : 0,
      'min_approval_quantity': minApprovalQuantity,
    };
  }

  factory Recipe.fromMap(Map<String, dynamic> map) {
    return Recipe(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      finishedProductUniqueId: map['finished_product_unique_id'] as String? ?? '',
      finishedProductName: map['finished_product_name'] as String?,
      outputQuantity: (map['output_quantity'] as num?)?.toDouble() ?? 0,
      unit: map['unit'] as String? ?? 'ks',
      productionWarehouseId: map['production_warehouse_id'] as int?,
      outputWarehouseId: map['output_warehouse_id'] as int?,
      productionTimeMinutes: map['production_time_minutes'] as int?,
      note: map['note'] as String?,
      isActive: (map['is_active'] as int?) != 0,
      minApprovalQuantity: (map['min_approval_quantity'] as num?)?.toDouble() ?? 0,
    );
  }

  Recipe copyWith({
    int? id,
    String? name,
    String? finishedProductUniqueId,
    String? finishedProductName,
    double? outputQuantity,
    String? unit,
    int? productionWarehouseId,
    int? outputWarehouseId,
    int? productionTimeMinutes,
    String? note,
    bool? isActive,
    double? minApprovalQuantity,
  }) {
    return Recipe(
      id: id ?? this.id,
      name: name ?? this.name,
      finishedProductUniqueId: finishedProductUniqueId ?? this.finishedProductUniqueId,
      finishedProductName: finishedProductName ?? this.finishedProductName,
      outputQuantity: outputQuantity ?? this.outputQuantity,
      unit: unit ?? this.unit,
      productionWarehouseId: productionWarehouseId ?? this.productionWarehouseId,
      outputWarehouseId: outputWarehouseId ?? this.outputWarehouseId,
      productionTimeMinutes: productionTimeMinutes ?? this.productionTimeMinutes,
      note: note ?? this.note,
      isActive: isActive ?? this.isActive,
      minApprovalQuantity: minApprovalQuantity ?? this.minApprovalQuantity,
    );
  }
}

/// Jedna surovina receptúry (produkt + množstvo na dávku). Skladom a dostupnosť sa počíta v UI.
class RecipeIngredient {
  final int? id;
  final int recipeId;
  final String productUniqueId;
  final String? productName;
  final String? plu;
  final double quantity;
  final String unit;

  const RecipeIngredient({
    this.id,
    required this.recipeId,
    required this.productUniqueId,
    this.productName,
    this.plu,
    required this.quantity,
    this.unit = 'ks',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'recipe_id': recipeId,
      'product_unique_id': productUniqueId,
      'product_name': productName,
      'plu': plu,
      'quantity': quantity,
      'unit': unit,
    };
  }

  factory RecipeIngredient.fromMap(Map<String, dynamic> map) {
    return RecipeIngredient(
      id: map['id'] as int?,
      recipeId: map['recipe_id'] as int? ?? 0,
      productUniqueId: map['product_unique_id'] as String? ?? '',
      productName: map['product_name'] as String?,
      plu: map['plu'] as String?,
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
      unit: map['unit'] as String? ?? 'ks',
    );
  }

  RecipeIngredient copyWith({
    int? id,
    int? recipeId,
    String? productUniqueId,
    String? productName,
    String? plu,
    double? quantity,
    String? unit,
  }) {
    return RecipeIngredient(
      id: id ?? this.id,
      recipeId: recipeId ?? this.recipeId,
      productUniqueId: productUniqueId ?? this.productUniqueId,
      productName: productName ?? this.productName,
      plu: plu ?? this.plu,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
    );
  }
}
