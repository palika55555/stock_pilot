/// Stav príjemky: draft, pending (odoslaný na schválenie), approved, rejected, cancelled, reversed.
/// Legacy: rozpracovany=draft, vykazana=reported (treated as draft for approval flow), schvalena=approved.
enum InboundReceiptStatus {
  rozpracovany('rozpracovany'),
  vykazana('vykazana'),
  pending('pending'),
  schvalena('schvalena'),
  rejected('rejected'),
  cancelled('cancelled'),
  reversed('reversed');

  final String value;
  const InboundReceiptStatus(this.value);

  static InboundReceiptStatus fromString(String? s) {
    if (s == null) return InboundReceiptStatus.vykazana;
    switch (s) {
      case 'schvalena': return InboundReceiptStatus.schvalena;
      case 'rozpracovany': return InboundReceiptStatus.rozpracovany;
      case 'pending': return InboundReceiptStatus.pending;
      case 'rejected': return InboundReceiptStatus.rejected;
      case 'cancelled': return InboundReceiptStatus.cancelled;
      case 'reversed': return InboundReceiptStatus.reversed;
      default: return InboundReceiptStatus.vykazana;
    }
  }

  /// Pre reporty a UI: či je stav „čakajúci“ (odoslaný na schválenie).
  bool get isPending => this == InboundReceiptStatus.pending;
  bool get isRejected => this == InboundReceiptStatus.rejected;
  bool get isCancelled => this == InboundReceiptStatus.cancelled;
  bool get isReversed => this == InboundReceiptStatus.reversed;
}

/// Druh pohybu príjemky (bežná príjemka, prevodka, s obstarávacími nákladmi...).
class ReceiptMovementType {
  final int? id;
  final String code;
  final String name;

  ReceiptMovementType({this.id, required this.code, required this.name});

  Map<String, dynamic> toMap() => {
        'id': id,
        'code': code,
        'name': name,
      };

  factory ReceiptMovementType.fromMap(Map<String, dynamic> map) =>
      ReceiptMovementType(
        id: map['id'] as int?,
        code: map['code'] as String? ?? 'STANDARD',
        name: map['name'] as String? ?? 'Bežná príjemka',
      );
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
  /// Sklad, do ktorého sa tovar prijíma (povinné).
  final int? warehouseId;
  /// Pri prevodke: sklad, z ktorého sa tovar odoberá.
  final int? sourceWarehouseId;
  /// Druh pohybu (kód z číselníka receipt_movement_types).
  final String movementTypeCode;
  /// Vysporiadaná = ku príjemke bol zaevidovaný daňový doklad alebo sa neočakáva žiadny.
  final bool isSettled;
  /// Pri prevodke: id výdajky (výdaj zo zdrojového skladu).
  final int? linkedStockOutId;
  /// Pri príjemke s obstarávacími nákladmi: spôsob rozpočítania (by_value, by_quantity, by_weight, manual).
  final String? costDistributionMethod;
  /// Odoslanie na schválenie
  final DateTime? submittedAt;
  /// Schválenie
  final DateTime? approvedAt;
  final String? approverUsername;
  final String? approverNote;
  /// Zamietnutie
  final DateTime? rejectedAt;
  final String? rejectionReason;
  /// Stornovanie
  final DateTime? reversedAt;
  final String? reversedByUsername;
  final String? reverseReason;
  /// Či už bolo množstvo pričítané na sklad (aby sa neaplikovalo dvakrát).
  final bool stockApplied;

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
    this.warehouseId,
    this.sourceWarehouseId,
    this.movementTypeCode = 'STANDARD',
    this.isSettled = false,
    this.linkedStockOutId,
    this.costDistributionMethod,
    this.submittedAt,
    this.approvedAt,
    this.approverUsername,
    this.approverNote,
    this.rejectedAt,
    this.rejectionReason,
    this.reversedAt,
    this.reversedByUsername,
    this.reverseReason,
    this.stockApplied = false,
  });

  bool get isEditable =>
      status != InboundReceiptStatus.schvalena &&
      status != InboundReceiptStatus.reversed &&
      status != InboundReceiptStatus.cancelled;
  bool get isApproved => status == InboundReceiptStatus.schvalena;
  bool get isDraft => status == InboundReceiptStatus.rozpracovany;
  bool get isPendingApproval => status == InboundReceiptStatus.pending;
  bool get isRejected => status == InboundReceiptStatus.rejected;
  bool get isReversed => status == InboundReceiptStatus.reversed;

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
      'warehouse_id': warehouseId,
      'source_warehouse_id': sourceWarehouseId,
      'movement_type_code': movementTypeCode,
      'je_vysporiadana': isSettled ? 1 : 0,
      'linked_stock_out_id': linkedStockOutId,
      'cost_distribution_method': costDistributionMethod,
      'submitted_at': submittedAt?.toIso8601String(),
      'approved_at': approvedAt?.toIso8601String(),
      'approver_username': approverUsername,
      'approver_note': approverNote,
      'rejected_at': rejectedAt?.toIso8601String(),
      'rejection_reason': rejectionReason,
      'reversed_at': reversedAt?.toIso8601String(),
      'reversed_by_username': reversedByUsername,
      'reverse_reason': reverseReason,
      'stock_applied': stockApplied ? 1 : 0,
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
      warehouseId: map['warehouse_id'] as int?,
      sourceWarehouseId: map['source_warehouse_id'] as int?,
      movementTypeCode: map['movement_type_code'] as String? ?? 'STANDARD',
      isSettled: (map['je_vysporiadana'] as int?) == 1,
      linkedStockOutId: map['linked_stock_out_id'] as int?,
      costDistributionMethod: map['cost_distribution_method'] as String?,
      submittedAt: map['submitted_at'] != null ? DateTime.tryParse(map['submitted_at'] as String) : null,
      approvedAt: map['approved_at'] != null ? DateTime.tryParse(map['approved_at'] as String) : null,
      approverUsername: map['approver_username'] as String?,
      approverNote: map['approver_note'] as String?,
      rejectedAt: map['rejected_at'] != null ? DateTime.tryParse(map['rejected_at'] as String) : null,
      rejectionReason: map['rejection_reason'] as String?,
      reversedAt: map['reversed_at'] != null ? DateTime.tryParse(map['reversed_at'] as String) : null,
      reversedByUsername: map['reversed_by_username'] as String?,
      reverseReason: map['reverse_reason'] as String?,
      stockApplied: (map['stock_applied'] as int?) == 1,
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
    int? warehouseId,
    int? sourceWarehouseId,
    String? movementTypeCode,
    bool? isSettled,
    int? linkedStockOutId,
    String? costDistributionMethod,
    DateTime? submittedAt,
    DateTime? approvedAt,
    String? approverUsername,
    String? approverNote,
    DateTime? rejectedAt,
    String? rejectionReason,
    DateTime? reversedAt,
    String? reversedByUsername,
    String? reverseReason,
    bool? stockApplied,
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
      warehouseId: warehouseId ?? this.warehouseId,
      sourceWarehouseId: sourceWarehouseId ?? this.sourceWarehouseId,
      movementTypeCode: movementTypeCode ?? this.movementTypeCode,
      isSettled: isSettled ?? this.isSettled,
      linkedStockOutId: linkedStockOutId ?? this.linkedStockOutId,
      costDistributionMethod: costDistributionMethod ?? this.costDistributionMethod,
      submittedAt: submittedAt ?? this.submittedAt,
      approvedAt: approvedAt ?? this.approvedAt,
      approverUsername: approverUsername ?? this.approverUsername,
      approverNote: approverNote ?? this.approverNote,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      reversedAt: reversedAt ?? this.reversedAt,
      reversedByUsername: reversedByUsername ?? this.reversedByUsername,
      reverseReason: reverseReason ?? this.reverseReason,
      stockApplied: stockApplied ?? this.stockApplied,
    );
  }
}

/// Obstarávací náklad pri príjemke (doprava, clo, balné, poistenie, iné).
class ReceiptAcquisitionCost {
  final int? id;
  final int receiptId;
  final String costType;
  final String? description;
  final double amountWithoutVat;
  final int vatPercent;
  final double amountWithVat;
  final String? costSupplierName;
  final String? documentNumber;
  final int sortOrder;

  ReceiptAcquisitionCost({
    this.id,
    required this.receiptId,
    required this.costType,
    this.description,
    this.amountWithoutVat = 0,
    this.vatPercent = 0,
    this.amountWithVat = 0,
    this.costSupplierName,
    this.documentNumber,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'receipt_id': receiptId,
      'cost_type': costType,
      'description': description,
      'amount_without_vat': (amountWithoutVat * 100000).round() / 100000,
      'vat_percent': vatPercent,
      'amount_with_vat': (amountWithVat * 100000).round() / 100000,
      'cost_supplier_name': costSupplierName,
      'document_number': documentNumber,
      'sort_order': sortOrder,
    };
  }

  factory ReceiptAcquisitionCost.fromMap(Map<String, dynamic> map) {
    return ReceiptAcquisitionCost(
      id: map['id'] as int?,
      receiptId: map['receipt_id'] as int,
      costType: map['cost_type'] as String? ?? 'Iné',
      description: map['description'] as String?,
      amountWithoutVat: (map['amount_without_vat'] as num?)?.toDouble() ?? 0,
      vatPercent: (map['vat_percent'] as num?)?.toInt() ?? 0,
      amountWithVat: (map['amount_with_vat'] as num?)?.toDouble() ?? 0,
      costSupplierName: map['cost_supplier_name'] as String?,
      documentNumber: map['document_number'] as String?,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
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
  /// Pri príjemke s obstarávacími nákladmi: alokovaná časť obstarávacích nákladov na túto položku (v EUR s DPH).
  final double allocatedCost;
  /// Číslo šarže / lot číslo (voliteľné).
  final String? batchNumber;
  /// Dátum expirácie vo formáte ISO 8601 "YYYY-MM-DD" (voliteľné).
  final String? expiryDate;

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
    this.allocatedCost = 0,
    this.batchNumber,
    this.expiryDate,
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
      'allocated_cost': _roundPrice(allocatedCost),
      'batch_number': batchNumber,
      'expiry_date': expiryDate,
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
      allocatedCost: (map['allocated_cost'] as num?)?.toDouble() ?? 0,
      batchNumber: map['batch_number'] as String?,
      expiryDate: map['expiry_date'] as String?,
    );
  }
}
