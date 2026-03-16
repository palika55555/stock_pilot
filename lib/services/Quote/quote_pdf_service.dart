import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/company.dart';
import '../../models/customer.dart';
import '../../models/quote.dart';

/// Generuje PDF cenovej ponuky podľa firemnej šablóny.
class QuotePdfService {
  static String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  static String _formatPrice(double v) =>
      '${v.toStringAsFixed(2).replaceAll('.', ',')} €';

  static String _formatQty(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2).replaceAll('.', ',');
  }

  static Future<Uint8List> buildPdf({
    required Quote quote,
    required List<QuoteItem> items,
    required Customer customer,
    Company? company,
    Uint8List? logoBytes,
  }) async {
    final baseFont = await PdfGoogleFonts.openSansRegular();
    final boldFont = await PdfGoogleFonts.openSansBold();
    final italicFont = await PdfGoogleFonts.openSansItalic();
    final theme = pw.ThemeData.withFont(base: baseFont, bold: boldFont);
    final pdf = pw.Document(theme: theme);
    final bool pricesIncludeVat = quote.pricesIncludeVat;

    // Výpočet súm
    double subtotal = 0;
    double goodsTotal = 0;
    double depositTotal = 0;
    for (final item in items) {
      final lineTotal = item.getLineTotalWithoutVat(pricesIncludeVat);
      subtotal += lineTotal;
      if (item.itemType == 'Paleta') {
        depositTotal += lineTotal;
      } else {
        goodsTotal += lineTotal;
      }
    }
    subtotal = (subtotal * 100).round() / 100;
    goodsTotal = (goodsTotal * 100).round() / 100;
    depositTotal = (depositTotal * 100).round() / 100;
    final totalToPay = (subtotal + quote.deliveryCost + quote.otherFees);

    pw.Widget? logoWidget;
    if (logoBytes != null && logoBytes.isNotEmpty) {
      try {
        logoWidget = pw.Image(
          pw.MemoryImage(logoBytes),
          width: 90,
          height: 60,
          fit: pw.BoxFit.contain,
        );
      } catch (_) {}
    }

    // Validita v dňoch
    int? validDays;
    if (quote.validUntil != null) {
      validDays = quote.validUntil!.difference(quote.createdAt).inDays;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 30, vertical: 30),
        build: (pw.Context ctx) => [
          // ── Hlavička: nadpis + logo ──────────────────────────────────────
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Cenová ponuka',
                style: pw.TextStyle(
                  fontSize: 26,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              if (logoWidget != null) logoWidget,
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Dátum vystavenia: ${_formatDate(quote.createdAt)}',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.Text(
            'Číslo ponuky: ${quote.quoteNumber}',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 12),

          // ── Vystavovateľ / Zákazník ──────────────────────────────────────
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(width: 0.5, color: PdfColors.grey600),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        right: pw.BorderSide(width: 0.5, color: PdfColors.grey600),
                      ),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Vystavovateľ',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        if (company != null) ...[
                          pw.Text(company.name,
                              style: const pw.TextStyle(fontSize: 9)),
                          if (company.fullAddress.isNotEmpty)
                            pw.Text(company.fullAddress,
                                style: const pw.TextStyle(fontSize: 9)),
                          if (company.ico?.isNotEmpty == true)
                            pw.Text('IČO: ${company.ico}',
                                style: const pw.TextStyle(fontSize: 9)),
                          if (company.dic?.isNotEmpty == true)
                            pw.Text('DIČ: ${company.dic}',
                                style: const pw.TextStyle(fontSize: 9)),
                          if (company.icDph?.isNotEmpty == true)
                            pw.Text('IČ DPH: ${company.icDph}',
                                style: const pw.TextStyle(fontSize: 9)),
                          pw.SizedBox(height: 3),
                          if (company.phone?.isNotEmpty == true)
                            pw.Text('Tel: ${company.phone}',
                                style: const pw.TextStyle(fontSize: 9)),
                          if (company.email?.isNotEmpty == true)
                            pw.Text('E-mail: ${company.email}',
                                style: const pw.TextStyle(fontSize: 9)),
                        ] else
                          pw.Text('Naša firma',
                              style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                  ),
                ),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Zákazník',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(customer.name,
                            style: const pw.TextStyle(fontSize: 9)),
                        if (_customerAddress(customer).isNotEmpty)
                          pw.Text(_customerAddress(customer),
                              style: const pw.TextStyle(fontSize: 9)),
                        if (customer.ico.isNotEmpty)
                          pw.Text('IČO: ${customer.ico}',
                              style: const pw.TextStyle(fontSize: 9)),
                        if (customer.dic?.isNotEmpty == true)
                          pw.Text('DIČ: ${customer.dic}',
                              style: const pw.TextStyle(fontSize: 9)),
                        if (customer.icDph?.isNotEmpty == true)
                          pw.Text('IČ DPH: ${customer.icDph}',
                              style: const pw.TextStyle(fontSize: 9)),
                        pw.SizedBox(height: 3),
                        if (customer.contactPerson?.isNotEmpty == true)
                          pw.Text('Kontakt: ${customer.contactPerson}',
                              style: const pw.TextStyle(fontSize: 9)),
                        if (customer.phone?.isNotEmpty == true)
                          pw.Text('Tel: ${customer.phone}',
                              style: const pw.TextStyle(fontSize: 9)),
                        if (customer.email?.isNotEmpty == true)
                          pw.Text('E-mail: ${customer.email}',
                              style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),

          // ── Predmet ponuky ────────────────────────────────────────────────
          pw.Text(
            'Predmet ponuky',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey500),
            columnWidths: {
              0: const pw.FixedColumnWidth(42),  // Typ
              1: const pw.FlexColumnWidth(2.5),  // Názov
              2: const pw.FlexColumnWidth(1.5),  // Popis
              3: const pw.FixedColumnWidth(38),  // Množ.
              4: const pw.FixedColumnWidth(26),  // Jedn.
              5: const pw.FixedColumnWidth(52),  // Jedn. cena
              6: const pw.FixedColumnWidth(42),  // Príplatok
              7: const pw.FixedColumnWidth(56),  // Celkom
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _hCell('Typ'),
                  _hCell('Názov'),
                  _hCell('Popis'),
                  _hCell('Množ.'),
                  _hCell('Jedn.'),
                  _hCell('Jedn. cena'),
                  _hCell('Príplatok'),
                  _hCell('Celkom'),
                ],
              ),
              ...items.map((item) {
                final lineTotal = item.getLineTotalWithoutVat(pricesIncludeVat);
                final surchargeText = item.surchargePercent > 0
                    ? '${item.surchargePercent}%'
                    : '-';
                return pw.TableRow(
                  children: [
                    _cell(item.itemType),
                    _cell(item.productName ?? item.productUniqueId),
                    _cell(item.description ?? ''),
                    _cell(_formatQty(item.qty)),
                    _cell(item.unit),
                    _cell(_formatPrice(item.unitPrice)),
                    _cell(surchargeText, center: true),
                    _cell(_formatPrice(lineTotal), right: true),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 10),

          // ── Súhrn ─────────────────────────────────────────────────────────
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Container(
                width: 220,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 0.5, color: PdfColors.grey500),
                ),
                child: pw.Column(
                  children: [
                    _summaryRow('Súčet položiek', subtotal, font: baseFont, boldFont: boldFont),
                    _summaryRow('Doprava', quote.deliveryCost, font: baseFont, boldFont: boldFont),
                    _summaryRow('Iné poplatky', quote.otherFees, font: baseFont, boldFont: boldFont),
                    pw.Container(
                      color: PdfColors.grey100,
                      child: pw.Column(
                        children: [
                          _summaryRow('Cena tovaru', goodsTotal, bold: true, font: baseFont, boldFont: boldFont),
                          if (depositTotal > 0)
                            _summaryRow('Vratná záloha', depositTotal, bold: true, font: baseFont, boldFont: boldFont),
                          _summaryRow('Celková cena na úhradu', totalToPay, bold: true, font: baseFont, boldFont: boldFont),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Text(
                'Cenová ponuka uvedená bez DPH',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontStyle: pw.FontStyle.italic,
                  color: PdfColors.grey700,
                  font: italicFont,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 14),

          // ── Podmienky ─────────────────────────────────────────────────────
          pw.Text(
            'Podmienky',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          if (validDays != null)
            _bulletRow('Ponuka platí $validDays dní od dátumu vystavenia.', baseFont),
          if (quote.paymentMethod?.isNotEmpty == true)
            _bulletRow('Spôsob platby: ${quote.paymentMethod}', baseFont),
          if (quote.deliveryTerms?.isNotEmpty == true)
            _bulletRow('Termín dodania / realizácie: ${quote.deliveryTerms}', baseFont),

          // ── Poznámky ─────────────────────────────────────────────────────
          if (quote.notes?.trim().isNotEmpty == true) ...[
            pw.SizedBox(height: 12),
            pw.Text(
              'Poznámky',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              quote.notes!.trim(),
              style: const pw.TextStyle(fontSize: 9),
            ),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  static String _customerAddress(Customer c) {
    final parts = <String>[];
    if (c.address?.isNotEmpty == true) parts.add(c.address!);
    final cityPart = [c.postalCode, c.city].where((s) => s?.isNotEmpty == true).join(' ');
    if (cityPart.isNotEmpty) parts.add(cityPart);
    return parts.join(', ');
  }

  static pw.Widget _hCell(String text) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: pw.Text(
          text,
          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
        ),
      );

  static pw.Widget _cell(String text, {bool right = false, bool center = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: pw.Text(
          text,
          style: const pw.TextStyle(fontSize: 8),
          textAlign: right
              ? pw.TextAlign.right
              : center
                  ? pw.TextAlign.center
                  : pw.TextAlign.left,
        ),
      );

  static pw.Widget _summaryRow(
    String label,
    double value, {
    bool bold = false,
    required pw.Font font,
    required pw.Font boldFont,
  }) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(width: 0.3, color: PdfColors.grey400)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                font: bold ? boldFont : font,
              ),
            ),
            pw.Text(
              _formatPrice(value),
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                font: bold ? boldFont : font,
              ),
            ),
          ],
        ),
      );

  static pw.Widget _bulletRow(String text, pw.Font font) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('• ', style: pw.TextStyle(fontSize: 9, font: font)),
            pw.Expanded(
              child: pw.Text(text, style: pw.TextStyle(fontSize: 9, font: font)),
            ),
          ],
        ),
      );

  static Future<Uint8List?> loadLogoBytes(String? logoPath) async {
    if (logoPath == null || logoPath.isEmpty) return null;
    try {
      final file = File(logoPath);
      if (await file.exists()) return await file.readAsBytes();
    } catch (_) {}
    return null;
  }
}
