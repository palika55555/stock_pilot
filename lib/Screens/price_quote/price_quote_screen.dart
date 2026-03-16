import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/company.dart';
import '../../models/customer.dart';
import '../../models/product.dart';
import '../../models/quote.dart';
import '../../screens/Settings/company_edit_screen.dart';
import '../../services/Company/company_service.dart';
import '../../services/Product/product_service.dart';
import '../../services/Quote/quote_pdf_service.dart';
import '../../services/Quote/quote_service.dart';
import 'package:printing/printing.dart';
import '../../widgets/quotes/add_quote_item_modal_widget.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/standard_text_field.dart';
import '../../widgets/Quotes/quote_document_card_widget.dart';

class PriceQuoteScreen extends StatefulWidget {
  final Customer customer;
  final int? quoteId;

  const PriceQuoteScreen({super.key, required this.customer, this.quoteId});

  @override
  State<PriceQuoteScreen> createState() => _PriceQuoteScreenState();
}

class _PriceQuoteScreenState extends State<PriceQuoteScreen> {
  final QuoteService _quoteService = QuoteService();
  final ProductService _productService = ProductService();
  final CompanyService _companyService = CompanyService();

  Company? _company;
  Quote? _quote;
  List<QuoteItem> _items = [];
  List<Product> _products = [];
  bool _loading = true;
  bool _saving = false;

  final TextEditingController _quoteNumberController = TextEditingController();
  final TextEditingController _validUntilController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _vatRateController = TextEditingController(text: '20');
  final TextEditingController _deliveryCostController = TextEditingController(text: '0');
  final TextEditingController _otherFeesController = TextEditingController(text: '0');
  final TextEditingController _paymentMethodController = TextEditingController(text: 'Bankový prevod');
  final TextEditingController _deliveryTermsController = TextEditingController(text: 'Dohodou');
  bool _pricesIncludeVat = false;

  bool get _isNewQuote => widget.quoteId == null;

  @override
  void initState() {
    super.initState();
    _vatRateController.text = widget.customer.defaultVatRate.toString();
    if (_isNewQuote) {
      _loadProductsAndNextNumber();
      final validUntil = DateTime.now().add(const Duration(days: 30));
      _validUntilController.text =
          '${validUntil.year}-${validUntil.month.toString().padLeft(2, '0')}-${validUntil.day.toString().padLeft(2, '0')}';
      _notesController.text =
          'Uvedená cena platí pri odbere plne naloženého kamióna.\n'
          'Vratná záloha za palety bude ponížená o amortizačný poplatok bez DPH.';
    } else {
      _loadQuoteAndItems();
    }
  }

  @override
  void dispose() {
    _quoteNumberController.dispose();
    _validUntilController.dispose();
    _notesController.dispose();
    _vatRateController.dispose();
    _deliveryCostController.dispose();
    _otherFeesController.dispose();
    _paymentMethodController.dispose();
    _deliveryTermsController.dispose();
    super.dispose();
  }

  Future<void> _loadProductsAndNextNumber() async {
    setState(() => _loading = true);
    final products = await _productService.getAllProducts();
    final nextNumber = await _quoteService.getNextQuoteNumber();
    final company = await _companyService.getCompany();
    if (mounted) {
      setState(() {
        _products = products;
        _company = company;
        _quoteNumberController.text = nextNumber;
        _loading = false;
      });
    }
  }

  Future<void> _loadQuoteAndItems() async {
    setState(() => _loading = true);
    final quote = await _quoteService.getQuoteById(widget.quoteId!);
    final items = await _quoteService.getQuoteItems(widget.quoteId!);
    final products = await _productService.getAllProducts();
    final company = await _companyService.getCompany();
    if (!mounted) return;
    setState(() {
      _quote = quote;
      _company = company;
      _products = products;
      _items = items;
      if (quote != null) {
        _quoteNumberController.text = quote.quoteNumber;
        _validUntilController.text = quote.validUntil != null
            ? '${quote.validUntil!.year}-${quote.validUntil!.month.toString().padLeft(2, '0')}-${quote.validUntil!.day.toString().padLeft(2, '0')}'
            : '';
        _notesController.text = quote.notes ?? '';
        _vatRateController.text = quote.defaultVatRate.toString();
        _pricesIncludeVat = quote.pricesIncludeVat;
        _deliveryCostController.text = quote.deliveryCost.toStringAsFixed(2);
        _otherFeesController.text = quote.otherFees.toStringAsFixed(2);
        _paymentMethodController.text = quote.paymentMethod ?? 'Bankový prevod';
        _deliveryTermsController.text = quote.deliveryTerms ?? 'Dohodou';
      }
      _loading = false;
    });
  }

  Future<void> _printOrPdf() async {
    final l10n = AppLocalizations.of(context)!;
    final c = widget.customer;
    final quoteNumber = _quoteNumberController.text.trim();
    if (quoteNumber.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.quoteNumberRequired)));
      return;
    }
    final validUntil = _validUntilController.text.trim().isNotEmpty
        ? DateTime.tryParse(_validUntilController.text.trim())
        : null;
    final defaultVat =
        int.tryParse(_vatRateController.text.trim()) ?? c.defaultVatRate;
    final quote = Quote(
      quoteNumber: quoteNumber,
      customerId: c.id!,
      customerName: c.name,
      createdAt: _quote?.createdAt ?? DateTime.now(),
      validUntil: validUntil,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      pricesIncludeVat: _pricesIncludeVat,
      defaultVatRate: defaultVat.clamp(0, 27),
      status: _quote?.status ?? QuoteStatus.draft,
      deliveryCost: double.tryParse(_deliveryCostController.text.trim().replaceAll(',', '.')) ?? 0.0,
      otherFees: double.tryParse(_otherFeesController.text.trim().replaceAll(',', '.')) ?? 0.0,
      paymentMethod: _paymentMethodController.text.trim().isEmpty ? null : _paymentMethodController.text.trim(),
      deliveryTerms: _deliveryTermsController.text.trim().isEmpty ? null : _deliveryTermsController.text.trim(),
    );
    Uint8List? logoBytes;
    if (_company?.logoPath != null)
      logoBytes = await QuotePdfService.loadLogoBytes(_company!.logoPath);
    try {
      final pdfBytes = await QuotePdfService.buildPdf(
        quote: quote,
        items: _items,
        customer: c,
        company: _company,
        logoBytes: logoBytes,
      );
      final filename =
          'cenova_ponuka_${quote.quoteNumber.replaceAll(RegExp(r'[^\w\-.]'), '_')}.pdf';
      try {
        await Printing.sharePdf(bytes: pdfBytes, filename: filename);
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('PDF pripravené na uloženie / zdieľanie')),
          );
      } on MissingPluginException catch (_) {
        await _saveAndOpenPdf(pdfBytes, filename);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba pri generovaní PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

  /// Uloží PDF do súboru a otvorí ho (fallback keď sharePdf nie je na platforme dostupný).
  Future<void> _saveAndOpenPdf(Uint8List pdfBytes, String filename) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(pdfBytes);
      if (Platform.isWindows) {
        await Process.run('start', ['', file.path], runInShell: true);
      } else if (Platform.isMacOS) {
        await Process.run('open', [file.path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [file.path]);
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('PDF uložené: ${file.path}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba pri ukladaní PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _reloadCompany() async {
    final company = await _companyService.getCompany();
    if (mounted) setState(() => _company = company);
  }

  Future<void> _addItem() async {
    final result = await showModalBottomSheet<QuoteItem>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AddQuoteItemModal(
        products: _products,
        defaultVatRate:
            int.tryParse(_vatRateController.text.trim()) ??
            widget.customer.defaultVatRate,
        pricesIncludeVat: _pricesIncludeVat,
      ),
    );
    // Refresh products in case user created new ones inside the modal
    final updatedProducts = await _productService.getAllProducts();
    if (!mounted) return;
    setState(() {
      _products = updatedProducts;
      if (result != null) {
        _items.add(QuoteItem(
          id: result.id,
          quoteId: _quote?.id ?? 0,
          productUniqueId: result.productUniqueId,
          productName: result.productName,
          plu: result.plu,
          qty: result.qty,
          unit: result.unit,
          unitPrice: result.unitPrice,
          discountPercent: result.discountPercent,
          vatPercent: result.vatPercent,
          itemType: result.itemType,
          description: result.description,
          surchargePercent: result.surchargePercent,
        ));
      }
    });
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
  }

  double _subtotalWithoutVat() {
    double sum = 0;
    for (final item in _items) {
      sum += item.getLineTotalWithoutVat(_pricesIncludeVat);
    }
    return (sum * 100).round() / 100;
  }

  double _totalVat() {
    double sum = 0;
    for (final item in _items) {
      sum +=
          item.getLineTotalWithVat(_pricesIncludeVat) -
          item.getLineTotalWithoutVat(_pricesIncludeVat);
    }
    return (sum * 100).round() / 100;
  }

  double _totalWithVat() {
    double sum = 0;
    for (final item in _items) {
      sum += item.getLineTotalWithVat(_pricesIncludeVat);
    }
    return (sum * 100).round() / 100;
  }

  double _goodsTotal() {
    double sum = 0;
    for (final item in _items) {
      if (item.itemType != 'Paleta') sum += item.getLineTotalWithoutVat(_pricesIncludeVat);
    }
    return (sum * 100).round() / 100;
  }

  /// Základná cena paliet bez amortizácie (zákazník ju dostane späť).
  double _palletBaseTotal() {
    double sum = 0;
    for (final item in _items) {
      if (item.itemType == 'Paleta') {
        final unitPriceWithoutVat = _pricesIncludeVat
            ? item.unitPrice / (1 + item.vatPercent / 100)
            : item.unitPrice;
        sum += item.qty * unitPriceWithoutVat * (1 - item.discountPercent / 100);
      }
    }
    return (sum * 100).round() / 100;
  }

  /// Amortizácia paliet = nenávratná časť (surchargePercent na Paleta položkách).
  double _amortizationTotal() {
    double sum = 0;
    for (final item in _items) {
      if (item.itemType == 'Paleta' && item.surchargePercent > 0) {
        final unitPriceWithoutVat = _pricesIncludeVat
            ? item.unitPrice / (1 + item.vatPercent / 100)
            : item.unitPrice;
        final base = item.qty * unitPriceWithoutVat * (1 - item.discountPercent / 100);
        sum += base * item.surchargePercent / 100;
      }
    }
    return (sum * 100).round() / 100;
  }

  double _deliveryCostValue() =>
      double.tryParse(_deliveryCostController.text.trim().replaceAll(',', '.')) ?? 0.0;

  double _otherFeesValue() =>
      double.tryParse(_otherFeesController.text.trim().replaceAll(',', '.')) ?? 0.0;

  double _totalToPay() {
    final total = _goodsTotal() + _deliveryCostValue() + _otherFeesValue() + _amortizationTotal();
    return (total * 100).round() / 100;
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final quoteNumber = _quoteNumberController.text.trim();
    if (quoteNumber.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.quoteNumberRequired)));
      return;
    }
    final validUntil = _validUntilController.text.trim().isNotEmpty
        ? DateTime.tryParse(_validUntilController.text.trim())
        : null;
    final defaultVat =
        int.tryParse(_vatRateController.text.trim()) ??
        widget.customer.defaultVatRate;

    setState(() => _saving = true);
    try {
      if (_isNewQuote) {
        final quote = Quote(
          quoteNumber: quoteNumber,
          customerId: widget.customer.id!,
          customerName: widget.customer.name,
          createdAt: DateTime.now(),
          validUntil: validUntil,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          pricesIncludeVat: _pricesIncludeVat,
          defaultVatRate: defaultVat.clamp(0, 27),
          status: QuoteStatus.draft,
          deliveryCost: double.tryParse(_deliveryCostController.text.trim().replaceAll(',', '.')) ?? 0.0,
          otherFees: double.tryParse(_otherFeesController.text.trim().replaceAll(',', '.')) ?? 0.0,
          paymentMethod: _paymentMethodController.text.trim().isEmpty ? null : _paymentMethodController.text.trim(),
          deliveryTerms: _deliveryTermsController.text.trim().isEmpty ? null : _deliveryTermsController.text.trim(),
        );
        final id = await _quoteService.createQuote(quote);
        for (final item in _items) {
          await _quoteService.addQuoteItem(
            QuoteItem(
              quoteId: id,
              productUniqueId: item.productUniqueId,
              productName: item.productName,
              plu: item.plu,
              qty: item.qty,
              unit: item.unit,
              unitPrice: item.unitPrice,
              discountPercent: item.discountPercent,
              vatPercent: item.vatPercent,
              itemType: item.itemType,
              description: item.description,
              surchargePercent: item.surchargePercent,
            ),
          );
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.quoteSaved),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        if (_quote == null) return;
        final updated = _quote!.copyWith(
          quoteNumber: quoteNumber,
          validUntil: validUntil,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          pricesIncludeVat: _pricesIncludeVat,
          defaultVatRate: defaultVat.clamp(0, 27),
          deliveryCost: double.tryParse(_deliveryCostController.text.trim().replaceAll(',', '.')) ?? 0.0,
          otherFees: double.tryParse(_otherFeesController.text.trim().replaceAll(',', '.')) ?? 0.0,
          paymentMethod: _paymentMethodController.text.trim().isEmpty ? null : _paymentMethodController.text.trim(),
          deliveryTerms: _deliveryTermsController.text.trim().isEmpty ? null : _deliveryTermsController.text.trim(),
        );
        await _quoteService.updateQuote(updated);
        await _quoteService.deleteQuoteItemsByQuoteId(_quote!.id!);
        for (final item in _items) {
          await _quoteService.addQuoteItem(
            QuoteItem(
              quoteId: _quote!.id!,
              productUniqueId: item.productUniqueId,
              productName: item.productName,
              plu: item.plu,
              qty: item.qty,
              unit: item.unit,
              unitPrice: item.unitPrice,
              discountPercent: item.discountPercent,
              vatPercent: item.vatPercent,
              itemType: item.itemType,
              description: item.description,
              surchargePercent: item.surchargePercent,
            ),
          );
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.quoteSaved),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = widget.customer;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: Text(l10n.priceQuote),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: l10n.printPdf,
            onPressed: _items.isEmpty ? null : _printOrPdf,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  QuoteDocumentCard(
                    company: _company,
                    customer: c,
                    quoteNumber: _quoteNumberController.text,
                    validUntilText: _validUntilController.text.trim(),
                    createdAt: _quote?.createdAt ?? DateTime.now(),
                    validUntil: _validUntilController.text.trim().isEmpty
                        ? null
                        : DateTime.tryParse(
                            _validUntilController.text.trim(),
                          ),
                    notesText: _notesController.text,
                    items: _items,
                    pricesIncludeVat: _pricesIncludeVat,
                    l10n: l10n,
                    subtotalWithoutVat: _subtotalWithoutVat(),
                    totalVat: _totalVat(),
                    totalWithVat: _totalWithVat(),
                    customerVatPayer: widget.customer.vatPayer,
                    onEditCompany: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CompanyEditScreen(),
                        ),
                      );
                      _reloadCompany();
                    },
                  ),
                  const SizedBox(height: 20),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.quoteDetails,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          StandardTextField(
                            controller: _quoteNumberController,
                            labelText: l10n.quoteNumber,
                            icon: Icons.tag,
                            readOnly: !_isNewQuote,
                          ),
                          const SizedBox(height: 12),
                          StandardTextField(
                            controller: _validUntilController,
                            labelText: l10n.validUntil,
                            hintText: 'YYYY-MM-DD',
                            icon: Icons.calendar_today,
                            keyboardType: TextInputType.datetime,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[\d\-]'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          StandardTextField(
                            controller: _notesController,
                            labelText: l10n.notes,
                            hintText: l10n.notesHint,
                            maxLines: 4,
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: StandardTextField(
                                  controller: _vatRateController,
                                  labelText: 'DPH %',
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(2),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: SwitchListTile(
                                  title: Text(
                                    l10n.pricesIncludeVat,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  value: _pricesIncludeVat,
                                  onChanged: (v) =>
                                      setState(() => _pricesIncludeVat = v),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: StandardTextField(
                                  controller: _deliveryCostController,
                                  labelText: 'Doprava (€)',
                                  icon: Icons.local_shipping_outlined,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: StandardTextField(
                                  controller: _otherFeesController,
                                  labelText: 'Iné poplatky (€)',
                                  icon: Icons.add_card_outlined,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          StandardTextField(
                            controller: _paymentMethodController,
                            labelText: 'Spôsob platby',
                            icon: Icons.payment_outlined,
                            hintText: 'napr. Bankový prevod',
                          ),
                          const SizedBox(height: 12),
                          StandardTextField(
                            controller: _deliveryTermsController,
                            labelText: 'Termín dodania / realizácie',
                            icon: Icons.event_outlined,
                            hintText: 'napr. Dohodou',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.quoteItems,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _addItem,
                        icon: const Icon(Icons.add),
                        label: Text(l10n.addItem),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_items.isEmpty)
                    Card(
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.receipt_long,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.noQuoteItems,
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 8),
                              FilledButton.icon(
                                onPressed: _addItem,
                                icon: const Icon(Icons.add),
                                label: Text(l10n.addItem),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    ...List.generate(_items.length, (index) {
                      final item = _items[index];
                      final lineWithVat = item.getLineTotalWithVat(
                        _pricesIncludeVat,
                      );
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 0,
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.teal.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.itemType,
                              style: const TextStyle(fontSize: 11, color: Colors.teal),
                            ),
                          ),
                          title: Text(item.productName ?? item.productUniqueId),
                          subtitle: Text(
                            '${_fmtQty(item.qty)} × ${item.unitPrice.toStringAsFixed(2)} ${item.unit}${item.discountPercent > 0 ? ' (−${item.discountPercent}%)' : ''}${item.description != null ? ' • ${item.description}' : ''}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${lineWithVat.toStringAsFixed(2)} €',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                onPressed: () => _removeItem(index),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  if (_items.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Card(
                      elevation: 0,
                      color: Colors.teal.withValues(alpha: 0.08),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _row('Cena tovaru', _goodsTotal()),
                            if (_deliveryCostValue() > 0) ...[
                              const SizedBox(height: 4),
                              _row('Doprava', _deliveryCostValue()),
                            ],
                            if (_otherFeesValue() > 0) ...[
                              const SizedBox(height: 4),
                              _row('Iné poplatky', _otherFeesValue()),
                            ],
                            if (_amortizationTotal() > 0) ...[
                              const SizedBox(height: 4),
                              _row('Amortizácia paliet', _amortizationTotal()),
                            ],
                            const Divider(height: 16),
                            _row('Celková cena na úhradu', _totalToPay(), bold: true),
                            if (_palletBaseTotal() > 0) ...[
                              const SizedBox(height: 4),
                              _row('Vratná záloha (palety)', _palletBaseTotal()),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              widget.customer.vatPayer
                                  ? 'Cenová ponuka uvedená bez DPH'
                                  : 'Zákazník nie je platcom DPH – ceny sú uvedené bez DPH',
                              style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.teal,
                      ),
                      child: _saving
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(l10n.saveQuote),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  static String _fmtQty(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }

  Widget _row(String label, double value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontWeight: bold ? FontWeight.bold : null),
        ),
        Text(
          '${value.toStringAsFixed(2)} €',
          style: TextStyle(fontWeight: bold ? FontWeight.bold : null),
        ),
      ],
    );
  }
}
