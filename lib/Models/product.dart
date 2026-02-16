class Product {
  final String? uniqueId;
  final String name;
  final String plu;
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

  /// Marža v % z predajnej ceny: (predajná - nákupná) / predajná × 100.
  /// Null ak predajná cena je 0 (nelze počítať).
  double? get marginPercent =>
      price > 0 ? ((price - purchasePrice) / price) * 100 : null;

  Product({
    this.uniqueId,
    required this.name,
    required this.plu,
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
  });

  Map<String, dynamic> toMap() {
    return {
      'unique_id': uniqueId,
      'name': name,
      'plu': plu,
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
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      uniqueId: map['unique_id'],
      name: map['name'],
      plu: map['plu'],
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
    );
  }
}
