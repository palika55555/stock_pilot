import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/product.dart';
import '../../models/receipt.dart';
import '../../models/supplier.dart';
import '../../models/warehouse.dart';
import '../../services/Product/product_service.dart';
import '../../services/Receipt/receipt_service.dart';
import '../../services/Warehouse/warehouse_service.dart';
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
  /// DPH % pre túto položku; prázdne = použiť spoločné DPH alebo DPH produktu.
  final TextEditingController vatPercentController = TextEditingController();
  String get unit => product?.unit ?? 'ks';
}

class GoodsReceiptModal extends StatefulWidget {
  final int? receiptId;

  const GoodsReceiptModal({super.key, this.receiptId});

  @override
  State<GoodsReceiptModal> createState() => _GoodsReceiptModalState();
}

class _GoodsReceiptModalState extends State<GoodsReceiptModal> {
  static const _radius = 12.0;
  static const _primaryBlue = Color(0xFF2563EB);
  static const _borderColor = Color(0xFFE2E8F0);
  static const _fillColor = Color(0xFFF8FAFC);

  final _formKey = GlobalKey<FormState>();
  final DatabaseService _db = DatabaseService();
  final ReceiptService _receiptService = ReceiptService();
  final ProductService _productService = ProductService();
  final SupplierService _supplierService = SupplierService();
  final WarehouseService _warehouseService = WarehouseService();

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
  bool _isSettled = false;
  final List<_ReceiptItemRow> _rows = [];
  List<Product> _products = [];
  List<Supplier> _suppliers = [];
  List<Warehouse> _warehouses = [];
  List<ReceiptMovementType> _movementTypes = [];
  Supplier? _selectedSupplier;
  Warehouse? _selectedWarehouse;
  ReceiptMovementType? _selectedMovementType;
  bool _productsLoaded = false;
  bool _isSaving = false;
  InboundReceipt? _editReceipt;

  bool get _isEditMode => widget.receiptId != null;

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
    _loadWarehousesAndMovementTypes();
    if (_isEditMode) {
      _loadReceiptAndProducts();
    } else {
      _loadProducts();
      _addRow();
      _generateNextReceiptNumber();
    }
    _vatRateController.addListener(_updateAllRowPrices);
  }

  Future<void> _loadWarehousesAndMovementTypes() async {
    final warehouses = await _warehouseService.getActiveWarehouses();
    final types = await _receiptService.getReceiptMovementTypes();
    if (mounted) {
      setState(() {
        _warehouses = warehouses;
        _movementTypes = types;
        if (_selectedWarehouse == null && _warehouses.isNotEmpty) {
          _selectedWarehouse = _warehouses.first;
        }
        if (_selectedMovementType == null && _movementTypes.isNotEmpty) {
          _selectedMovementType =
              _movementTypes.firstWhere(
                (t) => t.code == 'STANDARD',
                orElse: () => _movementTypes.first,
              );
        }
      });
    }
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
    final warehouses = await _warehouseService.getActiveWarehouses();
    final movementTypes = await _receiptService.getReceiptMovementTypes();
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
    Warehouse? matchedWarehouse;
    if (receipt?.warehouseId != null) {
      for (final w in warehouses) {
        if (w.id == receipt!.warehouseId) {
          matchedWarehouse = w;
          break;
        }
      }
    }
    ReceiptMovementType? matchedMovementType;
    if (receipt?.movementTypeCode != null && receipt!.movementTypeCode.isNotEmpty) {
      for (final t in movementTypes) {
        if (t.code == receipt.movementTypeCode) {
          matchedMovementType = t;
          break;
        }
      }
    }
    if (matchedMovementType == null && movementTypes.isNotEmpty) {
      matchedMovementType = movementTypes.first;
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
      _warehouses = warehouses;
      _movementTypes = movementTypes;
      _editReceipt = receipt;
      if (receipt != null) {
        _selectedSupplier = matchedSupplier;
        _selectedWarehouse = matchedWarehouse;
        _selectedMovementType = matchedMovementType;
        _isSettled = receipt.isSettled;
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

        double unitPriceForRow = item.unitPrice;
        if (unitPriceForRow <= 0 && product != null && product.purchasePrice > 0) {
          unitPriceForRow = product.purchasePrice;
        }

        double priceWithoutVat;
        if (_pricesIncludeVat) {
          final vat = item.vatPercent ??
              (_vatAppliesToAll
                  ? int.tryParse(_vatRateController.text)
                  : product?.purchaseVat) ??
              20;
          priceWithoutVat = _receiptService.calculateWithoutVat(
            unitPriceForRow,
            vat,
          );
        } else {
          priceWithoutVat = unitPriceForRow;
        }

        row.unitPriceWithoutVatController.text = priceWithoutVat
            .toStringAsFixed(5)
            .replaceAll(RegExp(r'0+$'), '')
            .replaceAll(RegExp(r'\.$'), '');
        if (item.vatPercent != null) {
          row.vatPercentController.text = item.vatPercent.toString();
        }
        row.unitPriceWithoutVatController.addListener(() => _updateRowWithVat(row));
        row.vatPercentController.addListener(() => _updateRowWithVat(row));
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

  int _effectiveVatForRow(_ReceiptItemRow row) {
    final rowVat = int.tryParse(row.vatPercentController.text.trim());
    if (rowVat != null && rowVat >= 0 && rowVat <= 100) return rowVat;
    if (_vatAppliesToAll) return int.tryParse(_vatRateController.text) ?? 20;
    return row.product?.purchaseVat ?? 20;
  }

  void _addRow() {
    final row = _ReceiptItemRow();
    row.unitPriceWithoutVatController.addListener(() => _updateRowWithVat(row));
    row.vatPercentController.addListener(() => _updateRowWithVat(row));
    setState(() => _rows.add(row));
  }

  void _updateRowWithVat(_ReceiptItemRow row) {
    final priceWithoutVat =
        double.tryParse(
          row.unitPriceWithoutVatController.text.replaceAll(',', '.'),
        ) ??
        0.0;
    final vat = _effectiveVatForRow(row);
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
      _rows[index].vatPercentController.dispose();
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

      final vat = _effectiveVatForRow(row);
      final priceWithVat = _receiptService.calculateWithVat(
        priceWithoutVat,
        vat,
      );
      final unitPriceToStore = _pricesIncludeVat
          ? priceWithVat
          : priceWithoutVat;

      items.add(
        InboundReceiptItem(
          receiptId: 0,
          productUniqueId: row.product!.uniqueId!,
          productName: row.product!.name,
          plu: row.product!.plu,
          qty: qty,
          unit: row.unit,
          unitPrice: _roundPrice(unitPriceToStore),
          vatPercent: vat,
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
    if (_selectedWarehouse == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vyberte sklad')),
      );
      return;
    }
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
      final warehouseId = _selectedWarehouse?.id;
      final movementTypeCode = _selectedMovementType?.code ?? 'STANDARD';

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
          warehouseId: warehouseId,
          movementTypeCode: movementTypeCode,
          isSettled: _isSettled,
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
          warehouseId: warehouseId,
          movementTypeCode: movementTypeCode,
          isSettled: _isSettled,
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
    if (_selectedWarehouse == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vyberte sklad')),
      );
      return;
    }

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
      final warehouseId = _selectedWarehouse?.id;
      final movementTypeCode = _selectedMovementType?.code ?? 'STANDARD';

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
          warehouseId: warehouseId,
          movementTypeCode: movementTypeCode,
          isSettled: _isSettled,
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
          warehouseId: warehouseId,
          movementTypeCode: movementTypeCode,
          isSettled: _isSettled,
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

  Future<void> _deleteReceipt() async {
    if (widget.receiptId == null || _editReceipt?.isApproved == true) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Odstrániť príjemku'),
        content: const Text(
          'Naozaj chcete odstrániť túto príjemku? Táto akcia sa nedá vrátiť späť.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Zrušiť'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Odstrániť'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isSaving = true);
    try {
      final ok = await _receiptService.deleteReceipt(widget.receiptId!);
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Príjemka bola odstránená'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Príjemku nebolo možné odstrániť (napr. už je schválená)'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba: $e'), backgroundColor: Colors.red),
        );
      }
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
      row.vatPercentController.dispose();
    }
    super.dispose();
  }

  static const _compactPadding = EdgeInsets.symmetric(horizontal: 10, vertical: 6);
  static const _compactPaddingTiny = EdgeInsets.symmetric(horizontal: 6, vertical: 4);

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 10, 12, bottomInset + 12),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 380, maxWidth: 880),
              child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isEditMode ? 'Upraviť príjemku' : 'Nový príjem tovaru',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        padding: const EdgeInsets.all(4),
                        minimumSize: const Size(32, 32),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _receiptNumberController,
                                  readOnly: !_manualReceiptNumber && !_isEditMode,
                                  style: const TextStyle(fontSize: 13),
                                  decoration: InputDecoration(
                                    labelText: 'Číslo príjemky',
                                    isDense: true,
                                    contentPadding: _compactPadding,
                                    border: const OutlineInputBorder(),
                                    prefixIcon: const Icon(Icons.tag, size: 20),
                                    suffixIcon: _isEditMode
                                        ? null
                                        : IconButton(
                                            icon: Icon(
                                              _manualReceiptNumber
                                                  ? Icons.auto_fix_high
                                                  : Icons.edit,
                                              size: 18,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _manualReceiptNumber =
                                                    !_manualReceiptNumber;
                                                if (!_manualReceiptNumber)
                                                  _generateNextReceiptNumber();
                                              });
                                            },
                                            style: IconButton.styleFrom(
                                              padding: const EdgeInsets.all(4),
                                              minimumSize: const Size(32, 32),
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: _invoiceController,
                                  style: const TextStyle(fontSize: 13),
                                  decoration: const InputDecoration(
                                    labelText: 'Číslo faktúry',
                                    isDense: true,
                                    contentPadding: _compactPadding,
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.description, size: 20),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<Warehouse?>(
                            isExpanded: true,
                            value: _selectedWarehouse,
                            decoration: const InputDecoration(
                              labelText: 'Sklad',
                              isDense: true,
                              contentPadding: _compactPadding,
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.warehouse, size: 20),
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('— Vyberte sklad —'),
                              ),
                              ..._warehouses.map(
                                (w) => DropdownMenuItem(
                                  value: w,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          w.name,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (w) => setState(() => _selectedWarehouse = w),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<Supplier?>(
                                  isExpanded: true,
                                  value: _selectedSupplier,
                                  decoration: const InputDecoration(
                                    labelText: 'Dodávateľ',
                                    isDense: true,
                                    contentPadding: _compactPadding,
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.business, size: 20),
                                  ),
                                  items: [
                                    const DropdownMenuItem(
                                      value: null,
                                      child: Text('— Vyberte dodávateľa —'),
                                    ),
                                    ..._suppliers.map(
                                      (s) => DropdownMenuItem(
                                        value: s,
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '${s.name} (IČO ${s.ico})',
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ),
                                          ],
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
                                  size: 20,
                                ),
                                tooltip: 'Pridať dodávateľa',
                                style: IconButton.styleFrom(
                                  padding: const EdgeInsets.all(4),
                                  minimumSize: const Size(36, 36),
                                ),
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
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _notesController,
                            maxLines: 1,
                            style: const TextStyle(fontSize: 13),
                            decoration: const InputDecoration(
                              labelText: 'Poznámka',
                              isDense: true,
                              contentPadding: _compactPadding,
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.note, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DropdownButtonFormField<ReceiptMovementType?>(
                            isExpanded: true,
                            value: _selectedMovementType,
                            decoration: const InputDecoration(
                              labelText: 'Druh pohybu',
                              isDense: true,
                              contentPadding: _compactPadding,
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.swap_horiz, size: 20),
                            ),
                            items: _movementTypes
                                .map(
                                  (t) => DropdownMenuItem(
                                    value: t,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            t.name,
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (t) =>
                                setState(() => _selectedMovementType = t),
                          ),
                          const SizedBox(height: 4),
                          CheckboxListTile(
                            title: const Text('Vysporiadané', style: TextStyle(fontSize: 13)),
                            subtitle: const Text(
                              'Daňový doklad zaevidovaný alebo sa neočakáva',
                              style: TextStyle(fontSize: 10),
                            ),
                            value: _isSettled,
                            onChanged: (v) =>
                                setState(() => _isSettled = v ?? false),
                            controlAffinity: ListTileControlAffinity.leading,
                            dense: true,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Typ príjemky',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: RadioListTile<bool>(
                                  title: const Text('S DPH', style: TextStyle(fontSize: 13)),
                                  value: true,
                                  groupValue: _pricesIncludeVat,
                                  onChanged: (v) =>
                                      setState(() => _pricesIncludeVat = true),
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                              Expanded(
                                child: RadioListTile<bool>(
                                  title: const Text('Bez DPH', style: TextStyle(fontSize: 13)),
                                  value: false,
                                  groupValue: _pricesIncludeVat,
                                  onChanged: (v) =>
                                      setState(() => _pricesIncludeVat = false),
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                          ),
                          CheckboxListTile(
                            title: const Text('Použiť DPH pre všetky položky', style: TextStyle(fontSize: 13)),
                            value: _vatAppliesToAll,
                            onChanged: (v) {
                              setState(() => _vatAppliesToAll = v ?? false);
                              _updateAllRowPrices();
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          if (_vatAppliesToAll) ...[
                            const SizedBox(height: 4),
                            SizedBox(
                              width: 80,
                              child: TextFormField(
                                controller: _vatRateController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(fontSize: 13),
                                decoration: const InputDecoration(
                                  labelText: 'DPH %',
                                  isDense: true,
                                  contentPadding: _compactPadding,
                                  border: OutlineInputBorder(),
                                ),
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Položky',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _addRow,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Pridať položku', style: TextStyle(fontSize: 13)),
                      style: FilledButton.styleFrom(
                        backgroundColor: _primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: const Size(0, 36),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (!_productsLoaded)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  _buildItemsTable(),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 44,
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
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 40,
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
                if (_isEditMode && _editReceipt != null && !_editReceipt!.isApproved) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: OutlinedButton.icon(
                      onPressed: _isSaving ? null : _deleteReceipt,
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                      label: const Text('Odstrániť'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildItemsTable() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: _borderColor),
        borderRadius: BorderRadius.circular(_radius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_radius),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(0.7),
            2: FlexColumnWidth(0.6),
            3: FlexColumnWidth(0.9),
            4: FlexColumnWidth(0.5),
            5: FlexColumnWidth(0.9),
            6: FlexColumnWidth(0.8),
            7: FixedColumnWidth(52),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(color: _fillColor),
              children: [
                _tableHeader('Produkt / Tovar'),
                _tableHeader('Skladom'),
                _tableHeader('Mn.'),
                _tableHeader('Cena bez DPH'),
                _tableHeader('DPH %'),
                _tableHeader('Cena s DPH'),
                _tableHeader('Spolu'),
                _tableHeader(''),
              ],
            ),
            ...List.generate(_rows.length, (i) => _buildTableRow(i)),
          ],
        ),
      ),
    );
  }

  Widget _tableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 11,
          color: Color(0xFF64748B),
        ),
      ),
    );
  }

  double _rowTotal(_ReceiptItemRow row) {
    final qty = int.tryParse(row.qtyController.text.trim()) ?? 0;
    final priceStr = _pricesIncludeVat
        ? row.unitPriceWithVatController.text.trim().replaceAll(',', '.')
        : row.unitPriceWithoutVatController.text.trim().replaceAll(',', '.');
    final price = double.tryParse(priceStr) ?? 0;
    return (qty * price * 100).round() / 100;
  }

  TableRow _buildTableRow(int index) {
    final row = _rows[index];
    final hasProduct = row.product != null;
    return TableRow(
      decoration: BoxDecoration(
        color: index.isEven ? Colors.white : const Color(0xFFFAFAFA),
      ),
      children: [
        Padding(
          padding: _compactPaddingTiny,
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<Product?>(
                  value: row.product,
                  isExpanded: true,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: _borderColor),
                    ),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('— Vyberte tovar —', style: TextStyle(fontSize: 12)),
                    ),
                    ..._products.map(
                      (p) => DropdownMenuItem(
                        value: p,
                        child: Text(
                          '${p.name} (${p.plu})',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                  onChanged: (p) => _onProductSelected(index, p),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_box_outlined, size: 18, color: _primaryBlue),
                onPressed: () => _addNewProduct(index),
                tooltip: 'Pridať tovar',
                padding: const EdgeInsets.all(2),
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),
        ),
        Padding(
          padding: _compactPaddingTiny,
          child: Center(
            child: Text(
              hasProduct ? '${row.product!.qty} ${row.unit}' : '—',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ),
        ),
        Padding(
          padding: _compactPaddingTiny,
          child: TextFormField(
            controller: row.qtyController,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: _borderColor),
              ),
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
        ),
        Padding(
          padding: _compactPaddingTiny,
          child: TextFormField(
            controller: row.unitPriceWithoutVatController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
            onChanged: (_) {
              _updateRowWithVat(row);
              setState(() {});
            },
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: _borderColor),
              ),
            ),
            inputFormatters: [_DecimalInputFormatter()],
          ),
        ),
        Padding(
          padding: _compactPaddingTiny,
          child: TextFormField(
            controller: row.vatPercentController,
            keyboardType: TextInputType.number,
            onChanged: (_) {
              _updateRowWithVat(row);
              setState(() {});
            },
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              isDense: true,
              hintText: _vatAppliesToAll ? null : 'vlast.',
              contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: _borderColor),
              ),
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
        ),
        Padding(
          padding: _compactPaddingTiny,
          child: TextFormField(
            controller: row.unitPriceWithVatController,
            readOnly: true,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: _fillColor,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: _borderColor),
              ),
            ),
          ),
        ),
        Padding(
          padding: _compactPaddingTiny,
          child: Center(
            child: Text(
              hasProduct ? '${_rowTotal(row).toStringAsFixed(2)} €' : '—',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: Color(0xFF94A3B8),
            ),
            onPressed: _rows.length > 1 ? () => _removeRow(index) : null,
            tooltip: 'Odstrániť',
            style: IconButton.styleFrom(
              padding: const EdgeInsets.all(2),
              minimumSize: const Size(28, 28),
            ),
          ),
        ),
      ],
    );
  }
}
