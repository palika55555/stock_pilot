import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pilot/models/transport.dart';

void main() {
  group('Transport', () {
    final testDate = DateTime(2025, 2, 10, 12, 0);

    test('fromMap vytvorí inštanciu so všetkými poľami', () {
      // Arrange
      final map = {
        'id': 1,
        'origin': 'Bratislava',
        'destination': 'Košice',
        'distance': 400.0,
        'is_round_trip': 1,
        'price_per_km': 0.5,
        'fuel_consumption': 6.5,
        'fuel_price': 1.4,
        'base_cost': 200.0,
        'fuel_cost': 36.4,
        'total_cost': 236.4,
        'created_at': testDate.toIso8601String(),
        'notes': 'Poznámka',
      };

      // Act
      final transport = Transport.fromMap(map);

      // Assert
      expect(transport.id, 1);
      expect(transport.origin, 'Bratislava');
      expect(transport.destination, 'Košice');
      expect(transport.distance, 400.0);
      expect(transport.isRoundTrip, true);
      expect(transport.pricePerKm, 0.5);
      expect(transport.fuelConsumption, 6.5);
      expect(transport.fuelPrice, 1.4);
      expect(transport.baseCost, 200.0);
      expect(transport.fuelCost, 36.4);
      expect(transport.totalCost, 236.4);
      expect(transport.notes, 'Poznámka');
    });

    test('fromMap považuje is_round_trip 0 za false', () {
      // Arrange
      final map = {
        'origin': 'A',
        'destination': 'B',
        'distance': 10.0,
        'is_round_trip': 0,
        'price_per_km': 1.0,
        'base_cost': 10.0,
        'fuel_cost': 0.0,
        'total_cost': 10.0,
        'created_at': testDate.toIso8601String(),
      };

      // Act
      final transport = Transport.fromMap(map);

      // Assert
      expect(transport.isRoundTrip, false);
    });

    test('fromMap umožňuje null fuel_consumption a fuel_price', () {
      // Arrange
      final map = {
        'origin': 'A',
        'destination': 'B',
        'distance': 10.0,
        'price_per_km': 1.0,
        'base_cost': 10.0,
        'fuel_cost': 0.0,
        'total_cost': 10.0,
        'created_at': testDate.toIso8601String(),
      };

      // Act
      final transport = Transport.fromMap(map);

      // Assert
      expect(transport.fuelConsumption, isNull);
      expect(transport.fuelPrice, isNull);
    });

    test('toMap vráti mapu zhodnú s fromMap', () {
      // Arrange
      final transport = Transport(
        id: 2,
        origin: 'Praha',
        destination: 'Brno',
        distance: 210.0,
        isRoundTrip: true,
        pricePerKm: 0.6,
        fuelConsumption: 7.0,
        fuelPrice: 1.5,
        baseCost: 126.0,
        fuelCost: 22.05,
        totalCost: 148.05,
        createdAt: testDate,
        notes: 'Test',
      );

      // Act
      final map = transport.toMap();
      final restored = Transport.fromMap(map);

      // Assert
      expect(restored.id, transport.id);
      expect(restored.origin, transport.origin);
      expect(restored.destination, transport.destination);
      expect(restored.distance, transport.distance);
      expect(restored.isRoundTrip, transport.isRoundTrip);
      expect(restored.totalCost, transport.totalCost);
    });

    test('copyWith mení len zadané polia', () {
      // Arrange
      final transport = Transport(
        origin: 'A',
        destination: 'B',
        distance: 100.0,
        pricePerKm: 0.5,
        baseCost: 50.0,
        fuelCost: 0.0,
        totalCost: 50.0,
        createdAt: testDate,
      );

      // Act
      final updated = transport.copyWith(destination: 'C', distance: 150.0);

      // Assert
      expect(updated.origin, 'A');
      expect(updated.destination, 'C');
      expect(updated.distance, 150.0);
    });
  });
}
