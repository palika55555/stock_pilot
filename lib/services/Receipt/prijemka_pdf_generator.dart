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
// Light professional palette
// ─────────────────────────────────────────────────────────────────────────────
const _white       = PdfColors.white;
const _bgSection   = PdfColor.fromInt(0xFFF8F9FA);  // svetlé pozadie sekcií
const _bgTableHdr  = PdfColor.fromInt(0xFFF1F3F5);  // hlavička tabuľky
const _bgRowAlt    = PdfColor.fromInt(0xFFFAFAFB);  // striedavý riadok
const _accent      = PdfColor.fromInt(0xFF10B981);  // zelená
const _accentBg    = PdfColor.fromInt(0xFFECFDF5);  // zelená bg (badge)
const _accentDim   = PdfColor.fromInt(0xFF059669);  // tmavšia zelená
const _warnBg      = PdfColor.fromInt(0xFFFFFBEB);  // žltá bg (nevysporiadaná)
const _warn        = PdfColor.fromInt(0xFFD97706);  // žltá
const _textMain    = PdfColor.fromInt(0xFF111827);  // hlavný text
const _textSub     = PdfColor.fromInt(0xFF6B7280);  // sekundárny text
const _border      = PdfColor.fromInt(0xFFE5E7EB);  // border
const _borderDark  = PdfColor.fromInt(0xFFD1D5DB);  // tmavší border

class PrijemkaPdfGenerator {

  // ── Formatters ─────────────────────────────────────────────────────────────

  static String _d(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  static String _p(double v) {
    final s  = v.toStringAsFixed(2).replaceAll('.', ',');
    final sp = s.split(',');
    final buf = StringBuffer();
    final ip = sp[0];
    for (int i = 0; i < ip.length; i++) {
      if (i > 0 && (ip.length - i) % 3 == 0) buf.write('\u202F');
      buf.write(ip[i]);
    }
    return '$buf,${sp[1]}';
  }

  static String _expiry(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final p = iso.split('-');
    return p.length == 3 ? '${p[2]}.${p[1]}.${p[0]}' : iso;
  }

  // ── Cell helpers ──────────────────────────────────────────────────────────

  static pw.Widget _cell(
    String text, {
    bool bold    = false,
    double fs    = 9,
    pw.TextAlign align = pw.TextAlign.left,
    PdfColor? bg,
    PdfColor color = _textMain,
    pw.EdgeInsets pad = const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
  }) =>
      pw.Container(
        color: bg,
        padding: pad,
        child: pw.Text(text,
            textAlign: align,
            style: pw.TextStyle(
                fontSize: fs,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: color),
            maxLines: 3,
            overflow: pw.TextOverflow.clip),
      );

  static pw.Widget _hCell(String text, {pw.TextAlign align = pw.TextAlign.left}) =>
      _cell(text.toUpperCase(),
          bold: true, fs: 7, align: align,
          bg: _bgTableHdr, color: _textSub,
          pad: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8));

  static pw.Widget _vatBadge(String text, {PdfColor? bg}) =>
      pw.Container(
        color: bg,
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        alignment: pw.Alignment.center,
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          color: _warnBg,
          child: pw.Text(text,
              style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: _warn)),
        ),
      );

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

    final hasBatch  = items.any((i) => i.batchNumber?.isNotEmpty == true);
    final hasExpiry = items.any((i) => i.expiryDate?.isNotEmpty  == true);

    pw.Widget table;
    pw.Widget? vatSection;

    switch (type) {
      case PrintType.standard:
        table      = _tableStandard(receipt, items, hasBatch, hasExpiry);
        vatSection = _vatSection(receipt, items);
        break;
      case PrintType.retail:
        table      = _tableRetail(receipt, items, ctx.productsByUniqueId);
        vatSection = _vatSection(receipt, items);
        break;
      case PrintType.warehouse:
        table      = _tableWarehouse(items, hasBatch, hasExpiry);
        vatSection = null;
        break;
      case PrintType.stocks:
        table      = _tableStocks(items, ctx.productsByUniqueId);
        vatSection = null;
        break;
    }

    final doc = pw.Document(theme: theme);
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 28),
        header: (_) => _pageHeader(receipt, ctx, c, type),
        footer: (pCtx) => _pageFooter(pCtx),
        build: (_) => [
          pw.SizedBox(height: 12),
          _statusBar(receipt),
          pw.SizedBox(height: 10),
          _partiesSection(receipt, ctx),
          pw.SizedBox(height: 14),
          table,
          if (vatSection != null) ...[
            pw.SizedBox(height: 12),
            vatSection,
          ],
          if (c.showSignatureBlock) ...[
            pw.SizedBox(height: 20),
            _signatureBlock(receipt),
          ],
          pw.SizedBox(height: 8),
        ],
      ),
    );

    return doc.save();
  }

  // ── Page header ────────────────────────────────────────────────────────────

  static pw.Widget _pageHeader(
    InboundReceipt receipt,
    PrijemkaPdfContext ctx,
    ReceiptPdfStyleConfig c,
    PrintType type,
  ) {
    final title = c.effectiveDocumentTitle ?? 'Príjemka tovaru';
    return pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            // Logo
            pw.Container(
              width: 54, height: 54,
              decoration: pw.BoxDecoration(
                color: _bgSection,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: _border, width: 1),
              ),
              child: pw.Center(
                child: pw.Text('LOGO',
                    style: pw.TextStyle(fontSize: 8, color: _textSub, fontWeight: pw.FontWeight.bold)),
              ),
            ),
            pw.SizedBox(width: 14),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(title,
                      style: pw.TextStyle(
                          fontSize: 22, fontWeight: pw.FontWeight.bold, color: _textMain)),
                  pw.SizedBox(height: 3),
                  pw.Text(_typeLabel(type),
                      style: pw.TextStyle(fontSize: 9, color: _textSub)),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(receipt.receiptNumber,
                    style: pw.TextStyle(
                        fontSize: 15, fontWeight: pw.FontWeight.bold, color: _textMain, letterSpacing: 0.3)),
                pw.SizedBox(height: 4),
                pw.Text('Dátum: ${_d(receipt.createdAt)}',
                    style: pw.TextStyle(fontSize: 9, color: _textSub)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Container(height: 1.5, color: _textMain),
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

  // ── Status bar ─────────────────────────────────────────────────────────────

  static pw.Widget _statusBar(InboundReceipt receipt) {
    final settled = receipt.isSettled;
    final vatText = receipt.pricesIncludeVat ? 'Ceny vrátane DPH' : 'Ceny bez DPH';

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: pw.BoxDecoration(
        color: _bgSection,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(7)),
        border: pw.Border.all(color: _border, width: 0.8),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            color: settled ? _accentBg : _warnBg,
            child: pw.Text(settled ? 'VYSPORIADANÁ' : 'NEVYSPORIADANÁ',
                style: pw.TextStyle(
                    fontSize: 7.5, fontWeight: pw.FontWeight.bold,
                    color: settled ? _accentDim : _warn)),
          ),
          pw.SizedBox(width: 14),
          pw.Container(width: 1, height: 14, color: _border),
          pw.SizedBox(width: 14),
          pw.Text(vatText, style: pw.TextStyle(fontSize: 9, color: _textMain)),
          if (receipt.vatAppliesToAll && receipt.vatRate != null) ...[
            pw.SizedBox(width: 14),
            pw.Container(width: 1, height: 14, color: _border),
            pw.SizedBox(width: 14),
            pw.RichText(text: pw.TextSpan(children: [
              pw.TextSpan(text: 'Sadzba DPH ',
                  style: pw.TextStyle(fontSize: 9, color: _textSub)),
              pw.TextSpan(text: '${receipt.vatRate} %',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _textMain)),
            ])),
          ],
        ],
      ),
    );
  }

  // ── Parties ────────────────────────────────────────────────────────────────

  static pw.Widget _partiesSection(InboundReceipt receipt, PrijemkaPdfContext ctx) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _border, width: 0.8),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(7)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: _partyCol(
            label: 'DODÁVATEĽ',
            name: receipt.supplierName,
            lines: [
              if (receipt.supplierIco?.isNotEmpty == true)
                'IČO: ${receipt.supplierIco}'
                '${receipt.supplierDic?.isNotEmpty == true ? "   ·   DIČ: ${receipt.supplierDic}" : ""}',
              if (receipt.supplierAddress?.isNotEmpty == true)
                receipt.supplierAddress!,
              if (receipt.deliveryNoteNumber?.isNotEmpty == true)
                'Dodací list: ${receipt.deliveryNoteNumber}',
              if (receipt.poNumber?.isNotEmpty == true)
                'Objednávka (PO): ${receipt.poNumber}',
            ],
          )),
          pw.Container(
            width: 0.8,
            height: 90,
            color: _border,
            margin: const pw.EdgeInsets.symmetric(vertical: 10),
          ),
          pw.Expanded(child: _partyCol(
            label: 'PRÍJEMCA / SKLAD',
            name: ctx.warehouseName ??
                (receipt.warehouseId != null ? 'Sklad #${receipt.warehouseId}' : null),
            lines: [
              if (receipt.invoiceNumber?.isNotEmpty == true)
                'Faktúra č.: ${receipt.invoiceNumber}',
              if (ctx.issuedBy != null) 'Vystavil: ${ctx.issuedBy}',
            ],
          )),
        ],
      ),
    );
  }

  static pw.Widget _partyCol({
    required String label,
    String? name,
    List<String> lines = const [],
  }) =>
      pw.Padding(
        padding: const pw.EdgeInsets.all(14),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label,
                style: pw.TextStyle(
                    fontSize: 7, fontWeight: pw.FontWeight.bold,
                    color: _textSub, letterSpacing: 0.8)),
            pw.SizedBox(height: 6),
            if (name != null && name.isNotEmpty)
              pw.Text(name,
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _textMain)),
            pw.SizedBox(height: 4),
            ...lines.map((l) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 2),
                  child: pw.Text(l, style: pw.TextStyle(fontSize: 8.5, color: _textSub)),
                )),
          ],
        ),
      );

  // ── Tables ────────────────────────────────────────────────────────────────

  static pw.Widget _tableStandard(
    InboundReceipt receipt,
    List<InboundReceiptItem> items,
    bool hasBatch,
    bool hasExpiry,
  ) {
    final dv = receipt.vatRate ?? 20;
    double nv(double p, int v) =>
        (!receipt.pricesIncludeVat || v <= 0) ? p : (p / (1 + v / 100) * 100).round() / 100;

    int ci = 0;
    final cols = <int, pw.TableColumnWidth>{
      ci++: const pw.FlexColumnWidth(2.8),
      ci++: const pw.FlexColumnWidth(0.8),
      if (hasBatch)  ci++: const pw.FlexColumnWidth(1.0),
      if (hasExpiry) ci++: const pw.FlexColumnWidth(0.95),
      ci++: const pw.FlexColumnWidth(0.9),
      ci++: const pw.FlexColumnWidth(0.55),
      ci++: const pw.FlexColumnWidth(1.1),
      ci++: const pw.FlexColumnWidth(0.75),
      ci:   const pw.FlexColumnWidth(1.2),
    };

    final rows = <pw.TableRow>[
      pw.TableRow(children: [
        _hCell('Názov'),
        _hCell('PLU'),
        if (hasBatch)  _hCell('Šarža'),
        if (hasExpiry) _hCell('Expirácia'),
        _hCell('Množstvo',         align: pw.TextAlign.right),
        _hCell('MJ'),
        _hCell('Cena bez DPH/MJ',  align: pw.TextAlign.right),
        _hCell('DPH',              align: pw.TextAlign.center),
        _hCell('Celkom s DPH',     align: pw.TextAlign.right),
      ]),
    ];

    for (int i = 0; i < items.length; i++) {
      final item   = items[i];
      final vat    = item.vatPercent ?? receipt.vatRate ?? dv;
      final unitNV = nv(item.unitPrice, vat);
      final total  = (item.unitPrice * item.qty * 100).round() / 100;
      final bg     = i.isOdd ? _bgRowAlt : _white;
      rows.add(pw.TableRow(children: [
        _cell(item.productName ?? item.productUniqueId, bg: bg, fs: 9.5),
        _cell(item.plu ?? '',                           bg: bg, color: _textSub),
        if (hasBatch)  _cell(item.batchNumber ?? '',   bg: bg, color: _textSub),
        if (hasExpiry) _cell(_expiry(item.expiryDate), bg: bg, color: _textSub),
        _cell('${item.qty}',             align: pw.TextAlign.right, bg: bg, bold: true),
        _cell(item.unit,                 bg: bg, color: _textSub),
        _cell('${_p(unitNV)} €',         align: pw.TextAlign.right, bg: bg),
        _vatBadge('$vat %',              bg: bg),
        _cell('${_p(total)} €',          align: pw.TextAlign.right, bg: bg, bold: true),
      ]));
    }

    return _buildTable(cols, rows);
  }

  static pw.Widget _tableRetail(
    InboundReceipt receipt,
    List<InboundReceiptItem> items,
    Map<String, Product> products,
  ) {
    final dv = receipt.vatRate ?? 20;
    double nv(double p, int v) =>
        (!receipt.pricesIncludeVat || v <= 0) ? p : (p / (1 + v / 100) * 100).round() / 100;

    final cols = <int, pw.TableColumnWidth>{
      0: const pw.FlexColumnWidth(2.4), 1: const pw.FlexColumnWidth(0.7),
      2: const pw.FlexColumnWidth(0.7), 3: const pw.FlexColumnWidth(0.5),
      4: const pw.FlexColumnWidth(1.0), 5: const pw.FlexColumnWidth(0.7),
      6: const pw.FlexColumnWidth(1.0), 7: const pw.FlexColumnWidth(1.0),
      8: const pw.FlexColumnWidth(0.7),
    };

    final rows = <pw.TableRow>[
      pw.TableRow(children: [
        _hCell('Názov'), _hCell('PLU'),
        _hCell('Množstvo',          align: pw.TextAlign.right),
        _hCell('MJ'),
        _hCell('Cena bez DPH',      align: pw.TextAlign.right),
        _hCell('DPH',               align: pw.TextAlign.center),
        _hCell('Celkom s DPH',      align: pw.TextAlign.right),
        _hCell('Predajná cena',     align: pw.TextAlign.right),
        _hCell('Marža %',           align: pw.TextAlign.right),
      ]),
    ];

    for (int i = 0; i < items.length; i++) {
      final item   = items[i];
      final vat    = item.vatPercent ?? receipt.vatRate ?? dv;
      final unitNV = nv(item.unitPrice, vat);
      final total  = (item.unitPrice * item.qty * 100).round() / 100;
      final prod   = products[item.productUniqueId];
      final sale   = prod?.price ?? 0.0;
      final margin = prod != null && prod.price > 0
          ? ((prod.price - item.unitPrice) / prod.price * 100) : null;
      final bg = i.isOdd ? _bgRowAlt : _white;
      rows.add(pw.TableRow(children: [
        _cell(item.productName ?? item.productUniqueId, bg: bg, fs: 9.5),
        _cell(item.plu ?? '',              bg: bg, color: _textSub),
        _cell('${item.qty}',               align: pw.TextAlign.right, bg: bg, bold: true),
        _cell(item.unit,                   bg: bg, color: _textSub),
        _cell('${_p(unitNV)} €',           align: pw.TextAlign.right, bg: bg),
        _vatBadge('$vat %',                bg: bg),
        _cell('${_p(total)} €',            align: pw.TextAlign.right, bg: bg, bold: true),
        _cell(sale > 0 ? '${_p(sale)} €' : '–', align: pw.TextAlign.right, bg: bg),
        _cell(margin != null ? '${margin.toStringAsFixed(1)} %' : '–',
            align: pw.TextAlign.right, bg: bg, color: _accentDim),
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
        _hCell('MJ'), _hCell('Skutočne prijaté'),
      ]),
    ];

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final bg = i.isOdd ? _bgRowAlt : _white;
      rows.add(pw.TableRow(children: [
        _cell(item.productName ?? item.productUniqueId, bg: bg, fs: 9.5),
        _cell(item.plu ?? '',                           bg: bg, color: _textSub),
        if (hasBatch)  _cell(item.batchNumber ?? '',   bg: bg, color: _textSub),
        if (hasExpiry) _cell(_expiry(item.expiryDate), bg: bg, color: _textSub),
        _cell(item.unit,                                bg: bg, color: _textSub),
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
      0: const pw.FlexColumnWidth(3.0), 1: const pw.FlexColumnWidth(1.0),
      2: const pw.FlexColumnWidth(1.2), 3: const pw.FlexColumnWidth(1.2),
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
      final bg = i.isOdd ? _bgRowAlt : _white;
      rows.add(pw.TableRow(children: [
        _cell(item.productName ?? item.productUniqueId, bg: bg, fs: 9.5),
        _cell('${item.qty} ${item.unit}', align: pw.TextAlign.right, bg: bg, bold: true),
        _cell(product != null ? '$stavPred' : '–', align: pw.TextAlign.right, bg: bg, color: _textSub),
        _cell(product != null ? '${product.qty}' : '–', align: pw.TextAlign.right, bg: bg,
            color: _accentDim, bold: true),
      ]));
    }

    return _buildTable(cols, rows);
  }

  static pw.Widget _buildTable(Map<int, pw.TableColumnWidth> cols, List<pw.TableRow> rows) =>
      pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _borderDark, width: 0.8),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(7)),
        ),
        child: pw.ClipRRect(
          horizontalRadius: 7,
          verticalRadius: 7,
          child: pw.Table(
            columnWidths: cols,
            border: pw.TableBorder(
              horizontalInside: pw.BorderSide(color: _border, width: 0.5),
              verticalInside:   pw.BorderSide(color: _border, width: 0.5),
            ),
            children: rows,
          ),
        ),
      );

  // ── VAT section ────────────────────────────────────────────────────────────

  static pw.Widget _vatSection(InboundReceipt receipt, List<InboundReceiptItem> items) {
    final dv        = receipt.vatRate ?? 20;
    final breakdown = <int, ({double wV, double woV, double vAmt})>{};

    for (final item in items) {
      final vat     = item.vatPercent ?? receipt.vatRate ?? dv;
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
          : (wV:   ((cur.wV   + wV)   * 100).round() / 100,
             woV:  ((cur.woV  + woV)  * 100).round() / 100,
             vAmt: ((cur.vAmt + vAmt) * 100).round() / 100);
    }

    final grandTotal  = items.fold<double>(0, (s, i) => s + (i.unitPrice * i.qty * 100).round() / 100);
    final sortedRates = breakdown.keys.toList()..sort();

    // Fixed widths — no Expanded
    const double cSadzba = 72;
    const double cZaklad = 88;
    const double cDph    = 70;
    const double cSpolu  = 88;
    const double leftW   = cSadzba + cZaklad + cDph + cSpolu + 20;
    const double rightW  = 175;

    pw.Widget _lbl(String t) => pw.Text(t,
        style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold,
            color: _textSub, letterSpacing: 0.7));

    pw.Widget _vatRow(String s, String z, String d, String sp) =>
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 5),
          child: pw.Row(children: [
            pw.SizedBox(width: cSadzba, child: pw.Text(s,
                style: pw.TextStyle(fontSize: 8.5, color: _textMain))),
            pw.SizedBox(width: cZaklad, child: pw.Text(z, textAlign: pw.TextAlign.right,
                style: pw.TextStyle(fontSize: 8.5, color: _textMain))),
            pw.SizedBox(width: cDph,    child: pw.Text(d, textAlign: pw.TextAlign.right,
                style: pw.TextStyle(fontSize: 8.5, color: _textMain))),
            pw.SizedBox(width: cSpolu,  child: pw.Text(sp, textAlign: pw.TextAlign.right,
                style: pw.TextStyle(fontSize: 8.5, color: _textMain))),
          ]),
        );

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _border, width: 0.8),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(7)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Left — rekapitulácia
          pw.SizedBox(
            width: leftW,
            child: pw.Container(
              color: _bgSection,
              padding: const pw.EdgeInsets.all(16),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _lbl('REKAPITULÁCIA DPH'),
                  pw.SizedBox(height: 10),
                  pw.Row(children: [
                    pw.SizedBox(width: cSadzba, child: _lbl('SADZBA')),
                    pw.SizedBox(width: cZaklad, child: pw.Align(
                        alignment: pw.Alignment.centerRight, child: _lbl('ZÁKLAD'))),
                    pw.SizedBox(width: cDph,    child: pw.Align(
                        alignment: pw.Alignment.centerRight, child: _lbl('DPH'))),
                    pw.SizedBox(width: cSpolu,  child: pw.Align(
                        alignment: pw.Alignment.centerRight, child: _lbl('SPOLU'))),
                  ]),
                  pw.SizedBox(height: 6),
                  pw.Container(height: 0.5, color: _borderDark),
                  pw.SizedBox(height: 8),
                  ...sortedRates.map((rate) {
                    final b = breakdown[rate]!;
                    return _vatRow('DPH $rate %',
                        '${_p(b.woV)} €', '${_p(b.vAmt)} €', '${_p(b.wV)} €');
                  }),
                ],
              ),
            ),
          ),
          pw.Container(width: 0.8, height: 80, color: _border,
              margin: const pw.EdgeInsets.symmetric(vertical: 12)),
          // Right — total
          pw.SizedBox(
            width: rightW,
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(16),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.SizedBox(height: 8),
                  pw.Text('CELKOM NA ÚHRADU',
                      style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold,
                          color: _textSub, letterSpacing: 0.8)),
                  pw.SizedBox(height: 10),
                  pw.Text('${_p(grandTotal)} €',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                          fontSize: 20, fontWeight: pw.FontWeight.bold, color: _textMain)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Signature block ────────────────────────────────────────────────────────

  static pw.Widget _signatureBlock(InboundReceipt receipt) {
    pw.Widget _box(String label, {bool stamp = false}) => pw.Expanded(
          child: pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _border, width: 0.8),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(7)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: _bgSection,
                    borderRadius: const pw.BorderRadius.only(
                      topLeft: pw.Radius.circular(6),
                      topRight: pw.Radius.circular(6),
                    ),
                  ),
                  child: pw.Text(label,
                      style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold,
                          color: _textSub, letterSpacing: 0.7)),
                ),
                pw.Container(height: 0.5, color: _border),
                pw.SizedBox(height: stamp ? 58 : 46),
                pw.Container(height: 0.5, color: _border),
                pw.Container(
                  color: _bgSection,
                  padding: const pw.EdgeInsets.fromLTRB(10, 5, 10, 8),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Meno a priezvisko:',
                          style: pw.TextStyle(fontSize: 6.5, color: _textSub)),
                      pw.SizedBox(height: 3),
                      pw.Text(_d(receipt.createdAt),
                          style: pw.TextStyle(fontSize: 7.5, color: _textSub)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text('PODPISOVÝ ZÁZNAM',
            style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold,
                color: _textSub, letterSpacing: 1)),
        pw.SizedBox(height: 8),
        pw.Row(children: [
          _box('VYSTAVIL / ZODPOVEDNÁ OSOBA'),
          pw.SizedBox(width: 10),
          _box('SCHVÁLIL'),
          pw.SizedBox(width: 10),
          _box('PRIJAL / PEČIATKA', stamp: true),
        ]),
      ],
    );
  }

  // ── Page footer ────────────────────────────────────────────────────────────

  static pw.Widget _pageFooter(pw.Context ctx) {
    final now = DateTime.now();
    final ts  = '${_d(now)} ${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}';
    return pw.Column(
      children: [
        pw.Container(height: 0.5, color: _border),
        pw.SizedBox(height: 5),
        pw.Row(children: [
          pw.Text('Vygenerované: $ts',
              style: pw.TextStyle(fontSize: 6.5, color: _textSub)),
          pw.Spacer(),
          pw.Text('Strana ${ctx.pageNumber} / ${ctx.pagesCount}',
              style: pw.TextStyle(fontSize: 6.5, color: _textSub)),
        ]),
      ],
    );
  }

  static String typeTitle(InboundReceipt receipt, PrijemkaPdfContext ctx) =>
      ctx.styleConfig?.effectiveDocumentTitle ?? 'PRÍJEMKA TOVARU';
}
