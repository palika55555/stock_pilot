import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pilot/models/product_kind.dart';

void main() {
  group('ProductKind', () {
    test('fromMap vytvorí inštanciu s id a name', () {
      // Arrange
      final map = {'id': 1, 'name': 'Klince'};

      // Act
      final kind = ProductKind.fromMap(map);

      // Assert
      expect(kind.id, 1);
      expect(kind.name, 'Klince');
    });

    test('fromMap používa prázdny reťazec pre chýbajúce name', () {
      // Arrange
      final map = {'id': 2};

      // Act
      final kind = ProductKind.fromMap(map);

      // Assert
      expect(kind.name, '');
    });

    test('toMap vráti mapu s id a name', () {
      // Arrange
      const kind = ProductKind(id: 3, name: 'Montážna pena');

      // Act
      final map = kind.toMap();

      // Assert
      expect(map['id'], 3);
      expect(map['name'], 'Montážna pena');
    });

    test('round-trip fromMap(toMap()) zachováva dáta', () {
      // Arrange
      const kind = ProductKind(id: 5, name: 'Druh X');

      // Act
      final restored = ProductKind.fromMap(kind.toMap());

      // Assert
      expect(restored.id, kind.id);
      expect(restored.name, kind.name);
    });

    test('copyWith mení len zadané polia', () {
      // Arrange
      const kind = ProductKind(id: 1, name: 'Pôvodný');

      // Act
      final updated = kind.copyWith(name: 'Nový názov');

      // Assert
      expect(updated.id, 1);
      expect(updated.name, 'Nový názov');
    });

    test('copyWith s id mení len id', () {
      // Arrange
      const kind = ProductKind(id: 1, name: 'Názov');

      // Act
      final updated = kind.copyWith(id: 10);

      // Assert
      expect(updated.id, 10);
      expect(updated.name, 'Názov');
    });
  });
}
