/// Stav príjemky: rozpracovaný (draft), vykázaná (editovateľná) alebo schválená (uzamknutá).
enum InboundReceiptStatus {
  rozpracovany('rozpracovany'),
  vykazana('vykazana'),
  schvalena('schvalena');

  final String value;
  const InboundReceiptStatus(this.value);

  static InboundReceiptStatus fromString(String? s) {
    if (s == 'schvalena') return InboundReceiptStatus.schvalena;
    if (s == 'rozpracovany') return InboundReceiptStatus.rozpracovany;
    return InboundReceiptStatus.vykazana;
  }
}

/// Inbound receipt (príjemka) header.
class InboundReceipt {
  final int? id;
  final String receiptNumber;
  final String? invoiceNumber;
  final DateTime createdAt;
  final String? supplierName;
  final String? notes;
  final String? username;
  final bool pricesIncludeVat;
  final bool vatAppliesToAll;
  final int? vatRate;
  final InboundReceiptStatus status;

  InboundReceipt({
    this.id,
    required this.receiptNumber,
    this.invoiceNumber,
    required this.createdAt,
    this.supplierName,
    this.notes,
    this.username,
    this.pricesIncludeVat = true,
    this.vatAppliesToAll = false,
    this.vatRate,
    this.status = InboundReceiptStatus.vykazana,
  });

  bool get isEditable => status != InboundReceiptStatus.schvalena;
  bool get isApproved => status == InboundReceiptStatus.schvalena;
  bool get isDraft => status == InboundReceiptStatus.rozpracovany;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'receipt_number': receiptNumber,
      'invoice_number': invoiceNumber,
      'created_at': createdAt.toIso8601String(),
      'supplier_name': supplierName,
      'notes': notes,
      'username': username,
      'prices_include_vat': pricesIncludeVat ? 1 : 0,
      'vat_applies_to_all': vatAppliesToAll ? 1 : 0,
      'vat_rate': vatRate,
      'status': status.value,
    };
  }

  factory InboundReceipt.fromMap(Map<String, dynamic> map) {
    return InboundReceipt(
      id: map['id'] as int?,
      receiptNumber: map['receipt_number'] as String,
      invoiceNumber: map['invoice_number'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      supplierName: map['supplier_name'] as String?,
      notes: map['notes'] as String?,
      username: map['username'] as String?,
      pricesIncludeVat: (map['prices_include_vat'] as int?) == 1,
      vatAppliesToAll: (map['vat_applies_to_all'] as int?) == 1,
      vatRate: map['vat_rate'] as int?,
      status: InboundReceiptStatus.fromString(map['status'] as String?),
    );
  }

  InboundReceipt copyWith({
    int? id,
    String? receiptNumber,
    String? invoiceNumber,
    DateTime? createdAt,
    String? supplierName,
    String? notes,
    String? username,
    bool? pricesIncludeVat,
    bool? vatAppliesToAll,
    int? vatRate,
    InboundReceiptStatus? status,
  }) {
    return InboundReceipt(
      id: id ?? this.id,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      createdAt: createdAt ?? this.createdAt,
      supplierName: supplierName ?? this.supplierName,
      notes: notes ?? this.notes,
      username: username ?? this.username,
      pricesIncludeVat: pricesIncludeVat ?? this.pricesIncludeVat,
      vatAppliesToAll: vatAppliesToAll ?? this.vatAppliesToAll,
      vatRate: vatRate ?? this.vatRate,
      status: status ?? this.status,
    );
  }
}

/// Single line item on an inbound receipt. Unit price: double, up to 5 decimal places.
class InboundReceiptItem {
  final int? id;
  final int receiptId;
  final String productUniqueId;
  final String? productName;
  final String? plu;
  final int qty;
  final String unit;
  final double unitPrice;
  /// DPH % pre túto položku; null = použiť DPH príjemky alebo produktu.
  final int? vatPercent;

  InboundReceiptItem({
    this.id,
    required this.receiptId,
    required this.productUniqueId,
    this.productName,
    this.plu,
    required this.qty,
    required this.unit,
    required this.unitPrice,
    this.vatPercent,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'receipt_id': receiptId,
      'product_unique_id': productUniqueId,
      'product_name': productName,
      'plu': plu,
      'qty': qty,
      'unit': unit,
      'unit_price': _roundPrice(unitPrice),
      'vat_percent': vatPercent,
    };
  }

  static double _roundPrice(double value) {
    return (value * 100000).round() / 100000;
  }

  factory InboundReceiptItem.fromMap(Map<String, dynamic> map) {
    return InboundReceiptItem(
      id: map['id'] as int?,
      receiptId: map['receipt_id'] as int,
      productUniqueId: map['product_unique_id'] as String,
      productName: map['product_name'] as String?,
      plu: map['plu'] as String?,
      qty: map['qty'] as int,
      unit: map['unit'] as String,
      unitPrice: (map['unit_price'] as num).toDouble(),
      vatPercent: map['vat_percent'] as int?,
    );
  }
}
