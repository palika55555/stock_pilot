import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/company.dart';
import '../../models/monthly_closure.dart';
import '../Database/database_service.dart';

/// PDF report zoznamu mesačných uzávierok (tlač / zdieľanie).
class MonthlyClosuresReportService {
  final DatabaseService _db = DatabaseService();

  Future<List<MonthlyClosure>> loadClosures() => _db.getMonthlyClosures();

  Future<Company?> loadCompany() => _db.getCompany();

  static String _formatDay(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  static String _formatDateTime(DateTime d) =>
      DateFormat('dd.MM.yyyy HH:mm').format(d.toLocal());

  /// Vygeneruje PDF – tabuľka uzavretých mesiacov.
  Future<Uint8List> buildPdf(
    List<MonthlyClosure> closures, {
    Company? company,
  }) async {
    final baseFont = await PdfGoogleFonts.openSansRegular();
    final boldFont = await PdfGoogleFonts.openSansBold();
    final theme = pw.ThemeData.withFont(base: baseFont, bold: boldFont);
    final doc = pw.Document(theme: theme);

    final now = DateTime.now();
    final companyLine = (company?.name ?? '').trim().isEmpty
        ? null
        : company!.name.trim();

    final header = <pw.Widget>[
      pw.Text(
        'StockPilot',
        style: pw.TextStyle(
          fontSize: 22,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.blue900,
        ),
      ),
      pw.SizedBox(height: 8),
      pw.Text(
        'Report: Mesačné uzávierky',
        style: pw.TextStyle(
          fontSize: 16,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
      if (companyLine != null) ...[
        pw.SizedBox(height: 4),
        pw.Text(companyLine, style: const pw.TextStyle(fontSize: 11)),
      ],
      pw.SizedBox(height: 6),
      pw.Text(
        'Vygenerované: ${_formatDay(now)}',
        style: const pw.TextStyle(fontSize: 11),
      ),
      pw.SizedBox(height: 4),
      pw.Text(
        'Počet záznamov: ${closures.length}',
        style: const pw.TextStyle(fontSize: 11),
      ),
    ];

    final tableRows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey300),
        children: [
          _cell('Obdobie (mesiac)', bold: true),
          _cell('Dátum uzavretia', bold: true),
          _cell('Kto', bold: true),
          _cell('Poznámka', bold: true),
        ],
      ),
      ...closures.map(
        (c) => pw.TableRow(
          children: [
            _cell(c.yearMonth),
            _cell(_formatDateTime(c.closedAt)),
            _cell(c.closedBy ?? '–'),
            _cell((c.notes ?? '').trim().isEmpty ? '–' : c.notes!.trim()),
          ],
        ),
      ),
    ];

    if (closures.isEmpty) {
      tableRows.add(
        pw.TableRow(
          children: [
            _cell('Žiadny uzavretý mesiac', bold: false),
            _cell('–'),
            _cell('–'),
            _cell('–'),
          ],
        ),
      );
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: header,
          ),
          pw.SizedBox(height: 20),
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.2),
              1: const pw.FlexColumnWidth(1.4),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(2.2),
            },
            children: tableRows,
          ),
        ],
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
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        maxLines: 4,
        overflow: pw.TextOverflow.clip,
      ),
    );
  }

  String _filename() {
    final d = DateTime.now();
    return 'mesacne_uzavierky_${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}.pdf';
  }

  Future<void> sharePdf(Uint8List bytes) async {
    await Printing.sharePdf(bytes: bytes, filename: _filename());
  }
}
