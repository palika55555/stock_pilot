import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/product.dart';
import '../../models/receipt.dart';
import '../../models/receipt_pdf_style_config.dart';

/// Typ tlačového výstupu príjemky podľa toho, kto dokument potrebuje.
enum PrintType {
  /// Účtovná príjemka: Názov, PLU, Mn, MJ, Cena bez DPH/MJ, Sadzba DPH, Celkom s DPH + pätička DPH.
  standard('Účtovná príjemka'),
  /// Príjemka s predajnými cenami a maržou %.
  retail('Príjemka s predajnými cenami'),
  /// Slepá príjemka pre skladníka – bez cien, stĺpec „Skutočne prijaté”.
  warehouse('Slepá príjemka pre skladníka'),
  /// Príjemka so stavmi zásob: Položka, Prijaté, Stav pred, Nový stav.
  stocks('Príjemka so stavmi zásob');

  final String label;
  const PrintType(this.label);
}

/// Kontext pre generovanie PDF (voliteľné údaje z aplikácie).
class PrijemkaPdfContext {
  final String? issuedBy;
  final String? warehouseName;
  final int? warehouseId;
  final Map<String, String> lastPurchaseDateByProductId;
  final Map<String, Product> productsByUniqueId;
  final ReceiptPdfStyleConfig? styleConfig;

  const PrijemkaPdfContext({
    this.issuedBy,
    this.warehouseName,
    this.warehouseId,
    this.lastPurchaseDateByProductId = const {},
    this.productsByUniqueId = const {},
    this.styleConfig,
  });
}

/// Generátor PDF tlačových zostáv pre príjemky podľa [PrintType].
class PrijemkaPdfGenerator {
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

  static pw.Widget _cell(String text,
      {bool bold = false, int fontSize = 9, pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Align(
        alignment: align == pw.TextAlign.right ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: fontSize.toDouble(),
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
          maxLines: 3,
          overflow: pw.TextOverflow.clip,
        ),
      ),
    );
  }

  /// Vygeneruje PDF príjemky podľa zvoleného [type].
  /// [context] môže obsahovať sklad, vystaviteľa, produkty (pre RETAIL/STOCKS) a štýl.
  static Future<Uint8List> generatePdf({
    required InboundReceipt receipt,
    required List<InboundReceiptItem> items,
    required PrintType type,
    PrijemkaPdfContext? context,
  }) async {
    final ctx = context ?? const PrijemkaPdfContext();
    final c = ctx.styleConfig ?? const ReceiptPdfStyleConfig();
    final primaryColor = _colorFromHex(c.primaryColorHex);
    final tableHeaderColor = _colorFromHex(c.tableHeaderColorHex) ?? PdfColors.grey300;

    final baseFont = await PdfGoogleFonts.openSansRegular();
    final boldFont = await PdfGoogleFonts.openSansBold();
    final theme = pw.ThemeData.withFont(base: baseFont, bold: boldFont);
    final doc = pw.Document(theme: theme);

    final header = _buildHeader(receipt, ctx, c, primaryColor);
    pw.Widget table;
    pw.Widget? footer;

    switch (type) {
      case PrintType.standard:
        table = _buildTableStandard(receipt, items, c, tableHeaderColor, ctx.lastPurchaseDateByProductId);
        footer = _buildVatFooter(receipt, items, c.bodyFontSize);
        break;
      case PrintType.retail:
        table = _buildTableRetail(receipt, items, c, tableHeaderColor, ctx.productsByUniqueId);
        footer = _buildVatFooter(receipt, items, c.bodyFontSize);
        break;
      case PrintType.warehouse:
        table = _buildTableWarehouse(receipt, items, c, tableHeaderColor);
        footer = null;
        break;
      case PrintType.stocks:
        table = _buildTableStocks(receipt, items, c, tableHeaderColor, ctx.productsByUniqueId);
        footer = null;
        break;
    }

    final pageChildren = <pw.Widget>[
      header,
      pw.SizedBox(height: 16),
      table,
      if (footer != null) ...[
        pw.SizedBox(height: 16),
        footer,
      ],
      if (c.showSignatureBlock) ...[
        pw.SizedBox(height: 24),
        _buildSignatureBlock(receipt, c.bodyFontSize),
      ],
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

  static pw.Widget _buildHeader(
    InboundReceipt receipt,
    PrijemkaPdfContext ctx,
    ReceiptPdfStyleConfig c,
    PdfColor? primaryColor,
  ) {
    final title = typeTitle(receipt, ctx);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: 60,
              height: 60,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                color: PdfColors.grey200,
              ),
              child: pw.Center(
                child: pw.Text(
                  'Logo',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                ),
              ),
            ),
            pw.SizedBox(width: 16),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    title,
                    style: pw.TextStyle(
                      fontSize: c.titleFontSize.toDouble(),
                      fontWeight: pw.FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Číslo dokladu: ${receipt.receiptNumber}',
                    style: pw.TextStyle(
                      fontSize: (c.bodyFontSize + 1).toDouble(),
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text('Dátum: ${_formatDate(receipt.createdAt)}',
                      style: pw.TextStyle(fontSize: c.bodyFontSize.toDouble())),
                  if (ctx.warehouseName != null || receipt.warehouseId != null)
                    pw.Text(
                      'Sklad: ${ctx.warehouseName ?? 'ID ${receipt.warehouseId}'}',
                      style: pw.TextStyle(fontSize: c.bodyFontSize.toDouble()),
                    ),
                  if (receipt.supplierName != null && receipt.supplierName!.isNotEmpty)
                    pw.Text(
                      'Dodávateľ: ${receipt.supplierName}',
                      style: pw.TextStyle(fontSize: c.bodyFontSize.toDouble()),
                    ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    receipt.isSettled ? 'Vysporiadaná' : 'Nevysporiadaná',
                    style: pw.TextStyle(
                      fontSize: c.bodyFontSize.toDouble(),
                      fontWeight: pw.FontWeight.bold,
                      color: receipt.isSettled ? PdfColors.green800 : PdfColors.orange800,
                    ),
                  ),
                  if (ctx.issuedBy != null && c.showIssuedBy) ...[
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Vystavil: ${ctx.issuedBy}',
                      style: pw.TextStyle(
                        fontSize: (c.bodyFontSize - 1).toDouble(),
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String typeTitle(InboundReceipt receipt, PrijemkaPdfContext ctx) {
    final base = ctx.styleConfig?.effectiveDocumentTitle ?? 'PRÍJEMKA TOVARU';
    return base;
  }

  static pw.Widget _buildTableStandard(
    InboundReceipt receipt,
    List<InboundReceiptItem> items,
    ReceiptPdfStyleConfig c,
    PdfColor tableHeaderColor,
    Map<String, String> lastPurchaseByProductId,
  ) {
    final defaultVat = receipt.vatRate ?? 20;
    double unitPriceWithoutVat(double unitPrice, int vatRate) {
      if (!receipt.pricesIncludeVat || vatRate <= 0) return unitPrice;
      return (unitPrice / (1 + vatRate / 100) * 100).round() / 100;
    }

    final colWidths = <int, pw.FlexColumnWidth>{
      0: const pw.FlexColumnWidth(2.5),
      1: const pw.FlexColumnWidth(0.8),
      2: const pw.FlexColumnWidth(0.8),
      3: const pw.FlexColumnWidth(0.6),
      4: const pw.FlexColumnWidth(1),
      5: const pw.FlexColumnWidth(0.6),
      6: const pw.FlexColumnWidth(1),
    };

    final headerRow = pw.TableRow(
      decoration: pw.BoxDecoration(color: tableHeaderColor),
      children: [
        _cell('Názov', bold: true, fontSize: c.bodyFontSize),
        _cell('PLU', bold: true, fontSize: c.bodyFontSize),
        _cell('Mn', bold: true, fontSize: c.bodyFontSize),
        _cell('MJ', bold: true, fontSize: c.bodyFontSize),
        _cell('Cena bez DPH/MJ', bold: true, fontSize: c.bodyFontSize, align: pw.TextAlign.right),
        _cell('Sadzba DPH', bold: true, fontSize: c.bodyFontSize, align: pw.TextAlign.right),
        _cell('Celkom s DPH', bold: true, fontSize: c.bodyFontSize, align: pw.TextAlign.right),
      ],
    );

    final rows = <pw.TableRow>[headerRow];
    for (final item in items) {
      final vatRate = item.vatPercent ?? receipt.vatRate ?? defaultVat;
      final unitNoVat = unitPriceWithoutVat(item.unitPrice, vatRate);
      final lineTotal = (item.unitPrice * item.qty * 100).round() / 100;
      rows.add(
        pw.TableRow(
          children: [
            _cell(item.productName ?? item.productUniqueId, fontSize: c.bodyFontSize),
            _cell(item.plu ?? '', fontSize: c.bodyFontSize),
            _cell('${item.qty}', fontSize: c.bodyFontSize, align: pw.TextAlign.right),
            _cell(item.unit, fontSize: c.bodyFontSize),
            _cell('${_formatPrice(unitNoVat)} €', fontSize: c.bodyFontSize, align: pw.TextAlign.right),
            _cell('$vatRate %', fontSize: c.bodyFontSize, align: pw.TextAlign.right),
            _cell('${_formatPrice(lineTotal)} €', fontSize: c.bodyFontSize, align: pw.TextAlign.right),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      columnWidths: colWidths,
      children: rows,
    );
  }

  static pw.Widget _buildVatFooter(
    InboundReceipt receipt,
    List<InboundReceiptItem> items,
    int bodyFontSize,
  ) {
    final defaultVat = receipt.vatRate ?? 20;
    final vatBreakdown = <int, ({double sumWithVat, double sumWithoutVat, double vatAmount})>{};
    for (final item in items) {
      final vatRate = item.vatPercent ?? receipt.vatRate ?? defaultVat;
      final lineTotal = (item.unitPrice * item.qty * 100).round() / 100;
      double lineWithVat, lineWithoutVat;
      if (receipt.pricesIncludeVat) {
        lineWithVat = lineTotal;
        lineWithoutVat = vatRate <= 0 ? lineTotal : (lineTotal / (1 + vatRate / 100) * 100).round() / 100;
      } else {
        lineWithoutVat = lineTotal;
        lineWithVat = vatRate <= 0 ? lineTotal : (lineTotal * (1 + vatRate / 100) * 100).round() / 100;
      }
      final vatAmt = (lineWithVat - lineWithoutVat) * 100;
      final vatAmtR = vatAmt.round() / 100;
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
    final total = items.fold<double>(
        0, (s, i) => s + (i.unitPrice * i.qty * 100).round() / 100);
    final vatRatesSorted = vatBreakdown.keys.toList()..sort();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(color: PdfColors.grey200),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Rekapitulácia DPH',
                style: pw.TextStyle(fontSize: bodyFontSize.toDouble(), fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 6),
              ...vatRatesSorted.map((rate) {
                final b = vatBreakdown[rate]!;
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 2),
                  child: pw.Text(
                    'DPH $rate%: Základ ${_formatPrice(b.sumWithoutVat)} €, '
                    'DPH ${_formatPrice(b.vatAmount)} €, Spolu ${_formatPrice(b.sumWithVat)} €',
                    style: pw.TextStyle(fontSize: bodyFontSize.toDouble()),
                  ),
                );
              }),
              pw.SizedBox(height: 4),
              pw.Text(
                'Spolu: ${_formatPrice(total)} €',
                style: pw.TextStyle(
                  fontSize: (bodyFontSize + 1).toDouble(),
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildTableRetail(
    InboundReceipt receipt,
    List<InboundReceiptItem> items,
    ReceiptPdfStyleConfig c,
    PdfColor tableHeaderColor,
    Map<String, Product> productsByUniqueId,
  ) {
    final defaultVat = receipt.vatRate ?? 20;
    double unitPriceWithoutVat(double unitPrice, int vatRate) {
      if (!receipt.pricesIncludeVat || vatRate <= 0) return unitPrice;
      return (unitPrice / (1 + vatRate / 100) * 100).round() / 100;
    }

    final colWidths = <int, pw.FlexColumnWidth>{
      0: const pw.FlexColumnWidth(2),
      1: const pw.FlexColumnWidth(0.7),
      2: const pw.FlexColumnWidth(0.6),
      3: const pw.FlexColumnWidth(0.9),
      4: const pw.FlexColumnWidth(0.6),
      5: const pw.FlexColumnWidth(0.9),
      6: const pw.FlexColumnWidth(0.9),
      7: const pw.FlexColumnWidth(0.8),
      8: const pw.FlexColumnWidth(0.7),
    };

    final headerRow = pw.TableRow(
      decoration: pw.BoxDecoration(color: tableHeaderColor),
      children: [
        _cell('Názov', bold: true, fontSize: c.bodyFontSize),
        _cell('PLU', bold: true, fontSize: c.bodyFontSize),
        _cell('Mn', bold: true, fontSize: c.bodyFontSize),
        _cell('MJ', bold: true, fontSize: c.bodyFontSize),
        _cell('Cena bez DPH/MJ', bold: true, fontSize: c.bodyFontSize, align: pw.TextAlign.right),
        _cell('Sadzba DPH', bold: true, fontSize: c.bodyFontSize, align: pw.TextAlign.right),
        _cell('Celkom s DPH', bold: true, fontSize: c.bodyFontSize, align: pw.TextAlign.right),
        _cell('Predajná cena', bold: true, fontSize: c.bodyFontSize, align: pw.TextAlign.right),
        _cell('Marža %', bold: true, fontSize: c.bodyFontSize, align: pw.TextAlign.right),
      ],
    );

    final rows = <pw.TableRow>[headerRow];
    for (final item in items) {
      final vatRate = item.vatPercent ?? receipt.vatRate ?? defaultVat;
      final unitNoVat = unitPriceWithoutVat(item.unitPrice, vatRate);
      final lineTotal = (item.unitPrice * item.qty * 100).round() / 100;
      final product = productsByUniqueId[item.productUniqueId];
      final salePrice = product?.price ?? 0.0;
      final margin = product != null && product.price > 0
          ? ((product.price - item.unitPrice) / product.price * 100)
          : null;
      rows.add(
        pw.TableRow(
          children: [
            _cell(item.productName ?? item.productUniqueId, fontSize: c.bodyFontSize),
            _cell(item.plu ?? '', fontSize: c.bodyFontSize),
            _cell('${item.qty}', fontSize: c.bodyFontSize, align: pw.TextAlign.right),
            _cell(item.unit, fontSize: c.bodyFontSize),
            _cell('${_formatPrice(unitNoVat)} €', fontSize: c.bodyFontSize, align: pw.TextAlign.right),
            _cell('$vatRate %', fontSize: c.bodyFontSize, align: pw.TextAlign.right),
            _cell('${_formatPrice(lineTotal)} €', fontSize: c.bodyFontSize, align: pw.TextAlign.right),
            _cell(salePrice > 0 ? '${_formatPrice(salePrice)} €' : '–', fontSize: c.bodyFontSize, align: pw.TextAlign.right),
            _cell(margin != null ? '${margin.toStringAsFixed(1)} %' : '–', fontSize: c.bodyFontSize, align: pw.TextAlign.right),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      columnWidths: colWidths,
      children: rows,
    );
  }

  static pw.Widget _buildTableWarehouse(
    InboundReceipt receipt,
    List<InboundReceiptItem> items,
    ReceiptPdfStyleConfig c,
    PdfColor tableHeaderColor,
  ) {
    final colWidths = <int, pw.FlexColumnWidth>{
      0: const pw.FlexColumnWidth(3),
      1: const pw.FlexColumnWidth(0.8),
      2: const pw.FlexColumnWidth(0.8),
      3: const pw.FlexColumnWidth(2),
    };

    final headerRow = pw.TableRow(
      decoration: pw.BoxDecoration(color: tableHeaderColor),
      children: [
        _cell('Názov', bold: true, fontSize: c.bodyFontSize),
        _cell('PLU', bold: true, fontSize: c.bodyFontSize),
        _cell('MJ', bold: true, fontSize: c.bodyFontSize),
        _cell('Skutočne prijaté', bold: true, fontSize: c.bodyFontSize),
      ],
    );

    final rows = <pw.TableRow>[headerRow];
    for (final item in items) {
      rows.add(
        pw.TableRow(
          children: [
            _cell(item.productName ?? item.productUniqueId, fontSize: c.bodyFontSize),
            _cell(item.plu ?? '', fontSize: c.bodyFontSize),
            _cell(item.unit, fontSize: c.bodyFontSize),
            _cell('', fontSize: c.bodyFontSize),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      columnWidths: colWidths,
      children: rows,
    );
  }

  static pw.Widget _buildTableStocks(
    InboundReceipt receipt,
    List<InboundReceiptItem> items,
    ReceiptPdfStyleConfig c,
    PdfColor tableHeaderColor,
    Map<String, Product> productsByUniqueId,
  ) {
    final colWidths = <int, pw.FlexColumnWidth>{
      0: const pw.FlexColumnWidth(2.5),
      1: const pw.FlexColumnWidth(1),
      2: const pw.FlexColumnWidth(1),
      3: const pw.FlexColumnWidth(1),
    };

    final headerRow = pw.TableRow(
      decoration: pw.BoxDecoration(color: tableHeaderColor),
      children: [
        _cell('Položka', bold: true, fontSize: c.bodyFontSize),
        _cell('Prijaté množstvo', bold: true, fontSize: c.bodyFontSize, align: pw.TextAlign.right),
        _cell('Stav pred príjmom', bold: true, fontSize: c.bodyFontSize, align: pw.TextAlign.right),
        _cell('Nový stav po príjme', bold: true, fontSize: c.bodyFontSize, align: pw.TextAlign.right),
      ],
    );

    final rows = <pw.TableRow>[headerRow];
    for (final item in items) {
      final product = productsByUniqueId[item.productUniqueId];
      final currentQty = product?.qty ?? 0;
      final stavPred = currentQty - item.qty;
      final novyStav = currentQty;
      rows.add(
        pw.TableRow(
          children: [
            _cell(item.productName ?? item.productUniqueId, fontSize: c.bodyFontSize),
            _cell('${item.qty} ${item.unit}', fontSize: c.bodyFontSize, align: pw.TextAlign.right),
            _cell(product != null ? '$stavPred' : '–', fontSize: c.bodyFontSize, align: pw.TextAlign.right),
            _cell(product != null ? '$novyStav' : '–', fontSize: c.bodyFontSize, align: pw.TextAlign.right),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      columnWidths: colWidths,
      children: rows,
    );
  }

  static pw.Widget _buildSignatureBlock(InboundReceipt receipt, int bodyFontSize) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Podpis prijímajúceho',
                style: pw.TextStyle(fontSize: (bodyFontSize - 1).toDouble(), color: PdfColors.grey700),
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
        pw.SizedBox(width: 40),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Dátum prijatia',
                style: pw.TextStyle(fontSize: (bodyFontSize - 1).toDouble(), color: PdfColors.grey700),
              ),
              pw.SizedBox(height: 2),
              pw.Text(_formatDate(receipt.createdAt),
                  style: pw.TextStyle(fontSize: bodyFontSize.toDouble(), fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }
}
