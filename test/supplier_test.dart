import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pilot/models/supplier.dart';

void main() {
  group('Supplier', () {
    test('fromMap vytvorí inštanciu so všetkými poľami', () {
      // Arrange
      final map = {
        'id': 1,
        'name': 'Dodávateľ s.r.o.',
        'ico': '12345678',
        'email': 'dodavatel@test.sk',
        'address': 'Ulica 1',
        'city': 'Košice',
        'postal_code': '04001',
        'dic': '1234567890',
        'ic_dph': 'SK1234567890',
        'default_vat_rate': 20,
        'is_active': 1,
      };

      // Act
      final supplier = Supplier.fromMap(map);

      // Assert
      expect(supplier.id, 1);
      expect(supplier.name, 'Dodávateľ s.r.o.');
      expect(supplier.ico, '12345678');
      expect(supplier.email, 'dodavatel@test.sk');
      expect(supplier.defaultVatRate, 20);
      expect(supplier.isActive, true);
    });

    test('fromMap používa predvolené hodnoty', () {
      // Arrange
      final map = {'name': 'D', 'ico': '111'};

      // Act
      final supplier = Supplier.fromMap(map);

      // Assert
      expect(supplier.defaultVatRate, 20);
      expect(supplier.isActive, true);
    });

    test('fromMap považuje is_active 0 za false', () {
      // Arrange
      final map = {'name': 'D', 'ico': '111', 'is_active': 0};

      // Act
      final supplier = Supplier.fromMap(map);

      // Assert
      expect(supplier.isActive, false);
    });

    test('toMap vráti mapu zhodnú s fromMap', () {
      // Arrange
      final supplier = Supplier(
        id: 2,
        name: 'Dodávateľ',
        ico: '222',
        email: 'e@e.sk',
        defaultVatRate: 23,
        isActive: false,
      );

      // Act
      final restored = Supplier.fromMap(supplier.toMap());

      // Assert
      expect(restored.id, supplier.id);
      expect(restored.name, supplier.name);
      expect(restored.defaultVatRate, supplier.defaultVatRate);
      expect(restored.isActive, supplier.isActive);
    });

    test('copyWith mení len zadané polia', () {
      // Arrange
      final supplier = Supplier(id: 1, name: 'Pôvodný', ico: '111');

      // Act
      final updated = supplier.copyWith(name: 'Nový', isActive: false);

      // Assert
      expect(updated.id, 1);
      expect(updated.name, 'Nový');
      expect(updated.ico, '111');
      expect(updated.isActive, false);
    });
  });
}
