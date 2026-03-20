import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/company.dart';
import '../../models/customer.dart';
import '../../models/invoice.dart';
import '../../services/Company/company_service.dart';
import '../../services/Customer/customer_service.dart';
import '../../services/Invoice/invoice_service.dart';
import '../../services/StockOut/stock_out_service.dart';
import '../../services/api_sync_service.dart' show fetchInvoiceQrString, getBackendToken, syncInvoicesToBackend;
import '../../services/payment/epc_sepa_qr.dart';
import '../Settings/company_edit_screen.dart';
import '../../services/pdf/invoice_pdf_service.dart';
import '../../theme/app_theme.dart' show AppColors;
import '../../utils/platform_pdf_saver.dart';
import '../../widgets/Invoices/invoice_form_widget.dart';

class InvoiceDetailScreen extends StatefulWidget {
  final int? invoiceId;

  const InvoiceDetailScreen({super.key, this.invoiceId});

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  final InvoiceService _service = InvoiceService();
  final CompanyService _companyService = CompanyService();
  final CustomerService _customerService = CustomerService();
  final StockOutService _stockOutService = StockOutService();

  Invoice? _invoice;
  List<InvoiceItem> _items = [];
  Company? _company;
  bool _loading = true;
  bool _saving = false;
  bool _isNew = false;

  @override
  void initState() {
    super.initState();
    _isNew = widget.invoiceId == null;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      _company = await _companyService.getCompany();
      if (!_isNew && widget.invoiceId != null) {
        _invoice = await _service.getInvoiceById(widget.invoiceId!);
        if (_invoice != null) {
          _items = await _service.getInvoiceItems(_invoice!.id!);
        }
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveInvoice(Invoice invoice, List<InvoiceItem> items) async {
    setState(() => _saving = true);
    try {
      // Prepočítaj sumy
      final totals = _service.calculateTotals(items);
      final saved = invoice.copyWith(
        totalWithoutVat: totals.$1,
        totalVat: totals.$2,
        totalWithVat: totals.$3,
        variableSymbol: invoice.variableSymbol?.isEmpty == true
            ? invoice.invoiceNumber.replaceAll(RegExp(r'[^0-9]'), '')
            : invoice.variableSymbol,
      );

      if (_isNew) {
        await _service.createInvoice(saved, items);
      } else {
        await _service.updateInvoice(saved, items);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Faktúra uložená'), backgroundColor: Colors.green),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chyba: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Pay by Square z backendu, ak nie je k dispozícii → lokálny SEPA/EPC QR (bez závislosti na sync endpointe).
  Future<({String? data, InvoiceQrKind kind})> _resolvePaymentQrData() async {
    if (_invoice == null || _company == null) {
      return (data: null, kind: InvoiceQrKind.payBySquare);
    }
    var qr = _invoice!.qrString;
    if (qr != null && qr.isNotEmpty) {
      return (data: qr, kind: InvoiceQrKind.payBySquare);
    }
    final token = getBackendToken();
    if (token != null && _invoice!.id != null) {
      qr = await fetchInvoiceQrString(_invoice!.id!, token);
      if (qr == null || qr.isEmpty) {
        await syncInvoicesToBackend();
        qr = await fetchInvoiceQrString(_invoice!.id!, token);
      }
      if (qr != null && qr.isNotEmpty) {
        return (data: qr, kind: InvoiceQrKind.payBySquare);
      }
    }
    final epc = buildEpcSepaQrData(company: _company!, invoice: _invoice!);
    if (epc != null) {
      return (data: epc, kind: InvoiceQrKind.epcSepa);
    }
    return (data: null, kind: InvoiceQrKind.payBySquare);
  }

  Future<void> _generatePdf() async {
    if (_invoice == null || _company == null) return;
    setState(() => _saving = true);
    try {
      final resolved = await _resolvePaymentQrData();
      String? qrString = resolved.data;
      final isEpc = resolved.kind == InvoiceQrKind.epcSepa;

      if (qrString != null &&
          qrString.isNotEmpty &&
          resolved.kind == InvoiceQrKind.payBySquare &&
          (_invoice!.qrString == null || _invoice!.qrString!.isEmpty)) {
        final updated = _invoice!.copyWith(qrString: qrString);
        await _service.updateInvoice(updated, _items);
        _invoice = updated;
      }

      // Načítaj logo
      Uint8List? logoBytes;
      if (_company!.logoPath != null && !kIsWeb) {
        final f = File(_company!.logoPath!);
        if (await f.exists()) logoBytes = await f.readAsBytes();
      }

      final pdfBytes = await InvoicePdfService.buildPdf(
        invoice: _invoice!,
        items: _items,
        company: _company!,
        logoBytes: logoBytes,
        qrString: qrString,
        paymentQrIsEpcSepa: isEpc,
      );

      final filename = 'faktura_${_invoice!.invoiceNumber}.pdf';

      if (!kIsWeb) {
        await saveAndOpenPdf(pdfBytes, filename);
      } else {
        await Printing.sharePdf(bytes: pdfBytes, filename: filename);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chyba pri generovaní PDF: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showPaymentQr() async {
    if (_invoice == null || _invoice!.id == null) return;
    setState(() => _saving = true);
    try {
      final resolved = await _resolvePaymentQrData();
      final qrString = resolved.data;
      final kind = resolved.kind;

      if (qrString == null || qrString.isEmpty) {
        if (!mounted) return;
        final hasIban = (_company?.iban ?? '').trim().isNotEmpty;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              hasIban
                  ? 'Nepodarilo sa vytvoriť platobný QR. Skontrolujte údaje firmy a sumu faktúry.'
                  : 'Chýba IBAN firmy pre úhradu faktúr.',
            ),
            action: !hasIban
                ? SnackBarAction(
                    label: 'Doplniť IBAN',
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CompanyEditScreen()),
                      );
                      await _loadData();
                    },
                  )
                : null,
          ),
        );
        return;
      }

      if (kind == InvoiceQrKind.payBySquare && _invoice!.qrString != qrString) {
        final updated = _invoice!.copyWith(qrString: qrString);
        await _service.updateInvoice(updated, _items);
        _invoice = updated;
      }

      if (!mounted) return;
      final hint = kind == InvoiceQrKind.epcSepa
          ? 'SEPA platobný QR (EPC). V mnohých bankách funguje rovnako ako klasická platba QR. Pay by Square vyžaduje aktuálny backend.'
          : 'Naskenujte v mobilnej banke (Pay by Square).';
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Platobný QR kód'),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                QrImageView(
                  data: qrString,
                  size: 230,
                  backgroundColor: Colors.white,
                ),
                const SizedBox(height: 8),
                Text(
                  hint,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Zavrieť')),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chyba pri načítaní QR: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changeStatus(InvoiceStatus newStatus) async {
    if (_invoice == null) return;
    final oldStatus = _invoice!.status;

    // Pri prechode do stavu "Vystavená" automaticky odpočítaj sklad (zo skladových položiek).
    if (oldStatus != InvoiceStatus.issued && newStatus == InvoiceStatus.issued) {
      try {
        await _stockOutService.createStockOutFromInvoice(
          invoice: _invoice!,
          invoiceItems: _items,
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Faktúru nemožno vystaviť: $e'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    final updated = _invoice!.copyWith(status: newStatus);
    await _service.updateInvoice(updated, _items);
    setState(() => _invoice = updated);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Stav zmenený na: ${newStatus.label}'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Future<void> _createCreditNote() async {
    if (_invoice == null) return;
    final creditNote = await _service.buildCreditNote(_invoice!, _items);
    if (!mounted) return;
    Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _NewCreditNoteScreen(invoice: creditNote, items: _items
            .map((i) => i.copyWith(invoiceId: 0, qty: -i.qty.abs()))
            .toList()),
      ),
    ).then((saved) {
      if (saved == true) Navigator.of(context).pop(true);
    });
  }

  Future<void> _deleteInvoice() async {
    if (_invoice?.id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vymazať faktúru'),
        content: Text('Naozaj chcete vymazať faktúru ${_invoice!.invoiceNumber}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Zrušiť')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Vymazať'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _service.deleteInvoice(_invoice!.id!);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: AppBar(
          backgroundColor: AppColors.bgCard,
          title: Text(_isNew ? 'Nová faktúra' : 'Faktúra', style: TextStyle(color: AppColors.textPrimary)),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgCard,
        elevation: 0,
        title: Text(
          _isNew ? 'Nová faktúra' : (_invoice?.invoiceNumber ?? 'Faktúra'),
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        actions: [
          if (!_isNew && _invoice != null) ...[
            // PDF
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'Generovať PDF',
              onPressed: _saving ? null : _generatePdf,
            ),
            IconButton(
              icon: const Icon(Icons.qr_code_2),
              tooltip: 'Zobraziť platobný QR',
              onPressed: _saving ? null : _showPaymentQr,
            ),
            // Zmena stavu
            PopupMenuButton<InvoiceStatus>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'Akcie',
              itemBuilder: (_) => [
                ...InvoiceStatus.values.map((s) => PopupMenuItem(
                      value: s,
                      child: Row(children: [
                        Icon(_statusIcon(s), size: 18, color: _statusColor(s)),
                        const SizedBox(width: 8),
                        Text(s.label),
                      ]),
                    )),
                const PopupMenuDivider(),
                if (_invoice!.invoiceType == InvoiceType.issuedInvoice)
                  PopupMenuItem<InvoiceStatus>(
                    value: null,
                    onTap: _createCreditNote,
                    child: const Row(children: [
                      Icon(Icons.undo, size: 18, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Vystaviť dobropis'),
                    ]),
                  ),
                PopupMenuItem<InvoiceStatus>(
                  value: null,
                  onTap: _deleteInvoice,
                  child: const Row(children: [
                    Icon(Icons.delete, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Vymazať faktúru', style: TextStyle(color: Colors.red)),
                  ]),
                ),
              ],
              onSelected: (s) {
                if (s != null) _changeStatus(s);
              },
            ),
          ],
        ],
      ),
      body: _saving
          ? const Center(child: CircularProgressIndicator())
          : InvoiceFormWidget(
              invoice: _invoice,
              items: _items,
              company: _company,
              onSave: _saveInvoice,
            ),
    );
  }

  Color _statusColor(InvoiceStatus s) {
    switch (s) {
      case InvoiceStatus.draft:     return Colors.grey;
      case InvoiceStatus.issued:    return Colors.blue;
      case InvoiceStatus.sent:      return Colors.orange;
      case InvoiceStatus.paid:      return Colors.green;
      case InvoiceStatus.overdue:   return Colors.red;
      case InvoiceStatus.cancelled: return Colors.red.shade200;
    }
  }

  IconData _statusIcon(InvoiceStatus s) {
    switch (s) {
      case InvoiceStatus.draft:     return Icons.edit;
      case InvoiceStatus.issued:    return Icons.send;
      case InvoiceStatus.sent:      return Icons.mark_email_read;
      case InvoiceStatus.paid:      return Icons.check_circle;
      case InvoiceStatus.overdue:   return Icons.warning;
      case InvoiceStatus.cancelled: return Icons.cancel;
    }
  }
}

/// Obrazovka na uloženie automaticky vytvoreného dobropisu
class _NewCreditNoteScreen extends StatefulWidget {
  final Invoice invoice;
  final List<InvoiceItem> items;
  const _NewCreditNoteScreen({required this.invoice, required this.items});

  @override
  State<_NewCreditNoteScreen> createState() => _NewCreditNoteScreenState();
}

class _NewCreditNoteScreenState extends State<_NewCreditNoteScreen> {
  final InvoiceService _service = InvoiceService();
  bool _saving = false;

  Future<void> _save(Invoice inv, List<InvoiceItem> items) async {
    setState(() => _saving = true);
    try {
      await _service.createInvoice(inv, items);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgCard,
        title: Text('Nový dobropis', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: _saving
          ? const Center(child: CircularProgressIndicator())
          : InvoiceFormWidget(
              invoice: widget.invoice,
              items: widget.items,
              company: null,
              onSave: _save,
            ),
    );
  }
}
