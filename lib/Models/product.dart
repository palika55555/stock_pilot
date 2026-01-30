class Product {
  final String? uniqueId;
  final String name;
  final String plu;
  final String category;
  final int qty;
  final String unit;
  final double price;
  final double withoutVat;
  final int vat;
  final int discount;
  final double lastPurchasePrice;
  final String lastPurchaseDate;
  final String currency;
  final String location;

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
    required this.lastPurchaseDate,
    required this.currency,
    required this.location,
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
      'last_purchase_date': lastPurchaseDate,
      'currency': currency,
      'location': location,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      uniqueId: map['unique_id'],
      name: map['name'],
      plu: map['plu'],
      category: map['category'],
      qty: map['qty'],
      unit: map['unit'],
      price: map['price'],
      withoutVat: map['without_vat'],
      vat: map['vat'],
      discount: map['discount'],
      lastPurchasePrice: map['last_purchase_price'],
      lastPurchaseDate: map['last_purchase_date'],
      currency: map['currency'],
      location: map['location'],
    );
  }
}




