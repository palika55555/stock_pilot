import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/product.dart';
import '../../models/quote.dart';
import '../../services/Product/product_service.dart';
import '../../widgets/Products/add_product_modal_widget.dart';

/// Modál na pridanie položky do cenovej ponuky. Vráti [QuoteItem] s quoteId = 0 (screen nastaví pri ukladaní).
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

  static const List<String> _itemTypes = ['Tovar', 'Paleta', 'Služba', 'Doprava', 'Iné'];

  @override
  void initState() {
    super.initState();
    _products = List.from(widget.products);
    _vatController.text = widget.defaultVatRate.toString();
  }

  @override
  void dispose() {
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

  void _onProductSelected(Product p) {
    setState(() {
      _selectedProduct = p;
      _nameController.text = p.name;
      _unitController.text = p.unit;
      final price = widget.pricesIncludeVat ? p.price : p.withoutVat;
      _unitPriceController.text = price.toStringAsFixed(2);
      _vatController.text = p.vat.toString();
    });
  }

  void _clearProduct() {
    setState(() {
      _selectedProduct = null;
    });
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
      productUniqueId: _selectedProduct?.uniqueId ?? 'manual_${DateTime.now().millisecondsSinceEpoch}',
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Pridať položku',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Typ položky
              DropdownButtonFormField<String>(
                value: _itemType,
                decoration: const InputDecoration(
                  labelText: 'Typ',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category_outlined),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                items: _itemTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _itemType = v ?? 'Tovar'),
              ),
              const SizedBox(height: 12),
              // Hľadanie produktu (voliteľné)
              if (_selectedProduct == null) ...[
                Autocomplete<Product>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    final q = textEditingValue.text.toLowerCase();
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
                        elevation: 4,
                        borderRadius: BorderRadius.circular(8),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 220),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (ctx, i) {
                              final p = options.elementAt(i);
                              return ListTile(
                                dense: true,
                                leading: const Icon(Icons.inventory_2_outlined, size: 18),
                                title: Text(p.name, style: const TextStyle(fontSize: 14)),
                                subtitle: Text(p.plu, style: const TextStyle(fontSize: 12)),
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
                      decoration: const InputDecoration(
                        labelText: 'Vybrať produkt (voliteľné)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
                    );
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: _createNewProduct,
                      icon: const Icon(Icons.add_circle_outline, size: 16),
                      label: const Text('Nový produkt', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ] else ...[
                // Vybraný produkt – chip s možnosťou zrušiť
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined, color: Colors.teal, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_selectedProduct!.name} (${_selectedProduct!.plu})',
                          style: const TextStyle(fontSize: 13, color: Colors.teal),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: _clearProduct,
                        child: const Icon(Icons.close, size: 18, color: Colors.teal),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              // Názov položky (povinný, auto-vyplnený z produktu)
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Názov položky *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label_outline),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Zadajte názov položky' : null,
              ),
              const SizedBox(height: 12),
              // Popis
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Popis (voliteľný)',
                  hintText: 'napr. cappuccino 6cm',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes_outlined),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
              ),
              const SizedBox(height: 12),
              // Množstvo + Jednotka + DPH
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _qtyController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Množstvo',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _unitController,
                      decoration: const InputDecoration(
                        labelText: 'Jedn.',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _vatController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'DPH %',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
              const SizedBox(height: 12),
              // Jedn. cena + zľava + príplatok
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _unitPriceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: widget.pricesIncludeVat
                            ? 'Jedn. cena s DPH'
                            : 'Jedn. cena bez DPH',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
                      validator: (v) {
                        final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                        if (n == null || n < 0) return '≥ 0';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _discountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Zľava %',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _surchargeController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: _itemType == 'Paleta' ? 'Amortizácia %' : 'Príplatok %',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Pridať položku'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
