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

  /// Konvertuje ISO dátum "YYYY-MM-DD" na "DD.MM.YYYY" pre PDF.
  static String _formatExpiry(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final parts = iso.split('-');
    if (parts.length == 3) return '${parts[2]}.${parts[1]}.${parts[0]}';
    return iso;
  }

  /// Vráti PDF ako bajty.
  /// [issuedBy] = meno prihláseného používateľa (vystavil); ak null, použije sa stockOut.username.
  /// [documentTitle] = nadpis: 'Výdajka' alebo 'Dodací list' (rovnaké dáta).
  /// [hidePrices] = true pre verziu bez cien (napr. pre kuriéra).
  static Future<Uint8List> buildPdf({
    required StockOut stockOut,
    required List<StockOutItem> items,
    String? issuedBy,
    String documentTitle = 'VÝDAJKA TOVARU',
    bool hidePrices = false,
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

    final hasBatch = items.any((i) => i.batchNumber != null && i.batchNumber!.isNotEmpty);
    final hasExpiry = items.any((i) => i.expiryDate != null && i.expiryDate!.isNotEmpty);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                documentTitle.toUpperCase(),
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
          _buildItemsTable(items, hidePrices: hidePrices, hasBatch: hasBatch, hasExpiry: hasExpiry),
          if (!hidePrices) ...[
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
          ],
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

  static pw.Widget _buildItemsTable(
    List<StockOutItem> items, {
    required bool hidePrices,
    required bool hasBatch,
    required bool hasExpiry,
  }) {
    if (hidePrices) {
      int ci = 0;
      final colW = <int, pw.TableColumnWidth>{
        ci++: const pw.FlexColumnWidth(3),
        if (hasBatch) ci++: const pw.FlexColumnWidth(0.9),
        if (hasExpiry) ci++: const pw.FlexColumnWidth(0.9),
        ci++: const pw.FlexColumnWidth(0.6),
        ci: const pw.FlexColumnWidth(0.5),
      };
      return pw.Table(
        border: pw.TableBorder.all(width: 0.5),
        columnWidths: colW,
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey300),
            children: [
              _cell('Položka / PLU', bold: true),
              if (hasBatch) _cell('Šarža', bold: true),
              if (hasExpiry) _cell('Expirácia', bold: true),
              _cell('Mn.', bold: true),
              _cell('MJ', bold: true),
            ],
          ),
          ...items.map((item) {
            final name = item.productName ?? item.productUniqueId;
            final plu = item.plu != null && item.plu!.isNotEmpty ? ' (${item.plu})' : '';
            return pw.TableRow(
              children: [
                _cell('$name$plu'),
                if (hasBatch) _cell(item.batchNumber ?? ''),
                if (hasExpiry) _cell(_formatExpiry(item.expiryDate)),
                _cell('${item.qty}'),
                _cell(item.unit),
              ],
            );
          }),
        ],
      );
    } else {
      int ci = 0;
      final colW = <int, pw.TableColumnWidth>{
        ci++: const pw.FlexColumnWidth(3),
        if (hasBatch) ci++: const pw.FlexColumnWidth(0.9),
        if (hasExpiry) ci++: const pw.FlexColumnWidth(0.9),
        ci++: const pw.FlexColumnWidth(0.6),
        ci++: const pw.FlexColumnWidth(0.5),
        ci++: const pw.FlexColumnWidth(1),
        ci: const pw.FlexColumnWidth(1),
      };
      return pw.Table(
        border: pw.TableBorder.all(width: 0.5),
        columnWidths: colW,
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey300),
            children: [
              _cell('Položka / PLU', bold: true),
              if (hasBatch) _cell('Šarža', bold: true),
              if (hasExpiry) _cell('Expirácia', bold: true),
              _cell('Mn.', bold: true),
              _cell('MJ', bold: true),
              _cell('Cena za MJ', bold: true),
              _cell('Celkom', bold: true),
            ],
          ),
          ...items.map((item) {
            final lineTotal = (item.unitPrice * item.qty * 100).round() / 100;
            final name = item.productName ?? item.productUniqueId;
            final plu = item.plu != null && item.plu!.isNotEmpty ? ' (${item.plu})' : '';
            return pw.TableRow(
              children: [
                _cell('$name$plu'),
                if (hasBatch) _cell(item.batchNumber ?? ''),
                if (hasExpiry) _cell(_formatExpiry(item.expiryDate)),
                _cell('${item.qty}'),
                _cell(item.unit),
                _cell(_formatPrice(item.unitPrice)),
                _cell(_formatPrice(lineTotal)),
              ],
            );
          }),
        ],
      );
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
