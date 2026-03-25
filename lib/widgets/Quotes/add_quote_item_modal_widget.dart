import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/product.dart';
import '../../models/quote.dart';
import '../../services/Product/product_service.dart';
import '../../theme/app_theme.dart';
import '../Products/add_product_modal_widget.dart';

/// Modál na pridanie položky do cenovej ponuky. Vráti [QuoteItem] s quoteId = 0.
class AddQuoteItemModal extends StatefulWidget {
  final List<Product> products;
  final int defaultVatRate;
  final bool pricesIncludeVat;

  const AddQuoteItemModal({
    super.key,
    required this.products,
    this.defaultVatRate = 20,
    this.pricesIncludeVat = true,
  });

  @override
  State<AddQuoteItemModal> createState() => _AddQuoteItemModalState();
}

class _AddQuoteItemModalState extends State<AddQuoteItemModal> {
  final _formKey = GlobalKey<FormState>();

  List<Product> _products = [];
  Product? _selectedProduct;
  String _itemType = 'Tovar';
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _unitController = TextEditingController(text: 'ks');
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController(text: '1');
  final TextEditingController _unitPriceController = TextEditingController();
  final TextEditingController _discountController = TextEditingController(text: '0');
  final TextEditingController _surchargeController = TextEditingController(text: '0');
  final TextEditingController _vatController = TextEditingController();

  static const List<String> _itemTypes = [
    'Tovar',
    'Paleta',
    'Služba',
    'Doprava',
    'Iné',
  ];

  static const List<int> _vatPresets = [0, 5, 10, 19, 20, 23];

  void _previewRefresh() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _products = List.from(widget.products);
    _vatController.text = widget.defaultVatRate.toString();
    for (final c in <TextEditingController>[
      _nameController,
      _qtyController,
      _unitPriceController,
      _discountController,
      _surchargeController,
      _vatController,
      _unitController,
    ]) {
      c.addListener(_previewRefresh);
    }
  }

  @override
  void dispose() {
    for (final c in <TextEditingController>[
      _nameController,
      _qtyController,
      _unitPriceController,
      _discountController,
      _surchargeController,
      _vatController,
      _unitController,
    ]) {
      c.removeListener(_previewRefresh);
    }
    _nameController.dispose();
    _unitController.dispose();
    _descriptionController.dispose();
    _qtyController.dispose();
    _unitPriceController.dispose();
    _discountController.dispose();
    _surchargeController.dispose();
    _vatController.dispose();
    super.dispose();
  }

  QuoteItem _draftItem() {
    final qty = double.tryParse(_qtyController.text.trim().replaceAll(',', '.')) ?? 0;
    final unitPrice =
        double.tryParse(_unitPriceController.text.trim().replaceAll(',', '.')) ?? 0;
    final discount = int.tryParse(_discountController.text.trim()) ?? 0;
    final surcharge = int.tryParse(_surchargeController.text.trim()) ?? 0;
    final vat = int.tryParse(_vatController.text.trim()) ?? widget.defaultVatRate;
    return QuoteItem(
      quoteId: 0,
      productUniqueId: 'preview',
      productName: _nameController.text.trim().isEmpty ? '—' : _nameController.text.trim(),
      qty: qty > 0 ? qty : 1,
      unit: _unitController.text.trim().isEmpty ? 'ks' : _unitController.text.trim(),
      unitPrice: unitPrice,
      discountPercent: discount.clamp(0, 100),
      vatPercent: vat.clamp(0, 27),
      itemType: _itemType,
      surchargePercent: surcharge.clamp(0, 100),
    );
  }

  void _onProductSelected(Product p) {
    setState(() {
      _selectedProduct = p;
      _nameController.text = p.name;
      _unitController.text = p.unit;
      final price = widget.pricesIncludeVat ? p.price : p.withoutVat;
      _unitPriceController.text = price.toStringAsFixed(2);
      _vatController.text = p.vat.toString();
    });
    HapticFeedback.lightImpact();
  }

  void _clearProduct() {
    setState(() => _selectedProduct = null);
  }

  Future<void> _createNewProduct() async {
    FocusScope.of(context).unfocus();
    await Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: const Text('Nový produkt'),
            leading: const CloseButton(),
          ),
          body: const SingleChildScrollView(
            child: AddProductModal(),
          ),
        ),
      ),
    );
    final updated = await ProductService().getAllProducts();
    if (mounted) setState(() => _products = updated);
  }

  void _setQtyQuick(double q) {
    _qtyController.text = q == q.truncateToDouble() ? q.toInt().toString() : q.toStringAsFixed(2);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final qty = double.tryParse(_qtyController.text.trim().replaceAll(',', '.')) ?? 1.0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Množstvo musí byť väčšie ako 0')),
      );
      return;
    }
    final unitPrice = double.tryParse(_unitPriceController.text.trim().replaceAll(',', '.')) ?? 0.0;
    final discount = int.tryParse(_discountController.text.trim()) ?? 0;
    final surcharge = int.tryParse(_surchargeController.text.trim()) ?? 0;
    final vat = int.tryParse(_vatController.text.trim()) ?? widget.defaultVatRate;
    final name = _nameController.text.trim();
    final unit = _unitController.text.trim();
    final description = _descriptionController.text.trim();

    final item = QuoteItem(
      quoteId: 0,
      productUniqueId: _selectedProduct?.uniqueId ??
          'manual_${DateTime.now().millisecondsSinceEpoch}',
      productName: name,
      plu: _selectedProduct?.plu,
      qty: qty,
      unit: unit.isEmpty ? 'ks' : unit,
      unitPrice: unitPrice,
      discountPercent: discount.clamp(0, 100),
      vatPercent: vat.clamp(0, 27),
      itemType: _itemType,
      description: description.isEmpty ? null : description,
      surchargePercent: surcharge.clamp(0, 100),
    );
    Navigator.pop(context, item);
  }

  Widget _section(String title, String subtitle, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accentGoldSubtle,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.accentGold),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    height: 1.25,
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

  Widget _livePreviewCard() {
    final draft = _draftItem();
    final qty = double.tryParse(_qtyController.text.trim().replaceAll(',', '.')) ?? 0;
    final unitOk = double.tryParse(_unitPriceController.text.trim().replaceAll(',', '.')) != null;
    final show =
        qty > 0 && unitOk && _nameController.text.trim().isNotEmpty;
    final w = draft.getLineTotalWithoutVat(widget.pricesIncludeVat);
    final v = draft.getLineTotalWithVat(widget.pricesIncludeVat);
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: show ? 1 : 0.45,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.accentGold.withValues(alpha: 0.12),
              AppColors.bgElevated,
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_rounded,
                    color: AppColors.accentGold, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Náhľad riadku',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accentGold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.pricesIncludeVat ? 'Riadok s DPH' : 'Riadok bez DPH',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  '${w.toStringAsFixed(2)} €  →  ${v.toStringAsFixed(2)} €',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              widget.pricesIncludeVat
                  ? 'Ľavá hodnota = bez DPH, pravá = s DPH (podľa zobrazenia v ponuke).'
                  : 'Jednotková cena je bez DPH; vpravo súhrn s DPH.',
              style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _vatChips() {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _vatPresets.map((v) {
          final selected = _vatController.text.trim() == v.toString();
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
            onSelected: (_) => setState(() => _vatController.text = v.toString()),
          );
        }).toList(),
      ),
    );
  }

  Widget _qtyQuickRow() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        children: [1, 2, 5, 10, 25].map((n) {
          return ActionChip(
            label: Text('× $n', style: GoogleFonts.dmSans(fontSize: 12)),
            backgroundColor: AppColors.bgElevated,
            side: const BorderSide(color: AppColors.borderDefault),
            onPressed: () => setState(() => _setQtyQuick(n.toDouble())),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.bgElevated.withValues(alpha: 0.5),
            AppColors.bgCard,
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: const Border(
          top: BorderSide(color: AppColors.borderDefault, width: 1),
        ),
      ),
      padding: EdgeInsets.fromLTRB(22, 10, 22, bottom + 22),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: AppColors.borderDefault,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.accentGold.withValues(alpha: 0.25),
                          AppColors.bgElevated,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: const Icon(Icons.add_chart_rounded,
                        color: AppColors.accentGold, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pridať položku',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Produkt doplní cenu a DPH • náhľad sa počíta live',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.bgElevated,
                      side: const BorderSide(color: AppColors.borderDefault),
                    ),
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.textSecondary, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _section(
                'Typ a zdroj',
                'Vyberte typ riadku alebo produkt z katalógu.',
                Icons.category_rounded,
              ),
              DropdownButtonFormField<String>(
                value: _itemType,
                style: GoogleFonts.dmSans(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Typ položky',
                  labelStyle: GoogleFonts.dmSans(color: AppColors.textSecondary),
                  prefixIcon: const Icon(Icons.label_outline,
                      color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.bgInput,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: _itemTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _itemType = v ?? 'Tovar'),
              ),
              const SizedBox(height: 12),
              if (_selectedProduct == null) ...[
                Autocomplete<Product>(
                  optionsBuilder: (TextEditingValue tev) {
                    final q = tev.text.toLowerCase();
                    if (q.isEmpty) return _products.take(50);
                    return _products.where(
                      (p) =>
                          p.name.toLowerCase().contains(q) ||
                          p.plu.toLowerCase().contains(q),
                    );
                  },
                  displayStringForOption: (p) => '${p.name} (${p.plu})',
                  onSelected: _onProductSelected,
                  optionsViewBuilder: (ctx, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        color: AppColors.bgElevated,
                        elevation: 8,
                        borderRadius: BorderRadius.circular(12),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 240),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (ctx, i) {
                              final p = options.elementAt(i);
                              return ListTile(
                                dense: true,
                                leading: const Icon(Icons.inventory_2_outlined,
                                    size: 18, color: AppColors.accentGold),
                                title: Text(p.name,
                                    style: GoogleFonts.dmSans(fontSize: 14)),
                                subtitle: Text(p.plu,
                                    style: GoogleFonts.dmSans(fontSize: 12)),
                                onTap: () => onSelected(p),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                  fieldViewBuilder: (ctx, controller, focusNode, onSubmitted) {
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      style: GoogleFonts.dmSans(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Vybrať produkt (voliteľné)',
                        filled: true,
                        fillColor: AppColors.bgInput,
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: AppColors.textSecondary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  },
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _createNewProduct,
                    icon: const Icon(Icons.add_circle_outline,
                        size: 18, color: AppColors.accentGold),
                    label: Text(
                      'Nový produkt',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: AppColors.accentGold,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.successSubtle,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.inventory_2_rounded,
                          color: AppColors.success, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_selectedProduct!.name} (${_selectedProduct!.plu})',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: _clearProduct,
                        child: const Icon(Icons.close_rounded,
                            size: 20, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              _section(
                'Text a množstvo',
                'Názov na ponuke, popis a rýchle množstvá.',
                Icons.edit_note_rounded,
              ),
              TextFormField(
                controller: _nameController,
                style: GoogleFonts.dmSans(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Názov položky *',
                  filled: true,
                  fillColor: AppColors.bgInput,
                  prefixIcon: const Icon(Icons.label_outline,
                      color: AppColors.textSecondary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Zadajte názov položky' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _descriptionController,
                style: GoogleFonts.dmSans(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Popis (voliteľný)',
                  hintText: 'napr. cappuccino 6 cm',
                  filled: true,
                  fillColor: AppColors.bgInput,
                  prefixIcon: const Icon(Icons.notes_outlined,
                      color: AppColors.textSecondary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _qtyController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.dmSans(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Množstvo',
                        filled: true,
                        fillColor: AppColors.bgInput,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                      ],
                      validator: (v) {
                        final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                        if (n == null || n <= 0) return '> 0';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _unitController,
                      style: GoogleFonts.dmSans(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Jedn.',
                        filled: true,
                        fillColor: AppColors.bgInput,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              _qtyQuickRow(),
              const SizedBox(height: 14),
              _section(
                'Cena a DPH',
                'Zodpovedá prepínaču „ceny s DPH“ v ponuke.',
                Icons.payments_outlined,
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _unitPriceController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.dmSans(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: widget.pricesIncludeVat
                            ? 'Jedn. cena s DPH'
                            : 'Jedn. cena bez DPH',
                        filled: true,
                        fillColor: AppColors.bgInput,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (v) {
                        final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                        if (n == null || n < 0) return '≥ 0';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _vatController,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.dmSans(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'DPH %',
                        filled: true,
                        fillColor: AppColors.bgInput,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(2),
                      ],
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        if (n == null || n < 0 || n > 27) return '0–27';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              _vatChips(),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _discountController,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.dmSans(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Zľava %',
                        filled: true,
                        fillColor: AppColors.bgInput,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        if (n == null || n < 0 || n > 100) return '0–100';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _surchargeController,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.dmSans(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        labelText:
                            _itemType == 'Paleta' ? 'Amortizácia %' : 'Príplatok %',
                        filled: true,
                        fillColor: AppColors.bgInput,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        if (n == null || n < 0 || n > 100) return '0–100';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              _livePreviewCard(),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _submit,
                  child: Text(
                    'Pridať položku',
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
