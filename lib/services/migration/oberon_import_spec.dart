/// Konfigurácia importu skladových kariet z Oberon (SQLite) do StockPilot.
class OberonProductImportSpec {
  /// Názov tabuľky v Oberon databáze (presne ako v `sqlite_master`).
  final String tableName;

  /// Kľúč = pole v StockPilot `products`, hodnota = názov stĺpca v Oberon.
  final Map<String, String?> columnMap;

  /// Ak `warehouse_id` nie je v mape, použije sa táto hodnota (inak null).
  final int? defaultWarehouseId;

  final String defaultCurrency;

  /// Ak je v lokálnej DB už produkt s rovnakým PLU, riadok sa preskočí.
  final bool skipIfPluExists;

  const OberonProductImportSpec({
    required this.tableName,
    required this.columnMap,
    this.defaultWarehouseId,
    this.defaultCurrency = 'EUR',
    this.skipIfPluExists = true,
  });

  OberonProductImportSpec copyWith({
    String? tableName,
    Map<String, String?>? columnMap,
    int? defaultWarehouseId,
    String? defaultCurrency,
    bool? skipIfPluExists,
  }) {
    return OberonProductImportSpec(
      tableName: tableName ?? this.tableName,
      columnMap: columnMap ?? this.columnMap,
      defaultWarehouseId: defaultWarehouseId ?? this.defaultWarehouseId,
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
      skipIfPluExists: skipIfPluExists ?? this.skipIfPluExists,
    );
  }
}
