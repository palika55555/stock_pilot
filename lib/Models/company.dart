/// Údaje vystavovateľa (naša firma) pre cenové ponuky a tlač.
class Company {
  final int? id;
  final String name;
  final String? address;
  final String? city;
  final String? postalCode;
  final String? country;
  final String? ico;
  final String? dic;
  final String? icDph;
  final bool vatPayer;
  final String? phone;
  final String? email;
  final String? web;
  final String? iban;
  final String? swift;
  final String? bankName;
  final String? account;
  final String? registerInfo; // OR, Oddiel, Vložka
  /// Cesta k súboru loga (pre tlač cenových ponúk).
  final String? logoPath;

  Company({
    this.id,
    required this.name,
    this.address,
    this.city,
    this.postalCode,
    this.country,
    this.ico,
    this.dic,
    this.icDph,
    this.vatPayer = true,
    this.phone,
    this.email,
    this.web,
    this.iban,
    this.swift,
    this.bankName,
    this.account,
    this.registerInfo,
    this.logoPath,
  });

  String get fullAddress {
    final parts = <String>[];
    if (address != null && address!.isNotEmpty) parts.add(address!);
    if (city != null && city!.isNotEmpty) {
      parts.add(
        postalCode != null && postalCode!.isNotEmpty
            ? '$postalCode $city'
            : city!,
      );
    }
    if (country != null && country!.isNotEmpty) parts.add(country!);
    return parts.join(', ');
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'city': city,
      'postal_code': postalCode,
      'country': country,
      'ico': ico,
      'dic': dic,
      'ic_dph': icDph,
      'vat_payer': vatPayer ? 1 : 0,
      'phone': phone,
      'email': email,
      'web': web,
      'iban': iban,
      'swift': swift,
      'bank_name': bankName,
      'account': account,
      'register_info': registerInfo,
      'logo_path': logoPath,
    };
  }

  factory Company.fromMap(Map<String, dynamic> map) {
    return Company(
      id: map['id'] as int?,
      name: map['name'] ?? '',
      address: map['address'] as String?,
      city: map['city'] as String?,
      postalCode: map['postal_code'] as String?,
      country: map['country'] as String?,
      ico: map['ico'] as String?,
      dic: map['dic'] as String?,
      icDph: map['ic_dph'] as String?,
      vatPayer: (map['vat_payer'] as int?) != 0,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      web: map['web'] as String?,
      iban: map['iban'] as String?,
      swift: map['swift'] as String?,
      bankName: map['bank_name'] as String?,
      account: map['account'] as String?,
      registerInfo: map['register_info'] as String?,
      logoPath: map['logo_path'] as String?,
    );
  }

  Company copyWith({
    int? id,
    String? name,
    String? address,
    String? city,
    String? postalCode,
    String? country,
    String? ico,
    String? dic,
    String? icDph,
    bool? vatPayer,
    String? phone,
    String? email,
    String? web,
    String? iban,
    String? swift,
    String? bankName,
    String? account,
    String? registerInfo,
    String? logoPath,
  }) {
    return Company(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      city: city ?? this.city,
      postalCode: postalCode ?? this.postalCode,
      country: country ?? this.country,
      ico: ico ?? this.ico,
      dic: dic ?? this.dic,
      icDph: icDph ?? this.icDph,
      vatPayer: vatPayer ?? this.vatPayer,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      web: web ?? this.web,
      iban: iban ?? this.iban,
      swift: swift ?? this.swift,
      bankName: bankName ?? this.bankName,
      account: account ?? this.account,
      registerInfo: registerInfo ?? this.registerInfo,
      logoPath: logoPath ?? this.logoPath,
    );
  }
}
