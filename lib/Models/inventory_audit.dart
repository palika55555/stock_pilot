/// Záznam inventúry skladu.
class InventoryAudit {
  final int? id;
  final int warehouseId;
  final String warehouseName;
  final String username;
  final DateTime createdAt;
  final int totalProducts;
  final int changedProducts;
  final String? notes;
  final String? userId;

  InventoryAudit({
    this.id,
    required this.warehouseId,
    required this.warehouseName,
    required this.username,
    required this.createdAt,
    required this.totalProducts,
    required this.changedProducts,
    this.notes,
    this.userId,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'warehouse_id': warehouseId,
        'warehouse_name': warehouseName,
        'username': username,
        'created_at': createdAt.toIso8601String(),
        'total_products': totalProducts,
        'changed_products': changedProducts,
        'notes': notes,
        'user_id': userId,
      };

  factory InventoryAudit.fromMap(Map<String, dynamic> m) => InventoryAudit(
        id: m['id'] as int?,
        warehouseId: m['warehouse_id'] as int? ?? 0,
        warehouseName: m['warehouse_name'] as String? ?? '',
        username: m['username'] as String? ?? '',
        createdAt: DateTime.tryParse(m['created_at'] as String? ?? '') ??
            DateTime.now(),
        totalProducts: m['total_products'] as int? ?? 0,
        changedProducts: m['changed_products'] as int? ?? 0,
        notes: m['notes'] as String?,
        userId: m['user_id']?.toString(),
      );
}

/// Položka inventúry – jeden produkt s rozdielom.
class InventoryAuditItem {
  final int? id;
  final int auditId;
  final String productUniqueId;
  final String productName;
  final String productPlu;
  final String unit;
  final int systemQty;
  final int actualQty;
  final int difference;

  InventoryAuditItem({
    this.id,
    required this.auditId,
    required this.productUniqueId,
    required this.productName,
    required this.productPlu,
    required this.unit,
    required this.systemQty,
    required this.actualQty,
    required this.difference,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'audit_id': auditId,
        'product_unique_id': productUniqueId,
        'product_name': productName,
        'product_plu': productPlu,
        'unit': unit,
        'system_qty': systemQty,
        'actual_qty': actualQty,
        'difference': difference,
      };

  factory InventoryAuditItem.fromMap(Map<String, dynamic> m) =>
      InventoryAuditItem(
        id: m['id'] as int?,
        auditId: m['audit_id'] as int? ?? 0,
        productUniqueId: m['product_unique_id'] as String? ?? '',
        productName: m['product_name'] as String? ?? '',
        productPlu: m['product_plu'] as String? ?? '',
        unit: m['unit'] as String? ?? 'ks',
        systemQty: m['system_qty'] as int? ?? 0,
        actualQty: m['actual_qty'] as int? ?? 0,
        difference: m['difference'] as int? ?? 0,
      );
}
