import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pilot/models/warehouse_transfer.dart';

void main() {
  group('WarehouseTransfer', () {
    test('fromMap vytvorí inštanciu so všetkými poľami', () {
      // Arrange
      final map = {
        'id': 1,
        'from_warehouse_id': 10,
        'to_warehouse_id': 20,
        'product_unique_id': 'prod-1',
        'product_name': 'Produkt',
        'product_plu': 'PLU1',
        'quantity': 50,
        'unit': 'ks',
        'created_at': '2025-02-10T14:30:00.000',
        'notes': 'Poznámka',
        'username': 'user1',
      };

      // Act
      final transfer = WarehouseTransfer.fromMap(map);

      // Assert
      expect(transfer.id, 1);
      expect(transfer.fromWarehouseId, 10);
      expect(transfer.toWarehouseId, 20);
      expect(transfer.productUniqueId, 'prod-1');
      expect(transfer.productName, 'Produkt');
      expect(transfer.quantity, 50);
      expect(transfer.unit, 'ks');
      expect(transfer.createdAt, DateTime(2025, 2, 10, 14, 30));
      expect(transfer.notes, 'Poznámka');
      expect(transfer.username, 'user1');
    });

    test('fromMap používa predvolené hodnoty pre voliteľné polia', () {
      // Arrange
      final map = {
        'from_warehouse_id': 1,
        'to_warehouse_id': 2,
        'product_unique_id': 'p',
        'created_at': '2025-01-01T00:00:00.000',
      };

      // Act
      final transfer = WarehouseTransfer.fromMap(map);

      // Assert
      expect(transfer.productName, '');
      expect(transfer.productPlu, '');
      expect(transfer.quantity, 0);
      expect(transfer.unit, 'ks');
      expect(transfer.notes, isNull);
      expect(transfer.username, isNull);
    });

    test('toMap vráti mapu zhodnú s fromMap', () {
      // Arrange
      final transfer = WarehouseTransfer(
        id: 5,
        fromWarehouseId: 1,
        toWarehouseId: 2,
        productUniqueId: 'uid',
        productName: 'Názov',
        productPlu: 'PLU',
        quantity: 100,
        unit: 'ks',
        createdAt: DateTime(2025, 2, 1),
        notes: 'N',
        username: 'u',
      );

      // Act
      final map = transfer.toMap();
      final restored = WarehouseTransfer.fromMap(map);

      // Assert
      expect(restored.id, transfer.id);
      expect(restored.fromWarehouseId, transfer.fromWarehouseId);
      expect(restored.toWarehouseId, transfer.toWarehouseId);
      expect(restored.productUniqueId, transfer.productUniqueId);
      expect(restored.quantity, transfer.quantity);
      expect(restored.createdAt, transfer.createdAt);
    });
  });
}
