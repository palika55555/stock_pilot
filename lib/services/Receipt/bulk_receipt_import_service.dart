import 'dart:typed_data';
import 'package:excel/excel.dart';
import '../../models/product.dart';
import '../../models/receipt.dart';
import '../Database/database_service.dart';
import '../Product/product_service.dart';

/// Jeden riadok z Excelu pred mapovaním na produkt.
class BulkImportRow {
  final String plu;
  final String? name;
  final int qty;
  final String unit;
  final double unitPrice;
  /// Nákupná cena s DPH (z Excelu).
  final double? purchasePriceWithVat;
  final double? purchasePriceWithoutVat;
  final double? purchaseVatPercent;
  /// Predajná cena s DPH (z Excelu).
  final double? salePriceWithVat;
  final double? salePriceWithoutVat;
  final double? saleVatPercent;

  BulkImportRow({
    required this.plu,
    this.name,
    required this.qty,
    this.unit = 'ks',
    required this.unitPrice,
    this.purchasePriceWithVat,
    this.purchasePriceWithoutVat,
    this.purchaseVatPercent,
    this.salePriceWithVat,
    this.salePriceWithoutVat,
    this.saleVatPercent,
  });
}

/// Výsledok parsovania Excelu (pred mapovaním na produkty).
class BulkParseResult {
  final List<BulkImportRow> rows;
  final int totalDataRows;
  final int skippedRows;

  BulkParseResult({
    required this.rows,
    required this.totalDataRows,
    required this.skippedRows,
  });
}

/// Výsledok importu: zhodné položky, nezhodné riadky, súhrn a varovania.
class BulkImportResult {
  final List<InboundReceiptItem> matchedItems;
  /// Excel riadky zodpovedajúce [matchedItems] (v rovnakom poradí) – pre náhľad cien nákup/predaj a DPH.
  final List<BulkImportRow> matchedRows;
  /// Dodávateľ pre každý zhodný produkt (v rovnakom poradí ako [matchedItems]), z [Product.supplierName].
  final List<String?> matchedItemSupplierNames;
  final List<BulkImportRow> unmatchedRows;
  final String? parseError;
  /// Počet neprázdnych riadkov v súbore (vrátane hlavičky ak bola).
  final int totalDataRows;
  /// Riadky vynechané (bez PLU/názvu alebo množstvo ≤ 0).
  final int skippedRows;
  /// Súčet hodnôt zhodných položiek (qty × unitPrice).
  final double totalValue;
  /// Varovania (duplicity, záporná cena, atď.).
  final List<String> warnings;

  BulkImportResult({
    required this.matchedItems,
    List<BulkImportRow>? matchedRows,
    List<String?>? matchedItemSupplierNames,
    required this.unmatchedRows,
    this.parseError,
    this.totalDataRows = 0,
    this.skippedRows = 0,
    this.totalValue = 0,
    this.warnings = const [],
  })  : matchedRows = matchedRows ?? [],
        matchedItemSupplierNames = matchedItemSupplierNames ?? List.filled(matchedItems.length, null);

  bool get hasError => parseError != null;
  int get matchedCount => matchedItems.length;
  int get unmatchedCount => unmatchedRows.length;
}

/// Služba pre import hromadného príjmu z Excelu.
/// Očakávaný formát: prvý riadok môže byť hlavička (PLU/Kód, Názov, Množstvo, MJ, Cena).
/// Stĺpce môžu byť v ľubovoľnom poradí podľa názvov hlavičiek (case-insensitive).
class BulkReceiptImportService {
  final DatabaseService _db = DatabaseService();

  static const _headerPlu = ['plu', 'kód', 'kod', 'code', 'ean'];
  static const _headerName = ['názov', 'nazov', 'name', 'produkt', 'položka'];
  static const _headerQty = ['množstvo', 'mnozstvo', 'počet', 'pocet', 'qty', 'quantity', 'ks'];
  static const _headerUnit = ['mj', 'unit', 'jednotka'];
  static const _headerPrice = [
    'cena',
    'price',
    'cena/jedn',
    'cena za jednotku',
    'unit price',
    'nakup s dph',
    'predaj s dph',
  ];
  static const _headerPurchaseWithoutVat = ['nakup bez dph', 'nákup bez dph', 'purchase without vat'];
  static const _headerPurchaseWithVat = ['nakup s dph', 'nákup s dph', 'purchase with vat'];
  static const _headerSaleWithoutVat = ['predaj bez dph', 'predaj bez dph', 'sale without vat'];
  static const _headerSaleWithVat = ['predaj s dph', 'predaj s dph', 'sale with vat'];
  static const _headerPurchaseVat = ['nakup dph', 'nákup dph', 'purchase vat'];
  static const _headerSaleVat = ['predaj dph', 'predaj dph', 'sale vat'];
  static const _headerVat = ['dph (%)', 'dph%', 'vat'];

  /// Načíta všetky produkty pre mapovanie PLU/názov -> Product.
  Future<List<Product>> _getAllProducts() async {
    return _db.getProducts();
  }

  /// Vyparsuje Excel (prvý list) a vráti riadky so štatistikami.
  /// Prvý riadok môže byť hlavička – stĺpce sa hľadajú podľa názvov.
  BulkParseResult parseExcel(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) {
      return BulkParseResult(rows: [], totalDataRows: 0, skippedRows: 0);
    }

    final sheetName = excel.tables.keys.first;
    final sheet = excel.tables[sheetName]!;
    final rows = <BulkImportRow>[];
    int startRow = 0;
    Map<String, int>? columnIndexByHeader;
    int totalDataRows = 0;
    int skippedRows = 0;

    List<int> priceColumnIndices = [];
    if (sheet.maxRows > 0) {
      final firstRow = _getRowValues(sheet, 0);
      final headers = firstRow.map((v) => _cellToString(v).toLowerCase().trim()).toList();
      if (_looksLikeHeaderRow(headers)) {
        columnIndexByHeader = _mapHeadersToColumnIndex(headers, priceColumnIndices);
        startRow = 1;
      }
    }

    for (var r = startRow; r < sheet.maxRows; r++) {
      final rowValues = _getRowValues(sheet, r);
      if (rowValues.every((v) => v == null || _cellToString(v).trim().isEmpty)) continue;

      totalDataRows++;

      String plu = '';
      String? name;
      int qty = 0;
      String unit = 'ks';
      double unitPrice = 0.0;

      double? purchasePriceWithVat;
      double? purchasePriceWithoutVat;
      double? salePriceWithVat;
      double? salePriceWithoutVat;
      double? purchaseVatPercent;
      double? saleVatPercent;

      if (columnIndexByHeader != null) {
        plu = _cellToString(_rowValue(rowValues, columnIndexByHeader['plu'])).trim();
        name = _cellToString(_rowValue(rowValues, columnIndexByHeader['name'])).trim();
        if (name.isEmpty) name = null;
        qty = _cellToInt(_rowValue(rowValues, columnIndexByHeader['qty']));
        unit = _cellToString(_rowValue(rowValues, columnIndexByHeader['unit'])).trim();
        if (unit.isEmpty) unit = 'ks';
        unitPrice = _readPriceFromRow(rowValues, columnIndexByHeader, priceColumnIndices);
        final pWith = _cellToDouble(_rowValue(rowValues, columnIndexByHeader['purchaseWithVat']));
        if (pWith > 0) purchasePriceWithVat = pWith;
        final pWithout = _cellToDouble(_rowValue(rowValues, columnIndexByHeader['purchaseWithoutVat']));
        if (pWithout > 0) purchasePriceWithoutVat = pWithout;
        final sWith = _cellToDouble(_rowValue(rowValues, columnIndexByHeader['saleWithVat']));
        if (sWith > 0) salePriceWithVat = sWith;
        final sWithout = _cellToDouble(_rowValue(rowValues, columnIndexByHeader['saleWithoutVat']));
        if (sWithout > 0) salePriceWithoutVat = sWithout;
        final pVat = _cellToDouble(_rowValue(rowValues, columnIndexByHeader['purchaseVat']));
        if (pVat > 0) purchaseVatPercent = pVat;
        final sVat = _cellToDouble(_rowValue(rowValues, columnIndexByHeader['saleVat']));
        if (sVat > 0) saleVatPercent = sVat;
        final vat = _cellToDouble(_rowValue(rowValues, columnIndexByHeader['vat']));
        if (vat > 0) {
          purchaseVatPercent ??= vat;
          saleVatPercent ??= vat;
        }
      } else {
        if (rowValues.isNotEmpty) plu = _cellToString(rowValues[0]).trim();
        if (rowValues.length > 1) qty = _cellToInt(rowValues[1]);
        if (rowValues.length > 2) unit = _cellToString(rowValues[2]).trim();
        if (unit.isEmpty) unit = 'ks';
        if (rowValues.length > 3) unitPrice = _cellToDouble(rowValues[3]);
        if (rowValues.length > 4) name = _cellToString(rowValues[4]).trim();
        if (name != null && name.isEmpty) name = null;
      }

      if (plu.isEmpty && (name == null || name.isEmpty)) {
        skippedRows++;
        continue;
      }
      if (qty <= 0) {
        skippedRows++;
        continue;
      }

      rows.add(BulkImportRow(
        plu: plu,
        name: name,
        qty: qty,
        unit: unit,
        unitPrice: unitPrice,
        purchasePriceWithVat: purchasePriceWithVat,
        purchasePriceWithoutVat: purchasePriceWithoutVat,
        purchaseVatPercent: purchaseVatPercent,
        salePriceWithVat: salePriceWithVat,
        salePriceWithoutVat: salePriceWithoutVat,
        saleVatPercent: saleVatPercent,
      ));
    }

    return BulkParseResult(rows: rows, totalDataRows: totalDataRows, skippedRows: skippedRows);
  }

  bool _looksLikeHeaderRow(List<String> headers) {
    final h = headers.join(' ').toLowerCase();
    if (_headerPlu.any((x) => h.contains(x))) return true;
    if (_headerQty.any((x) => h.contains(x))) return true;
    if (_headerPrice.any((x) => h.contains(x))) return true;
    return false;
  }

  Map<String, int> _mapHeadersToColumnIndex(List<String> headers, List<int> priceColumnIndices) {
    final map = <String, int>{};
    priceColumnIndices.clear();
    for (var i = 0; i < headers.length; i++) {
      final h = headers[i];
      if (!map.containsKey('plu') && _headerPlu.any((x) => h.contains(x))) map['plu'] = i;
      if (!map.containsKey('name') && _headerName.any((x) => h.contains(x))) map['name'] = i;
      if (!map.containsKey('qty') && _headerQty.any((x) => h.contains(x))) map['qty'] = i;
      if (!map.containsKey('unit') && _headerUnit.any((x) => h.contains(x))) map['unit'] = i;
      if (_headerPrice.any((x) => h.contains(x))) {
        priceColumnIndices.add(i);
        if (!map.containsKey('price')) map['price'] = i;
      }
      if (!map.containsKey('purchaseWithoutVat') && _headerPurchaseWithoutVat.any((x) => h.contains(x))) map['purchaseWithoutVat'] = i;
      if (!map.containsKey('purchaseWithVat') && _headerPurchaseWithVat.any((x) => h.contains(x))) map['purchaseWithVat'] = i;
      if (!map.containsKey('saleWithoutVat') && _headerSaleWithoutVat.any((x) => h.contains(x))) map['saleWithoutVat'] = i;
      if (!map.containsKey('saleWithVat') && _headerSaleWithVat.any((x) => h.contains(x))) map['saleWithVat'] = i;
      if (!map.containsKey('purchaseVat') && _headerPurchaseVat.any((x) => h.contains(x))) map['purchaseVat'] = i;
      if (!map.containsKey('saleVat') && _headerSaleVat.any((x) => h.contains(x))) map['saleVat'] = i;
      if (!map.containsKey('vat') && _headerVat.any((x) => h.contains(x))) map['vat'] = i;
    }
    return map;
  }

  /// Prečíta cenu z riadka – skúsi hlavný stĺpec ceny, potom všetky ostatné cenové stĺpce, vráti prvú nenulovú hodnotu.
  double _readPriceFromRow(
    List<dynamic> rowValues,
    Map<String, int> columnIndexByHeader,
    List<int> priceColumnIndices,
  ) {
    final indices = priceColumnIndices.isNotEmpty
        ? priceColumnIndices
        : (columnIndexByHeader['price'] != null ? [columnIndexByHeader['price']!] : <int>[]);
    for (final i in indices) {
      final v = _cellToDouble(_rowValue(rowValues, i));
      if (v > 0) return v;
    }
    return _cellToDouble(_rowValue(rowValues, columnIndexByHeader['price']));
  }

  List<dynamic> _getRowValues(Sheet sheet, int rowIndex) {
    final row = <dynamic>[];
    for (var c = 0; c < sheet.maxColumns; c++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIndex));
      row.add(cell.value);
    }
    return row;
  }

  dynamic _rowValue(List<dynamic> rowValues, int? index) {
    if (index == null || index < 0 || index >= rowValues.length) return null;
    return rowValues[index];
  }

  String _cellToString(dynamic value) {
    if (value == null) return '';
    if (value is TextCellValue) return value.value.toString();
    if (value is IntCellValue) return value.value.toString();
    if (value is DoubleCellValue) return value.value.toString();
    return value.toString();
  }

  int _cellToInt(dynamic value) {
    if (value == null) return 0;
    if (value is IntCellValue) return value.value;
    if (value is DoubleCellValue) return value.value.toInt();
    final s = _cellToString(value).replaceAll(RegExp(r'[^\d\-]'), '');
    return int.tryParse(s) ?? 0;
  }

  double _cellToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is DoubleCellValue) return value.value;
    if (value is IntCellValue) return value.value.toDouble();
    if (value is num) return value.toDouble();
    String s = _cellToString(value).trim().replaceAll(',', '.');
    s = s.replaceAll(RegExp(r'[^\d.\-]'), '');
    return double.tryParse(s) ?? 0.0;
  }

  /// Pre príjemku vráti nákupnú cenu (s DPH) z riadka; ak v Exceli nie je, fallback na [row.unitPrice].
  double _effectivePurchasePriceWithVat(BulkImportRow row) {
    if (row.purchasePriceWithVat != null && row.purchasePriceWithVat! > 0) {
      return row.purchasePriceWithVat!;
    }
    if (row.purchasePriceWithoutVat != null &&
        row.purchasePriceWithoutVat! > 0 &&
        row.purchaseVatPercent != null &&
        row.purchaseVatPercent! > 0) {
      return row.purchasePriceWithoutVat! * (1 + row.purchaseVatPercent! / 100);
    }
    return row.unitPrice >= 0 ? row.unitPrice : 0.0;
  }

  /// Nájde produkt podľa PLU alebo názvu (prvý zhodný).
  Product? _findProduct(List<Product> products, BulkImportRow row) {
    if (row.plu.isNotEmpty) {
      final byPlu = products.where((p) =>
          p.plu.trim().toLowerCase() == row.plu.toLowerCase()).toList();
      if (byPlu.isNotEmpty) return byPlu.first;
      final byUniqueId = products.where((p) =>
          p.uniqueId?.trim().toLowerCase() == row.plu.trim().toLowerCase()).toList();
      if (byUniqueId.isNotEmpty) return byUniqueId.first;
    }
    if (row.name != null && row.name!.trim().isNotEmpty) {
      final byName = products.where((p) =>
          p.name.trim().toLowerCase() == row.name!.trim().toLowerCase()).toList();
      if (byName.isNotEmpty) return byName.first;
    }
    return null;
  }

  /// Stĺpce šablóny zhodné s produktom a skladovými zásobami (warehouse supplies).
  static const List<String> _templateHeaders = [
    'PLU (Kód)',
    'Názov tovaru',
    'Kategória',
    'Množstvo',
    'MJ',
    'Cena',
    'Predaj bez DPH',
    'Predaj s DPH',
    'Marža (%)',
    'DPH (%)',
    'DPH (€)',
    'Zľava (%)',
    'Nákup bez DPH',
    'Nákup s DPH',
    'Nákup DPH (%)',
    'Recykl. popl.',
    'Posl. dátum nákupu',
    'Posledný nákup bez DPH',
    'Dodávateľ',
    'Mená',
    'Typ',
    'Lokácia',
  ];

  /// Vygeneruje Excel šablónu pre import príjemky so všetkými stĺpcami ako v produktoch / skladových zásobách.
  Uint8List buildImportTemplate() {
    final excel = Excel.createExcel();
    const sheetName = 'Import príjemky';
    final sheet = excel[sheetName];

    // Hlavička – všetky stĺpce
    for (var c = 0; c < _templateHeaders.length; c++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
          .value = TextCellValue(_templateHeaders[c]);
    }

    // Príklad riadok 1 (povinné pre import: PLU, Názov, Množstvo, MJ, Cena)
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value = TextCellValue('12345');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 1)).value = TextCellValue('Príklad produkt 1');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 1)).value = TextCellValue('Kategória A');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 1)).value = IntCellValue(10);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 1)).value = TextCellValue('ks');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 1)).value = DoubleCellValue(2.50);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: 1)).value = DoubleCellValue(2.03);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: 1)).value = DoubleCellValue(2.50);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: 1)).value = DoubleCellValue(18.8);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: 1)).value = IntCellValue(23);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: 1)).value = DoubleCellValue(0.47);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: 1)).value = IntCellValue(0);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: 1)).value = DoubleCellValue(2.03);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 13, rowIndex: 1)).value = DoubleCellValue(2.50);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 14, rowIndex: 1)).value = IntCellValue(23);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 15, rowIndex: 1)).value = DoubleCellValue(0);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 16, rowIndex: 1)).value = TextCellValue('22.02.2025');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 17, rowIndex: 1)).value = DoubleCellValue(2.03);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 18, rowIndex: 1)).value = TextCellValue('Dodávateľ s.r.o.');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 19, rowIndex: 1)).value = TextCellValue('EUR');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 20, rowIndex: 1)).value = TextCellValue('Sklad');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 21, rowIndex: 1)).value = TextCellValue('Polička A1');

    // Príklad riadok 2
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2)).value = TextCellValue('67890');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 2)).value = TextCellValue('Príklad produkt 2');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 2)).value = TextCellValue('Kategória B');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 2)).value = IntCellValue(5);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 2)).value = TextCellValue('kg');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 2)).value = DoubleCellValue(12.00);

    excel.setDefaultSheet(sheetName);
    final saved = excel.save();
    if (saved == null) throw Exception('Excel save failed');
    return Uint8List.fromList(saved);
  }

  /// Spracuje import: parsuje Excel, vykoná kontrolu a namapuje riadky na položky príjemky.
  Future<BulkImportResult> importFromExcel(Uint8List bytes) async {
    BulkParseResult parseResult;
    try {
      parseResult = parseExcel(bytes);
    } catch (e) {
      return BulkImportResult(
        matchedItems: [],
        unmatchedRows: [],
        parseError: e.toString(),
      );
    }
    final rows = parseResult.rows;
    if (rows.isEmpty) {
      return BulkImportResult(
        matchedItems: [],
        unmatchedRows: [],
        parseError: 'Excel neobsahuje žiadne platné riadky.',
        totalDataRows: parseResult.totalDataRows,
        skippedRows: parseResult.skippedRows,
      );
    }

    final products = await _getAllProducts();
    final matchedItems = <InboundReceiptItem>[];
    final matchedRows = <BulkImportRow>[];
    final matchedSupplierNames = <String?>[];
    final unmatchedRows = <BulkImportRow>[];
    final warnings = <String>[];

    for (final row in rows) {
      if (row.unitPrice < 0) {
        warnings.add('Záporná cena: ${row.plu.isNotEmpty ? row.plu : row.name ?? "?"} (riadok sa zahrnie s cenou 0)');
      }
      final product = _findProduct(products, row);
      if (product != null && product.uniqueId != null) {
        final unitPrice = _effectivePurchasePriceWithVat(row);
        final fallbackPrice = unitPrice > 0 ? unitPrice : product.purchasePrice;
        matchedItems.add(InboundReceiptItem(
          id: null,
          receiptId: 0,
          productUniqueId: product.uniqueId!,
          productName: product.name,
          plu: product.plu,
          qty: row.qty,
          unit: row.unit.isNotEmpty ? row.unit : product.unit,
          unitPrice: fallbackPrice,
        ));
        matchedRows.add(row);
        matchedSupplierNames.add(product.supplierName);
      } else {
        unmatchedRows.add(row);
      }
    }

    // Duplicitný produkt v zozname (rovnaký PLU viackrát)
    final seenIds = <String>{};
    for (final item in matchedItems) {
      if (!seenIds.add(item.productUniqueId)) {
        warnings.add('Duplicitný produkt v súbore: ${item.plu} – ${item.productName}');
      }
    }

    double totalValue = 0;
    for (final item in matchedItems) {
      totalValue += item.qty * item.unitPrice;
    }
    for (final row in unmatchedRows) {
      final price = row.unitPrice >= 0 ? row.unitPrice : 0.0;
      totalValue += row.qty * price;
    }

    return BulkImportResult(
      matchedItems: matchedItems,
      matchedRows: matchedRows,
      matchedItemSupplierNames: matchedSupplierNames,
      unmatchedRows: unmatchedRows,
      totalDataRows: parseResult.totalDataRows,
      skippedRows: parseResult.skippedRows,
      totalValue: totalValue,
      warnings: warnings,
    );
  }

  /// Vytvorí nové produkty z nezhodných riadkov a vráti položky príjemky pre ne.
  /// [warehouseId] – sklad pre nové produkty; ak null, použije sa prvý dostupný sklad.
  Future<List<InboundReceiptItem>> createProductsFromUnmatchedRows(
    List<BulkImportRow> rows, {
    int? warehouseId,
  }) async {
    if (rows.isEmpty) return [];
    int? targetWarehouseId = warehouseId;
    if (targetWarehouseId == null) {
      final warehouses = await _db.getWarehouses();
      if (warehouses.isNotEmpty) targetWarehouseId = warehouses.first.id;
    }
    final productService = ProductService();
    final items = <InboundReceiptItem>[];
    final baseId = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final productName = (row.name != null && row.name!.trim().isNotEmpty)
          ? row.name!.trim()
          : (row.plu.trim().isNotEmpty ? row.plu : 'Produkt ${i + 1}');
      final productPlu = row.plu.trim().isNotEmpty ? row.plu : 'IMP-$baseId-$i';
      final uniqueId = 'import-$baseId-$i';
      final purchaseWithVat = _effectivePurchasePriceWithVat(row);
      final unitPrice = purchaseWithVat >= 0 ? purchaseWithVat : 0.0;
      final purchaseVatPct = row.purchaseVatPercent ?? 23.0;
      final withoutVat = purchaseVatPct > 0 ? unitPrice / (1 + purchaseVatPct / 100) : unitPrice / 1.23;
      final withVat = unitPrice;
      final now = DateTime.now();
      final dateStr = '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';
      final product = Product(
        uniqueId: uniqueId,
        name: productName,
        plu: productPlu,
        category: '',
        qty: 0,
        unit: row.unit.isNotEmpty ? row.unit : 'ks',
        price: row.salePriceWithVat ??
            ((row.salePriceWithoutVat != null && row.saleVatPercent != null)
                ? row.salePriceWithoutVat! * (1 + row.saleVatPercent! / 100)
                : null) ?? withVat,
        withoutVat: row.salePriceWithoutVat ??
            ((row.salePriceWithVat != null && row.saleVatPercent != null)
                ? row.salePriceWithVat! / (1 + row.saleVatPercent! / 100)
                : null) ?? withoutVat,
        vat: (row.saleVatPercent ?? row.purchaseVatPercent)?.round() ?? 23,
        discount: 0,
        lastPurchasePrice: withVat,
        lastPurchasePriceWithoutVat: withoutVat,
        lastPurchaseDate: dateStr,
        currency: 'EUR',
        location: '',
        purchasePrice: withVat,
        purchasePriceWithoutVat: withoutVat,
        purchaseVat: purchaseVatPct.round(),
        warehouseId: targetWarehouseId,
      );
      await productService.createProduct(product);
      items.add(InboundReceiptItem(
        id: null,
        receiptId: 0,
        productUniqueId: uniqueId,
        productName: productName,
        plu: productPlu,
        qty: row.qty,
        unit: row.unit.isNotEmpty ? row.unit : 'ks',
        unitPrice: unitPrice,
      ));
    }
    return items;
  }
}
