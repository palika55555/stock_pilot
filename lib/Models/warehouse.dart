/// Typy skladu – zhodné s [Product.productType] pre prepojenie.
class WarehouseType {
  static const String predaj = 'Predaj';
  static const String vyroba = 'Výroba';
  static const String rezijnyMaterial = 'Režijný materiál';
  static const String sklad = 'Sklad';
  static const String sluzba = 'Služba'; // spätná kompatibilita
  static List<String> get all => [predaj, vyroba, rezijnyMaterial, sklad, sluzba];
}

class Warehouse {
  final int? id;
  final String name;
  final String code;
  final String warehouseType; // Predaj, Výroba, Režijný materiál, Sklad
  final String? address;
  final String? city;
  final String? postalCode;
  final bool isActive;
  /// Počet druhov (položiek) na sklade – voliteľne z DB/štatistík.
  final int? itemCount;
  /// Čas poslednej zmeny – voliteľne z DB.
  final DateTime? lastUpdate;
  /// Aktuálna zásoba (jednotky) – pre výpočet % zaplnenia.
  final num? currentStock;
  /// Maximálna kapacita (jednotky) – pre výpočet % zaplnenia.
  final num? maxCapacity;

  Warehouse({
    this.id,
    required this.name,
    required this.code,
    this.warehouseType = WarehouseType.predaj,
    this.address,
    this.city,
    this.postalCode,
    this.isActive = true,
    this.itemCount,
    this.lastUpdate,
    this.currentStock,
    this.maxCapacity,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'warehouse_type': warehouseType,
      'address': address,
      'city': city,
      'postal_code': postalCode,
      'is_active': isActive ? 1 : 0,
    };
  }

  factory Warehouse.fromMap(Map<String, dynamic> map) {
    DateTime? lastUpdate;
    if (map['last_update'] != null) {
      if (map['last_update'] is String) {
        lastUpdate = DateTime.tryParse(map['last_update'] as String);
      } else if (map['last_update'] is int) {
        lastUpdate = DateTime.fromMillisecondsSinceEpoch(map['last_update'] as int);
      }
    }
    return Warehouse(
      id: map['id'] as int?,
      name: map['name'] ?? '',
      code: map['code'] ?? '',
      warehouseType: map['warehouse_type'] as String? ?? WarehouseType.predaj,
      address: map['address'] as String?,
      city: map['city'] as String?,
      postalCode: map['postal_code'] as String?,
      isActive: (map['is_active'] as int?) != 0,
      itemCount: map['item_count'] as int?,
      lastUpdate: lastUpdate,
      currentStock: (map['current_stock'] as num?)?.toDouble(),
      maxCapacity: (map['max_capacity'] as num?)?.toDouble(),
    );
  }

  Warehouse copyWith({
    int? id,
    String? name,
    String? code,
    String? warehouseType,
    String? address,
    String? city,
    String? postalCode,
    bool? isActive,
    int? itemCount,
    DateTime? lastUpdate,
    num? currentStock,
    num? maxCapacity,
  }) {
    return Warehouse(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      warehouseType: warehouseType ?? this.warehouseType,
      address: address ?? this.address,
      city: city ?? this.city,
      postalCode: postalCode ?? this.postalCode,
      isActive: isActive ?? this.isActive,
      itemCount: itemCount ?? this.itemCount,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      currentStock: currentStock ?? this.currentStock,
      maxCapacity: maxCapacity ?? this.maxCapacity,
    );
  }
}
