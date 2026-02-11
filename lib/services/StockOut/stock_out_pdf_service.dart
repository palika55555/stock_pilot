import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/stock_out.dart';

/// Generuje PDF výdajky (stock-out / issue note) pre tlač alebo uloženie.
class StockOutPdfService {
  static String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  static String _formatPrice(double v) =>
      v.toStringAsFixed(2).replaceAll('.', ',');

  /// Vráti PDF ako bajty. [issuedBy] = meno prihláseného používateľa (vystavil); ak null, použije sa stockOut.username.
  static Future<Uint8List> buildPdf({
    required StockOut stockOut,
    required List<StockOutItem> items,
    String? issuedBy,
  }) async {
    final baseFont = await PdfGoogleFonts.openSansRegular();
    final boldFont = await PdfGoogleFonts.openSansBold();
    final theme = pw.ThemeData.withFont(base: baseFont, bold: boldFont);
    final doc = pw.Document(theme: theme);

    double total = 0;
    for (final item in items) {
      total += item.unitPrice * item.qty;
    }
    total = (total * 100).round() / 100;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'VÝDAJKA TOVARU',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                stockOut.documentNumber,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Text(
                'Dátum výdajky: ${_formatDate(stockOut.createdAt)}',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.Text(
                'Dátum tlače: ${_formatDate(DateTime.now())}',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
              pw.Text(
                'Typ výdaja: ${stockOut.issueType.label}',
                style: const pw.TextStyle(fontSize: 10),
              ),
              if (stockOut.recipientName != null &&
                  stockOut.recipientName!.trim().isNotEmpty) ...[
                pw.SizedBox(height: 6),
                pw.Text(
                  'Odberateľ / účel:',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  stockOut.recipientName!.trim(),
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
              if (stockOut.notes != null &&
                  stockOut.notes!.trim().isNotEmpty) ...[
                pw.SizedBox(height: 8),
                pw.Text(
                  'Poznámka:',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  stockOut.notes!.trim(),
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
              if (stockOut.isZeroVat)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 6),
                  child: pw.Text(
                    'Výdaj za 0 % DPH',
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey700,
                    ),
                  ),
                ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Stav: ${_statusLabel(stockOut.status)}',
                style: pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Vystavil: ${stockOut.username ?? issuedBy ?? '–'}',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(0.6),
              2: const pw.FlexColumnWidth(0.5),
              3: const pw.FlexColumnWidth(1),
              4: const pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  StockOutPdfService._cell('Položka / PLU', bold: true),
                  StockOutPdfService._cell('Mn.', bold: true),
                  StockOutPdfService._cell('MJ', bold: true),
                  StockOutPdfService._cell('Cena za MJ', bold: true),
                  StockOutPdfService._cell('Celkom', bold: true),
                ],
              ),
              ...items.map((item) {
                final lineTotal =
                    (item.unitPrice * item.qty * 100).round() / 100;
                final name = item.productName ?? item.productUniqueId;
                final plu = item.plu != null && item.plu!.isNotEmpty
                    ? ' (${item.plu})'
                    : '';
                return pw.TableRow(
                  children: [
                    StockOutPdfService._cell('$name$plu'),
                    StockOutPdfService._cell('${item.qty}'),
                    StockOutPdfService._cell(item.unit),
                    StockOutPdfService._cell(_formatPrice(item.unitPrice)),
                    StockOutPdfService._cell(_formatPrice(lineTotal)),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Spolu: ${_formatPrice(total)} €',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 28),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Podpis odberateľa',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Container(
                      width: double.infinity,
                      height: 1,
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey400,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      '(meno a podpis)',
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 40),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Dátum prevzatia',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Container(
                      width: double.infinity,
                      height: 1,
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return doc.save();
  }

  static String _statusLabel(StockOutStatus status) {
    switch (status) {
      case StockOutStatus.rozpracovany:
        return 'Rozpracovaný';
      case StockOutStatus.vykazana:
        return 'Vykázaná';
      case StockOutStatus.schvalena:
        return 'Schválená';
      case StockOutStatus.stornovana:
        return 'Stornovaná';
    }
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
        maxLines: 3,
        overflow: pw.TextOverflow.clip,
      ),
    );
  }
}
