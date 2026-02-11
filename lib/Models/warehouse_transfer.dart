/// Záznam presunu tovaru medzi skladmi.
class WarehouseTransfer {
  final int? id;
  final int fromWarehouseId;
  final int toWarehouseId;
  final String productUniqueId;
  final String productName;
  final String productPlu;
  final int quantity;
  final String unit;
  final DateTime createdAt;
  final String? notes;
  final String? username;

  WarehouseTransfer({
    this.id,
    required this.fromWarehouseId,
    required this.toWarehouseId,
    required this.productUniqueId,
    required this.productName,
    required this.productPlu,
    required this.quantity,
    required this.unit,
    required this.createdAt,
    this.notes,
    this.username,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'from_warehouse_id': fromWarehouseId,
      'to_warehouse_id': toWarehouseId,
      'product_unique_id': productUniqueId,
      'product_name': productName,
      'product_plu': productPlu,
      'quantity': quantity,
      'unit': unit,
      'created_at': createdAt.toIso8601String(),
      'notes': notes,
      'username': username,
    };
  }

  factory WarehouseTransfer.fromMap(Map<String, dynamic> map) {
    return WarehouseTransfer(
      id: map['id'] as int?,
      fromWarehouseId: map['from_warehouse_id'] as int,
      toWarehouseId: map['to_warehouse_id'] as int,
      productUniqueId: map['product_unique_id'] as String,
      productName: map['product_name'] as String? ?? '',
      productPlu: map['product_plu'] as String? ?? '',
      quantity: map['quantity'] as int? ?? 0,
      unit: map['unit'] as String? ?? 'ks',
      createdAt: DateTime.parse(map['created_at'] as String),
      notes: map['notes'] as String?,
      username: map['username'] as String?,
    );
  }
}
