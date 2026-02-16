import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pilot/services/Transport/transport_service.dart';

void main() {
  group('TransportService', () {
    late TransportService service;

    setUp(() {
      service = TransportService();
    });

    group('calculateTransportCosts', () {
      test('vráti baseCost ako distance * pricePerKm', () {
        // Arrange
        const distance = 100.0;
        const pricePerKm = 0.5;

        // Act
        final result = service.calculateTransportCosts(
          distance: distance,
          pricePerKm: pricePerKm,
        );

        // Assert
        expect(result['baseCost'], 50.0);
        expect(result['fuelCost'], 0.0);
        expect(result['totalCost'], 50.0);
        expect(result['distance'], distance);
      });

      test('počíta palivové náklady keď sú zadané spotreba a cena', () {
        // Arrange: 100 km, 6 l/100km, 1.5 €/l -> 6 l * 1.5 = 9 € paliva
        // base: 100 * 0.5 = 50 €
        const distance = 100.0;
        const pricePerKm = 0.5;
        const fuelConsumption = 6.0; // l/100km
        const fuelPrice = 1.5;

        // Act
        final result = service.calculateTransportCosts(
          distance: distance,
          pricePerKm: pricePerKm,
          fuelConsumption: fuelConsumption,
          fuelPrice: fuelPrice,
        );

        // Assert
        expect(result['baseCost'], 50.0);
        expect(result['fuelCost'], 9.0); // (100/100)*6*1.5
        expect(result['totalCost'], 59.0);
      });

      test('fuelCost je 0 keď fuelConsumption je 0', () {
        // Act
        final result = service.calculateTransportCosts(
          distance: 50.0,
          pricePerKm: 1.0,
          fuelConsumption: 0,
          fuelPrice: 1.5,
        );

        // Assert
        expect(result['fuelCost'], 0.0);
        expect(result['totalCost'], 50.0);
      });

      test('fuelCost je 0 keď fuelPrice je null', () {
        // Act
        final result = service.calculateTransportCosts(
          distance: 50.0,
          pricePerKm: 1.0,
          fuelConsumption: 6.0,
          fuelPrice: null,
        );

        // Assert
        expect(result['fuelCost'], 0.0);
      });

      test('fuelCost je 0 keď fuelConsumption je null', () {
        // Act
        final result = service.calculateTransportCosts(
          distance: 50.0,
          pricePerKm: 1.0,
          fuelConsumption: null,
          fuelPrice: 1.5,
        );

        // Assert
        expect(result['fuelCost'], 0.0);
      });
    });

    group('getAddressSuggestions', () {
      test('vráti prázdny zoznam keď input má menej ako 3 znaky', () async {
        // Act – bez API volania, len logika
        final result = await service.getAddressSuggestions(input: '');
        expect(result, isEmpty);

        final result2 = await service.getAddressSuggestions(input: 'ab');
        expect(result2, isEmpty);
      });
    });
  });
}
