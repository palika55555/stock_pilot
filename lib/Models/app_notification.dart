/// Typ udalosti notifikácie (príjemky, zásoby, ceny).
enum NotificationType {
  receiptSubmitted('RECEIPT_SUBMITTED'),
  receiptApproved('RECEIPT_APPROVED'),
  receiptRejected('RECEIPT_REJECTED'),
  receiptRecalled('RECEIPT_RECALLED'),
  receiptReversed('RECEIPT_REVERSED'),
  receiptPendingLong('RECEIPT_PENDING_LONG'),
  stockLow('STOCK_LOW'),
  priceChange('PRICE_CHANGE');

  final String value;
  const NotificationType(this.value);

  static NotificationType? fromString(String? s) {
    if (s == null) return null;
    for (final e in NotificationType.values) {
      if (e.value == s) return e;
    }
    return null;
  }

  bool get isReceiptRelated =>
      this == receiptSubmitted ||
      this == receiptApproved ||
      this == receiptRejected ||
      this == receiptRecalled ||
      this == receiptReversed ||
      this == receiptPendingLong;
  bool get isStockRelated => this == stockLow;
}

/// Jedna in-app notifikácia (uložená v lokálnej DB).
class AppNotification {
  final int? id;
  final String type;
  final String title;
  final String body;
  final int? receiptId;
  final String? receiptNumber;
  final String? extraData; // JSON: rejection_reason, product_name, etc.
  final DateTime createdAt;
  final bool read;
  final String? targetUsername; // komu je určená (null = všetci / in-app pre všetkých)

  const AppNotification({
    this.id,
    required this.type,
    required this.title,
    required this.body,
    this.receiptId,
    this.receiptNumber,
    this.extraData,
    required this.createdAt,
    this.read = false,
    this.targetUsername,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'body': body,
      'receipt_id': receiptId,
      'receipt_number': receiptNumber,
      'extra_data': extraData,
      'created_at': createdAt.toIso8601String(),
      'read': read ? 1 : 0,
      'target_username': targetUsername,
    };
  }

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'] as int?,
      type: map['type'] as String? ?? 'RECEIPT_SUBMITTED',
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      receiptId: map['receipt_id'] as int?,
      receiptNumber: map['receipt_number'] as String?,
      extraData: map['extra_data'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      read: (map['read'] as int?) == 1,
      targetUsername: map['target_username'] as String?,
    );
  }

  AppNotification copyWith({
    int? id,
    String? type,
    String? title,
    String? body,
    int? receiptId,
    String? receiptNumber,
    String? extraData,
    DateTime? createdAt,
    bool? read,
    String? targetUsername,
  }) {
    return AppNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      receiptId: receiptId ?? this.receiptId,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      extraData: extraData ?? this.extraData,
      createdAt: createdAt ?? this.createdAt,
      read: read ?? this.read,
      targetUsername: targetUsername ?? this.targetUsername,
    );
  }
}
