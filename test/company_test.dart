import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pilot/models/company.dart';

void main() {
  group('Company', () {
    test('fromMap vytvorí inštanciu so všetkými poľami', () {
      // Arrange
      final map = {
        'id': 1,
        'name': 'Firma s.r.o.',
        'address': 'Ulica 1',
        'city': 'Bratislava',
        'postal_code': '81101',
        'country': 'Slovensko',
        'ico': '12345678',
        'ic_dph': 'SK1234567890',
        'vat_payer': 1,
        'phone': '+421900000',
        'email': 'info@firma.sk',
        'web': 'https://firma.sk',
        'iban': 'SK...',
        'swift': 'GIBASKBX',
        'bank_name': 'Banka',
        'account': '123',
        'register_info': 'OR, Oddiel, Vložka',
        'logo_path': '/path/logo.png',
      };

      // Act
      final company = Company.fromMap(map);

      // Assert
      expect(company.id, 1);
      expect(company.name, 'Firma s.r.o.');
      expect(company.address, 'Ulica 1');
      expect(company.city, 'Bratislava');
      expect(company.postalCode, '81101');
      expect(company.vatPayer, true);
      expect(company.ico, '12345678');
      expect(company.logoPath, '/path/logo.png');
    });

    test('fromMap považuje vat_payer 0 za false', () {
      // Arrange
      final map = {'name': 'F', 'vat_payer': 0};

      // Act
      final company = Company.fromMap(map);

      // Assert
      expect(company.vatPayer, false);
    });

    test('fullAddress skladá adresu z častí', () {
      // Arrange
      final company = Company(
        name: 'F',
        address: 'Ulica 1',
        city: 'Bratislava',
        postalCode: '81101',
        country: 'Slovensko',
      );

      // Act
      final full = company.fullAddress;

      // Assert
      expect(full, 'Ulica 1, 81101 Bratislava, Slovensko');
    });

    test('fullAddress vynecháva prázdne časti', () {
      // Arrange
      final company = Company(name: 'F', city: 'Bratislava');

      // Act
      final full = company.fullAddress;

      // Assert
      expect(full, 'Bratislava');
    });

    test('fullAddress vracia prázdny reťazec ak všetko prázdne', () {
      // Arrange
      final company = Company(name: 'F');

      // Act
      final full = company.fullAddress;

      // Assert
      expect(full, '');
    });

    test('toMap a fromMap round-trip zachováva dáta', () {
      // Arrange
      final company = Company(
        id: 2,
        name: 'Test s.r.o.',
        address: 'A',
        city: 'C',
        postalCode: '12345',
        country: 'SK',
        ico: '111',
        vatPayer: true,
      );

      // Act
      final restored = Company.fromMap(company.toMap());

      // Assert
      expect(restored.id, company.id);
      expect(restored.name, company.name);
      expect(restored.vatPayer, company.vatPayer);
    });

    test('copyWith mení len zadané polia', () {
      // Arrange
      final company = Company(id: 1, name: 'Pôvodná', city: 'BA');

      // Act
      final updated = company.copyWith(name: 'Nový názov');

      // Assert
      expect(updated.id, 1);
      expect(updated.name, 'Nový názov');
      expect(updated.city, 'BA');
    });
  });
}
