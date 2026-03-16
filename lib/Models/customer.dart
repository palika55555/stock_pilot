class Customer {
  final int? id;
  final String name;
  final String ico;
  final String? email;
  final String? address;
  final String? city;
  final String? postalCode;
  final String? dic;
  final String? icDph;
  final String? contactPerson;
  final String? phone;

  /// Predvolená sadzba DPH % pre cenové ponuky pri tomto zákazníkovi.
  final int defaultVatRate;

  /// Stav zákazníka: aktívny (používaný pri cenových ponukách) alebo neaktívny.
  final bool isActive;

  /// Bilancia paliet u zákazníka (požičané / dlhované).
  final int palletBalance;

  /// Je zákazník platcom DPH?
  final bool vatPayer;

  Customer({
    this.id,
    required this.name,
    required this.ico,
    this.email,
    this.address,
    this.city,
    this.postalCode,
    this.dic,
    this.icDph,
    this.contactPerson,
    this.phone,
    this.defaultVatRate = 20,
    this.isActive = true,
    this.palletBalance = 0,
    this.vatPayer = true,
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
      'contact_person': contactPerson,
      'phone': phone,
      'default_vat_rate': defaultVatRate,
      'is_active': isActive ? 1 : 0,
      'pallet_balance': palletBalance,
      'vat_payer': vatPayer ? 1 : 0,
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] as int?,
      name: map['name'] ?? '',
      ico: map['ico'] ?? '',
      email: map['email'] as String?,
      address: map['address'] as String?,
      city: map['city'] as String?,
      postalCode: map['postal_code'] as String?,
      dic: map['dic'] as String?,
      icDph: map['ic_dph'] as String?,
      contactPerson: map['contact_person'] as String?,
      phone: map['phone'] as String?,
      defaultVatRate: map['default_vat_rate'] as int? ?? 20,
      isActive: (map['is_active'] as int?) != 0,
      palletBalance: map['pallet_balance'] as int? ?? 0,
      vatPayer: (map['vat_payer'] as int? ?? 1) != 0,
    );
  }

  Customer copyWith({
    int? id,
    String? name,
    String? ico,
    String? email,
    String? address,
    String? city,
    String? postalCode,
    String? dic,
    String? icDph,
    String? contactPerson,
    String? phone,
    int? defaultVatRate,
    bool? isActive,
    int? palletBalance,
    bool? vatPayer,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      ico: ico ?? this.ico,
      email: email ?? this.email,
      address: address ?? this.address,
      city: city ?? this.city,
      postalCode: postalCode ?? this.postalCode,
      dic: dic ?? this.dic,
      icDph: icDph ?? this.icDph,
      contactPerson: contactPerson ?? this.contactPerson,
      phone: phone ?? this.phone,
      defaultVatRate: defaultVatRate ?? this.defaultVatRate,
      isActive: isActive ?? this.isActive,
      palletBalance: palletBalance ?? this.palletBalance,
      vatPayer: vatPayer ?? this.vatPayer,
    );
  }
}
