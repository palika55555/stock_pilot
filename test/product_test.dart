import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pilot/models/product.dart';

void main() {
  group('Product', () {
    test('fromMap vytvorí inštanciu so všetkými poľami', () {
      // Arrange
      final map = {
        'unique_id': 'uid-1',
        'name': 'Produkt A',
        'plu': 'PLU001',
        'category': 'Kategória',
        'qty': 10,
        'unit': 'ks',
        'price': 12.5,
        'without_vat': 10.0,
        'vat': 25,
        'discount': 0,
        'last_purchase_price': 8.0,
        'last_purchase_price_without_vat': 6.5,
        'last_purchase_date': '2025-01-15',
        'currency': 'EUR',
        'location': 'A1',
        'purchase_price': 8.0,
        'purchase_price_without_vat': 6.5,
        'purchase_vat': 23,
        'recycling_fee': 0.0,
        'product_type': 'Sklad',
        'supplier_name': 'Dodávateľ',
        'kind_id': 1,
        'warehouse_id': 2,
      };

      // Act
      final product = Product.fromMap(map);

      // Assert
      expect(product.uniqueId, 'uid-1');
      expect(product.name, 'Produkt A');
      expect(product.plu, 'PLU001');
      expect(product.qty, 10);
      expect(product.price, 12.5);
      expect(product.purchasePrice, 8.0);
      expect(product.vat, 25);
      expect(product.kindId, 1);
      expect(product.warehouseId, 2);
    });

    test('fromMap používa predvolené hodnoty pri null/chybajúcich položkách', () {
      // Arrange
      final map = {
        'name': 'X',
        'plu': 'P',
        'category': 'C',
        'qty': 0,
        'unit': 'ks',
        'price': 0,
        'without_vat': 0,
        'vat': 23,
        'discount': 0,
        'last_purchase_price': 0,
        'last_purchase_date': '',
        'currency': 'EUR',
        'location': '',
      };

      // Act
      final product = Product.fromMap(map);

      // Assert
      expect(product.uniqueId, isNull);
      expect(product.qty, 0);
      expect(product.price, 0.0);
      expect(product.currency, 'EUR');
      expect(product.productType, 'Sklad');
      expect(product.purchaseVat, 23);
      expect(product.supplierName, isNull);
      expect(product.kindId, isNull);
    });

    test('toMap vráti mapu zhodnú s fromMap', () {
      // Arrange
      final product = Product(
        uniqueId: 'uid-2',
        name: 'Test',
        plu: 'PLU',
        category: 'Cat',
        qty: 5,
        unit: 'ks',
        price: 10.0,
        withoutVat: 8.0,
        vat: 23,
        discount: 0,
        lastPurchasePrice: 6.0,
        lastPurchaseDate: '2025-02-01',
        currency: 'EUR',
        location: 'B2',
        kindId: 1,
        warehouseId: 2,
      );

      // Act
      final map = product.toMap();
      final restored = Product.fromMap(map);

      // Assert
      expect(restored.uniqueId, product.uniqueId);
      expect(restored.name, product.name);
      expect(restored.qty, product.qty);
      expect(restored.price, product.price);
      expect(restored.kindId, product.kindId);
      expect(restored.warehouseId, product.warehouseId);
    });

    test('marginPercent vráti null keď price je 0', () {
      // Arrange
      final product = Product(
        name: 'Zero',
        plu: 'Z',
        category: 'C',
        qty: 0,
        unit: 'ks',
        price: 0,
        withoutVat: 0,
        vat: 23,
        discount: 0,
        lastPurchasePrice: 5,
        lastPurchaseDate: '',
        currency: 'EUR',
        location: '',
      );

      // Act
      final margin = product.marginPercent;

      // Assert
      expect(margin, isNull);
    });

    test('marginPercent vráti správny percentuálny podiel', () {
      // Arrange: predaj 100, nákup 60 -> marža (100-60)/100 * 100 = 40%
      final product = Product(
        name: 'M',
        plu: 'M',
        category: 'C',
        qty: 1,
        unit: 'ks',
        price: 100.0,
        withoutVat: 80.0,
        vat: 25,
        discount: 0,
        lastPurchasePrice: 60,
        lastPurchaseDate: '',
        currency: 'EUR',
        location: '',
        purchasePrice: 60.0,
      );

      // Act
      final margin = product.marginPercent;

      // Assert
      expect(margin, 40.0);
    });

    test('marginPercent vráti 0 keď predajná a nákupná cena sú rovnaké', () {
      // Arrange
      final product = Product(
        name: 'M',
        plu: 'M',
        category: 'C',
        qty: 1,
        unit: 'ks',
        price: 50.0,
        withoutVat: 40.0,
        vat: 25,
        discount: 0,
        lastPurchasePrice: 50,
        lastPurchaseDate: '',
        currency: 'EUR',
        location: '',
        purchasePrice: 50.0,
      );

      // Act
      final margin = product.marginPercent;

      // Assert
      expect(margin, 0.0);
    });
  });
}
