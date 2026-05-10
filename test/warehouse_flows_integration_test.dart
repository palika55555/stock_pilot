import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stock_pilot/models/product.dart';
import 'package:stock_pilot/models/production_order.dart';
import 'package:stock_pilot/models/receipt.dart';
import 'package:stock_pilot/models/recipe.dart';
import 'package:stock_pilot/models/stock_out.dart';
import 'package:stock_pilot/models/warehouse.dart';
import 'package:stock_pilot/services/Database/database_service.dart';
import 'package:stock_pilot/services/ProductionOrder/production_order_service.dart';
import 'package:stock_pilot/services/Receipt/receipt_service.dart';
import 'package:stock_pilot/services/StockOut/stock_out_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseService db;
  late StockOutService stockOutService;
  late ReceiptService receiptService;
  late ProductionOrderService productionOrderService;
  late Directory tempDir;

  Future<int> createWarehouse({
    required String name,
    required String code,
    String type = WarehouseType.sklad,
  }) async {
    return db.insertWarehouse(
      Warehouse(name: name, code: code, warehouseType: type),
    );
  }

  Product makeProduct({
    required String uniqueId,
    required String name,
    required String plu,
    required double qty,
    required int warehouseId,
    double purchasePrice = 1,
    int vat = 20,
  }) {
    return Product(
      uniqueId: uniqueId,
      name: name,
      plu: plu,
      category: 'Test',
      qty: qty,
      unit: 'ks',
      price: 10,
      withoutVat: 8.33,
      vat: vat,
      discount: 0,
      lastPurchasePrice: purchasePrice,
      lastPurchaseDate: '2026-01-01',
      currency: 'EUR',
      location: '',
      purchasePrice: purchasePrice,
      purchasePriceWithoutVat: purchasePrice / (1 + vat / 100),
      purchaseVat: vat,
      warehouseId: warehouseId,
    );
  }

  setUp(() async {
    sqfliteFfiInit();
    sqflite.databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});

    tempDir = await Directory.systemTemp.createTemp('stock_pilot_test_');
    db = DatabaseService();
    await db.setCustomPath(tempDir.path);
    await DatabaseService.setCurrentUser('integration-test-user');
    await db.clearAllData();

    stockOutService = StockOutService();
    receiptService = ReceiptService();
    productionOrderService = ProductionOrderService();
  });

  tearDown(() async {
    try {
      final database = await db.database;
      await database.close();
    } catch (_) {}
    DatabaseService.clearCurrentUser();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('nevykazana výdajka sa pri schválení neodpíše druhýkrát', () async {
    final warehouseId = await createWarehouse(
      name: 'Hlavný sklad',
      code: 'WH-1',
    );
    await db.insertProduct(
      makeProduct(
        uniqueId: 'P-001',
        name: 'Produkt 1',
        plu: '1001',
        qty: 10,
        warehouseId: warehouseId,
      ),
    );

    await stockOutService.createStockOut(
      stockOut: StockOut(
        documentNumber: '',
        createdAt: DateTime.now(),
        warehouseId: warehouseId,
      ),
      items: [
        StockOutItem(
          stockOutId: 0,
          productUniqueId: 'P-001',
          productName: 'Produkt 1',
          qty: 2,
          unit: 'ks',
          unitPrice: 10,
        ),
      ],
      isDraft: false,
    );

    var product = await db.getProductByUniqueId('P-001');
    expect(product, isNotNull);
    expect(product!.qty, 8);

    final outs = await stockOutService.getAllStockOuts();
    expect(outs, isNotEmpty);
    await stockOutService.approveStockOut(outs.first.id!);

    product = await db.getProductByUniqueId('P-001');
    expect(product, isNotNull);
    expect(product!.qty, 8, reason: 'Schválenie nesmie spraviť druhý odpis.');
  });

  test(
    'update už aplikovanej výdajky správne revertne a znovu aplikuje zásobu',
    () async {
      final warehouseId = await createWarehouse(
        name: 'Hlavný sklad',
        code: 'WH-2',
      );
      await db.insertProduct(
        makeProduct(
          uniqueId: 'P-002',
          name: 'Produkt 2',
          plu: '1002',
          qty: 10,
          warehouseId: warehouseId,
        ),
      );

      await stockOutService.createStockOut(
        stockOut: StockOut(
          documentNumber: '',
          createdAt: DateTime.now(),
          warehouseId: warehouseId,
        ),
        items: [
          StockOutItem(
            stockOutId: 0,
            productUniqueId: 'P-002',
            productName: 'Produkt 2',
            qty: 2,
            unit: 'ks',
            unitPrice: 10,
          ),
        ],
        isDraft: false,
      );

      final created = (await stockOutService.getAllStockOuts()).first;
      await stockOutService.updateStockOut(
        stockOut: created,
        items: [
          StockOutItem(
            stockOutId: created.id!,
            productUniqueId: 'P-002',
            productName: 'Produkt 2',
            qty: 3,
            unit: 'ks',
            unitPrice: 10,
          ),
        ],
      );

      final product = await db.getProductByUniqueId('P-002');
      expect(product, isNotNull);
      expect(
        product!.qty,
        7,
        reason: '10 - 3 po update už aplikovanej výdajky.',
      );
    },
  );

  test(
    'transfer príjemka nastaví stockApplied a korektne presunie množstvo',
    () async {
      final sourceId = await createWarehouse(name: 'Zdroj', code: 'SRC');
      final destId = await createWarehouse(name: 'Cieľ', code: 'DST');

      await db.insertProduct(
        makeProduct(
          uniqueId: 'P-TR-1',
          name: 'Transfer položka',
          plu: '2001',
          qty: 10,
          warehouseId: sourceId,
        ),
      );

      final receiptId = await receiptService.createReceipt(
        receipt: InboundReceipt(
          receiptNumber: '',
          createdAt: DateTime.now(),
          warehouseId: destId,
          sourceWarehouseId: sourceId,
          movementTypeCode: 'TRANSFER',
        ),
        items: [
          InboundReceiptItem(
            receiptId: 0,
            productUniqueId: 'P-TR-1',
            productName: 'Transfer položka',
            plu: '2001',
            qty: 3,
            unit: 'ks',
            unitPrice: 1,
          ),
        ],
        isDraft: false,
      );

      final receipt = await receiptService.getReceiptById(receiptId);
      expect(receipt, isNotNull);
      expect(receipt!.stockApplied, isTrue);
      expect(receipt.status, InboundReceiptStatus.schvalena);

      final sourceProduct = await db.getProductByUniqueId('P-TR-1');
      expect(sourceProduct, isNotNull);
      expect(sourceProduct!.qty, 7);

      final targetProducts = await db.getProductsByWarehouseId(destId);
      final moved = targetProducts.firstWhere(
        (p) => p.plu == '2001',
        orElse: () => throw StateError('Cieľový produkt nebol vytvorený'),
      );
      expect(moved.qty, 3);
    },
  );

  test(
    'dokončenie výroby používa desatinné množstvá bez zaokrúhlenia',
    () async {
      final sourceId = await createWarehouse(
        name: 'Sklad surovín',
        code: 'RAW',
        type: WarehouseType.vyroba,
      );
      final destId = await createWarehouse(name: 'Sklad výrobkov', code: 'FG');

      await db.insertProduct(
        makeProduct(
          uniqueId: 'ING-1',
          name: 'Surovina',
          plu: '3001',
          qty: 10,
          warehouseId: sourceId,
          purchasePrice: 2,
        ),
      );
      await db.insertProduct(
        makeProduct(
          uniqueId: 'FG-1',
          name: 'Hotový výrobok',
          plu: '4001',
          qty: 0,
          warehouseId: destId,
          purchasePrice: 1,
        ),
      );

      final recipeId = await db.insertRecipe(
        const Recipe(
          name: 'Recept A',
          finishedProductUniqueId: 'FG-1',
          outputQuantity: 1,
          unit: 'kg',
        ),
      );
      await db.insertRecipeIngredient(
        const RecipeIngredient(
          recipeId: 0,
          productUniqueId: 'ING-1',
          productName: 'Surovina',
          quantity: 0.5,
          unit: 'kg',
        ).copyWith(recipeId: recipeId),
      );

      final orderId = await productionOrderService.createOrder(
        order: ProductionOrder(
          orderNumber: 'VP-TEST-001',
          recipeId: recipeId,
          plannedQuantity: 1.5,
          productionDate: DateTime.now(),
          sourceWarehouseId: sourceId,
          destinationWarehouseId: destId,
          status: ProductionOrderStatus.inProgress,
        ),
      );

      await productionOrderService.completeProduction(
        orderId: orderId,
        actualQuantity: 1.5,
        completedByUsername: 'tester',
      );

      final ingredient = await db.getProductByUniqueId('ING-1');
      final finished = await db.getProductByUniqueId('FG-1');
      expect(ingredient, isNotNull);
      expect(finished, isNotNull);
      expect(ingredient!.qty, closeTo(9.25, 0.0001));
      expect(finished!.qty, closeTo(1.5, 0.0001));
    },
  );
}
