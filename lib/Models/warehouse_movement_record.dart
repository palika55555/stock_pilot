/// Jeden záznam v knihe skladových pohybov – príjem alebo výdaj jednej položky.
/// Slúži na analýzu skladových operácií. Záznamy sú len na čítanie (vznikajú z dokladov).
class WarehouseMovementRecord {
  final DateTime createdAt;
  final String documentNumber;
  final String productUniqueId;
  final String? productName;
  final String? plu;
  final int qty;
  final String unit;
  /// 'IN' = príjem, 'OUT' = výdaj
  final String direction;
  final int? warehouseId;
  /// Typ zdroja: receipt, stock_out, transfer
  final String sourceType;
  /// Pre transfer: ak direction OUT, ide o from_warehouse; ak IN, o to_warehouse
  final int? relatedId;

  WarehouseMovementRecord({
    required this.createdAt,
    required this.documentNumber,
    required this.productUniqueId,
    this.productName,
    this.plu,
    required this.qty,
    required this.unit,
    required this.direction,
    this.warehouseId,
    required this.sourceType,
    this.relatedId,
  });

  bool get isIn => direction == 'IN';
  bool get isOut => direction == 'OUT';
}
