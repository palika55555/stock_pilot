import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pilot/models/customer.dart';

void main() {
  group('Customer', () {
    test('fromMap vytvorí inštanciu so všetkými poľami', () {
      // Arrange
      final map = {
        'id': 1,
        'name': 'Zákazník s.r.o.',
        'ico': '87654321',
        'email': 'zakaznik@test.sk',
        'address': 'Ulica 2',
        'city': 'Prešov',
        'postal_code': '08001',
        'dic': '0987654321',
        'ic_dph': 'SK0987654321',
        'default_vat_rate': 20,
        'is_active': 1,
      };

      // Act
      final customer = Customer.fromMap(map);

      // Assert
      expect(customer.id, 1);
      expect(customer.name, 'Zákazník s.r.o.');
      expect(customer.ico, '87654321');
      expect(customer.defaultVatRate, 20);
      expect(customer.isActive, true);
    });

    test('fromMap používa predvolené hodnoty', () {
      // Arrange
      final map = {'name': 'Z', 'ico': '111'};

      // Act
      final customer = Customer.fromMap(map);

      // Assert
      expect(customer.defaultVatRate, 20);
      expect(customer.isActive, true);
    });

    test('fromMap považuje is_active 0 za false', () {
      // Arrange
      final map = {'name': 'Z', 'ico': '111', 'is_active': 0};

      // Act
      final customer = Customer.fromMap(map);

      // Assert
      expect(customer.isActive, false);
    });

    test('toMap vráti mapu zhodnú s fromMap', () {
      // Arrange
      final customer = Customer(
        id: 2,
        name: 'Zákazník',
        ico: '222',
        defaultVatRate: 23,
        isActive: false,
      );

      // Act
      final restored = Customer.fromMap(customer.toMap());

      // Assert
      expect(restored.id, customer.id);
      expect(restored.name, customer.name);
      expect(restored.defaultVatRate, customer.defaultVatRate);
      expect(restored.isActive, customer.isActive);
    });

    test('copyWith mení len zadané polia', () {
      // Arrange
      final customer = Customer(id: 1, name: 'Pôvodný', ico: '111');

      // Act
      final updated = customer.copyWith(name: 'Nový', defaultVatRate: 10);

      // Assert
      expect(updated.id, 1);
      expect(updated.name, 'Nový');
      expect(updated.ico, '111');
      expect(updated.defaultVatRate, 10);
    });
  });
}
