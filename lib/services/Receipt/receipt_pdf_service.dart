import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/receipt.dart';
import '../../models/receipt_pdf_style_config.dart';

/// Generuje PDF príjemky (inbound receipt) pre tlač alebo uloženie.
/// Štýl môže byť upravený cez [styleConfig] (Nastavenia → Generovanie PDF).
class ReceiptPdfService {
  static String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  static String _formatPrice(double v) =>
      v.toStringAsFixed(2).replaceAll('.', ',');

  static PdfColor? _colorFromHex(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    try {
      final h = hex.replaceFirst('#', '');
      final value = h.length <= 6 ? 0xFF000000 | int.parse(h, radix: 16) : int.parse(h, radix: 16);
      return PdfColor.fromInt(value);
    } catch (_) {
      return null;
    }
  }

  /// Vráti PDF ako bajty. [issuedBy] = meno prihláseného; [styleConfig] = štýl z nastavení;
  /// [lastPurchaseDateByProductId] = mapa productUniqueId -> formátovaný dátum (pre stĺpec Posledný dátum nákupu).
  static Future<Uint8List> buildPdf({
    required InboundReceipt receipt,
    required List<InboundReceiptItem> items,
    String? issuedBy,
    ReceiptPdfStyleConfig? styleConfig,
    Map<String, String>? lastPurchaseDateByProductId,
  }) async {
    final c = styleConfig ?? const ReceiptPdfStyleConfig();
    final primaryColor = _colorFromHex(c.primaryColorHex);
    final tableHeaderColor = _colorFromHex(c.tableHeaderColorHex) ?? PdfColors.grey300;

    final baseFont = await PdfGoogleFonts.openSansRegular();
    final boldFont = await PdfGoogleFonts.openSansBold();
    final theme = pw.ThemeData.withFont(base: baseFont, bold: boldFont);
    final doc = pw.Document(theme: theme);

    double total = 0;
    for (final item in items) {
      total += item.unitPrice * item.qty;
    }
    total = (total * 100).round() / 100;

    final defaultVat = receipt.vatRate ?? 20;
    final vatBreakdown = <int, ({double sumWithVat, double sumWithoutVat, double vatAmount})>{};
    for (final item in items) {
      final vatRate = item.vatPercent ?? receipt.vatRate ?? defaultVat;
      final lineTotalStored = (item.unitPrice * item.qty * 100).round() / 100;
      double lineWithVat;
      double lineWithoutVat;
      if (receipt.pricesIncludeVat) {
        lineWithVat = lineTotalStored;
        lineWithoutVat = vatRate <= 0
            ? lineTotalStored
            : (lineTotalStored / (1 + vatRate / 100) * 100).round() / 100;
      } else {
        lineWithoutVat = lineTotalStored;
        lineWithVat = vatRate <= 0
            ? lineTotalStored
            : (lineTotalStored * (1 + vatRate / 100) * 100).round() / 100;
      }
      final vatAmt = (lineWithVat - lineWithoutVat) * 100; final vatAmtR = (vatAmt.round()) / 100;
      final cur = vatBreakdown[vatRate];
      if (cur == null) {
        vatBreakdown[vatRate] = (sumWithVat: lineWithVat, sumWithoutVat: lineWithoutVat, vatAmount: vatAmtR);
      } else {
        vatBreakdown[vatRate] = (
          sumWithVat: ((cur.sumWithVat + lineWithVat) * 100).round() / 100,
          sumWithoutVat: ((cur.sumWithoutVat + lineWithoutVat) * 100).round() / 100,
          vatAmount: ((cur.vatAmount + vatAmtR) * 100).round() / 100,
        );
      }
    }
    final vatRatesSorted = vatBreakdown.keys.toList()..sort();

    final headerChildren = <pw.Widget>[
      pw.Text(
        c.effectiveDocumentTitle,
        style: pw.TextStyle(
          fontSize: c.titleFontSize.toDouble(),
          fontWeight: pw.FontWeight.bold,
          color: primaryColor,
        ),
      ),
      pw.SizedBox(height: 8),
      pw.Text(
        receipt.receiptNumber,
        style: pw.TextStyle(
          fontSize: (c.bodyFontSize + 2).toDouble(),
          fontWeight: pw.FontWeight.bold,
          color: primaryColor,
        ),
      ),
      pw.SizedBox(height: 12),
      pw.Text(
        'Dátum: ${_formatDate(receipt.createdAt)}',
        style: pw.TextStyle(fontSize: c.bodyFontSize.toDouble()),
      ),
      if (receipt.invoiceNumber != null && receipt.invoiceNumber!.isNotEmpty)
        pw.Text(
          'Faktúra: ${receipt.invoiceNumber}',
          style: pw.TextStyle(fontSize: c.bodyFontSize.toDouble()),
        ),
      if (receipt.supplierName != null && receipt.supplierName!.isNotEmpty) ...[
        pw.SizedBox(height: 6),
        pw.Text(
          'Dodávateľ:',
          style: pw.TextStyle(
            fontSize: c.bodyFontSize.toDouble(),
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.Text(
          receipt.supplierName!,
          style: pw.TextStyle(fontSize: c.bodyFontSize.toDouble()),
        ),
      ],
      if (receipt.notes != null && receipt.notes!.trim().isNotEmpty) ...[
        pw.SizedBox(height: 8),
        pw.Text(
          'Poznámka:',
          style: pw.TextStyle(
            fontSize: c.bodyFontSize.toDouble(),
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.Text(
          receipt.notes!.trim(),
          style: pw.TextStyle(fontSize: c.bodyFontSize.toDouble()),
        ),
      ],
      pw.SizedBox(height: 4),
      pw.Text(
        receipt.pricesIncludeVat ? 'Ceny sú s DPH' : 'Ceny sú bez DPH',
        style: pw.TextStyle(
          fontSize: (c.bodyFontSize - 1).toDouble(),
          color: PdfColors.grey700,
        ),
      ),
      if (c.showIssuedBy) ...[
        pw.SizedBox(height: 8),
        pw.Text(
          'Vystavil: ${receipt.username ?? issuedBy ?? '–'}',
          style: pw.TextStyle(
            fontSize: c.bodyFontSize.toDouble(),
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    ];

    final pageChildren = <pw.Widget>[
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: headerChildren,
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 20),
      _buildTable(
        receipt: receipt,
        items: items,
        c: c,
        tableHeaderColor: tableHeaderColor,
        lastPurchaseDateByProductId: lastPurchaseDateByProductId ?? {},
      ),
      pw.SizedBox(height: 16),
      _buildTotalAndVatSummary(
        total: total,
        vatBreakdown: vatBreakdown,
        vatRatesSorted: vatRatesSorted,
        bodyFontSize: c.bodyFontSize,
      ),
    ];

    if (c.showSignatureBlock) {
      pageChildren.addAll([
        pw.SizedBox(height: 28),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Podpis prijímajúceho',
                    style: pw.TextStyle(
                      fontSize: (c.bodyFontSize - 1).toDouble(),
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Container(
                    width: double.infinity,
                    height: 1,
                    decoration: const pw.BoxDecoration(color: PdfColors.grey400),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    '(meno a podpis)',
                    style: pw.TextStyle(
                      fontSize: (c.bodyFontSize - 2).toDouble(),
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
                    'Dátum prijatia',
                    style: pw.TextStyle(
                      fontSize: (c.bodyFontSize - 1).toDouble(),
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    _formatDate(receipt.createdAt),
                    style: pw.TextStyle(
                      fontSize: c.bodyFontSize.toDouble(),
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Container(
                    width: double.infinity,
                    height: 1,
                    decoration: const pw.BoxDecoration(color: PdfColors.grey400),
                  ),
                ],
              ),
            ),
          ],
        ),
      ]);
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => pageChildren,
      ),
    );

    return doc.save();
  }

  static pw.Widget _buildTotalAndVatSummary({
    required double total,
    required Map<int, ({double sumWithVat, double sumWithoutVat, double vatAmount})> vatBreakdown,
    required List<int> vatRatesSorted,
    required int bodyFontSize,
  }) {
    final children = <pw.Widget>[
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Text(
            'Spolu: ${_formatPrice(total)} €',
            style: pw.TextStyle(
              fontSize: (bodyFontSize + 1).toDouble(),
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    ];
    if (vatRatesSorted.length > 1) {
      children.add(pw.SizedBox(height: 10));
      children.add(
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Rozpis podľa DPH:',
                style: pw.TextStyle(
                  fontSize: bodyFontSize.toDouble(),
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              ...vatRatesSorted.map((rate) {
                final b = vatBreakdown[rate]!;
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 2),
                  child: pw.Text(
                    'DPH $rate%: základ ${_formatPrice(b.sumWithoutVat)} €, '
                    'DPH ${_formatPrice(b.vatAmount)} €, spolu ${_formatPrice(b.sumWithVat)} €',
                    style: pw.TextStyle(fontSize: bodyFontSize.toDouble()),
                  ),
                );
              }),
            ],
          ),
        ),
      );
    } else if (vatRatesSorted.length == 1 && vatBreakdown[vatRatesSorted.single]!.vatAmount > 0) {
      final b = vatBreakdown[vatRatesSorted.single]!;
      children.add(pw.SizedBox(height: 4));
      children.add(
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text(
              'DPH ${vatRatesSorted.single}%: ${_formatPrice(b.vatAmount)} €',
              style: pw.TextStyle(
                fontSize: (bodyFontSize - 1).toDouble(),
                color: PdfColors.grey700,
              ),
            ),
          ],
        ),
      );
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: children,
    );
  }

  static pw.Widget _buildTable({
    required InboundReceipt receipt,
    required List<InboundReceiptItem> items,
    required ReceiptPdfStyleConfig c,
    required PdfColor tableHeaderColor,
    required Map<String, String> lastPurchaseDateByProductId,
  }) {
    final defaultVatRate = receipt.vatRate ?? 0;
    double unitPriceWithoutVat(double unitPrice, int vatRate) {
      if (!receipt.pricesIncludeVat || vatRate <= 0) return unitPrice;
      return (unitPrice / (1 + vatRate / 100) * 100).round() / 100;
    }

    final headerCells = <pw.Widget>[];
    final columnWidths = <int, pw.FlexColumnWidth>{};
    int colIndex = 0;
    final showQtyUnit = c.showColQty || c.showColUnit;

    if (c.showColProductName) {
      headerCells.add(ReceiptPdfService._cell('Názov položky', bold: true, fontSize: c.bodyFontSize));
      columnWidths[colIndex++] = const pw.FlexColumnWidth(3);
    }
    if (c.showColPlu) {
      headerCells.add(ReceiptPdfService._cell('PLU / Kód', bold: true, fontSize: c.bodyFontSize));
      columnWidths[colIndex++] = const pw.FlexColumnWidth(0.9);
    }
    if (showQtyUnit) {
      headerCells.add(ReceiptPdfService._cell('Množstvo (Mn. + MJ)', bold: true, fontSize: c.bodyFontSize));
      columnWidths[colIndex++] = const pw.FlexColumnWidth(1.2);
    }
    if (c.showColUnitPriceWithoutVat) {
      headerCells.add(ReceiptPdfService._cell('Cena/MJ (bez DPH)', bold: true, fontSize: c.bodyFontSize));
      columnWidths[colIndex++] = const pw.FlexColumnWidth(1.2);
    }
    if (c.showColVatRate) {
      headerCells.add(ReceiptPdfService._cell('DPH %', bold: true, fontSize: c.bodyFontSize));
      columnWidths[colIndex++] = const pw.FlexColumnWidth(0.6);
    }
    if (c.showColUnitPriceWithVat) {
      headerCells.add(ReceiptPdfService._cell('Cena/MJ (s DPH)', bold: true, fontSize: c.bodyFontSize));
      columnWidths[colIndex++] = const pw.FlexColumnWidth(1.2);
    }
    if (c.showColTotal) {
      headerCells.add(ReceiptPdfService._cell('Celkom (s DPH)', bold: true, fontSize: c.bodyFontSize));
      columnWidths[colIndex++] = const pw.FlexColumnWidth(1.2);
    }
    if (c.showColVatAmount) {
      headerCells.add(ReceiptPdfService._cell('DPH (€)', bold: true, fontSize: c.bodyFontSize));
      columnWidths[colIndex++] = const pw.FlexColumnWidth(0.8);
    }
    if (c.showColLastPurchaseDate) {
      headerCells.add(ReceiptPdfService._cell('Posl. dátum nákupu', bold: true, fontSize: c.bodyFontSize));
      columnWidths[colIndex++] = const pw.FlexColumnWidth(1.2);
    }

    if (headerCells.isEmpty) {
      headerCells.add(ReceiptPdfService._cell('Názov položky', bold: true, fontSize: c.bodyFontSize));
      columnWidths[0] = const pw.FlexColumnWidth(4);
    }

    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: pw.BoxDecoration(color: tableHeaderColor),
        children: headerCells,
      ),
      ...items.map((item) {
        final itemVatRate = item.vatPercent ?? receipt.vatRate ?? 0;
        final lineTotal = (item.unitPrice * item.qty * 100).round() / 100;
        final name = item.productName ?? item.productUniqueId;
        final pluStr = item.plu ?? '';
        final unitPriceNoVat = unitPriceWithoutVat(item.unitPrice, itemVatRate);
        final lineTotalNoVat = (unitPriceNoVat * item.qty * 100).round() / 100;
        final vatAmount = ((lineTotal - lineTotalNoVat) * 100).round() / 100;
        final lastPurchase = lastPurchaseDateByProductId[item.productUniqueId] ?? '–';
        final vatRateStr = itemVatRate > 0 ? '$itemVatRate' : '0';

        final cells = <pw.Widget>[];
        if (c.showColProductName) {
          cells.add(ReceiptPdfService._cell(name, fontSize: c.bodyFontSize));
        }
        if (c.showColPlu) {
          cells.add(ReceiptPdfService._cell(pluStr, fontSize: c.bodyFontSize));
        }
        if (showQtyUnit) {
          cells.add(ReceiptPdfService._cell('${item.qty} ${item.unit}', fontSize: c.bodyFontSize));
        }
        if (c.showColUnitPriceWithoutVat) {
          cells.add(ReceiptPdfService._cell('${_formatPrice(unitPriceNoVat)} €', fontSize: c.bodyFontSize));
        }
        if (c.showColVatRate) {
          cells.add(ReceiptPdfService._cell('$vatRateStr%', fontSize: c.bodyFontSize));
        }
        if (c.showColUnitPriceWithVat) {
          cells.add(ReceiptPdfService._cell('${_formatPrice(item.unitPrice)} €', fontSize: c.bodyFontSize));
        }
        if (c.showColTotal) {
          cells.add(ReceiptPdfService._cell('${_formatPrice(lineTotal)} €', fontSize: c.bodyFontSize));
        }
        if (c.showColVatAmount) {
          cells.add(ReceiptPdfService._cell(_formatPrice(vatAmount), fontSize: c.bodyFontSize));
        }
        if (c.showColLastPurchaseDate) {
          cells.add(ReceiptPdfService._cell(lastPurchase, fontSize: c.bodyFontSize));
        }
        if (cells.isEmpty) {
          cells.add(ReceiptPdfService._cell(name, fontSize: c.bodyFontSize));
        }
        return pw.TableRow(children: cells);
      }),
    ];

    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      columnWidths: columnWidths,
      children: rows,
    );
  }

  static pw.Widget _cell(String text, {bool bold = false, int fontSize = 9}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: fontSize.toDouble(),
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        maxLines: 3,
        overflow: pw.TextOverflow.clip,
      ),
    );
  }
}
