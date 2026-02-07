import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/product.dart';
import '../../models/receipt.dart';
import '../../models/supplier.dart';
import '../../services/Product/product_service.dart';
import '../../services/Receipt/receipt_service.dart';
import '../../services/database/database_service.dart';
import '../../services/supplier/supplier_service.dart';
import '../products/add_product_modal_widget.dart';
import '../suppliers/add_supplier_modal_widget.dart';

/// Input formatter: digits and one decimal point, max 5 decimal places.
class _DecimalInputFormatter extends TextInputFormatter {
  static const int maxDecimals = 5;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;
    if (text == '-') return newValue;
    final match = RegExp(r'^\d*\.?\d{0,5}$').firstMatch(text);
    if (match == null) return oldValue;
    return newValue;
  }
}

class _ReceiptItemRow {
  Product? product;
  final TextEditingController qtyController = TextEditingController(text: '1');
  final TextEditingController unitPriceWithoutVatController =
      TextEditingController();
  final TextEditingController unitPriceWithVatController =
      TextEditingController();
  String get unit => product?.unit ?? 'ks';
}

class GoodsReceiptModal extends StatefulWidget {
  final int? receiptId;

  const GoodsReceiptModal({super.key, this.receiptId});

  @override
  State<GoodsReceiptModal> createState() => _GoodsReceiptModalState();
}

class _GoodsReceiptModalState extends State<GoodsReceiptModal> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseService _db = DatabaseService();
  final ReceiptService _receiptService = ReceiptService();
  final ProductService _productService = ProductService();
  final SupplierService _supplierService = SupplierService();

  final TextEditingController _invoiceController = TextEditingController();
  final TextEditingController _receiptNumberController =
      TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _vatRateController = TextEditingController(
    text: '20',
  );

  bool _pricesIncludeVat = true;
  bool _vatAppliesToAll = false;
  bool _manualReceiptNumber = false;
  final List<_ReceiptItemRow> _rows = [];
  List<Product> _products = [];
  List<Supplier> _suppliers = [];
  Supplier? _selectedSupplier;
  bool _productsLoaded = false;
  bool _isSaving = false;
  InboundReceipt? _editReceipt;

  bool get _isEditMode => widget.receiptId != null;

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
    if (_isEditMode) {
      _loadReceiptAndProducts();
    } else {
      _loadProducts();
      _addRow();
      _generateNextReceiptNumber();
    }
    _vatRateController.addListener(_updateAllRowPrices);
  }

  Future<void> _loadSuppliers() async {
    final list = await _supplierService.getActiveSuppliers();
    if (mounted)
      setState(() {
        _suppliers = list;
        // Pri úprave: ak je vybraný neaktívny dodávateľ, pridaj ho do zoznamu
        if (_selectedSupplier != null &&
            !_suppliers.any((s) => s.id == _selectedSupplier!.id)) {
          _suppliers = [..._suppliers, _selectedSupplier!];
        }
      });
  }

  Future<void> _generateNextReceiptNumber() async {
    final next = await _db.getNextReceiptNumber();
    if (mounted && !_manualReceiptNumber) {
      setState(() {
        _receiptNumberController.text = next;
      });
    }
  }

  Future<void> _loadReceiptAndProducts() async {
    final id = widget.receiptId!;
    final receipt = await _db.getInboundReceiptById(id);
    final items = await _db.getInboundReceiptItems(id);
    final products = await _productService.getAllProducts();
    final allSuppliers = await _supplierService.getAllSuppliers();
    if (!mounted) return;
    Supplier? matchedSupplier;
    if (receipt?.supplierName != null && receipt!.supplierName!.isNotEmpty) {
      for (final s in allSuppliers) {
        if (s.name == receipt.supplierName) {
          matchedSupplier = s;
          break;
        }
      }
    }
    var displaySuppliers = allSuppliers.where((s) => s.isActive).toList();
    if (matchedSupplier != null &&
        !matchedSupplier.isActive &&
        !displaySuppliers.any((s) => s.id == matchedSupplier!.id)) {
      displaySuppliers = [...displaySuppliers, matchedSupplier];
    }
    if (!mounted) return;
    setState(() {
      _products = products;
      _suppliers = displaySuppliers;
      _editReceipt = receipt;
      if (receipt != null) {
        _selectedSupplier = matchedSupplier;
        _invoiceController.text = receipt.invoiceNumber ?? '';
        _receiptNumberController.text = receipt.receiptNumber;
        _notesController.text = receipt.notes ?? '';
        _pricesIncludeVat = receipt.pricesIncludeVat;
        _vatAppliesToAll = receipt.vatAppliesToAll;
        _vatRateController.text =
            receipt.vatRate?.toString() ??
            (matchedSupplier?.defaultVatRate.toString() ?? '20');
        _manualReceiptNumber = true;
      }
      _rows.clear();
      for (final item in items) {
        Product? product;
        for (final p in products) {
          if (p.uniqueId == item.productUniqueId) {
            product = p;
            break;
          }
        }
        final row = _ReceiptItemRow();
        row.product = product;
        row.qtyController.text = item.qty.toString();

        double priceWithoutVat;
        if (_pricesIncludeVat) {
          final vat = _vatAppliesToAll
              ? (int.tryParse(_vatRateController.text) ?? 20)
              : (product?.purchaseVat ?? 20);
          priceWithoutVat = _receiptService.calculateWithoutVat(
            item.unitPrice,
            vat,
          );
        } else {
          priceWithoutVat = item.unitPrice;
        }

        row.unitPriceWithoutVatController.text = priceWithoutVat
            .toStringAsFixed(5)
            .replaceAll(RegExp(r'0+$'), '')
            .replaceAll(RegExp(r'\.$'), '');
        _updateRowWithVat(row);
        _rows.add(row);
      }
      if (_rows.isEmpty) _addRow();
      _productsLoaded = true;
    });
  }

  Future<void> _loadProducts() async {
    final list = await _productService.getAllProducts();
    if (mounted) {
      setState(() {
        _products = list;
        _productsLoaded = true;
      });
    }
  }

  void _addRow() {
    final row = _ReceiptItemRow();
    row.unitPriceWithoutVatController.addListener(() => _updateRowWithVat(row));
    setState(() => _rows.add(row));
  }

  void _updateRowWithVat(_ReceiptItemRow row) {
    final priceWithoutVat =
        double.tryParse(
          row.unitPriceWithoutVatController.text.replaceAll(',', '.'),
        ) ??
        0.0;
    final vat = _vatAppliesToAll
        ? (int.tryParse(_vatRateController.text) ?? 20)
        : (row.product?.purchaseVat ?? 20);
    final priceWithVat = _receiptService.calculateWithVat(priceWithoutVat, vat);
    row.unitPriceWithVatController.text = priceWithVat.toStringAsFixed(2);
  }

  void _updateAllRowPrices() {
    for (final row in _rows) {
      _updateRowWithVat(row);
    }
  }

  void _removeRow(int index) {
    if (_rows.length <= 1) return;
    setState(() {
      _rows[index].qtyController.dispose();
      _rows[index].unitPriceWithoutVatController.dispose();
      _rows[index].unitPriceWithVatController.dispose();
      _rows.removeAt(index);
    });
  }

  void _onProductSelected(int rowIndex, Product? product) {
    setState(() {
      _rows[rowIndex].product = product;
      if (product != null) {
        _rows[rowIndex].unitPriceWithoutVatController.text =
            product.purchasePriceWithoutVat > 0
            ? product.purchasePriceWithoutVat
                  .toStringAsFixed(5)
                  .replaceAll(RegExp(r'0+$'), '')
                  .replaceAll(RegExp(r'\.$'), '')
            : (product.purchasePrice / (1 + (product.purchaseVat / 100)))
                  .toStringAsFixed(5)
                  .replaceAll(RegExp(r'0+$'), '')
                  .replaceAll(RegExp(r'\.$'), '');
        _updateRowWithVat(_rows[rowIndex]);
      }
    });
  }

  void _addNewProduct(int rowIndex) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const AddProductModal(),
    ).then((newProduct) {
      if (newProduct != null && newProduct is Product) {
        setState(() {
          _products.add(newProduct);
          _onProductSelected(rowIndex, newProduct);
        });
      }
    });
  }

  static double _roundPrice(double v) => (v * 100000).round() / 100000;

  /// Zozbiera položky z riadkov (s plnou validáciou pre vykázanie).
  Future<List<InboundReceiptItem>?> _collectItems({
    bool allowEmpty = false,
  }) async {
    final items = <InboundReceiptItem>[];
    for (var i = 0; i < _rows.length; i++) {
      final row = _rows[i];
      if (row.product == null) {
        if (!allowEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Riadok ${i + 1}: vyberte tovar')),
          );
          return null;
        }
        continue;
      }
      final qty = int.tryParse(row.qtyController.text.trim());
      if (qty == null || qty < 1) {
        if (!allowEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Riadok ${i + 1}: zadajte platné množstvo')),
          );
          return null;
        }
        continue;
      }
      final priceWithoutVat = double.tryParse(
        row.unitPriceWithoutVatController.text.trim().replaceAll(',', '.'),
      );
      if (priceWithoutVat == null || priceWithoutVat < 0) {
        if (!allowEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Riadok ${i + 1}: zadajte platnú cenu')),
          );
          return null;
        }
        continue;
      }

      final vat = _vatAppliesToAll
          ? (int.tryParse(_vatRateController.text) ?? 20)
          : (row.product?.purchaseVat ?? 20);
      final priceWithVat = _receiptService.calculateWithVat(
        priceWithoutVat,
        vat,
      );
      final unitPriceToStore = _pricesIncludeVat
          ? priceWithVat
          : priceWithoutVat;

      if (!allowEmpty &&
          row.product != null &&
          (row.product!.purchasePriceWithoutVat != priceWithoutVat ||
              row.product!.purchaseVat != vat)) {
        final updatedProduct = Product(
          uniqueId: row.product!.uniqueId,
          name: row.product!.name,
          plu: row.product!.plu,
          category: row.product!.category,
          qty: row.product!.qty,
          unit: row.product!.unit,
          price: row.product!.price,
          withoutVat: row.product!.withoutVat,
          vat: row.product!.vat,
          discount: row.product!.discount,
          lastPurchasePrice: _roundPrice(priceWithVat),
          lastPurchaseDate: row.product!.lastPurchaseDate,
          currency: row.product!.currency,
          location: row.product!.location,
          purchasePrice: _roundPrice(priceWithVat),
          purchasePriceWithoutVat: _roundPrice(priceWithoutVat),
          purchaseVat: vat,
          recyclingFee: row.product!.recyclingFee,
          productType: row.product!.productType,
        );
        await _productService.updateProduct(updatedProduct);
      }

      items.add(
        InboundReceiptItem(
          receiptId: 0,
          productUniqueId: row.product!.uniqueId!,
          productName: row.product!.name,
          plu: row.product!.plu,
          qty: qty,
          unit: row.unit,
          unitPrice: _roundPrice(unitPriceToStore),
        ),
      );
    }
    if (!allowEmpty && items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pridajte aspoň jednu položku')),
      );
      return null;
    }
    return items;
  }

  Future<void> _saveDraft() async {
    final items = await _collectItems(allowEmpty: true);
    if (items == null) return;
    setState(() => _isSaving = true);
    try {
      final vatRate = _vatAppliesToAll
          ? int.tryParse(_vatRateController.text.trim())
          : null;
      final supplierName = _selectedSupplier?.name;
      final invoice = _invoiceController.text.trim().isEmpty
          ? null
          : _invoiceController.text.trim();
      final notesText = _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim();
      var receiptNumber = _receiptNumberController.text.trim();
      if (receiptNumber.isEmpty) {
        receiptNumber = await _db.getNextReceiptNumber();
        if (mounted) _receiptNumberController.text = receiptNumber;
      }

      if (_isEditMode && _editReceipt != null) {
        final receipt = _editReceipt!.copyWith(
          receiptNumber: receiptNumber,
          invoiceNumber: invoice,
          supplierName: supplierName,
          notes: notesText,
          pricesIncludeVat: _pricesIncludeVat,
          vatAppliesToAll: _vatAppliesToAll,
          vatRate: vatRate,
          status: InboundReceiptStatus.rozpracovany,
        );
        await _receiptService.updateReceipt(receipt: receipt, items: items);
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Príjemka uložená ako rozpracovaná'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        final receipt = InboundReceipt(
          receiptNumber: receiptNumber,
          invoiceNumber: invoice,
          createdAt: DateTime.now(),
          supplierName: supplierName,
          notes: notesText,
          pricesIncludeVat: _pricesIncludeVat,
          vatAppliesToAll: _vatAppliesToAll,
          vatRate: vatRate,
        );
        await _receiptService.createReceipt(
          receipt: receipt,
          items: items,
          isDraft: true,
        );
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Príjemka uložená ako rozpracovaná'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba: $e'), backgroundColor: Colors.red),
        );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final items = await _collectItems(allowEmpty: false);
    if (items == null) return;

    setState(() => _isSaving = true);
    try {
      final vatRate = _vatAppliesToAll
          ? int.tryParse(_vatRateController.text.trim())
          : null;
      final supplierName = _selectedSupplier?.name;
      final invoice = _invoiceController.text.trim().isEmpty
          ? null
          : _invoiceController.text.trim();
      final notesText = _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim();
      final receiptNumber = _receiptNumberController.text.trim();

      if (_isEditMode && _editReceipt != null) {
        final status = _editReceipt!.isDraft
            ? InboundReceiptStatus.vykazana
            : _editReceipt!.status;
        final receipt = _editReceipt!.copyWith(
          receiptNumber: receiptNumber,
          invoiceNumber: invoice,
          supplierName: supplierName,
          notes: notesText,
          pricesIncludeVat: _pricesIncludeVat,
          vatAppliesToAll: _vatAppliesToAll,
          vatRate: vatRate,
          status: status,
        );
        await _receiptService.updateReceipt(receipt: receipt, items: items);
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _editReceipt!.isDraft
                    ? 'Príjemka bola vykázaná'
                    : 'Príjemka bola upravená',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        final receipt = InboundReceipt(
          receiptNumber: receiptNumber,
          invoiceNumber: invoice,
          createdAt: DateTime.now(),
          supplierName: supplierName,
          notes: notesText,
          pricesIncludeVat: _pricesIncludeVat,
          vatAppliesToAll: _vatAppliesToAll,
          vatRate: vatRate,
        );
        await _receiptService.createReceipt(receipt: receipt, items: items);
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Príjemka bola uložená'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba: $e'), backgroundColor: Colors.red),
        );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _invoiceController.dispose();
    _receiptNumberController.dispose();
    _notesController.dispose();
    _vatRateController.dispose();
    for (final row in _rows) {
      row.qtyController.dispose();
      row.unitPriceWithoutVatController.dispose();
      row.unitPriceWithVatController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 20),
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
                    _isEditMode ? 'Upraviť príjemku' : 'Nový príjem tovaru',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _receiptNumberController,
                      readOnly: !_manualReceiptNumber && !_isEditMode,
                      decoration: InputDecoration(
                        labelText: 'Číslo príjemky',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.tag),
                        suffixIcon: _isEditMode
                            ? null
                            : IconButton(
                                icon: Icon(
                                  _manualReceiptNumber
                                      ? Icons.auto_fix_high
                                      : Icons.edit,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _manualReceiptNumber =
                                        !_manualReceiptNumber;
                                    if (!_manualReceiptNumber)
                                      _generateNextReceiptNumber();
                                  });
                                },
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _invoiceController,
                      decoration: const InputDecoration(
                        labelText: 'Číslo faktúry',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<Supplier?>(
                      value: _selectedSupplier,
                      decoration: const InputDecoration(
                        labelText: 'Dodávateľ',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.business),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('— Vyberte dodávateľa —'),
                        ),
                        ..._suppliers.map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Text(
                              '${s.name} (IČO ${s.ico})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (s) {
                        setState(() {
                          _selectedSupplier = s;
                          if (s != null) {
                            _vatRateController.text = s.defaultVatRate
                                .toString();
                            _vatAppliesToAll = true;
                            _updateAllRowPrices();
                          }
                        });
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.add_circle_outline,
                      color: Colors.blue,
                    ),
                    tooltip: 'Pridať dodávateľa',
                    onPressed: () async {
                      final result = await showModalBottomSheet<Supplier>(
                        context: context,
                        isScrollControlled: true,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                        ),
                        builder: (ctx) => const AddSupplierModal(),
                      );
                      if (!mounted) return;
                      await _loadSuppliers();
                      if (result != null && mounted)
                        setState(() {
                          final match = _suppliers.where(
                            (s) => s.id == result.id,
                          );
                          _selectedSupplier = match.isEmpty
                              ? result
                              : match.first;
                          _vatRateController.text = result.defaultVatRate
                              .toString();
                          _vatAppliesToAll = true;
                          _updateAllRowPrices();
                        });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Poznámka',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Typ príjemky',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<bool>(
                      title: const Text('S DPH'),
                      value: true,
                      groupValue: _pricesIncludeVat,
                      onChanged: (v) =>
                          setState(() => _pricesIncludeVat = true),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<bool>(
                      title: const Text('Bez DPH'),
                      value: false,
                      groupValue: _pricesIncludeVat,
                      onChanged: (v) =>
                          setState(() => _pricesIncludeVat = false),
                    ),
                  ),
                ],
              ),
              CheckboxListTile(
                title: const Text('Použiť DPH pre všetky položky'),
                value: _vatAppliesToAll,
                onChanged: (v) {
                  setState(() => _vatAppliesToAll = v ?? false);
                  _updateAllRowPrices();
                },
                controlAffinity: ListTileControlAffinity.leading,
              ),
              if (_vatAppliesToAll) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: 120,
                  child: TextFormField(
                    controller: _vatRateController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'DPH %',
                      border: OutlineInputBorder(),
                    ),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Položky',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addRow,
                    icon: const Icon(Icons.add),
                    label: const Text('Pridať položku'),
                  ),
                ],
              ),
              if (!_productsLoaded)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                ...List.generate(_rows.length, (i) => _buildItemRow(i)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _isEditMode && _editReceipt?.isDraft == true
                              ? 'Vykázať príjem'
                              : (_isEditMode
                                    ? 'Uložiť zmeny'
                                    : 'Uložiť príjem'),
                        ),
                ),
              ),
              if (!_isEditMode || _editReceipt?.isDraft == true) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _isSaving ? null : _saveDraft,
                    icon: const Icon(Icons.save_outlined, size: 20),
                    label: const Text('Uložiť ako rozpracovaný'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemRow(int index) {
    final row = _rows[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<Product?>(
                    value: row.product,
                    decoration: const InputDecoration(
                      labelText: 'Tovar',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('— Vyberte tovar —'),
                      ),
                      ..._products.map(
                        (p) => DropdownMenuItem(
                          value: p,
                          child: Text(
                            '${p.name} (${p.plu})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (p) => _onProductSelected(index, p),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add_box_outlined, color: Colors.blue),
                  onPressed: () => _addNewProduct(index),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.remove_circle_outline,
                    color: Colors.red,
                  ),
                  onPressed: _rows.length > 1 ? () => _removeRow(index) : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 80,
                  child: TextFormField(
                    controller: row.qtyController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Mn.',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: row.unitPriceWithoutVatController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Cena bez DPH',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    inputFormatters: [_DecimalInputFormatter()],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: row.unitPriceWithVatController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Cena s DPH',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
