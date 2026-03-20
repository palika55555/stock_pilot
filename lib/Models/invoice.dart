/// Typy faktúr (SK legislatíva)
enum InvoiceType {
  issuedInvoice('issuedInvoice', 'Faktúra'),
  proformaInvoice('proformaInvoice', 'Zálohová faktúra'),
  creditNote('creditNote', 'Dobropis'),
  debitNote('debitNote', 'Ťarchopis');

  final String value;
  final String label;
  const InvoiceType(this.value, this.label);

  static InvoiceType fromString(String? s) {
    switch (s) {
      case 'proformaInvoice': return InvoiceType.proformaInvoice;
      case 'creditNote':      return InvoiceType.creditNote;
      case 'debitNote':       return InvoiceType.debitNote;
      default:                return InvoiceType.issuedInvoice;
    }
  }

  /// Prefix číslovania pre daný typ
  String get numberPrefix {
    switch (this) {
      case InvoiceType.issuedInvoice:   return 'FAK';
      case InvoiceType.proformaInvoice: return 'ZAL';
      case InvoiceType.creditNote:      return 'DOP';
      case InvoiceType.debitNote:       return 'TAR';
    }
  }
}

/// Stavy faktúry
enum InvoiceStatus {
  draft('draft', 'Koncept'),
  issued('issued', 'Vystavená'),
  sent('sent', 'Odoslaná'),
  paid('paid', 'Uhradená'),
  overdue('overdue', 'Po splatnosti'),
  cancelled('cancelled', 'Stornovaná');

  final String value;
  final String label;
  const InvoiceStatus(this.value, this.label);

  static InvoiceStatus fromString(String? s) {
    switch (s) {
      case 'issued':    return InvoiceStatus.issued;
      case 'sent':      return InvoiceStatus.sent;
      case 'paid':      return InvoiceStatus.paid;
      case 'overdue':   return InvoiceStatus.overdue;
      case 'cancelled': return InvoiceStatus.cancelled;
      default:          return InvoiceStatus.draft;
    }
  }

  bool get isEditable => this == InvoiceStatus.draft;
}

/// Spôsoby úhrady
enum PaymentMethod {
  transfer('transfer', 'Bankový prevod'),
  cash('cash', 'Hotovosť'),
  card('card', 'Platobná karta');

  final String value;
  final String label;
  const PaymentMethod(this.value, this.label);

  static PaymentMethod fromString(String? s) {
    switch (s) {
      case 'cash': return PaymentMethod.cash;
      case 'card': return PaymentMethod.card;
      default:     return PaymentMethod.transfer;
    }
  }
}

/// Hlavička faktúry – povinné náležitosti §71 Zák. č. 222/2004 Z.z. o DPH
class Invoice {
  final int? id;
  final String invoiceNumber;
  final InvoiceType invoiceType;

  // Dátumy
  final DateTime issueDate;    // Dátum vystavenia
  final DateTime taxDate;      // Dátum zdaniteľného plnenia (DUZP)
  final DateTime dueDate;      // Dátum splatnosti

  // Odberateľ (denormalizovaný v čase vystavenia)
  final int? customerId;
  final String? customerName;
  final String? customerAddress;
  final String? customerCity;
  final String? customerPostalCode;
  final String? customerIco;
  final String? customerDic;
  final String? customerIcDph;
  final String customerCountry;

  // Referencie
  final int? quoteId;
  final String? quoteNumber;
  final int? projectId;
  final String? projectName;

  // Platobné údaje
  final PaymentMethod paymentMethod;
  final String? variableSymbol;     // = číslo faktúry
  final String constantSymbol;      // zvyčajne 0308
  final String? specificSymbol;

  // Vypočítané sumy
  final double totalWithoutVat;
  final double totalVat;
  final double totalWithVat;

  final InvoiceStatus status;
  final String? notes;

  // Dobropis / Ťarchopis – referencia na originál
  final int? originalInvoiceId;
  final String? originalInvoiceNumber;

  // Bol dodávateľ platiteľom DPH v čase vystavenia?
  final bool isVatPayer;

  // Pay by Square QR string (uložený po prvom vygenerovaní)
  final String? qrString;

  final DateTime createdAt;

  Invoice({
    this.id,
    required this.invoiceNumber,
    this.invoiceType = InvoiceType.issuedInvoice,
    required this.issueDate,
    required this.taxDate,
    required this.dueDate,
    this.customerId,
    this.customerName,
    this.customerAddress,
    this.customerCity,
    this.customerPostalCode,
    this.customerIco,
    this.customerDic,
    this.customerIcDph,
    this.customerCountry = 'SK',
    this.quoteId,
    this.quoteNumber,
    this.projectId,
    this.projectName,
    this.paymentMethod = PaymentMethod.transfer,
    this.variableSymbol,
    this.constantSymbol = '0308',
    this.specificSymbol,
    this.totalWithoutVat = 0.0,
    this.totalVat = 0.0,
    this.totalWithVat = 0.0,
    this.status = InvoiceStatus.draft,
    this.notes,
    this.originalInvoiceId,
    this.originalInvoiceNumber,
    this.isVatPayer = true,
    this.qrString,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isEditable => status.isEditable;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_number': invoiceNumber,
      'invoice_type': invoiceType.value,
      'issue_date': issueDate.toIso8601String(),
      'tax_date': taxDate.toIso8601String(),
      'due_date': dueDate.toIso8601String(),
      'customer_id': customerId,
      'customer_name': customerName,
      'customer_address': customerAddress,
      'customer_city': customerCity,
      'customer_postal_code': customerPostalCode,
      'customer_ico': customerIco,
      'customer_dic': customerDic,
      'customer_ic_dph': customerIcDph,
      'customer_country': customerCountry,
      'quote_id': quoteId,
      'quote_number': quoteNumber,
      'project_id': projectId,
      'project_name': projectName,
      'payment_method': paymentMethod.value,
      'variable_symbol': variableSymbol,
      'constant_symbol': constantSymbol,
      'specific_symbol': specificSymbol,
      'total_without_vat': totalWithoutVat,
      'total_vat': totalVat,
      'total_with_vat': totalWithVat,
      'status': status.value,
      'notes': notes,
      'original_invoice_id': originalInvoiceId,
      'original_invoice_number': originalInvoiceNumber,
      'is_vat_payer': isVatPayer ? 1 : 0,
      'qr_string': qrString,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Invoice.fromMap(Map<String, dynamic> map) {
    return Invoice(
      id: map['id'] as int?,
      invoiceNumber: map['invoice_number'] as String,
      invoiceType: InvoiceType.fromString(map['invoice_type'] as String?),
      issueDate: DateTime.parse(map['issue_date'] as String),
      taxDate: DateTime.parse(map['tax_date'] as String),
      dueDate: DateTime.parse(map['due_date'] as String),
      customerId: map['customer_id'] as int?,
      customerName: map['customer_name'] as String?,
      customerAddress: map['customer_address'] as String?,
      customerCity: map['customer_city'] as String?,
      customerPostalCode: map['customer_postal_code'] as String?,
      customerIco: map['customer_ico'] as String?,
      customerDic: map['customer_dic'] as String?,
      customerIcDph: map['customer_ic_dph'] as String?,
      customerCountry: map['customer_country'] as String? ?? 'SK',
      quoteId: map['quote_id'] as int?,
      quoteNumber: map['quote_number'] as String?,
      projectId: map['project_id'] as int?,
      projectName: map['project_name'] as String?,
      paymentMethod: PaymentMethod.fromString(map['payment_method'] as String?),
      variableSymbol: map['variable_symbol'] as String?,
      constantSymbol: map['constant_symbol'] as String? ?? '0308',
      specificSymbol: map['specific_symbol'] as String?,
      totalWithoutVat: (map['total_without_vat'] as num?)?.toDouble() ?? 0.0,
      totalVat: (map['total_vat'] as num?)?.toDouble() ?? 0.0,
      totalWithVat: (map['total_with_vat'] as num?)?.toDouble() ?? 0.0,
      status: InvoiceStatus.fromString(map['status'] as String?),
      notes: map['notes'] as String?,
      originalInvoiceId: map['original_invoice_id'] as int?,
      originalInvoiceNumber: map['original_invoice_number'] as String?,
      isVatPayer: (map['is_vat_payer'] as int?) == 1,
      qrString: map['qr_string'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
    );
  }

  Invoice copyWith({
    int? id,
    String? invoiceNumber,
    InvoiceType? invoiceType,
    DateTime? issueDate,
    DateTime? taxDate,
    DateTime? dueDate,
    int? customerId,
    String? customerName,
    String? customerAddress,
    String? customerCity,
    String? customerPostalCode,
    String? customerIco,
    String? customerDic,
    String? customerIcDph,
    String? customerCountry,
    int? quoteId,
    String? quoteNumber,
    int? projectId,
    String? projectName,
    PaymentMethod? paymentMethod,
    String? variableSymbol,
    String? constantSymbol,
    String? specificSymbol,
    double? totalWithoutVat,
    double? totalVat,
    double? totalWithVat,
    InvoiceStatus? status,
    String? notes,
    int? originalInvoiceId,
    String? originalInvoiceNumber,
    bool? isVatPayer,
    String? qrString,
    DateTime? createdAt,
  }) {
    return Invoice(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      invoiceType: invoiceType ?? this.invoiceType,
      issueDate: issueDate ?? this.issueDate,
      taxDate: taxDate ?? this.taxDate,
      dueDate: dueDate ?? this.dueDate,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerAddress: customerAddress ?? this.customerAddress,
      customerCity: customerCity ?? this.customerCity,
      customerPostalCode: customerPostalCode ?? this.customerPostalCode,
      customerIco: customerIco ?? this.customerIco,
      customerDic: customerDic ?? this.customerDic,
      customerIcDph: customerIcDph ?? this.customerIcDph,
      customerCountry: customerCountry ?? this.customerCountry,
      quoteId: quoteId ?? this.quoteId,
      quoteNumber: quoteNumber ?? this.quoteNumber,
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      variableSymbol: variableSymbol ?? this.variableSymbol,
      constantSymbol: constantSymbol ?? this.constantSymbol,
      specificSymbol: specificSymbol ?? this.specificSymbol,
      totalWithoutVat: totalWithoutVat ?? this.totalWithoutVat,
      totalVat: totalVat ?? this.totalVat,
      totalWithVat: totalWithVat ?? this.totalWithVat,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      originalInvoiceId: originalInvoiceId ?? this.originalInvoiceId,
      originalInvoiceNumber: originalInvoiceNumber ?? this.originalInvoiceNumber,
      isVatPayer: isVatPayer ?? this.isVatPayer,
      qrString: qrString ?? this.qrString,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Jedna položka faktúry
class InvoiceItem {
  final int? id;
  final int invoiceId;
  final String? productUniqueId;
  final String? productName;
  final double qty;
  final String unit;
  final double unitPrice;       // Cena za jednotku bez DPH
  final int discountPercent;
  /// Sadzba DPH platná od 1.1.2025: 23 | 19 | 5 | 0
  final int vatPercent;
  final String itemType;        // Tovar | Služba | Paleta | Doprava
  final String? description;

  InvoiceItem({
    this.id,
    required this.invoiceId,
    this.productUniqueId,
    this.productName,
    required this.qty,
    required this.unit,
    required this.unitPrice,
    this.discountPercent = 0,
    this.vatPercent = 23,
    this.itemType = 'Tovar',
    this.description,
  });

  /// Základ DPH pre riadok (bez DPH)
  double get lineBase {
    return (unitPrice * qty * (1 - discountPercent / 100) * 100).round() / 100;
  }

  /// Suma DPH pre riadok
  double get lineVat {
    return (lineBase * vatPercent / 100 * 100).round() / 100;
  }

  /// Celková suma riadku vrátane DPH
  double get lineTotal {
    return (lineBase * (1 + vatPercent / 100) * 100).round() / 100;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_id': invoiceId,
      'product_unique_id': productUniqueId,
      'product_name': productName,
      'qty': qty,
      'unit': unit,
      'unit_price': unitPrice,
      'discount_percent': discountPercent,
      'vat_percent': vatPercent,
      'item_type': itemType,
      'description': description,
    };
  }

  factory InvoiceItem.fromMap(Map<String, dynamic> map) {
    return InvoiceItem(
      id: map['id'] as int?,
      invoiceId: map['invoice_id'] as int,
      productUniqueId: map['product_unique_id'] as String?,
      productName: map['product_name'] as String?,
      qty: (map['qty'] as num).toDouble(),
      unit: map['unit'] as String,
      unitPrice: (map['unit_price'] as num).toDouble(),
      discountPercent: (map['discount_percent'] as num?)?.toInt() ?? 0,
      vatPercent: (map['vat_percent'] as num?)?.toInt() ?? 23,
      itemType: map['item_type'] as String? ?? 'Tovar',
      description: map['description'] as String?,
    );
  }

  InvoiceItem copyWith({
    int? id,
    int? invoiceId,
    String? productUniqueId,
    String? productName,
    double? qty,
    String? unit,
    double? unitPrice,
    int? discountPercent,
    int? vatPercent,
    String? itemType,
    String? description,
  }) {
    return InvoiceItem(
      id: id ?? this.id,
      invoiceId: invoiceId ?? this.invoiceId,
      productUniqueId: productUniqueId ?? this.productUniqueId,
      productName: productName ?? this.productName,
      qty: qty ?? this.qty,
      unit: unit ?? this.unit,
      unitPrice: unitPrice ?? this.unitPrice,
      discountPercent: discountPercent ?? this.discountPercent,
      vatPercent: vatPercent ?? this.vatPercent,
      itemType: itemType ?? this.itemType,
      description: description ?? this.description,
    );
  }
}

/// Rekapitulácia DPH pre jeden základ (pre PDF + zobrazenie)
class VatSummaryRow {
  final int vatPercent;
  final double base;
  final double vat;
  double get total => base + vat;

  VatSummaryRow({required this.vatPercent, required this.base, required this.vat});

  VatSummaryRow operator +(VatSummaryRow other) {
    return VatSummaryRow(
      vatPercent: vatPercent,
      base: (base + other.base * 100).round() / 100,
      vat: (vat + other.vat * 100).round() / 100,
    );
  }
}

/// Vypočíta rekapituláciu DPH pre zoznam položiek
Map<int, VatSummaryRow> buildVatSummary(List<InvoiceItem> items) {
  final Map<int, VatSummaryRow> summary = {};
  for (final item in items) {
    final base = item.lineBase;
    final vat  = item.lineVat;
    final key  = item.vatPercent;
    if (summary.containsKey(key)) {
      final existing = summary[key]!;
      summary[key] = VatSummaryRow(
        vatPercent: key,
        base: ((existing.base + base) * 100).round() / 100,
        vat:  ((existing.vat  + vat)  * 100).round() / 100,
      );
    } else {
      summary[key] = VatSummaryRow(vatPercent: key, base: base, vat: vat);
    }
  }
  return summary;
}
