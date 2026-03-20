/// Pravidlo rozšírenej cenotvorby – viazané na konkrétny produkt (1:N).
///
/// Systém vyberie pravidlo s najnižšou cenou, ktoré spĺňa všetky podmienky:
///  - množstvo je v rozsahu [quantityFrom, quantityTo]
///  - customerGroup sa zhoduje (ak zadaný)
///  - aktuálny čas je v intervale [validFrom, validTo]
class PricingRule {
  final int? id;
  final String productUniqueId;

  /// Ľudsky čitateľný názov pravidla, napr. "Veľkoobchod", "Akcia jún".
  final String? label;

  /// Špeciálna predajná cena s DPH.
  final double price;

  /// Minimálne množstvo (vrátane), od ktorého pravidlo platí. Default 1.
  final double quantityFrom;

  /// Maximálne množstvo (vrátane). Null = bez hornej hranice.
  final double? quantityTo;

  /// Skupina zákazníkov, napr. "retail", "wholesale", "vip". Null = pre všetkých.
  final String? customerGroup;

  /// Začiatok platnosti akcie. Null = platí vždy od začiatku.
  final DateTime? validFrom;

  /// Koniec platnosti akcie. Null = platí vždy do konca.
  final DateTime? validTo;

  const PricingRule({
    this.id,
    required this.productUniqueId,
    this.label,
    required this.price,
    this.quantityFrom = 1,
    this.quantityTo,
    this.customerGroup,
    this.validFrom,
    this.validTo,
  })  : assert(price >= 0, 'price must be >= 0'),
        assert(quantityFrom >= 0, 'quantityFrom must be >= 0');

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'product_unique_id': productUniqueId,
      'label': label,
      'price': price,
      'quantity_from': quantityFrom,
      'quantity_to': quantityTo,
      'customer_group': customerGroup,
      'valid_from': validFrom?.toIso8601String(),
      'valid_to': validTo?.toIso8601String(),
    };
  }

  factory PricingRule.fromMap(Map<String, dynamic> map) {
    return PricingRule(
      id: map['id'] as int?,
      productUniqueId: map['product_unique_id'] as String? ?? '',
      label: map['label'] as String?,
      price: (map['price'] as num?)?.toDouble() ?? 0,
      quantityFrom: (map['quantity_from'] as num?)?.toDouble() ?? 1,
      quantityTo: (map['quantity_to'] as num?)?.toDouble(),
      customerGroup: map['customer_group'] as String?,
      validFrom: map['valid_from'] != null
          ? DateTime.tryParse(map['valid_from'] as String)
          : null,
      validTo: map['valid_to'] != null
          ? DateTime.tryParse(map['valid_to'] as String)
          : null,
    );
  }

  PricingRule copyWith({
    int? id,
    String? productUniqueId,
    String? label,
    double? price,
    double? quantityFrom,
    double? quantityTo,
    String? customerGroup,
    DateTime? validFrom,
    DateTime? validTo,
    bool clearQuantityTo = false,
    bool clearCustomerGroup = false,
    bool clearValidFrom = false,
    bool clearValidTo = false,
    bool clearLabel = false,
  }) {
    return PricingRule(
      id: id ?? this.id,
      productUniqueId: productUniqueId ?? this.productUniqueId,
      label: clearLabel ? null : (label ?? this.label),
      price: price ?? this.price,
      quantityFrom: quantityFrom ?? this.quantityFrom,
      quantityTo: clearQuantityTo ? null : (quantityTo ?? this.quantityTo),
      customerGroup: clearCustomerGroup ? null : (customerGroup ?? this.customerGroup),
      validFrom: clearValidFrom ? null : (validFrom ?? this.validFrom),
      validTo: clearValidTo ? null : (validTo ?? this.validTo),
    );
  }

  /// Ľudsky čitateľný popis pravidla pre zobrazenie v UI.
  String get displaySummary {
    final parts = <String>[];
    if (quantityTo != null) {
      parts.add('${quantityFrom.toStringAsFixed(0)}–${quantityTo!.toStringAsFixed(0)} ks');
    } else {
      parts.add('≥ ${quantityFrom.toStringAsFixed(0)} ks');
    }
    if (customerGroup != null && customerGroup!.isNotEmpty) {
      parts.add(customerGroup!);
    }
    if (validFrom != null || validTo != null) {
      final from = validFrom != null
          ? '${validFrom!.day}.${validFrom!.month}.${validFrom!.year}'
          : '∞';
      final to = validTo != null
          ? '${validTo!.day}.${validTo!.month}.${validTo!.year}'
          : '∞';
      parts.add('$from – $to');
    }
    return parts.join(' · ');
  }

  @override
  String toString() =>
      'PricingRule(id: $id, product: $productUniqueId, price: $price, qtyFrom: $quantityFrom)';
}
