/// Stav výdajky: rozpracovaný (draft), vykázaná, schválená alebo stornovaná.
enum StockOutStatus {
  rozpracovany('rozpracovany'),
  vykazana('vykazana'),
  schvalena('schvalena'),
  stornovana('stornovana');

  final String value;
  const StockOutStatus(this.value);

  static StockOutStatus fromString(String? s) {
    if (s == 'schvalena') return StockOutStatus.schvalena;
    if (s == 'rozpracovany') return StockOutStatus.rozpracovany;
    if (s == 'stornovana') return StockOutStatus.stornovana;
    return StockOutStatus.vykazana;
  }
}

/// Typ výdaja (issue type) – účel výdajky.
enum StockOutIssueType {
  sale('SALE', 'Predaj'),
  consumption('CONS', 'Interná spotreba'),
  production('PROD', 'Výroba'),
  writeOff('SCRP', 'Odpis / Likvidácia'),
  returnToSupplier('RETURN', 'Reklamácia / Vrátenie'),
  transfer('TRAN', 'Medziskladový prevod');

  final String value;
  final String label;
  const StockOutIssueType(this.value, this.label);

  static StockOutIssueType fromString(String? s) {
    if (s == null || s.isEmpty) return StockOutIssueType.sale;
    for (final t in StockOutIssueType.values) {
      if (t.value == s) return t;
    }
    return StockOutIssueType.sale;
  }

  /// Pri odpise je povinný dôvod.
  bool get requiresWriteOffReason => this == StockOutIssueType.writeOff;
}

/// Hlavička výdajky (Stock Out / Issue Note) – OBERON: Vydajka (CisloDokladu, IDSkladu, Datum, DruhPohybu, JeVysporiadana, Odberatel).
class StockOut {
  final int? id;
  final String documentNumber;
  final DateTime createdAt;
  final String? recipientName;
  final String? notes;
  final String? username;
  final StockOutStatus status;
  /// Sklad, z ktorého sa vydáva (výdajka je vždy z jedného skladu).
  final int? warehouseId;
  /// Ak true (naviazaná faktúra), doklad je v UI uzamknutý (ReadOnly).
  final bool jeVysporiadana;
  /// 0 = výdaj za 0 % DPH, null = štandardná sadzba
  final int? vatRate;
  /// Typ výdaja: predaj, spotreba, výroba, odpis, reklamácia, prevod
  final StockOutIssueType issueType;
  /// Povinné pri type SCRP (odpis) – dôvod: expirácia, poškodenie, krádež...
  final String? writeOffReason;
  /// Pri prevodke: id príjemky (príjem do cieľového skladu).
  final int? linkedReceiptId;

  StockOut({
    this.id,
    required this.documentNumber,
    required this.createdAt,
    this.recipientName,
    this.notes,
    this.username,
    this.status = StockOutStatus.vykazana,
    this.warehouseId,
    this.jeVysporiadana = false,
    this.vatRate,
    this.issueType = StockOutIssueType.sale,
    this.writeOffReason,
    this.linkedReceiptId,
  });

  bool get isZeroVat => vatRate == 0;
  bool get isWriteOff => issueType == StockOutIssueType.writeOff;

  /// Vysporiadanú výdajku nie je možné upravovať (ReadOnly).
  bool get isEditable =>
      !jeVysporiadana &&
      status != StockOutStatus.schvalena &&
      status != StockOutStatus.stornovana;
  bool get isApproved => status == StockOutStatus.schvalena;
  bool get isDraft => status == StockOutStatus.rozpracovany;
  bool get isStorned => status == StockOutStatus.stornovana;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'document_number': documentNumber,
      'created_at': createdAt.toIso8601String(),
      'recipient_name': recipientName,
      'notes': notes,
      'username': username,
      'status': status.value,
      'warehouse_id': warehouseId,
      'je_vysporiadana': jeVysporiadana ? 1 : 0,
      'vat_rate': vatRate,
      'issue_type': issueType.value,
      'write_off_reason': writeOffReason,
      'linked_receipt_id': linkedReceiptId,
    };
  }

  factory StockOut.fromMap(Map<String, dynamic> map) {
    return StockOut(
      id: map['id'] as int?,
      documentNumber: map['document_number'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      recipientName: map['recipient_name'] as String?,
      notes: map['notes'] as String?,
      username: map['username'] as String?,
      status: StockOutStatus.fromString(map['status'] as String?),
      warehouseId: map['warehouse_id'] as int?,
      jeVysporiadana: (map['je_vysporiadana'] as int?) == 1,
      vatRate: map['vat_rate'] as int?,
      issueType: StockOutIssueType.fromString(map['issue_type'] as String?),
      writeOffReason: map['write_off_reason'] as String?,
      linkedReceiptId: map['linked_receipt_id'] as int?,
    );
  }

  StockOut copyWith({
    int? id,
    String? documentNumber,
    DateTime? createdAt,
    String? recipientName,
    String? notes,
    String? username,
    StockOutStatus? status,
    int? warehouseId,
    bool? jeVysporiadana,
    int? vatRate,
    StockOutIssueType? issueType,
    String? writeOffReason,
    int? linkedReceiptId,
  }) {
    return StockOut(
      id: id ?? this.id,
      documentNumber: documentNumber ?? this.documentNumber,
      createdAt: createdAt ?? this.createdAt,
      recipientName: recipientName ?? this.recipientName,
      notes: notes ?? this.notes,
      username: username ?? this.username,
      status: status ?? this.status,
      warehouseId: warehouseId ?? this.warehouseId,
      jeVysporiadana: jeVysporiadana ?? this.jeVysporiadana,
      vatRate: vatRate ?? this.vatRate,
      issueType: issueType ?? this.issueType,
      writeOffReason: writeOffReason ?? this.writeOffReason,
      linkedReceiptId: linkedReceiptId ?? this.linkedReceiptId,
    );
  }
}

/// Položka výdajky.
class StockOutItem {
  final int? id;
  final int stockOutId;
  final String productUniqueId;
  final String? productName;
  final String? plu;
  final int qty;
  final String unit;
  final double unitPrice;
  /// Číslo šarže / lot číslo (voliteľné).
  final String? batchNumber;
  /// Dátum expirácie vo formáte ISO 8601 "YYYY-MM-DD" (voliteľné).
  final String? expiryDate;

  StockOutItem({
    this.id,
    required this.stockOutId,
    required this.productUniqueId,
    this.productName,
    this.plu,
    required this.qty,
    required this.unit,
    required this.unitPrice,
    this.batchNumber,
    this.expiryDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'stock_out_id': stockOutId,
      'product_unique_id': productUniqueId,
      'product_name': productName,
      'plu': plu,
      'qty': qty,
      'unit': unit,
      'unit_price': _roundPrice(unitPrice),
      'batch_number': batchNumber,
      'expiry_date': expiryDate,
    };
  }

  static double _roundPrice(double value) {
    return (value * 100000).round() / 100000;
  }

  factory StockOutItem.fromMap(Map<String, dynamic> map) {
    return StockOutItem(
      id: map['id'] as int?,
      stockOutId: map['stock_out_id'] as int,
      productUniqueId: map['product_unique_id'] as String,
      productName: map['product_name'] as String?,
      plu: map['plu'] as String?,
      qty: map['qty'] as int,
      unit: map['unit'] as String,
      unitPrice: (map['unit_price'] as num).toDouble(),
      batchNumber: map['batch_number'] as String?,
      expiryDate: map['expiry_date'] as String?,
    );
  }
}
