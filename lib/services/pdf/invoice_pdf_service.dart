import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/company.dart';
import '../../models/invoice.dart';

/// Generuje SK-legislatívne správne PDF faktúry s Pay by Square QR kódom.
/// Povinné náležitosti: §71 Zák. č. 222/2004 Z.z. o DPH + Obchodný zákonník.
class InvoicePdfService {
  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  static String _fmtPrice(double v) {
    final formatted = v.abs().toStringAsFixed(2).replaceAll('.', ',');
    return v < 0 ? '-$formatted €' : '$formatted €';
  }

  static String _fmtQty(double v) {
    if (v == v.truncateToDouble()) return v.abs().toInt().toString();
    return v.abs().toStringAsFixed(3).replaceAll('.', ',');
  }

  static Future<Uint8List> buildPdf({
    required Invoice invoice,
    required List<InvoiceItem> items,
    required Company company,
    Uint8List? logoBytes,
    String? qrString, // Pay by Square alebo EPC/SEPA QR reťazec
    /// Ak true, pod QR je text pre európsky SEPA QR namiesto Pay by Square.
    bool paymentQrIsEpcSepa = false,
  }) async {
    final baseFont = await PdfGoogleFonts.openSansRegular();
    final boldFont = await PdfGoogleFonts.openSansBold();
    final theme = pw.ThemeData.withFont(base: baseFont, bold: boldFont);
    final doc = pw.Document(theme: theme);

    // Farby
    const primaryColor = PdfColor.fromInt(0xFF1565C0); // modrá
    const lightGray    = PdfColor.fromInt(0xFFF5F5F5);
    const darkGray     = PdfColor.fromInt(0xFF424242);
    const borderColor  = PdfColor.fromInt(0xFFBDBDBD);

    // ── Výpočet súm ──────────────────────────────────────────────────────────
    final vatSummary = buildVatSummary(items);
    final vatRows = vatSummary.values.toList()
      ..sort((a, b) => b.vatPercent.compareTo(a.vatPercent));

    // ── Logo ─────────────────────────────────────────────────────────────────
    pw.Widget? logoWidget;
    if (logoBytes != null && logoBytes.isNotEmpty) {
      try {
        logoWidget = pw.Image(pw.MemoryImage(logoBytes), width: 100, height: 60, fit: pw.BoxFit.contain);
      } catch (_) {}
    }

    // ── QR kód ───────────────────────────────────────────────────────────────
    pw.Widget? qrWidget;
    if (qrString != null && qrString.isNotEmpty) {
      try {
        qrWidget = pw.BarcodeWidget(
          barcode: pw.Barcode.qrCode(),
          data: qrString,
          width: 80,
          height: 80,
          drawText: false,
        );
      } catch (_) {}
    }

    final typeLabel = invoice.invoiceType.label.toUpperCase();
    final isCreditNote = invoice.invoiceType == InvoiceType.creditNote ||
        invoice.invoiceType == InvoiceType.debitNote;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        build: (pw.Context ctx) => [

          // ── HLAVIČKA: Nadpis + Logo ─────────────────────────────────────────
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    typeLabel,
                    style: pw.TextStyle(font: boldFont, fontSize: 22, color: primaryColor),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    invoice.invoiceNumber,
                    style: pw.TextStyle(font: boldFont, fontSize: 14, color: darkGray),
                  ),
                ],
              ),
              if (logoWidget != null) logoWidget,
            ],
          ),
          pw.Divider(height: 16, thickness: 1.5, color: primaryColor),

          // ── DODÁVATEĽ + ODBERATEĽ ────────────────────────────────────────────
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Dodávateľ
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('DODÁVATEĽ', style: pw.TextStyle(font: boldFont, fontSize: 8, color: primaryColor)),
                    pw.SizedBox(height: 4),
                    pw.Text(company.name, style: pw.TextStyle(font: boldFont, fontSize: 10)),
                    if (company.address?.isNotEmpty == true)
                      pw.Text(company.address!, style: const pw.TextStyle(fontSize: 9)),
                    if (company.city?.isNotEmpty == true || company.postalCode?.isNotEmpty == true)
                      pw.Text(
                        '${company.postalCode ?? ''} ${company.city ?? ''}'.trim(),
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    pw.SizedBox(height: 4),
                    if (company.ico?.isNotEmpty == true)
                      pw.Text('IČO: ${company.ico}', style: const pw.TextStyle(fontSize: 9)),
                    if (company.dic?.isNotEmpty == true)
                      pw.Text('DIČ: ${company.dic}', style: const pw.TextStyle(fontSize: 9)),
                    if (company.vatPayer && company.icDph?.isNotEmpty == true)
                      pw.Text('IČ DPH: ${company.icDph}', style: const pw.TextStyle(fontSize: 9)),
                    if (!company.vatPayer)
                      pw.Text(
                        'Nie som platiteľom DPH',
                        style: pw.TextStyle(font: boldFont, fontSize: 8, color: PdfColors.red),
                      ),
                    if (company.registerInfo?.isNotEmpty == true)
                      pw.Text(company.registerInfo!, style: const pw.TextStyle(fontSize: 8, color: darkGray)),
                  ],
                ),
              ),
              pw.SizedBox(width: 20),
              // Odberateľ
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('ODBERATEĽ', style: pw.TextStyle(font: boldFont, fontSize: 8, color: primaryColor)),
                    pw.SizedBox(height: 4),
                    pw.Text(invoice.customerName ?? '', style: pw.TextStyle(font: boldFont, fontSize: 10)),
                    if (invoice.customerAddress?.isNotEmpty == true)
                      pw.Text(invoice.customerAddress!, style: const pw.TextStyle(fontSize: 9)),
                    if (invoice.customerCity?.isNotEmpty == true || invoice.customerPostalCode?.isNotEmpty == true)
                      pw.Text(
                        '${invoice.customerPostalCode ?? ''} ${invoice.customerCity ?? ''}'.trim(),
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    pw.SizedBox(height: 4),
                    if (invoice.customerIco?.isNotEmpty == true)
                      pw.Text('IČO: ${invoice.customerIco}', style: const pw.TextStyle(fontSize: 9)),
                    if (invoice.customerDic?.isNotEmpty == true)
                      pw.Text('DIČ: ${invoice.customerDic}', style: const pw.TextStyle(fontSize: 9)),
                    if (invoice.customerIcDph?.isNotEmpty == true)
                      pw.Text('IČ DPH: ${invoice.customerIcDph}', style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 14),

          // ── DÁTUMY + PLATBA ──────────────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: lightGray,
              border: pw.Border.all(color: borderColor, width: 0.5),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(
              children: [
                _infoCell(boldFont, 'Dátum vystavenia', _fmtDate(invoice.issueDate)),
                _infoCell(boldFont, 'DUZP', _fmtDate(invoice.taxDate)),
                _infoCell(boldFont, 'Dátum splatnosti', _fmtDate(invoice.dueDate)),
                _infoCell(boldFont, 'Variabilný symbol', invoice.variableSymbol ?? invoice.invoiceNumber),
                _infoCell(boldFont, 'Konštantný symbol', invoice.constantSymbol),
                if (invoice.paymentMethod == PaymentMethod.transfer && company.iban?.isNotEmpty == true)
                  _infoCell(boldFont, 'Spôsob úhrady', 'Bankový prevod'),
                if (invoice.paymentMethod == PaymentMethod.cash)
                  _infoCell(boldFont, 'Spôsob úhrady', 'Hotovosť'),
                if (invoice.paymentMethod == PaymentMethod.card)
                  _infoCell(boldFont, 'Spôsob úhrady', 'Karta'),
              ],
            ),
          ),

          // IBAN (ak prevod)
          if (invoice.paymentMethod == PaymentMethod.transfer && company.iban?.isNotEmpty == true)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Row(
                children: [
                  pw.Text('IBAN: ', style: pw.TextStyle(font: boldFont, fontSize: 9)),
                  pw.Text(company.iban!, style: const pw.TextStyle(fontSize: 9)),
                  if (company.swift?.isNotEmpty == true) ...[
                    pw.Text('   SWIFT/BIC: ', style: pw.TextStyle(font: boldFont, fontSize: 9)),
                    pw.Text(company.swift!, style: const pw.TextStyle(fontSize: 9)),
                  ],
                  if (company.bankName?.isNotEmpty == true) ...[
                    pw.Text('   Banka: ', style: pw.TextStyle(font: boldFont, fontSize: 9)),
                    pw.Text(company.bankName!, style: const pw.TextStyle(fontSize: 9)),
                  ],
                ],
              ),
            ),

          // Dobropis referencia
          if (isCreditNote && invoice.originalInvoiceNumber?.isNotEmpty == true)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Text(
                'Opravný doklad k faktúre: ${invoice.originalInvoiceNumber}',
                style: pw.TextStyle(font: boldFont, fontSize: 9, color: PdfColors.red),
              ),
            ),

          pw.SizedBox(height: 14),

          // ── TABUĽKA POLOŽIEK ─────────────────────────────────────────────────
          pw.Table(
            border: pw.TableBorder.all(color: borderColor, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(5),  // Popis
              1: const pw.FixedColumnWidth(40), // Mn.
              2: const pw.FixedColumnWidth(28), // Jed.
              3: const pw.FixedColumnWidth(55), // Cena/jed.
              4: const pw.FixedColumnWidth(32), // DPH%
              5: const pw.FixedColumnWidth(60), // Základ
              6: const pw.FixedColumnWidth(52), // DPH
              7: const pw.FixedColumnWidth(65), // Celkom
            },
            children: [
              // Hlavička
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: primaryColor),
                children: [
                  _th('Popis', boldFont),
                  _th('Mn.', boldFont),
                  _th('Jed.', boldFont),
                  _th('Cena/jed.', boldFont),
                  _th('DPH\n%', boldFont),
                  _th('Základ\nbez DPH', boldFont),
                  _th('DPH', boldFont),
                  _th('Celkom\ns DPH', boldFont),
                ],
              ),
              // Položky
              ...items.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: i.isEven ? PdfColors.white : lightGray,
                  ),
                  children: [
                    _td('${item.productName ?? item.itemType}${item.description != null ? "\n${item.description}" : ""}'),
                    _tdR(_fmtQty(item.qty)),
                    _td(item.unit),
                    _tdR(_fmtPrice(item.unitPrice)),
                    _tdR('${item.vatPercent}%'),
                    _tdR(_fmtPrice(item.lineBase)),
                    _tdR(_fmtPrice(item.lineVat)),
                    _tdR(_fmtPrice(item.lineTotal)),
                  ],
                );
              }),
            ],
          ),

          pw.SizedBox(height: 12),

          // ── DPH REKAPITULÁCIA + SÚČTY + QR ───────────────────────────────────
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              // QR kód platby
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (qrWidget != null) ...[
                    qrWidget,
                    pw.SizedBox(height: 4),
                    if (paymentQrIsEpcSepa) ...[
                      pw.Text('Platba QR (SEPA / EPC)', style: const pw.TextStyle(fontSize: 7, color: darkGray)),
                      pw.Text('(funguje v mnohých bankách)', style: const pw.TextStyle(fontSize: 7, color: darkGray)),
                    ] else ...[
                      pw.Text('Platiť mobilnou bankou', style: const pw.TextStyle(fontSize: 7, color: darkGray)),
                      pw.Text('(PAY by Square)', style: const pw.TextStyle(fontSize: 7, color: darkGray)),
                    ],
                  ],
                ],
              ),

              pw.SizedBox(width: 20),

              // DPH rekapitulácia
              if (company.vatPayer && vatRows.isNotEmpty)
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      pw.Text('Rekapitulácia DPH', style: pw.TextStyle(font: boldFont, fontSize: 9)),
                      pw.SizedBox(height: 4),
                      pw.Table(
                        border: pw.TableBorder.all(color: borderColor, width: 0.5),
                        columnWidths: {
                          0: const pw.FlexColumnWidth(2),
                          1: const pw.FlexColumnWidth(3),
                          2: const pw.FlexColumnWidth(3),
                          3: const pw.FlexColumnWidth(3),
                        },
                        children: [
                          pw.TableRow(
                            decoration: const pw.BoxDecoration(color: lightGray),
                            children: [
                              _th('Sadzba', boldFont, fontSize: 8),
                              _th('Základ', boldFont, fontSize: 8),
                              _th('DPH', boldFont, fontSize: 8),
                              _th('Spolu', boldFont, fontSize: 8),
                            ],
                          ),
                          ...vatRows.map((r) => pw.TableRow(children: [
                            _td('${r.vatPercent}%', fontSize: 8),
                            _tdR(_fmtPrice(r.base), fontSize: 8),
                            _tdR(_fmtPrice(r.vat), fontSize: 8),
                            _tdR(_fmtPrice(r.total), fontSize: 8),
                          ])),
                        ],
                      ),
                    ],
                  ),
                ),

              pw.SizedBox(width: 20),

              // Celkové súčty
              pw.Container(
                width: 200,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: borderColor, width: 0.5),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  children: [
                    _sumRow('Základ bez DPH:', _fmtPrice(invoice.totalWithoutVat), boldFont),
                    _sumRow('DPH:', _fmtPrice(invoice.totalVat), boldFont),
                    pw.Divider(height: 6, thickness: 0.5),
                    _sumRowBig('CELKOM K ÚHRADE:', _fmtPrice(invoice.totalWithVat), boldFont, primaryColor),
                  ],
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 10),

          // ── POZNÁMKA ──────────────────────────────────────────────────────────
          if (invoice.notes?.isNotEmpty == true)
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: lightGray,
                border: pw.Border.all(color: borderColor, width: 0.5),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Poznámka: ', style: pw.TextStyle(font: boldFont, fontSize: 9)),
                  pw.Expanded(child: pw.Text(invoice.notes!, style: const pw.TextStyle(fontSize: 9))),
                ],
              ),
            ),

          // ── PÄTA ──────────────────────────────────────────────────────────────
          pw.SizedBox(height: 16),
          pw.Divider(height: 1, thickness: 0.5, color: borderColor),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                '${company.name}  |  ${company.email ?? ''}  |  ${company.phone ?? ''}',
                style: const pw.TextStyle(fontSize: 7, color: darkGray),
              ),
              pw.Text(
                'Vystavil: ${company.name}  •  ${_fmtDate(invoice.issueDate)}',
                style: const pw.TextStyle(fontSize: 7, color: darkGray),
              ),
            ],
          ),
        ],
      ),
    );

    return doc.save();
  }

  // ── Helper widgety ────────────────────────────────────────────────────────

  static pw.Widget _infoCell(pw.Font boldFont, String label, String value) {
    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: pw.TextStyle(font: boldFont, fontSize: 7)),
          pw.Text(value, style: const pw.TextStyle(fontSize: 8)),
        ],
      ),
    );
  }

  static pw.Widget _th(String text, pw.Font boldFont, {double fontSize = 8}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: boldFont, fontSize: fontSize, color: PdfColors.white),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _td(String text, {double fontSize = 8}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Text(text, style: pw.TextStyle(fontSize: fontSize)),
    );
  }

  static pw.Widget _tdR(String text, {double fontSize = 8}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Text(text, style: pw.TextStyle(fontSize: fontSize), textAlign: pw.TextAlign.right),
    );
  }

  static pw.Widget _sumRow(String label, String value, pw.Font boldFont) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
        pw.Text(value, style: pw.TextStyle(font: boldFont, fontSize: 9)),
      ],
    );
  }

  static pw.Widget _sumRowBig(String label, String value, pw.Font boldFont, PdfColor color) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(font: boldFont, fontSize: 11, color: color)),
        pw.Text(value, style: pw.TextStyle(font: boldFont, fontSize: 13, color: color)),
      ],
    );
  }
}
