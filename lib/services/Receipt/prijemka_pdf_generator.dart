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
// Design tokens — Light professional palette
// ─────────────────────────────────────────────────────────────────────────────

const _border    = PdfColor.fromInt(0xFFE5E7EB);
const _bgLight   = PdfColor.fromInt(0xFFF9FAFB);
const _bgRow     = PdfColor.fromInt(0xFFFAFAFA);
const _textMuted = PdfColor.fromInt(0xFF9CA3AF);
const _textSub   = PdfColor.fromInt(0xFF374151);
const _textDark  = PdfColor.fromInt(0xFF111111);
const _borderMid = PdfColor.fromInt(0xFFD1D5DB);
const _greenBg   = PdfColor.fromInt(0xFFD1FAE5);
const _greenText = PdfColor.fromInt(0xFF065F46);
const _amberBg   = PdfColor.fromInt(0xFFFEF3C7);
const _amberText = PdfColor.fromInt(0xFF92400E);
const _grayBg    = PdfColor.fromInt(0xFFF3F4F6);
const _white     = PdfColors.white;

/// Font bundle for PDF rendering (titles: serif; numbers/codes: mono; body: outfit).
class _Fonts {
  final pw.Font serif;
  final pw.Font mono;
  final pw.Font monoBold;
  final pw.Font body;
  final pw.Font bodyMed;
  final pw.Font bodySemi;
  const _Fonts({
    required this.serif,
    required this.mono,
    required this.monoBold,
    required this.body,
    required this.bodyMed,
    required this.bodySemi,
  });
}

class PrijemkaPdfGenerator {

  // ── Formatters ──────────────────────────────────────────────────────────────

  static String _d(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  /// Currency: 1 234,56 €
  static String _formatCurrency(double amount) =>
      '${amount.toStringAsFixed(2).replaceAll('.', ',').replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}\u202F')} €';

  static String _expiry(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final p = iso.split('-');
    return p.length == 3 ? '${p[2]}.${p[1]}.${p[0]}' : iso;
  }

  static String _formatQty(double qty) {
    final isWhole = qty == qty.roundToDouble();
    final s = isWhole ? qty.toInt().toString() : qty.toString();
    return s.replaceAll('.', ',');
  }

  static String _typeLabel(PrintType t) {
    switch (t) {
      case PrintType.standard:  return 'Účtovná príjemka';
      case PrintType.retail:    return 'Príjemka s predajnými cenami';
      case PrintType.warehouse: return 'Slepá príjemka pre skladníka';
      case PrintType.stocks:    return 'Príjemka so stavmi zásob';
    }
  }

  // ── Helper widgets ──────────────────────────────────────────────────────────

  /// Pill badge — solid color only, clipped to rounded rect (no decoration artifacts).
  static pw.Widget _buildPill(_Fonts f, String text, PdfColor bg, PdfColor fg,
      {double fs = 7.5}) =>
      pw.ClipRRect(
        horizontalRadius: 99,
        verticalRadius: 99,
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          color: bg,
          child: pw.Text(text.toUpperCase(),
              style: pw.TextStyle(
                  font: f.bodySemi,
                  fontSize: fs,
                  fontWeight: pw.FontWeight.bold,
                  color: fg)),
        ),
      );

  /// 1pt horizontal rule
  static pw.Widget _buildDivider({double thickness = 0.8, PdfColor? color}) =>
      pw.Container(height: thickness, color: color ?? _border);

  /// Uppercase section label (7.5pt bold muted, letterSpacing 0.9)
  static pw.Widget _buildSectionLabel(_Fonts f, String text) =>
      pw.Text(text.toUpperCase(),
          style: pw.TextStyle(
              font: f.body,
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
              color: _textMuted,
              letterSpacing: 0.9));

  // ── Cell helpers ────────────────────────────────────────────────────────────

  static pw.Widget _cell(
    _Fonts f,
    String text, {
    bool bold = false,
    double fs = 9.5,
    pw.TextAlign align = pw.TextAlign.left,
    PdfColor? bg,
    PdfColor color = _textSub,
    bool mono = false,
    pw.EdgeInsets pad = const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
  }) {
    final font = mono ? (bold ? f.monoBold : f.mono) : f.body;
    return pw.Container(
      color: bg,
      padding: pad,
      child: pw.Text(text,
          textAlign: align,
          style: pw.TextStyle(
              font: font,
              fontSize: fs,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color),
          maxLines: 3,
          overflow: pw.TextOverflow.clip),
    );
  }

  static pw.Widget _hCell(_Fonts f, String text,
          {pw.TextAlign align = pw.TextAlign.left}) =>
      pw.Container(
        color: _bgLight,
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: pw.Text(text.toUpperCase(),
            textAlign: align,
            style: pw.TextStyle(
                font: f.body,
                fontSize: 7.5,
                fontWeight: pw.FontWeight.bold,
                color: _textMuted,
                letterSpacing: 0.6)),
      );

  static pw.Widget _amberPill(_Fonts f, String text, {PdfColor? cellBg}) =>
      pw.Container(
        color: cellBg ?? _white,
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        alignment: pw.Alignment.center,
        child: pw.ClipRRect(
          horizontalRadius: 99,
          verticalRadius: 99,
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            color: _amberBg,
            child: pw.Text(text,
                style: pw.TextStyle(
                    font: f.bodySemi,
                    fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold,
                    color: _amberText)),
          ),
        ),
      );

  // ── 1. HEADER ───────────────────────────────────────────────────────────────

  static pw.Widget _buildHeader(
    _Fonts f,
    InboundReceipt receipt,
    PrijemkaPdfContext ctx,
    ReceiptPdfStyleConfig c,
    PrintType type,
  ) {
    final title = c.effectiveDocumentTitle;
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Container(
              width: 56,
              height: 56,
              decoration: pw.BoxDecoration(
                color: _bgLight,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                border: pw.Border.all(
                    color: _borderMid, width: 1.2, style: pw.BorderStyle.dashed),
              ),
              alignment: pw.Alignment.center,
              child: pw.Text('LOGO',
                  style: pw.TextStyle(
                      font: f.body,
                      fontSize: 9,
                      color: _textMuted)),
            ),
            pw.SizedBox(width: 16),
            pw.Expanded(
              child: pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(title,
                      style: pw.TextStyle(
                          font: f.serif,
                          fontSize: 22,
                          color: _textDark)),
                  pw.SizedBox(height: 3),
                  pw.Text(_typeLabel(type),
                      style: pw.TextStyle(
                          font: f.body,
                          fontSize: 10,
                          color: _textMuted)),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(receipt.receiptNumber,
                    style: pw.TextStyle(
                        font: f.monoBold,
                        fontSize: 16,
                        color: _textDark,
                        letterSpacing: 0.3)),
                pw.SizedBox(height: 5),
                pw.Text(_d(receipt.createdAt),
                    style: pw.TextStyle(
                        font: f.body,
                        fontSize: 10,
                        color: _textMuted)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 14),
        _buildDivider(thickness: 1.5, color: _textDark),
      ],
    );
  }

  // ── 2. STATUS BAR ───────────────────────────────────────────────────────────

  static pw.Widget _buildStatusBar(_Fonts f, InboundReceipt receipt) {
    final settled = receipt.isSettled;
    final vatText = receipt.pricesIncludeVat ? 'Ceny vrátane DPH' : 'Ceny bez DPH';

    return pw.Container(
      height: 34,
      color: _bgLight,
      padding: const pw.EdgeInsets.symmetric(horizontal: 14),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          _buildPill(
            f,
            settled ? 'Vysporiadaná' : 'Nevysporiadaná',
            settled ? _greenBg : _amberBg,
            settled ? _greenText : _amberText,
            fs: 10,
          ),
          pw.SizedBox(width: 14),
          pw.Container(width: 1, height: 14, color: _border),
          pw.SizedBox(width: 14),
          pw.RichText(
              text: pw.TextSpan(
                  text: vatText,
                  style: pw.TextStyle(
                      font: f.body,
                      fontSize: 9,
                      color: _textSub))),
          if (receipt.vatAppliesToAll && receipt.vatRate != null) ...[
            pw.SizedBox(width: 14),
            pw.Container(width: 1, height: 14, color: _border),
            pw.SizedBox(width: 14),
            pw.RichText(text: pw.TextSpan(children: [
              pw.TextSpan(
                  text: 'Sadzba DPH: ',
                  style: pw.TextStyle(
                      font: f.body,
                      fontSize: 9,
                      color: _textSub)),
              pw.TextSpan(
                  text: '${receipt.vatRate} %',
                  style: pw.TextStyle(
                      font: f.bodyMed,
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: _textSub)),
            ])),
          ],
        ],
      ),
    );
  }

  // ── 3. PARTIES ──────────────────────────────────────────────────────────────

  static pw.Widget _buildParties(
      _Fonts f, InboundReceipt receipt, PrijemkaPdfContext ctx) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _border, width: 0.8),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
              child: _partyCol(
            f,
            label: 'Dodávateľ',
            name: receipt.supplierName,
            lines: [
              if (receipt.supplierIco?.isNotEmpty == true)
                'IČO: ${receipt.supplierIco}${receipt.supplierDic?.isNotEmpty == true ? "   ·   DIČ: ${receipt.supplierDic}" : ""}',
              if (receipt.supplierAddress?.isNotEmpty == true)
                receipt.supplierAddress!,
              if (receipt.deliveryNoteNumber?.isNotEmpty == true)
                'Dodací list: ${receipt.deliveryNoteNumber}',
              if (receipt.poNumber?.isNotEmpty == true)
                'Objednávka (PO): ${receipt.poNumber}',
            ],
          )),
          pw.Container(
            width: 1,
            color: _border,
            margin: const pw.EdgeInsets.symmetric(vertical: 14),
          ),
          pw.Expanded(
              child: _partyCol(
            f,
            label: 'Príjemca / Sklad',
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

  static pw.Widget _partyCol(
    _Fonts f, {
    required String label,
    String? name,
    List<String> lines = const [],
  }) =>
      pw.Padding(
        padding: const pw.EdgeInsets.all(14),
        child: pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildSectionLabel(f, label),
            pw.SizedBox(height: 6),
            if (name != null && name.isNotEmpty)
              pw.Text(name,
                  style: pw.TextStyle(
                      font: f.bodySemi,
                      fontSize: 11,
                      color: _textDark)),
            pw.SizedBox(height: 4),
            ...lines.map(
                (l) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 2),
                    child: pw.Text(l,
                        style: pw.TextStyle(
                            font: f.body,
                            fontSize: 8.5,
                            color: _textMuted)))),
          ],
        ),
      );

  // ── 4. ITEMS TABLES ─────────────────────────────────────────────────────────

  static pw.Widget _tableStandard(
    _Fonts f,
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
        _hCell(f, 'Názov'),
        _hCell(f, 'PLU'),
        if (hasBatch)  _hCell(f, 'Šarža'),
        if (hasExpiry) _hCell(f, 'Expirácia'),
        _hCell(f, 'Množstvo',        align: pw.TextAlign.right),
        _hCell(f, 'MJ'),
        _hCell(f, 'Cena bez DPH/MJ', align: pw.TextAlign.right),
        _hCell(f, 'DPH',             align: pw.TextAlign.center),
        _hCell(f, 'Celkom s DPH',    align: pw.TextAlign.right),
      ]),
    ];

    for (int i = 0; i < items.length; i++) {
      final item  = items[i];
      final vat   = item.vatPercent ?? receipt.vatRate ?? dv;
      final unitNV = nv(item.unitPrice, vat);
      final total  = (item.unitPrice * item.qty * 100).round() / 100;
      final bg     = i.isOdd ? _bgRow : _white;
      rows.add(pw.TableRow(children: [
        _cell(f, item.productName ?? item.productUniqueId, bg: bg),
        _cell(f, item.plu ?? '',                           bg: bg, color: _textMuted, mono: true),
        if (hasBatch)  _cell(f, item.batchNumber ?? '',   bg: bg, color: _textMuted),
        if (hasExpiry) _cell(f, _expiry(item.expiryDate), bg: bg, color: _textMuted),
        _cell(f, _formatQty(item.qty),    align: pw.TextAlign.right, bg: bg, bold: true, mono: true),
        _cell(f, item.unit,               bg: bg, color: _textMuted),
        _cell(f, _formatCurrency(unitNV), align: pw.TextAlign.right, bg: bg, mono: true),
        _amberPill(f, '$vat %',           cellBg: bg),
        _cell(f, _formatCurrency(total),  align: pw.TextAlign.right, bg: bg, bold: true, mono: true),
      ]));
    }

    return _buildTable(cols, rows);
  }

  static pw.Widget _tableRetail(
    _Fonts f,
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
        _hCell(f, 'Názov'),             _hCell(f, 'PLU'),
        _hCell(f, 'Množstvo',      align: pw.TextAlign.right),
        _hCell(f, 'MJ'),
        _hCell(f, 'Cena bez DPH',  align: pw.TextAlign.right),
        _hCell(f, 'DPH',           align: pw.TextAlign.center),
        _hCell(f, 'Celkom s DPH',  align: pw.TextAlign.right),
        _hCell(f, 'Predajná cena', align: pw.TextAlign.right),
        _hCell(f, 'Marža %',       align: pw.TextAlign.right),
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
          ? ((prod.price - item.unitPrice) / prod.price * 100)
          : null;
      final bg = i.isOdd ? _bgRow : _white;
      rows.add(pw.TableRow(children: [
        _cell(f, item.productName ?? item.productUniqueId, bg: bg),
        _cell(f, item.plu ?? '',              bg: bg, color: _textMuted, mono: true),
        _cell(f, _formatQty(item.qty),        align: pw.TextAlign.right, bg: bg, bold: true, mono: true),
        _cell(f, item.unit,                   bg: bg, color: _textMuted),
        _cell(f, _formatCurrency(unitNV),     align: pw.TextAlign.right, bg: bg, mono: true),
        _amberPill(f, '$vat %',               cellBg: bg),
        _cell(f, _formatCurrency(total),      align: pw.TextAlign.right, bg: bg, bold: true, mono: true),
        _cell(f, sale > 0 ? _formatCurrency(sale) : '–', align: pw.TextAlign.right, bg: bg, mono: true),
        _cell(f, margin != null ? '${margin.toStringAsFixed(1)} %' : '–',
            align: pw.TextAlign.right, bg: bg, color: _greenText),
      ]));
    }

    return _buildTable(cols, rows);
  }

  static pw.Widget _tableWarehouse(
    _Fonts f,
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
        _hCell(f, 'Názov'),       _hCell(f, 'PLU'),
        if (hasBatch)  _hCell(f, 'Šarža'),
        if (hasExpiry) _hCell(f, 'Expirácia'),
        _hCell(f, 'MJ'),          _hCell(f, 'Skutočne prijaté'),
      ]),
    ];

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final bg = i.isOdd ? _bgRow : _white;
      rows.add(pw.TableRow(children: [
        _cell(f, item.productName ?? item.productUniqueId, bg: bg),
        _cell(f, item.plu ?? '',                           bg: bg, color: _textMuted, mono: true),
        if (hasBatch)  _cell(f, item.batchNumber ?? '',   bg: bg, color: _textMuted),
        if (hasExpiry) _cell(f, _expiry(item.expiryDate), bg: bg, color: _textMuted),
        _cell(f, item.unit,                                bg: bg, color: _textMuted),
        _cell(f, '',                                       bg: bg),
      ]));
    }

    return _buildTable(cols, rows);
  }

  static pw.Widget _tableStocks(
    _Fonts f,
    List<InboundReceiptItem> items,
    Map<String, Product> products,
  ) {
    final cols = <int, pw.TableColumnWidth>{
      0: const pw.FlexColumnWidth(3.0), 1: const pw.FlexColumnWidth(1.0),
      2: const pw.FlexColumnWidth(1.2), 3: const pw.FlexColumnWidth(1.2),
    };

    final rows = <pw.TableRow>[
      pw.TableRow(children: [
        _hCell(f, 'Položka'),
        _hCell(f, 'Prijaté',             align: pw.TextAlign.right),
        _hCell(f, 'Stav pred príjmom',   align: pw.TextAlign.right),
        _hCell(f, 'Nový stav po príjme', align: pw.TextAlign.right),
      ]),
    ];

    for (int i = 0; i < items.length; i++) {
      final item    = items[i];
      final product = products[item.productUniqueId];
      final stavPred = (product?.qty ?? 0) - item.qty;
      final bg = i.isOdd ? _bgRow : _white;
      rows.add(pw.TableRow(children: [
        _cell(f, item.productName ?? item.productUniqueId, bg: bg),
        _cell(f, '${_formatQty(item.qty)} ${item.unit}', align: pw.TextAlign.right, bg: bg, bold: true, mono: true),
        _cell(f, product != null ? '$stavPred' : '–', align: pw.TextAlign.right, bg: bg, color: _textMuted, mono: true),
        _cell(f, product != null ? '${product.qty}' : '–', align: pw.TextAlign.right, bg: bg, color: _greenText, bold: true, mono: true),
      ]));
    }

    return _buildTable(cols, rows);
  }

  static pw.Widget _buildTable(Map<int, pw.TableColumnWidth> cols, List<pw.TableRow> rows) =>
      pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _borderMid, width: 0.8),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        ),
        child: pw.ClipRRect(
          horizontalRadius: 8,
          verticalRadius: 8,
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

  // ── 5. VAT RECAP + TOTAL ────────────────────────────────────────────────────

  static pw.Widget _buildVatRecap(
      _Fonts f, InboundReceipt receipt, List<InboundReceiptItem> items) {
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

    final grandTotal  = items.fold<double>(
        0, (s, i) => s + (i.unitPrice * i.qty * 100).round() / 100);
    final sortedRates = breakdown.keys.toList()..sort();

    const double cSadzba = 72;
    const double cZaklad = 90;
    const double cDph    = 70;
    const double cSpolu  = 90;
    const double leftW   = cSadzba + cZaklad + cDph + cSpolu + 16;
    const double rightW  = 180;

    pw.Widget lbl(String t) => pw.Text(t.toUpperCase(),
        style: pw.TextStyle(
            font: f.body,
            fontSize: 6.5,
            fontWeight: pw.FontWeight.bold,
            color: _textMuted,
            letterSpacing: 0.7));

    pw.Widget vatRow(String s, String z, String d, String sp) =>
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 5),
          child: pw.Row(children: [
            pw.SizedBox(
                width: cSadzba,
                child: pw.Text(s,
                    style: pw.TextStyle(
                        font: f.body,
                        fontSize: 8.5,
                        color: _textSub))),
            pw.SizedBox(
                width: cZaklad,
                child: pw.Text(z,
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                        font: f.mono,
                        fontSize: 8.5,
                        color: _textSub))),
            pw.SizedBox(
                width: cDph,
                child: pw.Text(d,
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                        font: f.mono,
                        fontSize: 8.5,
                        color: _textMuted))),
            pw.SizedBox(
                width: cSpolu,
                child: pw.Text(sp,
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                        font: f.monoBold,
                        fontSize: 8.5,
                        fontWeight: pw.FontWeight.bold,
                        color: _textSub))),
          ]),
        );

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _border, width: 0.8),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: leftW,
            child: pw.Container(
              color: _bgLight,
              padding: const pw.EdgeInsets.all(16),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  _buildSectionLabel(f, 'Rekapitulácia DPH'),
                  pw.SizedBox(height: 10),
                  pw.Row(children: [
                    pw.SizedBox(width: cSadzba, child: lbl('Sadzba')),
                    pw.SizedBox(
                        width: cZaklad,
                        child: pw.Align(
                            alignment: pw.Alignment.centerRight,
                            child: lbl('Základ'))),
                    pw.SizedBox(
                        width: cDph,
                        child: pw.Align(
                            alignment: pw.Alignment.centerRight,
                            child: lbl('DPH'))),
                    pw.SizedBox(
                        width: cSpolu,
                        child: pw.Align(
                            alignment: pw.Alignment.centerRight,
                            child: lbl('Spolu'))),
                  ]),
                  pw.SizedBox(height: 6),
                  _buildDivider(),
                  pw.SizedBox(height: 8),
                  ...sortedRates.map((rate) {
                    final b = breakdown[rate]!;
                    return vatRow('DPH $rate %',
                        _formatCurrency(b.woV),
                        _formatCurrency(b.vAmt),
                        _formatCurrency(b.wV));
                  }),
                ],
              ),
            ),
          ),
          pw.Container(width: 1, color: _border),
          pw.SizedBox(
            width: rightW,
            child: pw.Container(
              color: _grayBg,
              padding: const pw.EdgeInsets.all(16),
              child: pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  _buildSectionLabel(f, 'Celkom na úhradu'),
                  pw.SizedBox(height: 10),
                  pw.Text(_formatCurrency(grandTotal),
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                          font: f.monoBold,
                          fontSize: 22,
                          color: _textDark)),
                  pw.SizedBox(height: 4),
                  pw.Text('vrátane DPH',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                          font: f.body,
                          fontSize: 8,
                          color: _textMuted)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 6. SIGNATURE FOOTER ────────────────────────────────────────────────────

  static pw.Widget _buildSignatureFooter(
      _Fonts f, InboundReceipt receipt, PrijemkaPdfContext ctx) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _border, width: 0.8),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(14),
              child: pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildSectionLabel(f, 'Vystavil'),
                  pw.SizedBox(height: 36),
                  pw.Center(
                      child: pw.Container(
                          width: 80,
                          height: 0.5,
                          color: _borderMid)),
                  pw.SizedBox(height: 6),
                  pw.Center(
                      child: pw.Text(ctx.issuedBy ?? '',
                          style: pw.TextStyle(
                              font: f.bodySemi,
                              fontSize: 9,
                              color: _textDark))),
                  pw.SizedBox(height: 2),
                  pw.Center(
                      child: pw.Text(_d(receipt.createdAt),
                          style: pw.TextStyle(
                              font: f.mono,
                              fontSize: 8,
                              color: _textMuted))),
                ],
              ),
            ),
          ),
          pw.Container(width: 1, color: _border),
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(14),
              child: pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildSectionLabel(f, 'Schválil'),
                  pw.SizedBox(height: 36),
                  pw.Center(
                      child: pw.Container(
                          width: 80,
                          height: 0.5,
                          color: _borderMid)),
                  pw.SizedBox(height: 6),
                  pw.Center(
                      child: pw.Text('Meno a podpis',
                          style: pw.TextStyle(
                              font: f.body,
                              fontSize: 8,
                              color: _textMuted))),
                  pw.SizedBox(height: 2),
                  pw.Center(
                      child: pw.Text('Dátum: ___________',
                          style: pw.TextStyle(
                              font: f.body,
                              fontSize: 8,
                              color: _textMuted))),
                ],
              ),
            ),
          ),
          pw.Container(width: 1, color: _border),
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(14),
              child: pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildSectionLabel(f, 'Pečiatka'),
                  pw.SizedBox(height: 12),
                  pw.Center(
                    child: pw.Container(
                      width: 100,
                      height: 60,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(
                            color: _borderMid,
                            width: 1.2,
                            style: pw.BorderStyle.dashed),
                        borderRadius:
                            const pw.BorderRadius.all(pw.Radius.circular(6)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Page footer ─────────────────────────────────────────────────────────────

  static pw.Widget _pageFooter(_Fonts f, pw.Context ctx) {
    final now = DateTime.now();
    final ts  = '${_d(now)} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        _buildDivider(),
        pw.SizedBox(height: 5),
        pw.Row(children: [
          pw.Text('Vygenerované: $ts',
              style: pw.TextStyle(
                  font: f.body,
                  fontSize: 6.5,
                  color: _textMuted)),
          pw.Spacer(),
          pw.Text('Strana ${ctx.pageNumber} / ${ctx.pagesCount}',
              style: pw.TextStyle(
                  font: f.body,
                  fontSize: 6.5,
                  color: _textMuted)),
        ]),
      ],
    );
  }

  // ── Public API ──────────────────────────────────────────────────────────────

  static Future<Uint8List> generatePdf({
    required InboundReceipt receipt,
    required List<InboundReceiptItem> items,
    required PrintType type,
    PrijemkaPdfContext? context,
  }) async {
    final ctx = context ?? const PrijemkaPdfContext();
    final c   = ctx.styleConfig ?? const ReceiptPdfStyleConfig();

    final serifFont  = await PdfGoogleFonts.dMSerifDisplayRegular();
    final monoFont   = await PdfGoogleFonts.dMMonoRegular();
    final monoBold   = await PdfGoogleFonts.dMMonoMedium();
    final bodyFont   = await PdfGoogleFonts.outfitRegular();
    final bodyMedium = await PdfGoogleFonts.outfitMedium();
    final bodySemi   = await PdfGoogleFonts.outfitSemiBold();
    final fonts = _Fonts(
        serif: serifFont,
        mono: monoFont,
        monoBold: monoBold,
        body: bodyFont,
        bodyMed: bodyMedium,
        bodySemi: bodySemi);
    final theme = pw.ThemeData.withFont(base: bodyFont, bold: bodySemi);

    final hasBatch  = items.any((i) => i.batchNumber?.isNotEmpty == true);
    final hasExpiry = items.any((i) => i.expiryDate?.isNotEmpty == true);

    pw.Widget itemsTable;
    bool hasVat;

    switch (type) {
      case PrintType.standard:
        itemsTable = _tableStandard(fonts, receipt, items, hasBatch, hasExpiry);
        hasVat = true;
        break;
      case PrintType.retail:
        itemsTable = _tableRetail(fonts, receipt, items, ctx.productsByUniqueId);
        hasVat = true;
        break;
      case PrintType.warehouse:
        itemsTable = _tableWarehouse(fonts, items, hasBatch, hasExpiry);
        hasVat = false;
        break;
      case PrintType.stocks:
        itemsTable = _tableStocks(fonts, items, ctx.productsByUniqueId);
        hasVat = false;
        break;
    }

    final doc = pw.Document(theme: theme);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 28, 40, 28),
        header: (_) => _buildHeader(fonts, receipt, ctx, c, type),
        footer: (pCtx) => _pageFooter(fonts, pCtx),
        build: (_) => [
          pw.SizedBox(height: 10),
          _buildStatusBar(fonts, receipt),
          pw.SizedBox(height: 12),
          _buildParties(fonts, receipt, ctx),
          pw.SizedBox(height: 14),
          itemsTable,
          if (hasVat) ...[
            pw.SizedBox(height: 14),
            _buildVatRecap(fonts, receipt, items),
          ],
          pw.SizedBox(height: 20),
          _buildSignatureFooter(fonts, receipt, ctx),
          pw.SizedBox(height: 8),
        ],
      ),
    );

    return doc.save();
  }

  // ── Utility ─────────────────────────────────────────────────────────────────

  static String typeTitle(InboundReceipt receipt, PrijemkaPdfContext ctx) =>
      ctx.styleConfig?.effectiveDocumentTitle ?? 'PRÍJEMKA TOVARU';
}
