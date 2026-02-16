import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pilot/models/stock_out.dart';

void main() {
  group('StockOutStatus', () {
    test('fromString vráti schvalena pre "schvalena"', () {
      expect(StockOutStatus.fromString('schvalena'), StockOutStatus.schvalena);
    });
    test('fromString vráti rozpracovany pre "rozpracovany"', () {
      expect(StockOutStatus.fromString('rozpracovany'), StockOutStatus.rozpracovany);
    });
    test('fromString vráti stornovana pre "stornovana"', () {
      expect(StockOutStatus.fromString('stornovana'), StockOutStatus.stornovana);
    });
    test('fromString vráti vykazana pre "vykazana"', () {
      expect(StockOutStatus.fromString('vykazana'), StockOutStatus.vykazana);
    });
    test('fromString vráti vykazana pre null alebo neznámy reťazec', () {
      expect(StockOutStatus.fromString(null), StockOutStatus.vykazana);
      expect(StockOutStatus.fromString('unknown'), StockOutStatus.vykazana);
    });
  });

  group('StockOutIssueType', () {
    test('fromString vráti správny typ pre každú hodnotu', () {
      expect(StockOutIssueType.fromString('SALE'), StockOutIssueType.sale);
      expect(StockOutIssueType.fromString('CONS'), StockOutIssueType.consumption);
      expect(StockOutIssueType.fromString('PROD'), StockOutIssueType.production);
      expect(StockOutIssueType.fromString('SCRP'), StockOutIssueType.writeOff);
      expect(StockOutIssueType.fromString('RETURN'), StockOutIssueType.returnToSupplier);
      expect(StockOutIssueType.fromString('TRAN'), StockOutIssueType.transfer);
    });
    test('fromString vráti sale pre null alebo prázdny reťazec', () {
      expect(StockOutIssueType.fromString(null), StockOutIssueType.sale);
      expect(StockOutIssueType.fromString(''), StockOutIssueType.sale);
    });
    test('fromString vráti sale pre neznámy kód', () {
      expect(StockOutIssueType.fromString('XXX'), StockOutIssueType.sale);
    });
    test('requiresWriteOffReason je true len pre writeOff', () {
      expect(StockOutIssueType.writeOff.requiresWriteOffReason, true);
      expect(StockOutIssueType.sale.requiresWriteOffReason, false);
      expect(StockOutIssueType.consumption.requiresWriteOffReason, false);
    });
  });

  group('StockOut', () {
    final testDate = DateTime(2025, 2, 10);

    test('fromMap vytvorí inštanciu so všetkými poľami', () {
      // Arrange
      final map = {
        'id': 1,
        'document_number': 'VYD-001',
        'created_at': testDate.toIso8601String(),
        'recipient_name': 'Zákazník',
        'notes': 'Poznámka',
        'username': 'user1',
        'status': 'schvalena',
        'vat_rate': 0,
        'issue_type': 'SALE',
        'write_off_reason': null,
      };

      // Act
      final stockOut = StockOut.fromMap(map);

      // Assert
      expect(stockOut.id, 1);
      expect(stockOut.documentNumber, 'VYD-001');
      expect(stockOut.status, StockOutStatus.schvalena);
      expect(stockOut.vatRate, 0);
      expect(stockOut.issueType, StockOutIssueType.sale);
      expect(stockOut.isZeroVat, true);
      expect(stockOut.isApproved, true);
    });

    test('isEditable je false pre schvalena a stornovana', () {
      expect(StockOut(documentNumber: 'X', createdAt: testDate, status: StockOutStatus.schvalena).isEditable, false);
      expect(StockOut(documentNumber: 'X', createdAt: testDate, status: StockOutStatus.stornovana).isEditable, false);
    });

    test('isEditable je true pre vykazana a rozpracovany', () {
      expect(StockOut(documentNumber: 'X', createdAt: testDate, status: StockOutStatus.vykazana).isEditable, true);
      expect(StockOut(documentNumber: 'X', createdAt: testDate, status: StockOutStatus.rozpracovany).isEditable, true);
    });

    test('isWriteOff je true len pre issueType writeOff', () {
      expect(StockOut(documentNumber: 'X', createdAt: testDate, issueType: StockOutIssueType.writeOff).isWriteOff, true);
      expect(StockOut(documentNumber: 'X', createdAt: testDate, issueType: StockOutIssueType.sale).isWriteOff, false);
    });

    test('toMap a fromMap round-trip zachováva dáta', () {
      // Arrange
      final stockOut = StockOut(
        id: 2,
        documentNumber: 'VYD-002',
        createdAt: testDate,
        recipientName: 'R',
        notes: 'N',
        username: 'u',
        status: StockOutStatus.vykazana,
        vatRate: 23,
        issueType: StockOutIssueType.consumption,
      );

      // Act
      final restored = StockOut.fromMap(stockOut.toMap());

      // Assert
      expect(restored.documentNumber, stockOut.documentNumber);
      expect(restored.status, stockOut.status);
      expect(restored.issueType, stockOut.issueType);
    });

    test('copyWith mení len zadané polia', () {
      // Arrange
      final stockOut = StockOut(documentNumber: 'D', createdAt: testDate, status: StockOutStatus.vykazana);

      // Act
      final updated = stockOut.copyWith(status: StockOutStatus.schvalena);

      // Assert
      expect(updated.documentNumber, 'D');
      expect(updated.status, StockOutStatus.schvalena);
    });
  });

  group('StockOutItem', () {
    test('fromMap vytvorí inštanciu so všetkými poľami', () {
      // Arrange
      final map = {
        'id': 1,
        'stock_out_id': 10,
        'product_unique_id': 'prod-1',
        'product_name': 'Produkt',
        'plu': 'PLU1',
        'qty': 25,
        'unit': 'ks',
        'unit_price': 12.5,
      };

      // Act
      final item = StockOutItem.fromMap(map);

      // Assert
      expect(item.id, 1);
      expect(item.stockOutId, 10);
      expect(item.productUniqueId, 'prod-1');
      expect(item.productName, 'Produkt');
      expect(item.plu, 'PLU1');
      expect(item.qty, 25);
      expect(item.unit, 'ks');
      expect(item.unitPrice, 12.5);
    });

    test('toMap vráti mapu s zaokrúhlenou unit_price', () {
      // Arrange – _roundPrice zaokrúhli na 5 desatinných miest
      final item = StockOutItem(
        stockOutId: 1,
        productUniqueId: 'p',
        qty: 1,
        unit: 'ks',
        unitPrice: 10.123456789,
      );

      // Act
      final map = item.toMap();

      // Assert
      expect(map['unit_price'], closeTo(10.12346, 0.00001));
    });

    test('round-trip fromMap(toMap()) zachováva dáta', () {
      // Arrange
      final item = StockOutItem(
        id: 5,
        stockOutId: 3,
        productUniqueId: 'uid',
        productName: 'Názov',
        plu: 'PLU',
        qty: 10,
        unit: 'ks',
        unitPrice: 99.99,
      );

      // Act
      final restored = StockOutItem.fromMap(item.toMap());

      // Assert
      expect(restored.stockOutId, item.stockOutId);
      expect(restored.productUniqueId, item.productUniqueId);
      expect(restored.qty, item.qty);
      expect(restored.unitPrice, item.unitPrice);
    });
  });
}
