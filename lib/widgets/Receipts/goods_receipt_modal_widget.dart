import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/product.dart';
import '../../models/receipt.dart';
import '../../models/supplier.dart';
import '../../models/warehouse.dart';
import '../../services/Product/product_service.dart';
import '../../services/Receipt/receipt_service.dart';
import '../../services/Warehouse/warehouse_service.dart';
import '../../services/Database/database_service.dart';
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
  /// Pri manuálnom rozpočítaní: zadaná alokovaná suma na položku (s DPH).
  final TextEditingController manualAllocatedCostController = TextEditingController();
  String get unit => product?.unit ?? 'ks';
}

/// Jeden riadok obstarávacieho nákladu v príjemke s nákladmi.
class _AcquisitionCostRow {
  String costType;
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController amountWithoutVatController = TextEditingController();
  final TextEditingController vatPercentController = TextEditingController(text: '20');
  final TextEditingController costSupplierController = TextEditingController();
  final TextEditingController documentNumberController = TextEditingController();
  _AcquisitionCostRow({this.costType = 'Doprava'});
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
  Warehouse? _selectedSourceWarehouse;
  ReceiptMovementType? _selectedMovementType;
  bool _productsLoaded = false;
  bool _supplierValidationError = false;

  bool get _isTransfer =>
      _selectedMovementType?.code == 'TRANSFER';
  bool get _isWithCosts =>
      _selectedMovementType?.code == 'WITH_COSTS';

  final List<_AcquisitionCostRow> _acquisitionCostRows = [];
  String _costDistributionMethod = 'by_value'; // by_value, by_quantity, by_weight, manual

  List<Product> get _productsForRows =>
      _isTransfer && _selectedSourceWarehouse != null
          ? _products
              .where((p) => p.warehouseId == _selectedSourceWarehouse!.id)
              .toList()
          : _products;
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
    List<ReceiptAcquisitionCost> acquisitionCostsList = [];
    if (receipt?.movementTypeCode == 'WITH_COSTS') {
      acquisitionCostsList = await _receiptService.getReceiptAcquisitionCosts(id);
    }
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
    Warehouse? matchedSourceWarehouse;
    if (receipt?.sourceWarehouseId != null) {
      for (final w in warehouses) {
        if (w.id == receipt!.sourceWarehouseId) {
          matchedSourceWarehouse = w;
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
      _warehouses = warehouses;
      _movementTypes = movementTypes;
      _editReceipt = receipt;
      if (receipt != null) {
        _selectedSupplier = matchedSupplier;
        _selectedWarehouse = matchedWarehouse;
        _selectedSourceWarehouse = matchedSourceWarehouse;
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
        if (receipt.movementTypeCode == 'WITH_COSTS') {
          _costDistributionMethod = receipt.costDistributionMethod ?? 'by_value';
          _acquisitionCostRows.clear();
          for (final c in acquisitionCostsList) {
            final cr = _AcquisitionCostRow(costType: c.costType);
            cr.descriptionController.text = c.description ?? '';
            cr.amountWithoutVatController.text = c.amountWithoutVat.toStringAsFixed(2);
            cr.vatPercentController.text = c.vatPercent.toString();
            cr.costSupplierController.text = c.costSupplierName ?? '';
            cr.documentNumberController.text = c.documentNumber ?? '';
            _acquisitionCostRows.add(cr);
          }
          if (_acquisitionCostRows.isEmpty) _acquisitionCostRows.add(_AcquisitionCostRow());
        }
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
        if (item.allocatedCost > 0) {
          row.manualAllocatedCostController.text = item.allocatedCost.toStringAsFixed(2);
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
      _rows[index].manualAllocatedCostController.dispose();
      _rows.removeAt(index);
    });
  }

  static const List<String> _costTypes = ['Doprava', 'Clo', 'Balné', 'Poistenie', 'Iné'];

  void _addAcquisitionCostRow() {
    setState(() => _acquisitionCostRows.add(_AcquisitionCostRow()));
  }

  void _removeAcquisitionCostRow(int index) {
    if (_acquisitionCostRows.length <= 1) return;
    setState(() {
      final r = _acquisitionCostRows[index];
      r.descriptionController.dispose();
      r.amountWithoutVatController.dispose();
      r.vatPercentController.dispose();
      r.costSupplierController.dispose();
      r.documentNumberController.dispose();
      _acquisitionCostRows.removeAt(index);
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
    final allocations = _isWithCosts && _acquisitionCostRows.isNotEmpty
        ? _computeAllocatedCostPerItem()
        : <double>[];
    var allocationIndex = 0;
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
      final allocatedCost = allocationIndex < allocations.length
          ? _roundPrice(allocations[allocationIndex++])
          : 0.0;

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
          allocatedCost: allocatedCost,
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
    if (_isTransfer && _selectedSourceWarehouse == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vyberte zdrojový sklad')),
      );
      return;
    }
    if (!_isTransfer && _selectedSupplier == null) {
      setState(() => _supplierValidationError = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vyberte dodávateľa')),
      );
      return;
    }
    setState(() {
      _supplierValidationError = false;
      _isSaving = true;
    });
    try {
      final vatRate = _vatAppliesToAll
          ? int.tryParse(_vatRateController.text.trim())
          : null;
      final supplierName = _isTransfer ? null : _selectedSupplier?.name;
      final invoice = _isTransfer
          ? null
          : (_invoiceController.text.trim().isEmpty
              ? null
              : _invoiceController.text.trim());
      final notesText = _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim();
      var receiptNumber = _receiptNumberController.text.trim();
      if (receiptNumber.isEmpty) {
        receiptNumber = await _db.getNextReceiptNumber();
        if (mounted) _receiptNumberController.text = receiptNumber;
      }
      final warehouseId = _selectedWarehouse?.id;
      final sourceWarehouseId = _isTransfer ? _selectedSourceWarehouse?.id : null;
      final movementTypeCode = _selectedMovementType?.code ?? 'STANDARD';

      if (_isEditMode && _editReceipt != null) {
        List<ReceiptAcquisitionCost>? draftEditCosts;
        if (_isWithCosts && _acquisitionCostRows.isNotEmpty) {
          draftEditCosts = [];
          for (final r in _acquisitionCostRows) {
            final without = double.tryParse(r.amountWithoutVatController.text.trim().replaceAll(',', '.')) ?? 0;
            if (without <= 0) continue;
            final vat = int.tryParse(r.vatPercentController.text.trim()) ?? 0;
            draftEditCosts.add(ReceiptAcquisitionCost(
              receiptId: _editReceipt!.id!,
              costType: r.costType,
              description: r.descriptionController.text.trim().isEmpty ? null : r.descriptionController.text.trim(),
              amountWithoutVat: without,
              vatPercent: vat,
              amountWithVat: _receiptService.calculateWithVat(without, vat),
              costSupplierName: r.costSupplierController.text.trim().isEmpty ? null : r.costSupplierController.text.trim(),
              documentNumber: r.documentNumberController.text.trim().isEmpty ? null : r.documentNumberController.text.trim(),
            ));
          }
        }
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
          sourceWarehouseId: sourceWarehouseId,
          movementTypeCode: movementTypeCode,
          isSettled: _isSettled,
          costDistributionMethod: _isWithCosts ? _costDistributionMethod : _editReceipt!.costDistributionMethod,
        );
        await _receiptService.updateReceipt(receipt: receipt, items: items, acquisitionCosts: draftEditCosts);
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
        List<ReceiptAcquisitionCost>? draftCosts;
        if (_isWithCosts && _acquisitionCostRows.isNotEmpty) {
          draftCosts = [];
          for (final r in _acquisitionCostRows) {
            final without = double.tryParse(r.amountWithoutVatController.text.trim().replaceAll(',', '.')) ?? 0;
            if (without <= 0) continue;
            final vat = int.tryParse(r.vatPercentController.text.trim()) ?? 0;
            draftCosts.add(ReceiptAcquisitionCost(
              receiptId: 0,
              costType: r.costType,
              description: r.descriptionController.text.trim().isEmpty ? null : r.descriptionController.text.trim(),
              amountWithoutVat: without,
              vatPercent: vat,
              amountWithVat: _receiptService.calculateWithVat(without, vat),
              costSupplierName: r.costSupplierController.text.trim().isEmpty ? null : r.costSupplierController.text.trim(),
              documentNumber: r.documentNumberController.text.trim().isEmpty ? null : r.documentNumberController.text.trim(),
            ));
          }
        }
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
          sourceWarehouseId: sourceWarehouseId,
          movementTypeCode: movementTypeCode,
          isSettled: _isSettled,
          costDistributionMethod: _isWithCosts ? _costDistributionMethod : null,
        );
        await _receiptService.createReceipt(
          receipt: receipt,
          items: items,
          acquisitionCosts: draftCosts,
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
    if (_isTransfer) {
      if (_selectedSourceWarehouse == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vyberte zdrojový sklad')),
        );
        return;
      }
      if (_selectedSourceWarehouse!.id == _selectedWarehouse!.id) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zdrojový a cieľový sklad musia byť rôzne')),
        );
        return;
      }
    } else {
      if (_selectedSupplier == null) {
        setState(() => _supplierValidationError = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vyberte dodávateľa')),
        );
        return;
      }
      // Pri príjemke S DPH: ak nie je zaškrtnuté "Použiť DPH pre všetky položky", každá položka musí mať vyplnené DPH %
      if (_pricesIncludeVat && !_vatAppliesToAll) {
        for (var i = 0; i < _rows.length; i++) {
          final row = _rows[i];
          if (row.product == null) continue;
          final vatText = row.vatPercentController.text.trim();
          if (vatText.isEmpty || int.tryParse(vatText) == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Položka ${i + 1}: pri príjemke S DPH zadajte DPH % pre každú položku (alebo zaškrtnite "Použiť DPH pre všetky položky").',
                ),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
        }
      }
      if (_isWithCosts) {
        for (final r in _acquisitionCostRows) {
          final amt = double.tryParse(r.amountWithoutVatController.text.trim().replaceAll(',', '.'));
          if (amt != null && amt < 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Suma obstarávacieho nákladu nemôže byť záporná'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
          final hasContent = r.descriptionController.text.trim().isNotEmpty ||
              (r.amountWithoutVatController.text.trim().isNotEmpty) ||
              r.costSupplierController.text.trim().isNotEmpty ||
              r.documentNumberController.text.trim().isNotEmpty;
          if (hasContent && (amt == null || amt <= 0)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Zadajte sumu bez DPH > 0 pre pridaný obstarávací náklad'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
        }
      }
    }

    setState(() {
      _supplierValidationError = false;
      _isSaving = true;
    });
    try {
      final vatRate = _vatAppliesToAll
          ? int.tryParse(_vatRateController.text.trim())
          : null;
      final supplierName = _isTransfer ? null : _selectedSupplier?.name;
      final invoice = _isTransfer
          ? null
          : (_invoiceController.text.trim().isEmpty
              ? null
              : _invoiceController.text.trim());
      final notesText = _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim();
      final receiptNumber = _receiptNumberController.text.trim();
      final warehouseId = _selectedWarehouse?.id;
      final sourceWarehouseId = _isTransfer ? _selectedSourceWarehouse?.id : null;
      final movementTypeCode = _selectedMovementType?.code ?? 'STANDARD';

      if (_isEditMode && _editReceipt != null) {
        final status = _editReceipt!.isDraft
            ? InboundReceiptStatus.vykazana
            : _editReceipt!.status;
        List<ReceiptAcquisitionCost>? editAcquisitionCosts;
        if (_isWithCosts && _acquisitionCostRows.isNotEmpty) {
          editAcquisitionCosts = [];
          for (final r in _acquisitionCostRows) {
            final without = double.tryParse(r.amountWithoutVatController.text.trim().replaceAll(',', '.')) ?? 0;
            if (without <= 0) continue;
            final vat = int.tryParse(r.vatPercentController.text.trim()) ?? 0;
            editAcquisitionCosts.add(ReceiptAcquisitionCost(
              receiptId: _editReceipt!.id!,
              costType: r.costType,
              description: r.descriptionController.text.trim().isEmpty ? null : r.descriptionController.text.trim(),
              amountWithoutVat: without,
              vatPercent: vat,
              amountWithVat: _receiptService.calculateWithVat(without, vat),
              costSupplierName: r.costSupplierController.text.trim().isEmpty ? null : r.costSupplierController.text.trim(),
              documentNumber: r.documentNumberController.text.trim().isEmpty ? null : r.documentNumberController.text.trim(),
            ));
          }
        }
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
          sourceWarehouseId: sourceWarehouseId,
          movementTypeCode: movementTypeCode,
          isSettled: _isSettled,
          costDistributionMethod: _isWithCosts ? _costDistributionMethod : _editReceipt!.costDistributionMethod,
        );
        await _receiptService.updateReceipt(receipt: receipt, items: items, acquisitionCosts: editAcquisitionCosts);
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
        final costDistributionMethod = _isWithCosts ? _costDistributionMethod : null;
        List<ReceiptAcquisitionCost>? acquisitionCosts;
        if (_isWithCosts && _acquisitionCostRows.isNotEmpty) {
          acquisitionCosts = [];
          for (final r in _acquisitionCostRows) {
            final without = double.tryParse(r.amountWithoutVatController.text.trim().replaceAll(',', '.')) ?? 0;
            if (without <= 0) continue;
            final vat = int.tryParse(r.vatPercentController.text.trim()) ?? 0;
            final withVat = _receiptService.calculateWithVat(without, vat);
            acquisitionCosts.add(ReceiptAcquisitionCost(
              receiptId: 0,
              costType: r.costType,
              description: r.descriptionController.text.trim().isEmpty ? null : r.descriptionController.text.trim(),
              amountWithoutVat: without,
              vatPercent: vat,
              amountWithVat: withVat,
              costSupplierName: r.costSupplierController.text.trim().isEmpty ? null : r.costSupplierController.text.trim(),
              documentNumber: r.documentNumberController.text.trim().isEmpty ? null : r.documentNumberController.text.trim(),
            ));
          }
        }
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
          sourceWarehouseId: sourceWarehouseId,
          movementTypeCode: movementTypeCode,
          isSettled: _isSettled,
          costDistributionMethod: costDistributionMethod,
        );
        final receiptId = await _receiptService.createReceipt(
          receipt: receipt,
          items: items,
          acquisitionCosts: acquisitionCosts,
          isDraft: true,
        );
        if (mounted) {
          String? savedNumber;
          final savedReceipt = await _receiptService.getReceiptById(receiptId);
          if (savedReceipt != null) savedNumber = savedReceipt.receiptNumber;
          if (mounted) {
            Navigator.pop(context, true);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  savedNumber != null && savedNumber.isNotEmpty
                      ? 'Príjemka $savedNumber uložená ako rozpracovaná. Pre vykázanie ju otvorte a zvoľte „Vykázať príjem“.'
                      : 'Príjemka uložená ako rozpracovaná. Pre vykázanie ju otvorte a zvoľte „Vykázať príjem“.',
                  style: const TextStyle(fontSize: 14),
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
                              if (!_isTransfer) ...[
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
                          if (_isTransfer) ...[
                            const SizedBox(height: 8),
                            DropdownButtonFormField<Warehouse?>(
                              isExpanded: true,
                              value: _selectedSourceWarehouse,
                              decoration: const InputDecoration(
                                labelText: 'Zdrojový sklad *',
                                isDense: true,
                                contentPadding: _compactPadding,
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.warehouse_outlined, size: 20),
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('— Vyberte zdrojový sklad —'),
                                ),
                                ..._warehouses
                                    .where((w) => w.id != _selectedWarehouse?.id)
                                    .map(
                                  (w) => DropdownMenuItem(
                                    value: w,
                                    child: Text(
                                      w.name,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (w) => setState(() => _selectedSourceWarehouse = w),
                            ),
                          ],
                          const SizedBox(height: 8),
                          if (!_isTransfer)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<Supplier?>(
                                    isExpanded: true,
                                    value: _selectedSupplier,
                                    decoration: InputDecoration(
                                      labelText: 'Dodávateľ',
                                      isDense: true,
                                      contentPadding: _compactPadding,
                                      border: const OutlineInputBorder(),
                                      prefixIcon: const Icon(Icons.business, size: 20),
                                      errorText: _supplierValidationError
                                          ? 'Vyberte dodávateľa'
                                          : null,
                                      errorBorder: _supplierValidationError
                                          ? OutlineInputBorder(
                                              borderSide: const BorderSide(color: Colors.red),
                                              borderRadius: BorderRadius.circular(4),
                                            )
                                          : null,
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
                                      _supplierValidationError = false;
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
                            onChanged: (t) {
                              setState(() {
                                _selectedMovementType = t;
                                if (t?.code == 'TRANSFER') {
                                  _selectedSourceWarehouse = null;
                                  _pricesIncludeVat = false;
                                }
                                if (t?.code == 'WITH_COSTS' && _acquisitionCostRows.isEmpty) {
                                  _acquisitionCostRows.add(_AcquisitionCostRow());
                                }
                              });
                            },
                          ),
                          if (_isTransfer) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, size: 20, color: Colors.blue.shade700),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Tovar bude presunutý z vybraného zdrojového skladu do cieľového skladu.',
                                      style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
                          if (!_isTransfer) ...[
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
                          ],
                          if (_vatAppliesToAll && !_isTransfer) ...[
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
                if (_isWithCosts) ...[
                  const SizedBox(height: 12),
                  _buildAcquisitionCostsSection(),
                  const SizedBox(height: 12),
                  _buildCostSummarySection(),
                ],
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
    final withCosts = _isWithCosts;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: _borderColor),
        borderRadius: BorderRadius.circular(_radius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_radius),
        child: Table(
          columnWidths: withCosts
              ? const {
                  0: FlexColumnWidth(2),
                  1: FlexColumnWidth(0.7),
                  2: FlexColumnWidth(0.6),
                  3: FlexColumnWidth(0.9),
                  4: FlexColumnWidth(0.5),
                  5: FlexColumnWidth(0.9),
                  6: FlexColumnWidth(0.8),
                  7: FlexColumnWidth(0.7),
                  8: FlexColumnWidth(0.9),
                  9: FixedColumnWidth(52),
                }
              : const {
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
                if (withCosts) _tableHeader('Náklady'),
                if (withCosts) _tableHeader('Skutočná nákupná cena'),
                _tableHeader(''),
              ],
            ),
            ...List.generate(_rows.length, (i) => _buildTableRow(i)),
          ],
        ),
      ),
    );
  }

  Widget _buildAcquisitionCostsSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: _borderColor),
        borderRadius: BorderRadius.circular(_radius),
        color: const Color(0xFFF8FAFC),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Obstarávacie náklady',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: _addAcquisitionCostRow,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Pridať náklad', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _costDistributionMethod,
            decoration: const InputDecoration(
              labelText: 'Rozpočítanie nákladov',
              isDense: true,
              contentPadding: _compactPadding,
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'by_value', child: Text('Podľa hodnoty')),
              DropdownMenuItem(value: 'by_quantity', child: Text('Podľa množstva')),
              DropdownMenuItem(value: 'by_weight', child: Text('Podľa hmotnosti')),
              DropdownMenuItem(value: 'manual', child: Text('Manuálne')),
            ],
            onChanged: (v) => setState(() => _costDistributionMethod = v ?? 'by_value'),
          ),
          const SizedBox(height: 12),
          ...List.generate(_acquisitionCostRows.length, (i) => _buildAcquisitionCostRow(i)),
          const SizedBox(height: 8),
          Text(
            'Spolu obstarávacie náklady: ${_totalAcquisitionCostsWithVat().toStringAsFixed(2)} € (s DPH)',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildAcquisitionCostRow(int index) {
    final r = _acquisitionCostRows[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: DropdownButtonFormField<String>(
              value: r.costType,
              isExpanded: true,
              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
              items: _costTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12)))).toList(),
              onChanged: (v) => setState(() => r.costType = v ?? 'Iné'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: r.descriptionController,
              decoration: const InputDecoration(labelText: 'Popis', isDense: true),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: TextFormField(
              controller: r.amountWithoutVatController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Suma bez DPH', isDense: true),
              inputFormatters: [_DecimalInputFormatter()],
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 50,
            child: TextFormField(
              controller: r.vatPercentController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'DPH %', isDense: true),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Text(
                '${(_receiptService.calculateWithVat(double.tryParse(r.amountWithoutVatController.text.trim().replaceAll(',', '.')) ?? 0, int.tryParse(r.vatPercentController.text.trim()) ?? 0)).toStringAsFixed(2)} €',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: r.costSupplierController,
              decoration: const InputDecoration(labelText: 'Dodávateľ nákladu', isDense: true),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: TextFormField(
              controller: r.documentNumberController,
              decoration: const InputDecoration(labelText: 'Č. dokladu', isDense: true),
              onChanged: (_) => setState(() {}),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: _acquisitionCostRows.length > 1 ? () => _removeAcquisitionCostRow(index) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildCostSummarySection() {
    double goodsWithoutVat = 0;
    double goodsWithVat = 0;
    for (final row in _rows) {
      if (row.product == null) continue;
      final qty = int.tryParse(row.qtyController.text.trim()) ?? 0;
      if (qty <= 0) continue;
      final priceWithout = double.tryParse(row.unitPriceWithoutVatController.text.trim().replaceAll(',', '.')) ?? 0;
      final vat = _effectiveVatForRow(row);
      goodsWithoutVat += qty * priceWithout;
      goodsWithVat += qty * _receiptService.calculateWithVat(priceWithout, vat);
    }
    goodsWithoutVat = _roundPrice(goodsWithoutVat);
    goodsWithVat = _roundPrice(goodsWithVat);
    final costsWithoutVat = _totalAcquisitionCostsWithoutVat();
    final costsWithVat = _totalAcquisitionCostsWithVat();
    final totalVat = _roundPrice((goodsWithVat - goodsWithoutVat) + (costsWithVat - costsWithoutVat));
    final grandTotal = _roundPrice(goodsWithVat + costsWithVat);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: _borderColor),
        borderRadius: BorderRadius.circular(_radius),
        color: const Color(0xFFF0FDF4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Zhrnutie', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          _summaryRow('Suma tovaru bez DPH', '${goodsWithoutVat.toStringAsFixed(2)} €'),
          _summaryRow('Suma obstarávacích nákladov bez DPH', '${costsWithoutVat.toStringAsFixed(2)} €'),
          _summaryRow('Celková DPH', '${totalVat.toStringAsFixed(2)} €'),
          _summaryRow('Celková suma s DPH', '${grandTotal.toStringAsFixed(2)} €', bold: true),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.w600 : null)),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.w600 : null)),
        ],
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

  /// Suma riadku s DPH (pre rozpočítanie obstarávacích nákladov podľa hodnoty).
  double _rowTotalWithVat(_ReceiptItemRow row) {
    if (row.product == null) return 0;
    final qty = int.tryParse(row.qtyController.text.trim()) ?? 0;
    if (qty <= 0) return 0;
    final priceWithVat = double.tryParse(
      row.unitPriceWithVatController.text.trim().replaceAll(',', '.'),
    ) ?? 0;
    return _roundPrice(qty * priceWithVat);
  }

  /// Celková suma obstarávacích nákladov s DPH.
  double _totalAcquisitionCostsWithVat() {
    double sum = 0;
    for (final r in _acquisitionCostRows) {
      final without = double.tryParse(r.amountWithoutVatController.text.trim().replaceAll(',', '.')) ?? 0;
      final vat = int.tryParse(r.vatPercentController.text.trim()) ?? 0;
      sum += _receiptService.calculateWithVat(without, vat);
    }
    return _roundPrice(sum);
  }

  /// Celková suma obstarávacích nákladov bez DPH.
  double _totalAcquisitionCostsWithoutVat() {
    double sum = 0;
    for (final r in _acquisitionCostRows) {
      sum += double.tryParse(r.amountWithoutVatController.text.trim().replaceAll(',', '.')) ?? 0;
    }
    return _roundPrice(sum);
  }

  /// Vráti zoznam alokovaných súm (s DPH) pre každý platný riadok položky (v poradí _rows).
  List<double> _computeAllocatedCostPerItem() {
    final validRows = <int>[];
    final weights = <double>[];
    final manualAmounts = <double>[];
    for (var i = 0; i < _rows.length; i++) {
      final row = _rows[i];
      if (row.product == null) continue;
      final qty = int.tryParse(row.qtyController.text.trim()) ?? 0;
      if (qty <= 0) continue;
      validRows.add(i);
      if (_costDistributionMethod == 'manual') {
        manualAmounts.add(
          double.tryParse(row.manualAllocatedCostController.text.trim().replaceAll(',', '.')) ?? 0,
        );
      } else if (_costDistributionMethod == 'by_value') {
        weights.add(_rowTotalWithVat(row));
      } else {
        weights.add(qty.toDouble()); // by_quantity, by_weight (fallback)
      }
    }
    final totalCost = _totalAcquisitionCostsWithVat();
    if (totalCost <= 0 || validRows.isEmpty) {
      return List.filled(validRows.length, 0.0);
    }
    if (_costDistributionMethod == 'manual') {
      return manualAmounts;
    }
    final totalWeight = weights.fold<double>(0, (a, b) => a + b);
    if (totalWeight <= 0) return List.filled(validRows.length, 0.0);
    final allocated = weights.map((w) => _roundPrice(totalCost * (w / totalWeight))).toList();
    // Korekcia zaokrúhlení: posledný = totalCost - sum(ostatných)
    final sumAlloc = allocated.fold<double>(0, (a, b) => a + b);
    if (allocated.isNotEmpty && (sumAlloc - totalCost).abs() > 0.00001) {
      allocated[allocated.length - 1] = _roundPrice(totalCost - (sumAlloc - allocated.last));
    }
    return allocated;
  }

  /// Alokovaná suma pre riadok (index) – pre zobrazenie v tabuľke. Pri manuále sa berie z poľa.
  double _getAllocatedCostForRow(int rowIndex) {
    if (!_isWithCosts) return 0;
    final validIndices = <int>[];
    for (var i = 0; i < _rows.length; i++) {
      if (_rows[i].product != null &&
          (int.tryParse(_rows[i].qtyController.text.trim()) ?? 0) > 0) {
        validIndices.add(i);
      }
    }
    final alloc = _computeAllocatedCostPerItem();
    final idx = validIndices.indexOf(rowIndex);
    if (idx < 0 || idx >= alloc.length) return 0;
    return alloc[idx];
  }

  /// Skutočná nákupná cena na jednotku (s DPH) pre riadok = (cena*Q + alokovaný náklad) / Q.
  double _getTrueUnitPriceWithVatForRow(int rowIndex) {
    final row = _rows[rowIndex];
    if (row.product == null) return 0;
    final qty = int.tryParse(row.qtyController.text.trim()) ?? 0;
    if (qty <= 0) return 0;
    final priceWithVat = double.tryParse(
      row.unitPriceWithVatController.text.trim().replaceAll(',', '.'),
    ) ?? 0;
    final alloc = _getAllocatedCostForRow(rowIndex);
    return _roundPrice((priceWithVat * qty + alloc) / qty);
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
                    ..._productsForRows.map(
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
            child: Builder(
              builder: (_) {
                if (!hasProduct) return const Text('—', style: TextStyle(fontSize: 12, color: Color(0xFF64748B)));
                if (_selectedWarehouse == null) return const Text('—', style: TextStyle(fontSize: 12, color: Color(0xFF64748B)));
                final inWarehouse = _products.where((p) =>
                    p.warehouseId == _selectedWarehouse!.id && p.plu == row.product!.plu).toList();
                final qty = inWarehouse.isNotEmpty ? inWarehouse.first.qty : 0;
                return Text(
                  '$qty ${row.unit}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                );
              },
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
        if (_isWithCosts)
          Padding(
            padding: _compactPaddingTiny,
            child: Center(
              child: _costDistributionMethod == 'manual'
                  ? TextFormField(
                      controller: row.manualAllocatedCostController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                      inputFormatters: [_DecimalInputFormatter()],
                    )
                  : Text(
                      '${_getAllocatedCostForRow(index).toStringAsFixed(2)} €',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
            ),
          ),
        if (_isWithCosts)
          Padding(
            padding: _compactPaddingTiny,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF22C55E), width: 1),
              ),
              child: Center(
                child: Text(
                  hasProduct && (int.tryParse(row.qtyController.text.trim()) ?? 0) > 0
                      ? '${_getTrueUnitPriceWithVatForRow(index).toStringAsFixed(2)} €'
                      : '—',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF166534),
                  ),
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
