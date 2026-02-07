import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/company.dart';
import '../../models/customer.dart';
import '../../models/quote.dart';

/// Generuje PDF cenovej ponuky pre tlač alebo uloženie.
class QuotePdfService {
  static String _formatDate(DateTime d) => '${d.day}.${d.month}.${d.year}';
  static String _formatPrice(double v) =>
      v.toStringAsFixed(2).replaceAll('.', ',');

  /// Vráti PDF ako bajty. [logoBytes] môže byť null; ak je zadané, zobrazí sa ako logo v hlavičke.
  /// Používa Unicode font (Open Sans) pre správne zobrazenie slovenskej diakritiky a €.
  static Future<Uint8List> buildPdf({
    required Quote quote,
    required List<QuoteItem> items,
    required Customer customer,
    Company? company,
    Uint8List? logoBytes,
  }) async {
    final baseFont = await PdfGoogleFonts.openSansRegular();
    final boldFont = await PdfGoogleFonts.openSansBold();
    final theme = pw.ThemeData.withFont(base: baseFont, bold: boldFont);
    final pdf = pw.Document(theme: theme);
    final bool pricesIncludeVat = quote.pricesIncludeVat;

    double subtotalWithoutVat = 0;
    double totalVat = 0;
    double totalWithVat = 0;
    for (final item in items) {
      subtotalWithoutVat += item.getLineTotalWithoutVat(pricesIncludeVat);
      totalVat +=
          item.getLineTotalWithVat(pricesIncludeVat) -
          item.getLineTotalWithoutVat(pricesIncludeVat);
      totalWithVat += item.getLineTotalWithVat(pricesIncludeVat);
    }
    subtotalWithoutVat = (subtotalWithoutVat * 100).round() / 100;
    totalVat = (totalVat * 100).round() / 100;
    totalWithVat = (totalWithVat * 100).round() / 100;

    pw.Widget? logoWidget;
    if (logoBytes != null && logoBytes.isNotEmpty) {
      try {
        logoWidget = pw.Image(
          pw.MemoryImage(logoBytes),
          width: 80,
          height: 80,
          fit: pw.BoxFit.contain,
        );
      } catch (_) {}
    }

    pdf.addPage(
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
                    if (logoWidget != null)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 12),
                        child: logoWidget,
                      ),
                    if (company != null) ...[
                      pw.Text(
                        company.name,
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      if (company.fullAddress.isNotEmpty)
                        pw.Text(
                          company.fullAddress,
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      if (company.ico != null && company.ico!.isNotEmpty)
                        pw.Text(
                          'IČO: ${company.ico}',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      if (company.icDph != null && company.icDph!.isNotEmpty)
                        pw.Text(
                          'IČ DPH: ${company.icDph}',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      if (company.phone != null && company.phone!.isNotEmpty)
                        pw.Text(
                          'Tel: ${company.phone}',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      if (company.email != null && company.email!.isNotEmpty)
                        pw.Text(
                          'Email: ${company.email}',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                    ] else
                      pw.Text(
                        'Naša firma',
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'CENOVÁ PONUKA',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      quote.quoteNumber,
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 16),
                    pw.Text(
                      'Ponuka pre:',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(
                      customer.name,
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (customer.address != null &&
                        customer.address!.isNotEmpty)
                      pw.Text(
                        customer.address!,
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    if (customer.city != null && customer.city!.isNotEmpty)
                      pw.Text(
                        '${customer.postalCode ?? ''} ${customer.city}'.trim(),
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Row(
            children: [
              pw.Text(
                'Dátum vystavenia: ',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.Text(
                _formatDate(quote.createdAt),
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.SizedBox(width: 24),
              pw.Text('Platnosť do: ', style: const pw.TextStyle(fontSize: 10)),
              pw.Text(
                quote.validUntil != null ? _formatDate(quote.validUntil!) : '—',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
          if (quote.notes != null && quote.notes!.trim().isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text(
              'Poznámky:',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              quote.notes!.trim(),
              style: const pw.TextStyle(fontSize: 10),
            ),
          ],
          pw.SizedBox(height: 16),
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(0.6),
              2: const pw.FlexColumnWidth(0.5),
              3: const pw.FlexColumnWidth(1),
              4: const pw.FlexColumnWidth(1),
              5: const pw.FlexColumnWidth(0.5),
              6: const pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _cell('Popis položky', bold: true),
                  _cell('Množstvo', bold: true),
                  _cell('MJ', bold: true),
                  _cell('Cena za MJ', bold: true),
                  _cell('Celkom bez DPH', bold: true),
                  _cell('DPH', bold: true),
                  _cell('Celkom s DPH', bold: true),
                ],
              ),
              ...items.map((item) {
                final withoutVat = item.getLineTotalWithoutVat(
                  pricesIncludeVat,
                );
                final withVat = item.getLineTotalWithVat(pricesIncludeVat);
                return pw.TableRow(
                  children: [
                    _cell(item.productName ?? item.productUniqueId),
                    _cell('${item.qty}'),
                    _cell(item.unit),
                    _cell(_formatPrice(item.unitPrice)),
                    _cell(_formatPrice(withoutVat)),
                    _cell('${item.vatPercent}%'),
                    _cell(_formatPrice(withVat)),
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
                    'Spolu:',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Celkom bez DPH: ${_formatPrice(subtotalWithoutVat)} €',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'DPH: ${_formatPrice(totalVat)} €',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Celkom s DPH: ${_formatPrice(totalWithVat)} €',
                    style: pw.TextStyle(
                      fontSize: 10,
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

    return pdf.save();
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
        maxLines: 2,
        overflow: pw.TextOverflow.clip,
      ),
    );
  }

  /// Načíta logo z [logoPath] ako bajty. Vráti null ak súbor neexistuje alebo sa nepodarí načítať.
  static Future<Uint8List?> loadLogoBytes(String? logoPath) async {
    if (logoPath == null || logoPath.isEmpty) return null;
    try {
      final file = File(logoPath);
      if (await file.exists()) return await file.readAsBytes();
    } catch (_) {}
    return null;
  }
}
