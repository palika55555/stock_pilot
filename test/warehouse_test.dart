import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pilot/models/warehouse.dart';

void main() {
  group('Warehouse', () {
    test('fromMap vytvorí inštanciu so všetkými poľami', () {
      // Arrange
      final map = {
        'id': 1,
        'name': 'Sklad 1',
        'code': 'WH01',
        'warehouse_type': 'Sklad',
        'address': 'Ulica 1',
        'city': 'Bratislava',
        'postal_code': '81101',
        'is_active': 1,
        'item_count': 42,
        'last_update': '2025-02-01T10:00:00.000',
        'current_stock': 100.0,
        'max_capacity': 500.0,
      };

      // Act
      final wh = Warehouse.fromMap(map);

      // Assert
      expect(wh.id, 1);
      expect(wh.name, 'Sklad 1');
      expect(wh.code, 'WH01');
      expect(wh.warehouseType, 'Sklad');
      expect(wh.isActive, true);
      expect(wh.itemCount, 42);
      expect(wh.currentStock, 100.0);
      expect(wh.maxCapacity, 500.0);
    });

    test('fromMap parsuje last_update z int (milliseconds)', () {
      // Arrange
      final ms = DateTime(2025, 1, 15).millisecondsSinceEpoch;
      final map = {
        'id': 1,
        'name': 'W',
        'code': 'W',
        'last_update': ms,
      };

      // Act
      final wh = Warehouse.fromMap(map);

      // Assert
      expect(wh.lastUpdate, DateTime(2025, 1, 15));
    });

    test('fromMap považuje is_active 0 za false', () {
      // Arrange
      final map = {
        'name': 'W',
        'code': 'W',
        'is_active': 0,
      };

      // Act
      final wh = Warehouse.fromMap(map);

      // Assert
      expect(wh.isActive, false);
    });

    test('toMap vracia is_active 1 pre true', () {
      // Arrange
      final wh = Warehouse(name: 'W', code: 'W', isActive: true);

      // Act
      final map = wh.toMap();

      // Assert
      expect(map['is_active'], 1);
    });

    test('copyWith mení len zadané polia', () {
      // Arrange
      final wh = Warehouse(
        id: 1,
        name: 'Pôvodný',
        code: 'C1',
        itemCount: 5,
      );

      // Act
      final updated = wh.copyWith(name: 'Nový názov', itemCount: 10);

      // Assert
      expect(updated.id, 1);
      expect(updated.name, 'Nový názov');
      expect(updated.code, 'C1');
      expect(updated.itemCount, 10);
    });

    test('round-trip fromMap(toMap()) zachováva dáta', () {
      // Arrange
      final wh = Warehouse(
        id: 2,
        name: 'Sklad',
        code: 'SK',
        warehouseType: WarehouseType.vyroba,
        address: 'Addr',
        city: 'City',
        postalCode: '12345',
        isActive: true,
      );

      // Act
      final map = wh.toMap();
      final restored = Warehouse.fromMap(map);

      // Assert
      expect(restored.id, wh.id);
      expect(restored.name, wh.name);
      expect(restored.code, wh.code);
      expect(restored.warehouseType, wh.warehouseType);
      expect(restored.isActive, wh.isActive);
    });
  });

  group('WarehouseType', () {
    test('all obsahuje očakávané typy', () {
      expect(WarehouseType.all, contains(WarehouseType.predaj));
      expect(WarehouseType.all, contains(WarehouseType.vyroba));
      expect(WarehouseType.all, contains(WarehouseType.sklad));
    });
  });
}
