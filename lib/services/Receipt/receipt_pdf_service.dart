import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/receipt.dart';

/// Generuje PDF príjemky (inbound receipt) pre tlač alebo uloženie.
class ReceiptPdfService {
  static String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  static String _formatPrice(double v) =>
      v.toStringAsFixed(2).replaceAll('.', ',');

  /// Vráti PDF ako bajty. Používa Unicode font (Open Sans) z balíka printing pre slovenskú diakritiku a €.
  static Future<Uint8List> buildPdf({
    required InboundReceipt receipt,
    required List<InboundReceiptItem> items,
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
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'PRÍJEMKA TOVARU',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      receipt.receiptNumber,
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 12),
                    pw.Text(
                      'Dátum: ${_formatDate(receipt.createdAt)}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    if (receipt.invoiceNumber != null &&
                        receipt.invoiceNumber!.isNotEmpty)
                      pw.Text(
                        'Faktúra: ${receipt.invoiceNumber}',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    if (receipt.supplierName != null &&
                        receipt.supplierName!.isNotEmpty) ...[
                      pw.SizedBox(height: 6),
                      pw.Text(
                        'Dodávateľ:',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        receipt.supplierName!,
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                    if (receipt.notes != null &&
                        receipt.notes!.trim().isNotEmpty) ...[
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'Poznámka:',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        receipt.notes!.trim(),
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                    pw.SizedBox(height: 4),
                    pw.Text(
                      receipt.pricesIncludeVat
                          ? 'Ceny sú s DPH'
                          : 'Ceny sú bez DPH',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
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
                  ReceiptPdfService._cell('Položka / PLU', bold: true),
                  ReceiptPdfService._cell('Mn.', bold: true),
                  ReceiptPdfService._cell('MJ', bold: true),
                  ReceiptPdfService._cell('Cena za MJ', bold: true),
                  ReceiptPdfService._cell('Celkom', bold: true),
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
                    ReceiptPdfService._cell('$name$plu'),
                    ReceiptPdfService._cell('${item.qty}'),
                    ReceiptPdfService._cell(item.unit),
                    ReceiptPdfService._cell(_formatPrice(item.unitPrice)),
                    ReceiptPdfService._cell(_formatPrice(lineTotal)),
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
        maxLines: 3,
        overflow: pw.TextOverflow.clip,
      ),
    );
  }
}
