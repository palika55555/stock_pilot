import 'dart:typed_data';
import 'package:excel/excel.dart';
import '../../models/product.dart';
import '../../models/receipt.dart';
import '../Database/database_service.dart';

/// Jeden riadok z Excelu pred mapovaním na produkt.
class BulkImportRow {
  final String plu;
  final String? name;
  final int qty;
  final String unit;
  final double unitPrice;

  BulkImportRow({
    required this.plu,
    this.name,
    required this.qty,
    this.unit = 'ks',
    required this.unitPrice,
  });
}

/// Výsledok importu: zhodné položky a nezhodné riadky.
class BulkImportResult {
  final List<InboundReceiptItem> matchedItems;
  final List<BulkImportRow> unmatchedRows;
  final String? parseError;

  BulkImportResult({
    required this.matchedItems,
    required this.unmatchedRows,
    this.parseError,
  });

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
  static const _headerPrice = ['cena', 'price', 'cena/jedn', 'cena za jednotku', 'unit price'];

  /// Načíta všetky produkty pre mapovanie PLU/názov -> Product.
  Future<List<Product>> _getAllProducts() async {
    return _db.getProducts();
  }

  /// Vyparsuje Excel (prvý list) a vráti riadky ako [BulkImportRow].
  /// Prvý riadok môže byť hlavička – stĺpce sa hľadajú podľa názvov.
  List<BulkImportRow> parseExcel(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) return [];

    final sheetName = excel.tables.keys.first;
    final sheet = excel.tables[sheetName]!;
    final rows = <BulkImportRow>[];
    int startRow = 0;
    Map<String, int>? columnIndexByHeader;

    if (sheet.maxRows > 0) {
      final firstRow = _getRowValues(sheet, 0);
      final headers = firstRow.map((v) => _cellToString(v).toLowerCase().trim()).toList();
      if (_looksLikeHeaderRow(headers)) {
        columnIndexByHeader = _mapHeadersToColumnIndex(headers);
        startRow = 1;
      }
    }

    for (var r = startRow; r < sheet.maxRows; r++) {
      final rowValues = _getRowValues(sheet, r);
      if (rowValues.every((v) => v == null || _cellToString(v).trim().isEmpty)) continue;

      String plu = '';
      String? name;
      int qty = 0;
      String unit = 'ks';
      double unitPrice = 0.0;

      if (columnIndexByHeader != null) {
        plu = _cellToString(rowValues[columnIndexByHeader['plu'] ?? -1]).trim();
        name = _cellToString(rowValues[columnIndexByHeader['name'] ?? -1]).trim();
        if (name.isEmpty) name = null;
        qty = _cellToInt(rowValues[columnIndexByHeader['qty'] ?? -1]);
        unit = _cellToString(rowValues[columnIndexByHeader['unit'] ?? -1]).trim();
        if (unit.isEmpty) unit = 'ks';
        unitPrice = _cellToDouble(rowValues[columnIndexByHeader['price'] ?? -1]);
      } else {
        if (rowValues.isNotEmpty) plu = _cellToString(rowValues[0]).trim();
        if (rowValues.length > 1) qty = _cellToInt(rowValues[1]);
        if (rowValues.length > 2) unit = _cellToString(rowValues[2]).trim();
        if (unit.isEmpty) unit = 'ks';
        if (rowValues.length > 3) unitPrice = _cellToDouble(rowValues[3]);
        if (rowValues.length > 4) name = _cellToString(rowValues[4]).trim();
        if (name != null && name.isEmpty) name = null;
      }

      if (plu.isEmpty && (name == null || name.isEmpty)) continue;
      if (qty <= 0) continue;

      rows.add(BulkImportRow(
        plu: plu,
        name: name,
        qty: qty,
        unit: unit,
        unitPrice: unitPrice,
      ));
    }

    return rows;
  }

  bool _looksLikeHeaderRow(List<String> headers) {
    final h = headers.join(' ').toLowerCase();
    if (_headerPlu.any((x) => h.contains(x))) return true;
    if (_headerQty.any((x) => h.contains(x))) return true;
    if (_headerPrice.any((x) => h.contains(x))) return true;
    return false;
  }

  Map<String, int> _mapHeadersToColumnIndex(List<String> headers) {
    final map = <String, int>{};
    for (var i = 0; i < headers.length; i++) {
      final h = headers[i];
      if (_headerPlu.any((x) => h.contains(x))) map['plu'] = i;
      if (_headerName.any((x) => h.contains(x))) map['name'] = i;
      if (_headerQty.any((x) => h.contains(x))) map['qty'] = i;
      if (_headerUnit.any((x) => h.contains(x))) map['unit'] = i;
      if (_headerPrice.any((x) => h.contains(x))) map['price'] = i;
    }
    return map;
  }

  List<dynamic> _getRowValues(Sheet sheet, int rowIndex) {
    final row = <dynamic>[];
    for (var c = 0; c < sheet.maxColumns; c++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIndex));
      row.add(cell.value);
    }
    return row;
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
    final s = _cellToString(value).replaceAll(',', '.');
    return double.tryParse(s) ?? 0.0;
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

  /// Spracuje import: parsuje Excel a namapuje riadky na položky príjemky.
  /// [receiptId] je dočasne 0 – pri vytváraní príjemky sa nepoužíva, položky sa vytvoria s reálnym receiptId.
  Future<BulkImportResult> importFromExcel(Uint8List bytes) async {
    List<BulkImportRow> rows;
    try {
      rows = parseExcel(bytes);
    } catch (e) {
      return BulkImportResult(
        matchedItems: [],
        unmatchedRows: [],
        parseError: e.toString(),
      );
    }
    if (rows.isEmpty) {
      return BulkImportResult(
        matchedItems: [],
        unmatchedRows: [],
        parseError: 'Excel neobsahuje žiadne platné riadky.',
      );
    }

    final products = await _getAllProducts();
    final matchedItems = <InboundReceiptItem>[];
    final unmatchedRows = <BulkImportRow>[];

    for (final row in rows) {
      final product = _findProduct(products, row);
      if (product != null && product.uniqueId != null) {
        matchedItems.add(InboundReceiptItem(
          id: null,
          receiptId: 0,
          productUniqueId: product.uniqueId!,
          productName: product.name,
          plu: product.plu,
          qty: row.qty,
          unit: row.unit.isNotEmpty ? row.unit : product.unit,
          unitPrice: row.unitPrice >= 0 ? row.unitPrice : product.purchasePrice,
        ));
      } else {
        unmatchedRows.add(row);
      }
    }

    return BulkImportResult(
      matchedItems: matchedItems,
      unmatchedRows: unmatchedRows,
    );
  }
}
