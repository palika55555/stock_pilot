import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/product.dart';
import '../../models/receipt.dart';
import '../../models/receipt_pdf_style_config.dart';

enum PrintType {
  standard('Účtovná príjemka'),
  retail('Príjemka s predajnými cenami'),
  warehouse('Slepá príjemka pre skladníka'),
  stocks('Príjemka so stavmi zásob');

  final String label;
  const PrintType(this.label);
}

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

// ─────────────────────────────────────────────────────────────────────────────
// Paleta — čiernobiela s jemnými odtieňmi sivej
// ─────────────────────────────────────────────────────────────────────────────
const _kBlack      = PdfColors.black;
const _kWhite      = PdfColors.white;
const _kGrey100    = PdfColor.fromInt(0xFFF5F5F5);
const _kGrey200    = PdfColor.fromInt(0xFFEEEEEE);
const _kGrey400    = PdfColor.fromInt(0xFFBDBDBD);
const _kGrey700    = PdfColor.fromInt(0xFF616161);
const _kGrey900    = PdfColor.fromInt(0xFF212121);
const _kAccentLine = PdfColor.fromInt(0xFF424242); // linka pod nadpisom

class PrijemkaPdfGenerator {

  // ── Formatters ─────────────────────────────────────────────────────────────

  static String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  static String _formatPrice(double v) {
    final s = v.toStringAsFixed(2).replaceAll('.', ',');
    final parts = s.split(',');
    final buf   = StringBuffer();
    final ip    = parts[0];
    for (int i = 0; i < ip.length; i++) {
      if (i > 0 && (ip.length - i) % 3 == 0) buf.write('\u202F');
      buf.write(ip[i]);
    }
    return '$buf,${parts[1]}';
  }

  static String _formatExpiryForPdf(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final p = iso.split('-');
    if (p.length == 3) return '${p[2]}.${p[1]}.${p[0]}';
    return iso;
  }

  static PdfColor? _colorFromHex(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    try {
      final h = hex.replaceFirst('#', '');
      final v = h.length <= 6 ? 0xFF000000 | int.parse(h, radix: 16) : int.parse(h, radix: 16);
      return PdfColor.fromInt(v);
    } catch (_) { return null; }
  }

  // ── Cell ──────────────────────────────────────────────────────────────────

  static pw.Widget _cell(
    String text, {
    bool bold = false,
    double fs  = 8.5,
    pw.TextAlign align = pw.TextAlign.left,
    PdfColor? bg,
    PdfColor? fg,
    pw.EdgeInsets pad = const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
  }) {
    return pw.Container(
      color: bg,
      padding: pad,
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: fs,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: fg ?? _kGrey900,
        ),
        maxLines: 3,
        overflow: pw.TextOverflow.clip,
      ),
    );
  }

  static pw.Widget _hCell(String text, {pw.TextAlign align = pw.TextAlign.left}) =>
      _cell(text, bold: true, fs: 8, align: align,
            bg: _kGrey200, fg: _kGrey900,
            pad: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 6));

  // ── Public API ─────────────────────────────────────────────────────────────

  static Future<Uint8List> generatePdf({
    required InboundReceipt receipt,
    required List<InboundReceiptItem> items,
    required PrintType type,
    PrijemkaPdfContext? context,
  }) async {
    final ctx = context ?? const PrijemkaPdfContext();
    final c   = ctx.styleConfig ?? const ReceiptPdfStyleConfig();

    final baseFont = await PdfGoogleFonts.openSansRegular();
    final boldFont = await PdfGoogleFonts.openSansBold();
    final theme    = pw.ThemeData.withFont(base: baseFont, bold: boldFont);
    final doc      = pw.Document(theme: theme);

    final hasBatch  = items.any((i) => i.batchNumber?.isNotEmpty == true);
    final hasExpiry = items.any((i) => i.expiryDate?.isNotEmpty  == true);

    pw.Widget table;
    pw.Widget? vatFooter;

    switch (type) {
      case PrintType.standard:
        table     = _tableStandard(receipt, items, hasBatch, hasExpiry);
        vatFooter = _vatFooter(receipt, items);
        break;
      case PrintType.retail:
        table     = _tableRetail(receipt, items, ctx.productsByUniqueId);
        vatFooter = _vatFooter(receipt, items);
        break;
      case PrintType.warehouse:
        table     = _tableWarehouse(items, hasBatch, hasExpiry);
        vatFooter = null;
        break;
      case PrintType.stocks:
        table     = _tableStocks(items, ctx.productsByUniqueId);
        vatFooter = null;
        break;
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 36),
        header: (_) => _pageHeader(receipt, ctx, c, type),
        footer: (ctx) => _pageFooter(ctx),
        build: (_) => [
          pw.SizedBox(height: 18),
          _partiesRow(receipt, ctx),
          pw.SizedBox(height: 14),
          _metaRow(receipt),
          pw.SizedBox(height: 18),
          table,
          if (vatFooter != null) ...[
            pw.SizedBox(height: 16),
            vatFooter,
          ],
          if (c.showSignatureBlock) ...[
            pw.SizedBox(height: 32),
            _signatureBlock(receipt),
          ],
          pw.SizedBox(height: 8),
        ],
      ),
    );

    return doc.save();
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  // Čistý header: logo vľavo, názov dokladu vpravo — oddelený tučnou linkou.

  static pw.Widget _pageHeader(
    InboundReceipt receipt,
    PrijemkaPdfContext ctx,
    ReceiptPdfStyleConfig c,
    PrintType type,
  ) {
    final docTitle = c.effectiveDocumentTitle ?? 'PRÍJEMKA TOVARU';
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Logo placeholder
            pw.Container(
              width: 54,
              height: 54,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _kGrey400, width: 0.8),
              ),
              child: pw.Center(
                child: pw.Text('LOGO',
                    style: pw.TextStyle(fontSize: 8, color: _kGrey400)),
              ),
            ),
            pw.SizedBox(width: 16),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(docTitle,
                      style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: _kGrey900)),
                  pw.SizedBox(height: 3),
                  pw.Text(_typeLabel(type),
                      style: pw.TextStyle(fontSize: 9, color: _kGrey700)),
                ],
              ),
            ),
            // Doc info block (right-aligned)
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(receipt.receiptNumber,
                    style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: _kGrey900)),
                pw.SizedBox(height: 3),
                pw.Text('Dátum: ${_formatDate(receipt.createdAt)}',
                    style: pw.TextStyle(fontSize: 9, color: _kGrey700)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        // Tučná oddeľovacia linka
        pw.Container(height: 1.5, color: _kAccentLine),
      ],
    );
  }

  static String _typeLabel(PrintType t) {
    switch (t) {
      case PrintType.standard:  return 'Účtovná príjemka';
      case PrintType.retail:    return 'Príjemka s predajnými cenami';
      case PrintType.warehouse: return 'Slepá príjemka pre skladníka';
      case PrintType.stocks:    return 'Príjemka so stavmi zásob';
    }
  }

  // ── Parties row ───────────────────────────────────────────────────────────
  // Dodávateľ | Príjemca — dve kolonky oddelené zvislou čiarou.

  static pw.Widget _partiesRow(InboundReceipt receipt, PrijemkaPdfContext ctx) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(child: _partyBlock(
          label: 'DODÁVATEĽ',
          name: receipt.supplierName,
          lines: [
            if (receipt.supplierIco?.isNotEmpty == true)
              'IČO: ${receipt.supplierIco}'
              '${receipt.supplierDic?.isNotEmpty == true ? "   DIČ: ${receipt.supplierDic}" : ""}',
            if (receipt.supplierAddress?.isNotEmpty == true)
              receipt.supplierAddress!,
          ],
        )),
        // Zvislá oddeľovacia čiara
        pw.Container(
          width: 0.8,
          margin: const pw.EdgeInsets.symmetric(horizontal: 16),
          color: _kGrey400,
        ),
        pw.Expanded(child: _partyBlock(
          label: 'PRÍJEMCA / SKLAD',
          name: ctx.warehouseName ?? (receipt.warehouseId != null ? 'Sklad ID: ${receipt.warehouseId}' : null),
          lines: [
            if (receipt.deliveryNoteNumber?.isNotEmpty == true)
              'Dodací list č.: ${receipt.deliveryNoteNumber}',
            if (receipt.poNumber?.isNotEmpty == true)
              'Č. objednávky (PO): ${receipt.poNumber}',
            if (receipt.invoiceNumber?.isNotEmpty == true)
              'Faktúra č.: ${receipt.invoiceNumber}',
            if (ctx.issuedBy != null) 'Vystavil: ${ctx.issuedBy}',
          ],
        )),
      ],
    );
  }

  static pw.Widget _partyBlock({
    required String label,
    String? name,
    List<String> lines = const [],
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Sekcia label
        pw.Text(label,
            style: pw.TextStyle(
                fontSize: 7,
                fontWeight: pw.FontWeight.bold,
                color: _kGrey700,
                letterSpacing: 0.8)),
        pw.SizedBox(height: 5),
        if (name != null && name.isNotEmpty)
          pw.Text(name,
              style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: _kGrey900)),
        pw.SizedBox(height: 3),
        ...lines.map((l) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2),
              child: pw.Text(l,
                  style: pw.TextStyle(fontSize: 8.5, color: _kGrey700)),
            )),
      ],
    );
  }

  // ── Meta row (stav, DPH info) ─────────────────────────────────────────────

  static pw.Widget _metaRow(InboundReceipt receipt) {
    final statusText  = receipt.isSettled ? 'Vysporiadaná' : 'Nevysporiadaná';
    final vatText     = receipt.pricesIncludeVat ? 'Ceny vrátane DPH' : 'Ceny bez DPH';
    final vatRateText = receipt.vatAppliesToAll && receipt.vatRate != null
        ? '   •   Sadzba DPH: ${receipt.vatRate} %' : '';

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        color: _kGrey100,
        border: pw.Border.all(color: _kGrey200, width: 0.8),
      ),
      child: pw.Row(
        children: [
          // Stav dokladu
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _kGrey400, width: 0.8),
            ),
            child: pw.Text(statusText,
                style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: _kGrey900)),
          ),
          pw.SizedBox(width: 16),
          pw.Text('$vatText$vatRateText',
              style: pw.TextStyle(fontSize: 8.5, color: _kGrey700)),
        ],
      ),
    );
  }

  // ── Tables ────────────────────────────────────────────────────────────────

  static pw.Widget _tableStandard(
    InboundReceipt receipt,
    List<InboundReceiptItem> items,
    bool hasBatch,
    bool hasExpiry,
  ) {
    final defaultVat = receipt.vatRate ?? 20;
    double noVat(double p, int vat) =>
        (!receipt.pricesIncludeVat || vat <= 0)
            ? p
            : (p / (1 + vat / 100) * 100).round() / 100;

    int ci = 0;
    final cols = <int, pw.TableColumnWidth>{
      ci++: const pw.FlexColumnWidth(2.8),
      ci++: const pw.FlexColumnWidth(0.8),
      if (hasBatch)  ci++: const pw.FlexColumnWidth(1.0),
      if (hasExpiry) ci++: const pw.FlexColumnWidth(0.95),
      ci++: const pw.FlexColumnWidth(0.65),
      ci++: const pw.FlexColumnWidth(0.55),
      ci++: const pw.FlexColumnWidth(1.1),
      ci++: const pw.FlexColumnWidth(0.65),
      ci:   const pw.FlexColumnWidth(1.1),
    };

    final rows = <pw.TableRow>[
      pw.TableRow(children: [
        _hCell('Názov'),
        _hCell('PLU'),
        if (hasBatch)  _hCell('Šarža'),
        if (hasExpiry) _hCell('Expirácia'),
        _hCell('Mn',              align: pw.TextAlign.right),
        _hCell('MJ'),
        _hCell('Cena bez DPH/MJ', align: pw.TextAlign.right),
        _hCell('DPH',             align: pw.TextAlign.right),
        _hCell('Celkom s DPH',    align: pw.TextAlign.right),
      ]),
    ];

    for (int i = 0; i < items.length; i++) {
      final item  = items[i];
      final vat   = item.vatPercent ?? receipt.vatRate ?? defaultVat;
      final unitNV = noVat(item.unitPrice, vat);
      final total  = (item.unitPrice * item.qty * 100).round() / 100;
      final bg     = i.isOdd ? _kGrey100 : _kWhite;
      rows.add(pw.TableRow(children: [
        _cell(item.productName ?? item.productUniqueId, bg: bg),
        _cell(item.plu ?? '',                          bg: bg),
        if (hasBatch)  _cell(item.batchNumber ?? '',   bg: bg),
        if (hasExpiry) _cell(_formatExpiryForPdf(item.expiryDate), bg: bg),
        _cell('${item.qty}',                align: pw.TextAlign.right, bg: bg),
        _cell(item.unit,                               bg: bg),
        _cell('${_formatPrice(unitNV)} €',  align: pw.TextAlign.right, bg: bg),
        _cell('$vat %',                     align: pw.TextAlign.right, bg: bg),
        _cell('${_formatPrice(total)} €',   align: pw.TextAlign.right, bg: bg),
      ]));
    }

    return _buildTable(cols, rows);
  }

  static pw.Widget _tableRetail(
    InboundReceipt receipt,
    List<InboundReceiptItem> items,
    Map<String, Product> products,
  ) {
    final defaultVat = receipt.vatRate ?? 20;
    double noVat(double p, int vat) =>
        (!receipt.pricesIncludeVat || vat <= 0) ? p : (p / (1 + vat / 100) * 100).round() / 100;

    final cols = <int, pw.TableColumnWidth>{
      0: const pw.FlexColumnWidth(2.4), 1: const pw.FlexColumnWidth(0.7),
      2: const pw.FlexColumnWidth(0.6), 3: const pw.FlexColumnWidth(0.5),
      4: const pw.FlexColumnWidth(1.0), 5: const pw.FlexColumnWidth(0.6),
      6: const pw.FlexColumnWidth(1.0), 7: const pw.FlexColumnWidth(1.0),
      8: const pw.FlexColumnWidth(0.7),
    };

    final rows = <pw.TableRow>[
      pw.TableRow(children: [
        _hCell('Názov'),  _hCell('PLU'),
        _hCell('Mn',           align: pw.TextAlign.right),
        _hCell('MJ'),
        _hCell('Cena bez DPH', align: pw.TextAlign.right),
        _hCell('DPH',          align: pw.TextAlign.right),
        _hCell('Celkom s DPH', align: pw.TextAlign.right),
        _hCell('Predajná cena',align: pw.TextAlign.right),
        _hCell('Marža %',      align: pw.TextAlign.right),
      ]),
    ];

    for (int i = 0; i < items.length; i++) {
      final item  = items[i];
      final vat   = item.vatPercent ?? receipt.vatRate ?? defaultVat;
      final unitNV = noVat(item.unitPrice, vat);
      final total  = (item.unitPrice * item.qty * 100).round() / 100;
      final prod   = products[item.productUniqueId];
      final sale   = prod?.price ?? 0.0;
      final margin = prod != null && prod.price > 0
          ? ((prod.price - item.unitPrice) / prod.price * 100) : null;
      final bg = i.isOdd ? _kGrey100 : _kWhite;
      rows.add(pw.TableRow(children: [
        _cell(item.productName ?? item.productUniqueId, bg: bg),
        _cell(item.plu ?? '', bg: bg),
        _cell('${item.qty}',               align: pw.TextAlign.right, bg: bg),
        _cell(item.unit,                   bg: bg),
        _cell('${_formatPrice(unitNV)} €', align: pw.TextAlign.right, bg: bg),
        _cell('$vat %',                    align: pw.TextAlign.right, bg: bg),
        _cell('${_formatPrice(total)} €',  align: pw.TextAlign.right, bg: bg),
        _cell(sale > 0 ? '${_formatPrice(sale)} €' : '–', align: pw.TextAlign.right, bg: bg),
        _cell(margin != null ? '${margin.toStringAsFixed(1)} %' : '–', align: pw.TextAlign.right, bg: bg),
      ]));
    }

    return _buildTable(cols, rows);
  }

  static pw.Widget _tableWarehouse(
    List<InboundReceiptItem> items,
    bool hasBatch,
    bool hasExpiry,
  ) {
    int ci = 0;
    final cols = <int, pw.TableColumnWidth>{
      ci++: const pw.FlexColumnWidth(3.0),
      ci++: const pw.FlexColumnWidth(0.8),
      if (hasBatch)  ci++: const pw.FlexColumnWidth(1.0),
      if (hasExpiry) ci++: const pw.FlexColumnWidth(1.0),
      ci++: const pw.FlexColumnWidth(0.7),
      ci:   const pw.FlexColumnWidth(2.0),
    };

    final rows = <pw.TableRow>[
      pw.TableRow(children: [
        _hCell('Názov'), _hCell('PLU'),
        if (hasBatch)  _hCell('Šarža'),
        if (hasExpiry) _hCell('Expirácia'),
        _hCell('MJ'),
        _hCell('Skutočne prijaté'),
      ]),
    ];

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final bg = i.isOdd ? _kGrey100 : _kWhite;
      rows.add(pw.TableRow(children: [
        _cell(item.productName ?? item.productUniqueId, bg: bg),
        _cell(item.plu ?? '',                           bg: bg),
        if (hasBatch)  _cell(item.batchNumber ?? '',    bg: bg),
        if (hasExpiry) _cell(_formatExpiryForPdf(item.expiryDate), bg: bg),
        _cell(item.unit,                                bg: bg),
        _cell('',                                       bg: bg),
      ]));
    }

    return _buildTable(cols, rows);
  }

  static pw.Widget _tableStocks(
    List<InboundReceiptItem> items,
    Map<String, Product> products,
  ) {
    final cols = <int, pw.TableColumnWidth>{
      0: const pw.FlexColumnWidth(3.0),
      1: const pw.FlexColumnWidth(1.0),
      2: const pw.FlexColumnWidth(1.2),
      3: const pw.FlexColumnWidth(1.2),
    };

    final rows = <pw.TableRow>[
      pw.TableRow(children: [
        _hCell('Položka'),
        _hCell('Prijaté',             align: pw.TextAlign.right),
        _hCell('Stav pred príjmom',   align: pw.TextAlign.right),
        _hCell('Nový stav po príjme', align: pw.TextAlign.right),
      ]),
    ];

    for (int i = 0; i < items.length; i++) {
      final item    = items[i];
      final product = products[item.productUniqueId];
      final stavPred = (product?.qty ?? 0) - item.qty;
      final novyStav = product?.qty ?? 0;
      final bg = i.isOdd ? _kGrey100 : _kWhite;
      rows.add(pw.TableRow(children: [
        _cell(item.productName ?? item.productUniqueId, bg: bg),
        _cell('${item.qty} ${item.unit}', align: pw.TextAlign.right, bg: bg),
        _cell(product != null ? '$stavPred' : '–', align: pw.TextAlign.right, bg: bg),
        _cell(product != null ? '$novyStav' : '–', align: pw.TextAlign.right, bg: bg),
      ]));
    }

    return _buildTable(cols, rows);
  }

  static pw.Widget _buildTable(
    Map<int, pw.TableColumnWidth> cols,
    List<pw.TableRow> rows,
  ) {
    return pw.Table(
      columnWidths: cols,
      border: pw.TableBorder(
        top:             pw.BorderSide(color: _kGrey400, width: 0.8),
        bottom:          pw.BorderSide(color: _kGrey400, width: 0.8),
        left:            pw.BorderSide(color: _kGrey400, width: 0.8),
        right:           pw.BorderSide(color: _kGrey400, width: 0.8),
        horizontalInside: pw.BorderSide(color: _kGrey200, width: 0.5),
        verticalInside:   pw.BorderSide(color: _kGrey200, width: 0.5),
      ),
      children: rows,
    );
  }

  // ── VAT Footer ─────────────────────────────────────────────────────────────

  static pw.Widget _vatFooter(
    InboundReceipt receipt,
    List<InboundReceiptItem> items,
  ) {
    final defaultVat = receipt.vatRate ?? 20;
    final breakdown  = <int, ({double wV, double woV, double vAmt})>{};

    for (final item in items) {
      final vat     = item.vatPercent ?? receipt.vatRate ?? defaultVat;
      final lineRaw = (item.unitPrice * item.qty * 100).round() / 100;
      double wV, woV;
      if (receipt.pricesIncludeVat) {
        wV  = lineRaw;
        woV = vat <= 0 ? lineRaw : (lineRaw / (1 + vat / 100) * 100).round() / 100;
      } else {
        woV = lineRaw;
        wV  = vat <= 0 ? lineRaw : (lineRaw * (1 + vat / 100) * 100).round() / 100;
      }
      final vAmt = ((wV - woV) * 100).round() / 100;
      final cur  = breakdown[vat];
      breakdown[vat] = cur == null
          ? (wV: wV, woV: woV, vAmt: vAmt)
          : (
              wV:   ((cur.wV   + wV)   * 100).round() / 100,
              woV:  ((cur.woV  + woV)  * 100).round() / 100,
              vAmt: ((cur.vAmt + vAmt) * 100).round() / 100,
            );
    }

    final grandTotal = items.fold<double>(
        0, (s, i) => s + (i.unitPrice * i.qty * 100).round() / 100);
    final sortedRates = breakdown.keys.toList()..sort();

    // Fixná šírka stĺpcov — žiadne Expanded (unbounded constraint fix)
    const double colLabel = 100;
    const double colBase  = 80;
    const double colVat   = 60;
    const double colTotal = 80;
    const double boxW     = colLabel + colBase + colVat + colTotal + 8;

    pw.Widget _rw(String label, String base, String vat, String total, {bool bold = false}) =>
        pw.Row(children: [
          pw.SizedBox(width: colLabel,
              child: pw.Text(label, style: pw.TextStyle(fontSize: 8.5,
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal))),
          pw.SizedBox(width: colBase,
              child: pw.Text(base, textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(fontSize: 8.5,
                      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal))),
          pw.SizedBox(width: colVat,
              child: pw.Text(vat, textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(fontSize: 8.5,
                      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal))),
          pw.SizedBox(width: colTotal,
              child: pw.Text(total, textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(fontSize: 8.5,
                      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal))),
        ]);

    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.SizedBox(
        width: boxW,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Container(height: 1.5, color: _kAccentLine),
            pw.SizedBox(height: 8),

            // Hlavičky stĺpcov
            pw.Row(children: [
              pw.SizedBox(width: colLabel,
                  child: pw.Text('Rekapitulácia DPH',
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(width: colBase,
                  child: pw.Text('Základ', textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(fontSize: 7.5, color: _kGrey700))),
              pw.SizedBox(width: colVat,
                  child: pw.Text('DPH', textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(fontSize: 7.5, color: _kGrey700))),
              pw.SizedBox(width: colTotal,
                  child: pw.Text('Spolu', textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(fontSize: 7.5, color: _kGrey700))),
            ]),
            pw.SizedBox(height: 4),
            pw.Container(height: 0.5, color: _kGrey400),
            pw.SizedBox(height: 6),

            // Riadky DPH
            ...sortedRates.map((rate) {
              final b = breakdown[rate]!;
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: _rw('DPH $rate %', '${_formatPrice(b.woV)} €',
                    '${_formatPrice(b.vAmt)} €', '${_formatPrice(b.wV)} €'),
              );
            }),

            pw.SizedBox(height: 6),
            pw.Container(height: 1, color: _kGrey900),
            pw.SizedBox(height: 8),

            // Celková suma
            pw.Row(
              children: [
                pw.SizedBox(width: colLabel,
                    child: pw.Text('CELKOM NA ÚHRADU',
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                pw.Spacer(),
                pw.Text('${_formatPrice(grandTotal)} €',
                      style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: _kGrey900)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Container(height: 1.5, color: _kAccentLine),
            ],
          ),
        ),
      );
  }

  static pw.Widget _w80(pw.Widget child) => pw.SizedBox(width: 80, child: child);
  static pw.Widget _w60(pw.Widget child) => pw.SizedBox(width: 60, child: child);

  // ── Signature block ────────────────────────────────────────────────────────

  static pw.Widget _signatureBlock(InboundReceipt receipt) {
    // Jeden podpisový blok — nadpis, priestor pre podpis, linka, meno, dátum
    pw.Widget _sigBox({
      required String title,
      bool showStamp = false,
      String? dateValue,
    }) {
      return pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _kGrey200, width: 0.8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // Hlavička bloku
            pw.Container(
              color: _kGrey100,
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              child: pw.Text(title,
                  style: pw.TextStyle(
                      fontSize: 7.5,
                      fontWeight: pw.FontWeight.bold,
                      color: _kGrey700,
                      letterSpacing: 0.5)),
            ),
            pw.Container(height: 0.5, color: _kGrey200),
            // Priestor pre podpis / pečiatku
            pw.Container(
              height: showStamp ? 64 : 52,
              padding: const pw.EdgeInsets.all(8),
              child: showStamp
                  ? pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Pečiatka:',
                            style: pw.TextStyle(fontSize: 7, color: _kGrey400)),
                      ],
                    )
                  : pw.SizedBox(),
            ),
            // Spodný pruh — linka + meno + dátum
            pw.Container(
              color: _kGrey100,
              padding: const pw.EdgeInsets.fromLTRB(8, 5, 8, 6),
              child: pw.Row(
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Meno a priezvisko:',
                          style: pw.TextStyle(fontSize: 6.5, color: _kGrey400)),
                      pw.SizedBox(height: 10),
                      pw.SizedBox(
                        width: 120,
                        child: pw.Container(height: 0.6, color: _kGrey400),
                      ),
                    ],
                  ),
                  pw.Spacer(),
                  pw.SizedBox(width: 12),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Dátum:',
                          style: pw.TextStyle(fontSize: 6.5, color: _kGrey400)),
                      pw.SizedBox(height: 3),
                      pw.Text(
                          dateValue ?? _formatDate(receipt.createdAt),
                          style: pw.TextStyle(
                              fontSize: 8.5,
                              fontWeight: pw.FontWeight.bold,
                              color: _kGrey900)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // Oddeľovač
        pw.Container(height: 1, color: _kGrey200),
        pw.SizedBox(height: 16),
        pw.Text('PODPISOVÝ ZÁZNAM',
            style: pw.TextStyle(
                fontSize: 7,
                fontWeight: pw.FontWeight.bold,
                color: _kGrey700,
                letterSpacing: 1.0)),
        pw.SizedBox(height: 8),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: _sigBox(title: 'VYSTAVIL / ZODPOVEDNÁ OSOBA')),
            pw.SizedBox(width: 10),
            pw.Expanded(child: _sigBox(title: 'SCHVÁLIL')),
            pw.SizedBox(width: 10),
            pw.Expanded(child: _sigBox(title: 'PRIJAL / PEČIATKA', showStamp: true)),
          ],
        ),
      ],
    );
  }

  // ── Page footer ────────────────────────────────────────────────────────────

  static pw.Widget _pageFooter(pw.Context ctx) {
    final now = DateTime.now();
    final ts  = '${_formatDate(now)} '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 6),
      padding: const pw.EdgeInsets.only(top: 5),
      decoration: const pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: _kGrey400, width: 0.5))),
      child: pw.Row(children: [
        pw.Text('Vygenerované: $ts',
            style: pw.TextStyle(fontSize: 7, color: _kGrey700)),
        pw.Spacer(),
        pw.Text('Strana ${ctx.pageNumber} / ${ctx.pagesCount}',
            style: pw.TextStyle(fontSize: 7, color: _kGrey700)),
      ]),
    );
  }

  // ── Legacy ─────────────────────────────────────────────────────────────────

  static String typeTitle(InboundReceipt receipt, PrijemkaPdfContext ctx) =>
      ctx.styleConfig?.effectiveDocumentTitle ?? 'PRÍJEMKA TOVARU';
}
