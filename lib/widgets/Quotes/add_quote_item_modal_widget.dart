import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/product.dart';
import '../../models/quote.dart';

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

  Product? _selectedProduct;
  final TextEditingController _qtyController = TextEditingController(text: '1');
  final TextEditingController _unitPriceController = TextEditingController();
  final TextEditingController _discountController = TextEditingController(
    text: '0',
  );
  final TextEditingController _vatController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _vatController.text = widget.defaultVatRate.toString();
    _unitPriceController.addListener(_syncUnitPriceLabel);
    _vatController.addListener(_syncUnitPriceLabel);
  }

  void _syncUnitPriceLabel() {}

  @override
  void dispose() {
    _qtyController.dispose();
    _unitPriceController.dispose();
    _discountController.dispose();
    _vatController.dispose();
    super.dispose();
  }

  void _onProductSelected(Product? p) {
    setState(() {
      _selectedProduct = p;
      if (p != null) {
        final price = widget.pricesIncludeVat ? p.price : p.withoutVat;
        _unitPriceController.text = price.toStringAsFixed(2);
        _vatController.text = p.vat.toString();
      } else {
        _unitPriceController.clear();
        _vatController.text = widget.defaultVatRate.toString();
      }
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vyberte produkt')));
      return;
    }
    final qty = int.tryParse(_qtyController.text.trim()) ?? 1;
    if (qty < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Množstvo musí byť aspoň 1')),
      );
      return;
    }
    final unitPrice =
        double.tryParse(
          _unitPriceController.text.trim().replaceAll(',', '.'),
        ) ??
        0.0;
    final discount = int.tryParse(_discountController.text.trim()) ?? 0;
    final vat =
        int.tryParse(_vatController.text.trim()) ?? widget.defaultVatRate;
    final item = QuoteItem(
      quoteId: 0,
      productUniqueId: _selectedProduct!.uniqueId!,
      productName: _selectedProduct!.name,
      plu: _selectedProduct!.plu,
      qty: qty,
      unit: _selectedProduct!.unit,
      unitPrice: unitPrice,
      discountPercent: discount.clamp(0, 100),
      vatPercent: vat.clamp(0, 27),
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
              const SizedBox(height: 16),
              DropdownButtonFormField<Product>(
                value: _selectedProduct,
                decoration: const InputDecoration(
                  labelText: 'Produkt',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                items: widget.products
                    .map(
                      (p) => DropdownMenuItem(
                        value: p,
                        child: Text(
                          '${p.name} (${p.plu})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _onProductSelected,
                validator: (v) => v == null ? 'Vyberte produkt' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _qtyController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Množstvo',
                        border: OutlineInputBorder(),
                      ),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        if (n == null || n < 1) return 'Min. 1';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _vatController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'DPH %',
                        border: OutlineInputBorder(),
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
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _unitPriceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: widget.pricesIncludeVat
                            ? 'Jedn. cena s DPH'
                            : 'Jedn. cena bez DPH',
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final n = double.tryParse(
                          (v ?? '').replaceAll(',', '.'),
                        );
                        if (n == null || n < 0) return 'Číslo ≥ 0';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _discountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Zľava %',
                        border: OutlineInputBorder(),
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
