/// Záznam skladového pohybu (výdaj) – jedna položka výdajky = jeden pohyb.
class StockMovement {
  final int? id;
  final int stockOutId;
  final String documentNumber;
  final DateTime createdAt;
  final String productUniqueId;
  final String? productName;
  final String? plu;
  final int qty;
  final String unit;
  /// Smer: 'OUT' pre výdaj
  final String direction;

  StockMovement({
    this.id,
    required this.stockOutId,
    required this.documentNumber,
    required this.createdAt,
    required this.productUniqueId,
    this.productName,
    this.plu,
    required this.qty,
    required this.unit,
    this.direction = 'OUT',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'stock_out_id': stockOutId,
        'document_number': documentNumber,
        'created_at': createdAt.toIso8601String(),
        'product_unique_id': productUniqueId,
        'product_name': productName,
        'plu': plu,
        'qty': qty,
        'unit': unit,
        'direction': direction,
      };

  factory StockMovement.fromMap(Map<String, dynamic> map) => StockMovement(
        id: map['id'] as int?,
        stockOutId: map['stock_out_id'] as int,
        documentNumber: map['document_number'] as String? ?? '',
        createdAt: map['created_at'] != null
            ? DateTime.parse(map['created_at'] as String)
            : DateTime.now(),
        productUniqueId: map['product_unique_id'] as String,
        productName: map['product_name'] as String?,
        plu: map['plu'] as String?,
        qty: map['qty'] as int,
        unit: map['unit'] as String,
        direction: map['direction'] as String? ?? 'OUT',
      );
}
