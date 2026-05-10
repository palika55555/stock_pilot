/// Paleta – výstup z výroby, evidovaná cez QR (STOCKPILOT_PALLET:id).
enum PalletStatus {
  naSklade('Na sklade'),
  uZakaznika('U zákazníka'),
  predane('Predané'),
  expedovane('Expedované'),
  rezervovane('Rezervované'),
  vratenaPrazdna('Vrátená prázdna');

  const PalletStatus(this.label);
  final String label;

  bool get isSold => this == PalletStatus.predane || this == PalletStatus.expedovane;
  bool get atCustomer => this == PalletStatus.uZakaznika;

  static PalletStatus fromString(String? v) {
    if (v == null) return PalletStatus.naSklade;
    return PalletStatus.values.firstWhere(
      (e) => e.label == v,
      orElse: () => PalletStatus.naSklade,
    );
  }
}

class Pallet {
  final int? id;
  final int batchId;
  final String productType;
  final int quantity;
  final int? customerId;
  final PalletStatus status;
  final String? createdAt;
  final String? soldAt;
  final String? saleNote;

  Pallet({
    this.id,
    required this.batchId,
    required this.productType,
    required this.quantity,
    this.customerId,
    this.status = PalletStatus.naSklade,
    this.createdAt,
    this.soldAt,
    this.saleNote,
  });

  static String qrPayload(int palletId) => 'STOCKPILOT_PALLET:$palletId';

  static int? parseIdFromQr(String qrContent) {
    const prefix = 'STOCKPILOT_PALLET:';
    if (!qrContent.startsWith(prefix)) return null;
    return int.tryParse(qrContent.substring(prefix.length).trim());
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'batch_id': batchId,
      'product_type': productType,
      'quantity': quantity,
      'customer_id': customerId,
      'status': status.label,
      'created_at': createdAt,
      'sold_at': soldAt,
      'sale_note': saleNote,
    };
  }

  static Pallet fromMap(Map<String, Object?> map) {
    return Pallet(
      id: map['id'] as int?,
      batchId: map['batch_id'] as int,
      productType: map['product_type'] as String,
      quantity: map['quantity'] as int? ?? 0,
      customerId: map['customer_id'] as int?,
      status: PalletStatus.fromString(map['status'] as String?),
      createdAt: map['created_at'] as String?,
      soldAt: map['sold_at'] as String?,
      saleNote: map['sale_note'] as String?,
    );
  }

  Pallet copyWith({
    int? id,
    int? batchId,
    String? productType,
    int? quantity,
    int? customerId,
    bool clearCustomer = false,
    PalletStatus? status,
    String? createdAt,
    String? soldAt,
    bool clearSoldAt = false,
    String? saleNote,
    bool clearSaleNote = false,
  }) {
    return Pallet(
      id: id ?? this.id,
      batchId: batchId ?? this.batchId,
      productType: productType ?? this.productType,
      quantity: quantity ?? this.quantity,
      customerId: clearCustomer ? null : (customerId ?? this.customerId),
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      soldAt: clearSoldAt ? null : (soldAt ?? this.soldAt),
      saleNote: clearSaleNote ? null : (saleNote ?? this.saleNote),
    );
  }
}
