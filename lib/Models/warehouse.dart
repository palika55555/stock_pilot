class Warehouse {
  final int? id;
  final String name;
  final String code;
  final String? address;
  final String? city;
  final String? postalCode;
  final bool isActive;

  Warehouse({
    this.id,
    required this.name,
    required this.code,
    this.address,
    this.city,
    this.postalCode,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'address': address,
      'city': city,
      'postal_code': postalCode,
      'is_active': isActive ? 1 : 0,
    };
  }

  factory Warehouse.fromMap(Map<String, dynamic> map) {
    return Warehouse(
      id: map['id'] as int?,
      name: map['name'] ?? '',
      code: map['code'] ?? '',
      address: map['address'] as String?,
      city: map['city'] as String?,
      postalCode: map['postal_code'] as String?,
      isActive: (map['is_active'] as int?) != 0,
    );
  }

  Warehouse copyWith({
    int? id,
    String? name,
    String? code,
    String? address,
    String? city,
    String? postalCode,
    bool? isActive,
  }) {
    return Warehouse(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      address: address ?? this.address,
      city: city ?? this.city,
      postalCode: postalCode ?? this.postalCode,
      isActive: isActive ?? this.isActive,
    );
  }
}
