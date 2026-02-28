class Product {
  final String? uniqueId;
  final String name;
  final String plu;
  /// EAN / čiarový kód – pre vyhľadanie pri skenovaní a zobrazenie množstva.
  final String? ean;
  final String category;
  final int qty;
  final String unit;
  final double price; // Sales price with VAT
  final double withoutVat; // Sales price without VAT
  final int vat; // Sales VAT %
  final int discount;
  final double lastPurchasePrice;
  final double lastPurchasePriceWithoutVat; // Posledný nákup bez DPH (jedna hodnota)
  final String lastPurchaseDate;
  final String currency;
  final String location;
  final double purchasePrice; // Purchase price with VAT
  final double purchasePriceWithoutVat; // Purchase price without VAT
  final int purchaseVat; // Purchase VAT %
  final double recyclingFee;
  final String productType; // e.g. 'Sklad', 'Výroba'
  final String? supplierName; // Dodávateľ (z poslednej schválenej príjemky)
  final int? kindId;
  final int? warehouseId;
  /// Číslo viazanej položky (napr. fľaša k nápoju) – pri výdaji sa pridá s rovnakým množstvom.
  final String? linkedProductUniqueId;

  // --- Skladová karta (podľa OBERON plánu) ---
  /// Minimálne množstvo – pri zobrazení zostatku pod touto hranicou sa množstvo zobrazí tučne.
  final int minQuantity;
  /// Umožniť pracovať s položkou na pokladnici.
  final bool allowAtCashRegister;
  /// Uvádzať v tlačovom výstupe Cenník.
  final bool showInPriceList;
  /// Neaktívna karta sa zobrazí prečiarknutá.
  final bool isActive;
  /// Dočasne nedostupná (prepína sa napr. cez F6) – zobrazí sa sivou.
  final bool temporarilyUnavailable;
  /// Skladová skupina – 1 karta = max. 1 skupina (logické delenie, číslovanie).
  final String? stockGroup;
  /// Typ karty: jednoduchá, služba, vratný obal, sada, výrobok, receptúra.
  final String cardType;
  /// Na kartu sa vzťahuje pravidlo rozšírenej cenotvorby – zobrazí sa fialovou.
  final bool hasExtendedPricing;
  /// Iba celé množstvá – pri predaji/výdaji musí byť množstvo celé číslo.
  final bool ibaCeleMnozstva;

  /// Marža v % z predajnej ceny: (predajná - nákupná) / predajná × 100.
  /// Null ak predajná cena je 0 (nelze počítať).
  double? get marginPercent =>
      price > 0 ? ((price - purchasePrice) / price) * 100 : null;

  Product({
    this.uniqueId,
    required this.name,
    required this.plu,
    this.ean,
    required this.category,
    required this.qty,
    required this.unit,
    required this.price,
    required this.withoutVat,
    required this.vat,
    required this.discount,
    required this.lastPurchasePrice,
    this.lastPurchasePriceWithoutVat = 0.0,
    required this.lastPurchaseDate,
    required this.currency,
    required this.location,
    this.purchasePrice = 0.0,
    this.purchasePriceWithoutVat = 0.0,
    this.purchaseVat = 23,
    this.recyclingFee = 0.0,
    this.productType = 'Sklad',
    this.supplierName,
    this.kindId,
    this.warehouseId,
    this.linkedProductUniqueId,
    this.minQuantity = 0,
    this.allowAtCashRegister = true,
    this.showInPriceList = true,
    this.isActive = true,
    this.temporarilyUnavailable = false,
    this.stockGroup,
    this.cardType = 'jednoduchá',
    this.hasExtendedPricing = false,
    this.ibaCeleMnozstva = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'unique_id': uniqueId,
      'name': name,
      'plu': plu,
      'ean': ean,
      'category': category,
      'qty': qty,
      'unit': unit,
      'price': price,
      'without_vat': withoutVat,
      'vat': vat,
      'discount': discount,
      'last_purchase_price': lastPurchasePrice,
      'last_purchase_price_without_vat': lastPurchasePriceWithoutVat,
      'last_purchase_date': lastPurchaseDate,
      'currency': currency,
      'location': location,
      'purchase_price': purchasePrice,
      'purchase_price_without_vat': purchasePriceWithoutVat,
      'purchase_vat': purchaseVat,
      'recycling_fee': recyclingFee,
      'product_type': productType,
      'supplier_name': supplierName,
      'kind_id': kindId,
      'warehouse_id': warehouseId,
      'linked_product_unique_id': linkedProductUniqueId,
      'min_quantity': minQuantity,
      'allow_at_cash_register': allowAtCashRegister ? 1 : 0,
      'show_in_price_list': showInPriceList ? 1 : 0,
      'is_active': isActive ? 1 : 0,
      'temporarily_unavailable': temporarilyUnavailable ? 1 : 0,
      'stock_group': stockGroup,
      'card_type': cardType,
      'has_extended_pricing': hasExtendedPricing ? 1 : 0,
      'iba_cele_mnozstva': ibaCeleMnozstva ? 1 : 0,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      uniqueId: map['unique_id'],
      name: map['name'],
      plu: map['plu'],
      ean: map['ean'] as String?,
      category: map['category'],
      qty: (map['qty'] as num?)?.toInt() ?? 0,
      unit: map['unit'],
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      withoutVat: (map['without_vat'] as num?)?.toDouble() ?? 0.0,
      vat: (map['vat'] as num?)?.toInt() ?? 23,
      discount: (map['discount'] as num?)?.toInt() ?? 0,
      lastPurchasePrice:
          (map['last_purchase_price'] as num?)?.toDouble() ?? 0.0,
      lastPurchasePriceWithoutVat:
          (map['last_purchase_price_without_vat'] as num?)?.toDouble() ?? 0.0,
      lastPurchaseDate: map['last_purchase_date'] ?? '',
      currency: map['currency'] ?? 'EUR',
      location: map['location'] ?? '',
      purchasePrice: (map['purchase_price'] as num?)?.toDouble() ?? 0.0,
      purchasePriceWithoutVat:
          (map['purchase_price_without_vat'] as num?)?.toDouble() ?? 0.0,
      purchaseVat: (map['purchase_vat'] as num?)?.toInt() ?? 23,
      recyclingFee: (map['recycling_fee'] as num?)?.toDouble() ?? 0.0,
      productType: map['product_type'] ?? 'Sklad',
      supplierName: map['supplier_name'] as String?,
      kindId: map['kind_id'] as int?,
      warehouseId: map['warehouse_id'] as int?,
      linkedProductUniqueId: map['linked_product_unique_id'] as String?,
      minQuantity: (map['min_quantity'] as num?)?.toInt() ?? 0,
      allowAtCashRegister: (map['allow_at_cash_register'] as num?)?.toInt() != 0,
      showInPriceList: (map['show_in_price_list'] as num?)?.toInt() != 0,
      isActive: (map['is_active'] as num?)?.toInt() != 0,
      temporarilyUnavailable: (map['temporarily_unavailable'] as num?)?.toInt() == 1,
      stockGroup: map['stock_group'] as String?,
      cardType: map['card_type'] as String? ?? 'jednoduchá',
      hasExtendedPricing: (map['has_extended_pricing'] as num?)?.toInt() == 1,
      ibaCeleMnozstva: (map['iba_cele_mnozstva'] as num?)?.toInt() == 1,
    );
  }

  Product copyWith({
    String? uniqueId,
    String? name,
    String? plu,
    String? ean,
    String? category,
    int? qty,
    String? unit,
    double? price,
    double? withoutVat,
    int? vat,
    int? discount,
    double? lastPurchasePrice,
    double? lastPurchasePriceWithoutVat,
    String? lastPurchaseDate,
    String? currency,
    String? location,
    double? purchasePrice,
    double? purchasePriceWithoutVat,
    int? purchaseVat,
    double? recyclingFee,
    String? productType,
    String? supplierName,
    int? kindId,
    int? warehouseId,
    String? linkedProductUniqueId,
    int? minQuantity,
    bool? allowAtCashRegister,
    bool? showInPriceList,
    bool? isActive,
    bool? temporarilyUnavailable,
    String? stockGroup,
    String? cardType,
    bool? hasExtendedPricing,
    bool? ibaCeleMnozstva,
  }) {
    return Product(
      uniqueId: uniqueId ?? this.uniqueId,
      name: name ?? this.name,
      plu: plu ?? this.plu,
      ean: ean ?? this.ean,
      category: category ?? this.category,
      qty: qty ?? this.qty,
      unit: unit ?? this.unit,
      price: price ?? this.price,
      withoutVat: withoutVat ?? this.withoutVat,
      vat: vat ?? this.vat,
      discount: discount ?? this.discount,
      lastPurchasePrice: lastPurchasePrice ?? this.lastPurchasePrice,
      lastPurchasePriceWithoutVat: lastPurchasePriceWithoutVat ?? this.lastPurchasePriceWithoutVat,
      lastPurchaseDate: lastPurchaseDate ?? this.lastPurchaseDate,
      currency: currency ?? this.currency,
      location: location ?? this.location,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      purchasePriceWithoutVat: purchasePriceWithoutVat ?? this.purchasePriceWithoutVat,
      purchaseVat: purchaseVat ?? this.purchaseVat,
      recyclingFee: recyclingFee ?? this.recyclingFee,
      productType: productType ?? this.productType,
      supplierName: supplierName ?? this.supplierName,
      kindId: kindId ?? this.kindId,
      warehouseId: warehouseId ?? this.warehouseId,
      linkedProductUniqueId: linkedProductUniqueId ?? this.linkedProductUniqueId,
      minQuantity: minQuantity ?? this.minQuantity,
      allowAtCashRegister: allowAtCashRegister ?? this.allowAtCashRegister,
      showInPriceList: showInPriceList ?? this.showInPriceList,
      isActive: isActive ?? this.isActive,
      temporarilyUnavailable: temporarilyUnavailable ?? this.temporarilyUnavailable,
      stockGroup: stockGroup ?? this.stockGroup,
      cardType: cardType ?? this.cardType,
      hasExtendedPricing: hasExtendedPricing ?? this.hasExtendedPricing,
      ibaCeleMnozstva: ibaCeleMnozstva ?? this.ibaCeleMnozstva,
    );
  }
}
