import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

import '../../l10n/app_localizations.dart';
import '../../models/company.dart';
import '../../models/customer.dart';
import '../../models/product.dart';
import '../../models/quote.dart';
import '../../screens/Settings/company_edit_screen.dart';
import '../../services/Company/company_service.dart';
import '../../services/Product/product_service.dart';
import '../../services/Quote/quote_pdf_service.dart';
import '../../services/Quote/quote_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/standard_text_field.dart';
import '../../widgets/Quotes/add_quote_item_modal_widget.dart';
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
  final TextEditingController _vatRateController = TextEditingController(
    text: '20',
  );
  bool _pricesIncludeVat = true;

  bool get _isNewQuote => widget.quoteId == null;

  static const List<int> _vatPresets = [0, 5, 10, 19, 20, 23];

  void _refreshUi() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _vatRateController.text = widget.customer.defaultVatRate.toString();
    for (final c in <TextEditingController>[
      _quoteNumberController,
      _validUntilController,
      _notesController,
      _vatRateController,
    ]) {
      c.addListener(_refreshUi);
    }
    if (_isNewQuote) {
      _loadProductsAndNextNumber();
      final validUntil = DateTime.now().add(const Duration(days: 30));
      _validUntilController.text =
          '${validUntil.year}-${validUntil.month.toString().padLeft(2, '0')}-${validUntil.day.toString().padLeft(2, '0')}';
    } else {
      _loadQuoteAndItems();
    }
  }

  @override
  void dispose() {
    for (final c in <TextEditingController>[
      _quoteNumberController,
      _validUntilController,
      _notesController,
      _vatRateController,
    ]) {
      c.removeListener(_refreshUi);
    }
    _quoteNumberController.dispose();
    _validUntilController.dispose();
    _notesController.dispose();
    _vatRateController.dispose();
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
    );
    Uint8List? logoBytes;
    if (_company?.logoPath != null) {
      logoBytes = await QuotePdfService.loadLogoBytes(_company!.logoPath);
    }
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('PDF pripravené na uloženie / zdieľanie')),
          );
        }
      } on MissingPluginException catch (_) {
        await _saveAndOpenPdf(pdfBytes, filename);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba pri generovaní PDF: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

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
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _reloadCompany() async {
    final company = await _companyService.getCompany();
    if (mounted) {
      setState(() => _company = company);
    }
  }

  Future<void> _addItem() async {
    if (_products.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Žiadne produkty na výber')));
      return;
    }
    final result = await showModalBottomSheet<QuoteItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => AddQuoteItemModal(
        products: _products,
        defaultVatRate:
            int.tryParse(_vatRateController.text.trim()) ??
            widget.customer.defaultVatRate,
        pricesIncludeVat: _pricesIncludeVat,
      ),
    );
    final updatedProducts = await _productService.getAllProducts();
    if (!mounted) return;
    setState(() {
      _products = updatedProducts;
      if (result != null) {
        _items.add(
          QuoteItem(
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
          ),
        );
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

  double get _formCompleteness {
    double s = 0;
    if (_quoteNumberController.text.trim().isNotEmpty) s += 0.2;
    if (DateTime.tryParse(_validUntilController.text.trim()) != null) s += 0.2;
    if (_items.isNotEmpty) s += 0.4;
    if (_notesController.text.trim().isNotEmpty) s += 0.1;
    if (_vatRateController.text.trim().isNotEmpty) s += 0.1;
    return s.clamp(0.0, 1.0);
  }

  String? _validUntilHint() {
    final d = DateTime.tryParse(_validUntilController.text.trim());
    if (d == null) return null;
    final today =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final end = DateTime(d.year, d.month, d.day);
    final days = end.difference(today).inDays;
    if (days < 0) return 'Platnosť už vypršala';
    if (days == 0) return 'Posledný deň platnosti';
    return 'Zostáva $days dní';
  }

  void _setValidUntilDays(int days) {
    final dt = DateTime.now().add(Duration(days: days));
    setState(() {
      _validUntilController.text =
          '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    });
  }

  void _appendNoteSnippet(String snippet) {
    final t = _notesController.text.trim();
    if (t.isEmpty) {
      _notesController.text = snippet;
    } else if (!t.contains(snippet)) {
      _notesController.text = '$t\n$snippet';
    }
    setState(() {});
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
              backgroundColor: AppColors.success,
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
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildSmartHeader(AppLocalizations l10n, Customer c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.accentGold.withValues(alpha: 0.14),
            AppColors.bgElevated,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.accentGoldSubtle,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: AppColors.accentGold, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.priceQuote,
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  c.name,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentGold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Číslo, platnosť a položky sa dopĺňajú prediktívne — '
                  'úplnosť vidíš v pruhu nižšie.',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    height: 1.35,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletenessStrip() {
    final p = _formCompleteness;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pripravenosť ponuky',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                  letterSpacing: 0.3,
                ),
              ),
              Text(
                '${(p * 100).round()} %',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentGold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: p,
              minHeight: 6,
              backgroundColor: AppColors.borderDefault,
              color: AppColors.accentGold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValidityChips() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _validChip('7 dní', 7),
          _validChip('14 dní', 14),
          _validChip('30 dní', 30),
          _validChip('60 dní', 60),
        ],
      ),
    );
  }

  Widget _validChip(String label, int days) {
    return ActionChip(
      label: Text(label, style: GoogleFonts.dmSans(fontSize: 12)),
      backgroundColor: AppColors.bgElevated,
      side: const BorderSide(color: AppColors.borderDefault),
      onPressed: () => _setValidUntilDays(days),
    );
  }

  Widget _buildQuoteVatChips() {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _vatPresets.map((v) {
          final selected = _vatRateController.text.trim() == v.toString();
          return FilterChip(
            label: Text('$v %'),
            selected: selected,
            showCheckmark: false,
            selectedColor: AppColors.accentGoldSubtle,
            backgroundColor: AppColors.bgElevated,
            side: BorderSide(
              color: selected ? AppColors.accentGold : AppColors.borderDefault,
            ),
            labelStyle: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.accentGold : AppColors.textSecondary,
            ),
            onSelected: (_) =>
                setState(() => _vatRateController.text = v.toString()),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSmartTipBanner(AppLocalizations l10n) {
    if (!_isNewQuote || _items.isNotEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.infoSubtle,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.tips_and_updates_rounded,
              color: AppColors.info, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ďalší krok',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.info,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pridaj položky z katalógu — cena a DPH sa predvyplnia z produktu.',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteSuggestions() {
    const snippets = [
      'Uvedená cena platí pri odbere plne naloženého kamióna.',
      'Vratná záloha za palety bude ponížená o amortizačný poplatok bez DPH.',
      'Ceny sú uvedené bez DPH.',
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: snippets.map((s) {
          return ActionChip(
            label: Text(
              s.length > 42 ? '${s.substring(0, 40)}…' : s,
              style: GoogleFonts.dmSans(fontSize: 11),
            ),
            backgroundColor: AppColors.bgElevated,
            side: const BorderSide(color: AppColors.borderDefault),
            onPressed: () => _appendNoteSnippet(s),
          );
        }).toList(),
      ),
    );
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
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accentGold),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSmartHeader(l10n, c),
                  _buildCompletenessStrip(),
                  _buildSmartTipBanner(l10n),
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
                  const SizedBox(height: 12),
                  Container(
                    decoration: AppColors.cardDecorationSmall(16),
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.tune_rounded,
                                color: AppColors.accentGold, size: 22),
                            const SizedBox(width: 10),
                            Text(
                              l10n.quoteDetails,
                              style: GoogleFonts.outfit(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Platnosť jedným ťukom; DPH predvoľby podľa častých sadzieb.',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 14),
                        StandardTextField(
                          controller: _quoteNumberController,
                          labelText: l10n.quoteNumber,
                          icon: Icons.tag,
                          readOnly: !_isNewQuote,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Platnosť do',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _buildValidityChips(),
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
                        if (_validUntilHint() != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            _validUntilHint()!,
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: AppColors.accentGold,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        StandardTextField(
                          controller: _notesController,
                          labelText: l10n.notes,
                          hintText: l10n.notesHint,
                          maxLines: 4,
                          onChanged: (_) => setState(() {}),
                        ),
                        _buildNoteSuggestions(),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                            const SizedBox(width: 12),
                            Expanded(
                              child: SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  l10n.pricesIncludeVat,
                                  style: GoogleFonts.dmSans(fontSize: 13),
                                ),
                                value: _pricesIncludeVat,
                                activeThumbColor: AppColors.accentGold,
                                activeTrackColor: AppColors.accentGoldSubtle,
                                onChanged: (v) =>
                                    setState(() => _pricesIncludeVat = v),
                              ),
                            ),
                          ],
                        ),
                        _buildQuoteVatChips(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.quoteItems,
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _addItem,
                        icon: const Icon(Icons.add_rounded,
                            color: AppColors.accentGold),
                        label: Text(
                          l10n.addItem,
                          style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.accentGold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_items.isEmpty)
                    Container(
                      decoration: AppColors.cardDecorationSmall(16),
                      padding: const EdgeInsets.all(28),
                      child: Center(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.accentGoldSubtle,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.inventory_2_outlined,
                                size: 40,
                                color: AppColors.accentGold,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              l10n.noQuoteItems,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.dmSans(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton.icon(
                              onPressed: _addItem,
                              icon: const Icon(Icons.add_rounded, size: 20),
                              label: Text(l10n.addItem),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...List.generate(_items.length, (index) {
                      final item = _items[index];
                      final lineWithVat = item.getLineTotalWithVat(
                        _pricesIncludeVat,
                      );
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: AppColors.cardDecorationSmall(14),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accentGoldSubtle,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              item.itemType,
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.accentGold,
                              ),
                            ),
                          ),
                          title: Text(
                            item.productName ?? item.productUniqueId,
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            '${item.qty} × ${item.unitPrice.toStringAsFixed(2)} ${item.unit}${item.discountPercent > 0 ? ' (−${item.discountPercent}%)' : ''}',
                            style: GoogleFonts.dmSans(fontSize: 12),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${lineWithVat.toStringAsFixed(2)} €',
                                style: GoogleFonts.dmSans(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: AppColors.danger,
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
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.accentGold.withValues(alpha: 0.12),
                            AppColors.bgElevated,
                          ],
                        ),
                        border: Border.all(
                          color: AppColors.accentGold.withValues(alpha: 0.35),
                        ),
                      ),
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.calculate_outlined,
                                  color: AppColors.accentGold, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Súhrn',
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _row(l10n.subtotalWithoutVat, _subtotalWithoutVat()),
                          const SizedBox(height: 4),
                          _row('DPH', _totalVat()),
                          const Divider(height: 16, color: AppColors.borderSubtle),
                          _row(l10n.totalWithVat, _totalWithVat(), bold: true),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.bgPrimary,
                              ),
                            )
                          : Text(
                              l10n.saveQuote,
                              style: GoogleFonts.dmSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _row(String label, double value, {bool bold = false}) {
    final w = bold ? FontWeight.w800 : FontWeight.w500;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontWeight: w,
            fontSize: bold ? 15 : 13,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          '${value.toStringAsFixed(2)} €',
          style: GoogleFonts.dmSans(
            fontWeight: w,
            fontSize: bold ? 16 : 13,
            color: bold ? AppColors.accentGold : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
