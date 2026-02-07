class Supplier {
  final int? id;
  final String name;
  final String ico;
  final String? email;
  final String? address;
  final String? city;
  final String? postalCode;
  final String? dic;
  final String? icDph;

  /// Default VAT % used for receipts when creating them with this supplier.
  final int defaultVatRate;

  /// Stav dodávateľa: aktívny (používaný) alebo neaktívny (skrytý z výberu pri príjemkách).
  final bool isActive;

  Supplier({
    this.id,
    required this.name,
    required this.ico,
    this.email,
    this.address,
    this.city,
    this.postalCode,
    this.dic,
    this.icDph,
    this.defaultVatRate = 20,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'ico': ico,
      'email': email,
      'address': address,
      'city': city,
      'postal_code': postalCode,
      'dic': dic,
      'ic_dph': icDph,
      'default_vat_rate': defaultVatRate,
      'is_active': isActive ? 1 : 0,
    };
  }

  factory Supplier.fromMap(Map<String, dynamic> map) {
    return Supplier(
      id: map['id'] as int?,
      name: map['name'] ?? '',
      ico: map['ico'] ?? '',
      email: map['email'] as String?,
      address: map['address'] as String?,
      city: map['city'] as String?,
      postalCode: map['postal_code'] as String?,
      dic: map['dic'] as String?,
      icDph: map['ic_dph'] as String?,
      defaultVatRate: map['default_vat_rate'] as int? ?? 20,
      isActive: (map['is_active'] as int?) != 0,
    );
  }

  Supplier copyWith({
    int? id,
    String? name,
    String? ico,
    String? email,
    String? address,
    String? city,
    String? postalCode,
    String? dic,
    String? icDph,
    int? defaultVatRate,
    bool? isActive,
  }) {
    return Supplier(
      id: id ?? this.id,
      name: name ?? this.name,
      ico: ico ?? this.ico,
      email: email ?? this.email,
      address: address ?? this.address,
      city: city ?? this.city,
      postalCode: postalCode ?? this.postalCode,
      dic: dic ?? this.dic,
      icDph: icDph ?? this.icDph,
      defaultVatRate: defaultVatRate ?? this.defaultVatRate,
      isActive: isActive ?? this.isActive,
    );
  }
}
