import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/warehouse.dart';
import '../../models/product.dart';
import '../Database/database_service.dart';

/// Generuje a zdieľa report skladu v PDF alebo Excel formáte.
class WarehouseReportService {
  final DatabaseService _db = DatabaseService();

  static String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  /// Načíta produkty daného skladu.
  Future<List<Product>> getProductsForWarehouse(Warehouse warehouse) async {
    if (warehouse.id == null) return [];
    return _db.getProductsByWarehouseId(warehouse.id!);
  }

  /// Vygeneruje PDF report: hlavička StockPilot, názov skladu, dátum, tabuľka produktov a počtu.
  Future<Uint8List> buildPdf({
    required Warehouse warehouse,
    required List<Product> products,
    String productColumnLabel = 'Produkt',
    String quantityColumnLabel = 'Počet',
  }) async {
    final baseFont = await PdfGoogleFonts.openSansRegular();
    final boldFont = await PdfGoogleFonts.openSansBold();
    final theme = pw.ThemeData.withFont(base: baseFont, bold: boldFont);
    final doc = pw.Document(theme: theme);

    final now = DateTime.now();
    final headerChildren = <pw.Widget>[
      pw.Text(
        'StockPilot',
        style: pw.TextStyle(
          fontSize: 22,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.blue900,
        ),
      ),
      pw.SizedBox(height: 12),
      pw.Text(
        warehouse.name,
        style: pw.TextStyle(
          fontSize: 16,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
      pw.SizedBox(height: 6),
      pw.Text(
        'Dátum: ${_formatDate(now)}',
        style: const pw.TextStyle(fontSize: 11),
      ),
    ];

    final tableRows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey300),
        children: [
          _cell(productColumnLabel, bold: true),
          _cell(quantityColumnLabel, bold: true),
        ],
      ),
      ...products.map((p) => pw.TableRow(
            children: [
              _cell(p.name),
              _cell('${p.qty}'),
            ],
          )),
    ];

    if (products.isEmpty) {
      tableRows.add(
        pw.TableRow(
          children: [
            _cell('–'),
            _cell('–'),
          ],
        ),
      );
    }

    final pageChildren = <pw.Widget>[
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: headerChildren,
      ),
      pw.SizedBox(height: 20),
      pw.Table(
        border: pw.TableBorder.all(width: 0.5),
        columnWidths: {
          0: const pw.FlexColumnWidth(4),
          1: const pw.FlexColumnWidth(1),
        },
        children: tableRows,
      ),
    ];

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => pageChildren,
      ),
    );

    return doc.save();
  }

  static pw.Widget _cell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        maxLines: 2,
        overflow: pw.TextOverflow.clip,
      ),
    );
  }

  /// Vygeneruje Excel report: názov skladu, dátum, tabuľka produktov a počtu.
  Future<Uint8List> buildExcel({
    required Warehouse warehouse,
    required List<Product> products,
    String productColumnLabel = 'Produkt',
    String quantityColumnLabel = 'Počet',
  }) async {
    final excel = Excel.createExcel();
    final sheetName = _sanitizeSheetName(warehouse.name);
    final sheet = excel[sheetName];

    final now = DateTime.now();
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('StockPilot');
    sheet.cell(CellIndex.indexByString('A2')).value = TextCellValue(warehouse.name);
    sheet.cell(CellIndex.indexByString('A3')).value = TextCellValue('Dátum: ${_formatDate(now)}');

    sheet.cell(CellIndex.indexByString('A5')).value = TextCellValue(productColumnLabel);
    sheet.cell(CellIndex.indexByString('B5')).value = TextCellValue(quantityColumnLabel);

    for (var i = 0; i < products.length; i++) {
      final row = 6 + i;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value =
          TextCellValue(products[i].name);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value =
          IntCellValue(products[i].qty.round());
    }

    excel.setDefaultSheet(sheetName);
    final saved = excel.save();
    if (saved == null) throw Exception('Excel save failed');
    return Uint8List.fromList(saved);
  }

  static String _sanitizeSheetName(String name) {
    var s = name.replaceAll(RegExp(r'[\\/*?:\[\]]'), '_');
    if (s.length > 31) s = s.substring(0, 31);
    return s.isEmpty ? 'Report' : s;
  }

  /// Zdieľa PDF cez natívny share sheet (Printing.sharePdf).
  Future<void> sharePdf({required Uint8List bytes, required String filename}) async {
    try {
      await Printing.sharePdf(bytes: bytes, filename: filename);
    } on MissingPluginException {
      await _shareViaFile(bytes: bytes, filename: filename, mimeType: 'application/pdf');
    }
  }

  /// Uloží súbor do temp adresára a zdieľa cez share_plus.
  Future<void> shareExcel({required Uint8List bytes, required String filename}) async {
    await _shareViaFile(
      bytes: bytes,
      filename: filename,
      mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  Future<void> _shareViaFile({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/$filename';
    final file = File(path);
    await file.writeAsBytes(bytes);
    await Share.shareXFiles(
      [XFile(path, mimeType: mimeType)],
      subject: filename,
    );
  }
}
