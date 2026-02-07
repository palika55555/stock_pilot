/// Model pre prepravu
class Transport {
  final int? id;
  final String origin;
  final String destination;
  final double distance; // v kilometroch
  final bool isRoundTrip; // cesta tam aj späť
  final double pricePerKm;
  final double? fuelConsumption; // spotreba na 100 km
  final double? fuelPrice; // cena paliva za liter
  final double baseCost;
  final double fuelCost;
  final double totalCost;
  final DateTime createdAt;
  final String? notes;

  Transport({
    this.id,
    required this.origin,
    required this.destination,
    required this.distance,
    this.isRoundTrip = false,
    required this.pricePerKm,
    this.fuelConsumption,
    this.fuelPrice,
    required this.baseCost,
    required this.fuelCost,
    required this.totalCost,
    required this.createdAt,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'origin': origin,
      'destination': destination,
      'distance': distance,
      'is_round_trip': isRoundTrip ? 1 : 0,
      'price_per_km': pricePerKm,
      'fuel_consumption': fuelConsumption,
      'fuel_price': fuelPrice,
      'base_cost': baseCost,
      'fuel_cost': fuelCost,
      'total_cost': totalCost,
      'created_at': createdAt.toIso8601String(),
      'notes': notes,
    };
  }

  factory Transport.fromMap(Map<String, dynamic> map) {
    return Transport(
      id: map['id'] as int?,
      origin: map['origin'] as String,
      destination: map['destination'] as String,
      distance: (map['distance'] as num).toDouble(),
      isRoundTrip: (map['is_round_trip'] as int? ?? 0) == 1,
      pricePerKm: (map['price_per_km'] as num).toDouble(),
      fuelConsumption: map['fuel_consumption'] != null
          ? (map['fuel_consumption'] as num).toDouble()
          : null,
      fuelPrice: map['fuel_price'] != null
          ? (map['fuel_price'] as num).toDouble()
          : null,
      baseCost: (map['base_cost'] as num).toDouble(),
      fuelCost: (map['fuel_cost'] as num).toDouble(),
      totalCost: (map['total_cost'] as num).toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
      notes: map['notes'] as String?,
    );
  }

  Transport copyWith({
    int? id,
    String? origin,
    String? destination,
    double? distance,
    bool? isRoundTrip,
    double? pricePerKm,
    double? fuelConsumption,
    double? fuelPrice,
    double? baseCost,
    double? fuelCost,
    double? totalCost,
    DateTime? createdAt,
    String? notes,
  }) {
    return Transport(
      id: id ?? this.id,
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      distance: distance ?? this.distance,
      isRoundTrip: isRoundTrip ?? this.isRoundTrip,
      pricePerKm: pricePerKm ?? this.pricePerKm,
      fuelConsumption: fuelConsumption ?? this.fuelConsumption,
      fuelPrice: fuelPrice ?? this.fuelPrice,
      baseCost: baseCost ?? this.baseCost,
      fuelCost: fuelCost ?? this.fuelCost,
      totalCost: totalCost ?? this.totalCost,
      createdAt: createdAt ?? this.createdAt,
      notes: notes ?? this.notes,
    );
  }
}
