/// Stav cenovej ponuky.
enum QuoteStatus {
  draft('draft'),
  sent('sent'),
  accepted('accepted'),
  rejected('rejected');

  final String value;
  const QuoteStatus(this.value);

  static QuoteStatus fromString(String? s) {
    switch (s) {
      case 'sent':
        return QuoteStatus.sent;
      case 'accepted':
        return QuoteStatus.accepted;
      case 'rejected':
        return QuoteStatus.rejected;
      default:
        return QuoteStatus.draft;
    }
  }
}

/// Hlavička cenovej ponuky.
class Quote {
  final int? id;
  final String quoteNumber;
  final int customerId;
  final String? customerName; // denormalized pre zobrazenie
  final DateTime createdAt;
  final DateTime? validUntil;
  final String? notes;
  final bool pricesIncludeVat;
  final int defaultVatRate;
  final QuoteStatus status;

  Quote({
    this.id,
    required this.quoteNumber,
    required this.customerId,
    this.customerName,
    required this.createdAt,
    this.validUntil,
    this.notes,
    this.pricesIncludeVat = true,
    this.defaultVatRate = 20,
    this.status = QuoteStatus.draft,
  });

  bool get isEditable => status == QuoteStatus.draft;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'quote_number': quoteNumber,
      'customer_id': customerId,
      'customer_name': customerName,
      'created_at': createdAt.toIso8601String(),
      'valid_until': validUntil?.toIso8601String(),
      'notes': notes,
      'prices_include_vat': pricesIncludeVat ? 1 : 0,
      'default_vat_rate': defaultVatRate,
      'status': status.value,
    };
  }

  factory Quote.fromMap(Map<String, dynamic> map) {
    return Quote(
      id: map['id'] as int?,
      quoteNumber: map['quote_number'] as String,
      customerId: map['customer_id'] as int,
      customerName: map['customer_name'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      validUntil: map['valid_until'] != null
          ? DateTime.parse(map['valid_until'] as String)
          : null,
      notes: map['notes'] as String?,
      pricesIncludeVat: (map['prices_include_vat'] as int?) == 1,
      defaultVatRate: map['default_vat_rate'] as int? ?? 20,
      status: QuoteStatus.fromString(map['status'] as String?),
    );
  }

  Quote copyWith({
    int? id,
    String? quoteNumber,
    int? customerId,
    String? customerName,
    DateTime? createdAt,
    DateTime? validUntil,
    String? notes,
    bool? pricesIncludeVat,
    int? defaultVatRate,
    QuoteStatus? status,
  }) {
    return Quote(
      id: id ?? this.id,
      quoteNumber: quoteNumber ?? this.quoteNumber,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      createdAt: createdAt ?? this.createdAt,
      validUntil: validUntil ?? this.validUntil,
      notes: notes ?? this.notes,
      pricesIncludeVat: pricesIncludeVat ?? this.pricesIncludeVat,
      defaultVatRate: defaultVatRate ?? this.defaultVatRate,
      status: status ?? this.status,
    );
  }
}

/// Jedna položka cenovej ponuky.
class QuoteItem {
  final int? id;
  final int quoteId;
  final String productUniqueId;
  final String? productName;
  final String? plu;
  final int qty;
  final String unit;
  final double unitPrice; // cena za jednotku (s DPH alebo bez podľa hlavičky)
  final int discountPercent;
  final int vatPercent;

  QuoteItem({
    this.id,
    required this.quoteId,
    required this.productUniqueId,
    this.productName,
    this.plu,
    required this.qty,
    required this.unit,
    required this.unitPrice,
    this.discountPercent = 0,
    this.vatPercent = 20,
  });

  /// Súčet riadku bez DPH. [pricesIncludeVat] = či je unitPrice s DPH.
  double getLineTotalWithoutVat(bool pricesIncludeVat) {
    final afterDiscount = unitPrice * qty * (1 - discountPercent / 100);
    if (pricesIncludeVat) {
      return (afterDiscount / (1 + vatPercent / 100) * 100).round() / 100;
    }
    return (afterDiscount * 100).round() / 100;
  }

  /// Súčet riadku s DPH. [pricesIncludeVat] = či je unitPrice s DPH.
  double getLineTotalWithVat(bool pricesIncludeVat) {
    final withoutVat = getLineTotalWithoutVat(pricesIncludeVat);
    return (withoutVat * (1 + vatPercent / 100) * 100).round() / 100;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'quote_id': quoteId,
      'product_unique_id': productUniqueId,
      'product_name': productName,
      'plu': plu,
      'qty': qty,
      'unit': unit,
      'unit_price': _roundPrice(unitPrice),
      'discount_percent': discountPercent,
      'vat_percent': vatPercent,
    };
  }

  static double _roundPrice(double value) {
    return (value * 100000).round() / 100000;
  }

  factory QuoteItem.fromMap(Map<String, dynamic> map) {
    return QuoteItem(
      id: map['id'] as int?,
      quoteId: map['quote_id'] as int,
      productUniqueId: map['product_unique_id'] as String,
      productName: map['product_name'] as String?,
      plu: map['plu'] as String?,
      qty: map['qty'] as int,
      unit: map['unit'] as String,
      unitPrice: (map['unit_price'] as num).toDouble(),
      discountPercent: map['discount_percent'] as int? ?? 0,
      vatPercent: map['vat_percent'] as int? ?? 20,
    );
  }
}
