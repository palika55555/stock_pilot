import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/product.dart';
import '../../models/receipt.dart';
import '../../models/supplier.dart';
import '../../models/warehouse.dart';
import '../../theme/app_theme.dart';
import '../../services/Product/product_service.dart';
import '../../services/Receipt/receipt_service.dart';
import '../../services/Warehouse/warehouse_service.dart';
import '../../services/Database/database_service.dart';
import '../../services/Supplier/supplier_service.dart';
import '../products/add_product_modal_widget.dart';
import '../suppliers/add_supplier_modal_widget.dart';

/// Input formatter: digits and one decimal separator ("," or "."), max 5 decimals.
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
    final match = RegExp(r'^\d*(?:[.,]\d{0,5})?$').firstMatch(text);
    if (match == null) return oldValue;
    return newValue;
  }
}

double? _tryParseDecimal(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return null;
  return double.tryParse(t.replaceAll(',', '.'));
}

bool _isWholeNumber(double v) => v == v.roundToDouble();

String _formatQtyForInput(double qty) {
  if (_isWholeNumber(qty)) return qty.toInt().toString();
  return qty.toString().replaceAll('.', ',');
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
  /// Číslo šarže / lot číslo.
  final TextEditingController batchController = TextEditingController();
  /// Dátum expirácie (zobrazovaný formát DD.MM.YYYY, ukladaný ako YYYY-MM-DD).
  final TextEditingController expiryController = TextEditingController();
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
  final TextEditingController _deliveryNoteController = TextEditingController();
  final TextEditingController _poNumberController = TextEditingController();

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
        _deliveryNoteController.text = receipt.deliveryNoteNumber ?? '';
        _poNumberController.text = receipt.poNumber ?? '';
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
        row.qtyController.text = _formatQtyForInput(item.qty);

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
        if (item.batchNumber != null && item.batchNumber!.isNotEmpty) {
          row.batchController.text = item.batchNumber!;
        }
        if (item.expiryDate != null && item.expiryDate!.isNotEmpty) {
          row.expiryController.text = _isoToDisplay(item.expiryDate!);
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
      _rows[index].batchController.dispose();
      _rows[index].expiryController.dispose();
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
      final qty = _tryParseDecimal(row.qtyController.text) ?? 0.0;
      if (qty <= 0) {
        if (!allowEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Riadok ${i + 1}: zadajte platné množstvo')),
          );
          return null;
        }
        continue;
      }
      if (row.product?.ibaCeleMnozstva == true && !_isWholeNumber(qty)) {
        if (!allowEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Riadok ${i + 1}: množstvo musí byť celé číslo')),
          );
          return null;
        }
        continue;
      }
      final priceWithoutVat = _tryParseDecimal(row.unitPriceWithoutVatController.text);
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

      final batchText = row.batchController.text.trim();
      final expiryText = row.expiryController.text.trim();
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
          batchNumber: batchText.isNotEmpty ? batchText : null,
          expiryDate: expiryText.isNotEmpty ? _displayToIso(expiryText) : null,
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
      final (supplierId, supplierIco, supplierDic, supplierAddress) = _isTransfer ? (null, null, null, null) : _supplierSnapshot();
      final deliveryNoteNumber = _textOrNull(_deliveryNoteController);
      final poNumber = _textOrNull(_poNumberController);
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
          supplierId: supplierId,
          supplierIco: supplierIco,
          supplierDic: supplierDic,
          supplierAddress: supplierAddress,
          deliveryNoteNumber: deliveryNoteNumber,
          poNumber: poNumber,
        );
        await _receiptService.updateReceipt(receipt: receipt, items: items, acquisitionCosts: draftEditCosts);
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Príjemka uložená ako rozpracovaná'),
              backgroundColor: AppColors.success,
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
          supplierId: supplierId,
          supplierIco: supplierIco,
          supplierDic: supplierDic,
          supplierAddress: supplierAddress,
          deliveryNoteNumber: deliveryNoteNumber,
          poNumber: poNumber,
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
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba: $e'), backgroundColor: AppColors.danger),
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
                backgroundColor: AppColors.danger,
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
                backgroundColor: AppColors.danger,
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
                backgroundColor: AppColors.danger,
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
      final (supplierId, supplierIco, supplierDic, supplierAddress) = _isTransfer ? (null, null, null, null) : _supplierSnapshot();
      final deliveryNoteNumber = _textOrNull(_deliveryNoteController);
      final poNumber = _textOrNull(_poNumberController);
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
          supplierId: supplierId,
          supplierIco: supplierIco,
          supplierDic: supplierDic,
          supplierAddress: supplierAddress,
          deliveryNoteNumber: deliveryNoteNumber,
          poNumber: poNumber,
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
              backgroundColor: AppColors.success,
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
          supplierId: supplierId,
          supplierIco: supplierIco,
          supplierDic: supplierDic,
          supplierAddress: supplierAddress,
          deliveryNoteNumber: deliveryNoteNumber,
          poNumber: poNumber,
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
                backgroundColor: AppColors.success,
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
            backgroundColor: AppColors.danger,
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
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
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
            backgroundColor: AppColors.warning,
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Príjemku nebolo možné odstrániť (napr. už je schválená)'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba: $e'), backgroundColor: AppColors.danger),
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
    _deliveryNoteController.dispose();
    _poNumberController.dispose();
    for (final row in _rows) {
      row.qtyController.dispose();
      row.unitPriceWithoutVatController.dispose();
      row.unitPriceWithVatController.dispose();
      row.vatPercentController.dispose();
      row.batchController.dispose();
      row.expiryController.dispose();
    }
    super.dispose();
  }

  static const _compactPadding = EdgeInsets.symmetric(horizontal: 10, vertical: 6);
  static const _compactPaddingTiny = EdgeInsets.symmetric(horizontal: 6, vertical: 4);

  /// Zostaví kombinovanú adresu dodávateľa z jednotlivých polí.
  static String? _buildSupplierAddress(Supplier s) {
    final parts = [s.address, s.city, s.postalCode].where((p) => p != null && p.isNotEmpty).join(', ');
    return parts.isEmpty ? null : parts;
  }

  /// Helper: vytvorí snapshot identifikáciu dodávateľa zo súčasne vybraného _selectedSupplier.
  (int?, String?, String?, String?) _supplierSnapshot() {
    final s = _selectedSupplier;
    if (s == null) return (null, null, null, null);
    return (s.id, s.ico.isNotEmpty ? s.ico : null, s.dic, _buildSupplierAddress(s));
  }

  /// Helper: bezpečne získa textovú hodnotu z controllera (null ak prázdne).
  static String? _textOrNull(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  /// Konvertuje ISO dátum "YYYY-MM-DD" na zobrazovaný formát "DD.MM.YYYY".
  static String _isoToDisplay(String iso) {
    final parts = iso.split('-');
    if (parts.length == 3) return '${parts[2]}.${parts[1]}.${parts[0]}';
    return iso;
  }

  /// Konvertuje zobrazovaný formát "DD.MM.YYYY" na ISO "YYYY-MM-DD".
  static String? _displayToIso(String display) {
    final parts = display.split('.');
    if (parts.length == 3 && parts[2].length == 4) {
      return '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
    }
    return null;
  }

  /// Otvorí date picker a nastaví hodnotu do expiryController.
  Future<void> _pickExpiryDate(TextEditingController controller) async {
    DateTime initial = DateTime.now().add(const Duration(days: 365));
    final current = controller.text.trim();
    if (current.isNotEmpty) {
      final iso = _displayToIso(current);
      if (iso != null) {
        final parsed = DateTime.tryParse(iso);
        if (parsed != null) initial = parsed;
      }
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      final display = '${picked.day.toString().padLeft(2, '0')}.${picked.month.toString().padLeft(2, '0')}.${picked.year}';
      setState(() => controller.text = display);
    }
  }

  /// Vráti farbu / ikonu pre expiry date: červená ak expirované, oranžová ak do 30 dní, inak null.
  Color? _expiryWarningColor(String displayDate) {
    final iso = _displayToIso(displayDate);
    if (iso == null) return null;
    final date = DateTime.tryParse(iso);
    if (date == null) return null;
    final now = DateTime.now();
    if (date.isBefore(now)) return AppColors.danger;
    if (date.difference(now).inDays <= 30) return Colors.orange;
    return null;
  }

  // -------------------------------------------------------------------------
  // Styling helpers
  // -------------------------------------------------------------------------

  InputDecoration _styledInputDecoration(String label, {Widget? prefixIcon}) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AppColors.bgInput,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(_radius)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: const BorderSide(color: AppColors.borderDefault),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: const BorderSide(color: AppColors.accentGold, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      prefixIcon: prefixIcon,
    );
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    return Dialog(
      backgroundColor: AppColors.bgElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 1100, maxHeight: screenH * 0.88),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogHeader(),
              const Divider(height: 1, thickness: 1, color: AppColors.borderDefault),
              Flexible(
                child: SizedBox(
                  height: screenH * 0.76,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 320,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: _buildFormPanel(),
                        ),
                      ),
                      const VerticalDivider(
                          width: 1, thickness: 1, color: AppColors.borderDefault),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildItemsHeader(),
                            const Divider(
                                height: 1, thickness: 1, color: AppColors.borderDefault),
                            Expanded(
                              child: _productsLoaded
                                  ? SingleChildScrollView(
                                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          _buildItemsTable(),
                                          if (_isWithCosts) ...[
                                            const SizedBox(height: 12),
                                            _buildAcquisitionCostsSection(),
                                            const SizedBox(height: 12),
                                            _buildCostSummarySection(),
                                          ],
                                        ],
                                      ),
                                    )
                                  : const Center(child: CircularProgressIndicator()),
                            ),
                            const Divider(
                                height: 1, thickness: 1, color: AppColors.borderDefault),
                            _buildBottomBar(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialogHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.successSubtle,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.south_west_rounded,
                color: AppColors.success, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _isEditMode ? 'Upraviť príjemku' : 'Nový príjem tovaru',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Zavrieť',
            style: IconButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              backgroundColor: AppColors.bgInput,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Číslo príjemky
        TextFormField(
          controller: _receiptNumberController,
          readOnly: !_manualReceiptNumber && !_isEditMode,
          decoration: _styledInputDecoration('Číslo príjemky',
                  prefixIcon: const Icon(Icons.tag,
                      size: 20, color: AppColors.textMuted))
              .copyWith(
            suffixIcon: _isEditMode
                ? null
                : IconButton(
                    icon: Icon(
                      _manualReceiptNumber
                          ? Icons.auto_fix_high
                          : Icons.edit_rounded,
                      color: AppColors.accentGold,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _manualReceiptNumber = !_manualReceiptNumber;
                        if (!_manualReceiptNumber) _generateNextReceiptNumber();
                      });
                    },
                  ),
          ),
        ),
        if (!_isTransfer) ...[
          const SizedBox(height: 10),
          TextFormField(
            controller: _invoiceController,
            decoration: _styledInputDecoration('Číslo faktúry',
                prefixIcon: const Icon(Icons.description,
                    size: 20, color: AppColors.textMuted)),
          ),
        ],
        const SizedBox(height: 10),
        // Druh pohybu
        DropdownButtonFormField<ReceiptMovementType?>(
          isExpanded: true,
          value: _selectedMovementType,
          decoration: _styledInputDecoration('Druh pohybu',
              prefixIcon: const Icon(Icons.swap_horiz,
                  size: 20, color: AppColors.textMuted)),
          dropdownColor: AppColors.bgInput,
          borderRadius: BorderRadius.circular(_radius),
          items: _movementTypes
              .map((t) => DropdownMenuItem(
                    value: t,
                    child: Text(t.name, overflow: TextOverflow.ellipsis),
                  ))
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
              color: AppColors.infoSubtle,
              borderRadius: BorderRadius.circular(_radius),
              border: Border.all(color: AppColors.info.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: AppColors.info),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tovar bude presunutý z vybraného zdrojového skladu do cieľového skladu.',
                    style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        // Cieľový sklad
        DropdownButtonFormField<Warehouse?>(
          isExpanded: true,
          value: _selectedWarehouse,
          decoration: _styledInputDecoration(
              _isTransfer ? 'Cieľový sklad *' : 'Sklad *',
              prefixIcon: const Icon(Icons.warehouse_outlined,
                  size: 20, color: AppColors.textMuted)),
          dropdownColor: AppColors.bgInput,
          borderRadius: BorderRadius.circular(_radius),
          items: [
            const DropdownMenuItem(
                value: null, child: Text('— Vyberte sklad —')),
            ..._warehouses.map((w) => DropdownMenuItem(
                  value: w,
                  child: Text(w.name, overflow: TextOverflow.ellipsis),
                )),
          ],
          onChanged: (w) => setState(() => _selectedWarehouse = w),
        ),
        if (_isTransfer) ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<Warehouse?>(
            isExpanded: true,
            value: _selectedSourceWarehouse,
            decoration: _styledInputDecoration('Zdrojový sklad *',
                prefixIcon: const Icon(Icons.warehouse_outlined,
                    size: 20, color: AppColors.textMuted)),
            dropdownColor: AppColors.bgInput,
            borderRadius: BorderRadius.circular(_radius),
            items: [
              const DropdownMenuItem(
                  value: null,
                  child: Text('— Vyberte zdrojový sklad —')),
              ..._warehouses
                  .where((w) => w.id != _selectedWarehouse?.id)
                  .map((w) => DropdownMenuItem(
                        value: w,
                        child: Text(w.name, overflow: TextOverflow.ellipsis),
                      )),
            ],
            onChanged: (w) => setState(() => _selectedSourceWarehouse = w),
          ),
        ],
        if (!_isTransfer) ...[
          const SizedBox(height: 10),
          // Dodávateľ
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DropdownButtonFormField<Supplier?>(
                  isExpanded: true,
                  value: _selectedSupplier,
                  decoration: _styledInputDecoration('Dodávateľ *',
                          prefixIcon: const Icon(Icons.business_outlined,
                              size: 20, color: AppColors.textMuted))
                      .copyWith(
                    errorText:
                        _supplierValidationError ? 'Vyberte dodávateľa' : null,
                  ),
                  dropdownColor: AppColors.bgInput,
                  borderRadius: BorderRadius.circular(_radius),
                  items: [
                    const DropdownMenuItem(
                        value: null,
                        child: Text('— Vyberte dodávateľa —')),
                    ..._suppliers.map((s) => DropdownMenuItem(
                          value: s,
                          child: Text('${s.name} (IČO ${s.ico})',
                              overflow: TextOverflow.ellipsis),
                        )),
                  ],
                  onChanged: (s) {
                    setState(() {
                      _selectedSupplier = s;
                      _supplierValidationError = false;
                      if (s != null) {
                        _vatRateController.text = s.defaultVatRate.toString();
                        _vatAppliesToAll = true;
                        _updateAllRowPrices();
                      }
                    });
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline,
                    color: AppColors.accentGold, size: 22),
                tooltip: 'Pridať dodávateľa',
                onPressed: () async {
                  final result = await showModalBottomSheet<Supplier>(
                    context: context,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (ctx) => const AddSupplierModal(),
                  );
                  if (!mounted) return;
                  await _loadSuppliers();
                  if (result != null && mounted)
                    setState(() {
                      final match =
                          _suppliers.where((s) => s.id == result.id);
                      _selectedSupplier =
                          match.isEmpty ? result : match.first;
                      _vatRateController.text =
                          result.defaultVatRate.toString();
                      _vatAppliesToAll = true;
                      _updateAllRowPrices();
                    });
                },
              ),
            ],
          ),
          if (_selectedSupplier != null) ...[
            const SizedBox(height: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.bgInput,
                borderRadius: BorderRadius.circular(_radius),
                border: Border.all(color: AppColors.borderDefault),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      [
                        if (_selectedSupplier!.ico.isNotEmpty)
                          'IČO: ${_selectedSupplier!.ico}',
                        if (_selectedSupplier!.dic != null &&
                            _selectedSupplier!.dic!.isNotEmpty)
                          'DIČ: ${_selectedSupplier!.dic}',
                        if (_selectedSupplier!.address != null &&
                            _selectedSupplier!.address!.isNotEmpty)
                          _selectedSupplier!.address!,
                      ].join('  •  '),
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
        const SizedBox(height: 10),
        // Dodací list + objednávka
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _deliveryNoteController,
                decoration: _styledInputDecoration('Č. dodacieho listu',
                    prefixIcon: const Icon(Icons.receipt_long_outlined,
                        size: 18, color: AppColors.textMuted)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _poNumberController,
                decoration: _styledInputDecoration('Č. objednávky (PO)',
                    prefixIcon: const Icon(Icons.shopping_cart_outlined,
                        size: 18, color: AppColors.textMuted)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _notesController,
          maxLines: 2,
          decoration: _styledInputDecoration('Poznámka',
              prefixIcon: const Icon(Icons.note_outlined,
                  size: 20, color: AppColors.textMuted)),
        ),
        const SizedBox(height: 4),
        // Vysporiadané
        Material(
          color: Colors.transparent,
          child: CheckboxListTile(
            value: _isSettled,
            onChanged: (v) => setState(() => _isSettled = v ?? false),
            title: const Text('Vysporiadané',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary)),
            subtitle: const Text(
                'Daňový doklad zaevidovaný alebo sa neočakáva',
                style: TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.accentGold,
            dense: true,
          ),
        ),
        // DPH nastavenia (len pre normálny príjem, nie presun)
        if (!_isTransfer) ...[
          const SizedBox(height: 4),
          const Text('Typ príjemky',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          Row(
            children: [
              Expanded(
                child: RadioListTile<bool>(
                  title: const Text('S DPH', style: TextStyle(fontSize: 13)),
                  value: true,
                  groupValue: _pricesIncludeVat,
                  onChanged: (v) => setState(() => _pricesIncludeVat = true),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.accentGold,
                ),
              ),
              Expanded(
                child: RadioListTile<bool>(
                  title: const Text('Bez DPH', style: TextStyle(fontSize: 13)),
                  value: false,
                  groupValue: _pricesIncludeVat,
                  onChanged: (v) => setState(() => _pricesIncludeVat = false),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.accentGold,
                ),
              ),
            ],
          ),
          Material(
            color: Colors.transparent,
            child: CheckboxListTile(
              title: const Text('Použiť DPH pre všetky položky',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary)),
              value: _vatAppliesToAll,
              onChanged: (v) {
                setState(() => _vatAppliesToAll = v ?? false);
                _updateAllRowPrices();
              },
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              activeColor: AppColors.accentGold,
              dense: true,
            ),
          ),
          if (_vatAppliesToAll) ...[
            const SizedBox(height: 4),
            SizedBox(
              width: 90,
              child: TextFormField(
                controller: _vatRateController,
                keyboardType: TextInputType.number,
                decoration: _styledInputDecoration('DPH %'),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
          ],
        ],
        // Rozpočítanie nákladov (len pre WITH_COSTS)
        if (_isWithCosts) ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _costDistributionMethod,
            decoration: _styledInputDecoration('Rozpočítanie nákladov',
                prefixIcon: const Icon(Icons.calculate_outlined,
                    size: 20, color: AppColors.textMuted)),
            dropdownColor: AppColors.bgInput,
            borderRadius: BorderRadius.circular(_radius),
            items: const [
              DropdownMenuItem(value: 'by_value', child: Text('Podľa hodnoty')),
              DropdownMenuItem(
                  value: 'by_quantity', child: Text('Podľa množstva')),
              DropdownMenuItem(
                  value: 'by_weight', child: Text('Podľa hmotnosti')),
              DropdownMenuItem(value: 'manual', child: Text('Manuálne')),
            ],
            onChanged: (v) =>
                setState(() => _costDistributionMethod = v ?? 'by_value'),
          ),
        ],
      ],
    );
  }

  Widget _buildItemsHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.list_alt_rounded,
              size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          const Text('Položky',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const Spacer(),
          FilledButton.icon(
            onPressed: _addRow,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Pridať', style: TextStyle(fontSize: 12)),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentGold,
              foregroundColor: AppColors.bgPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  double get _goodsWithoutVat {
    double sum = 0;
    for (final row in _rows) {
      if (row.product == null) continue;
      final qty = _tryParseDecimal(row.qtyController.text) ?? 0;
      final price =
          _tryParseDecimal(row.unitPriceWithoutVatController.text) ?? 0;
      sum += qty * price;
    }
    return _roundPrice(sum);
  }

  double get _goodsWithVat {
    double sum = 0;
    for (final row in _rows) {
      if (row.product == null) continue;
      final qty = _tryParseDecimal(row.qtyController.text) ?? 0;
      final price =
          _tryParseDecimal(row.unitPriceWithVatController.text) ?? 0;
      sum += qty * price;
    }
    return _roundPrice(sum);
  }

  Widget _buildBottomBar() {
    final withoutVat = _goodsWithoutVat;
    final withVat = _goodsWithVat;
    final vatAmount = _roundPrice(withVat - withoutVat);
    final grandTotal = _isWithCosts
        ? _roundPrice(withVat + _totalAcquisitionCostsWithVat())
        : withVat;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.bgCard,
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                _miniSummaryItem('Základ', withoutVat),
                const SizedBox(width: 16),
                _miniSummaryItem('DPH', vatAmount),
                const SizedBox(width: 16),
                _miniSummaryItem(
                    _isWithCosts ? 'Celkom s nákladmi' : 'Celkom',
                    grandTotal,
                    highlight: true),
              ],
            ),
          ),
          const SizedBox(width: 16),
          if (_isEditMode &&
              _editReceipt != null &&
              !_editReceipt!.isApproved) ...[
            OutlinedButton.icon(
              onPressed: _isSaving ? null : _deleteReceipt,
              icon: const Icon(Icons.delete_outline_rounded, size: 16),
              label:
                  const Text('Odstrániť', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
              ),
            ),
            const SizedBox(width: 10),
          ],
          if (!_isEditMode || _editReceipt?.isDraft == true)
            OutlinedButton.icon(
              onPressed: _isSaving ? null : _saveDraft,
              icon: const Icon(Icons.save_outlined, size: 16),
              label: const Text('Rozpracovaný',
                  style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.borderDefault),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
              ),
            ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: _isSaving ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentGold,
              foregroundColor: AppColors.bgPrimary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: _isSaving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.bgPrimary))
                : Text(
                    _isEditMode && _editReceipt?.isDraft == true
                        ? 'Vykázať príjem'
                        : (_isEditMode ? 'Uložiť zmeny' : 'Uložiť príjem'),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _miniSummaryItem(String label, double value,
      {bool highlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 10, color: AppColors.textSecondary)),
        Text(
          '${value.toStringAsFixed(2)} €',
          style: TextStyle(
            fontSize: highlight ? 16 : 13,
            fontWeight: highlight ? FontWeight.bold : FontWeight.w600,
            color: highlight ? AppColors.accentGold : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }


  Widget _buildItemsTable() {
    final withCosts = _isWithCosts;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderDefault),
        borderRadius: BorderRadius.circular(_radius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_radius),
        child: Table(
          columnWidths: withCosts
              ? const {
                  0: FlexColumnWidth(2),
                  1: FlexColumnWidth(0.7),
                  2: FlexColumnWidth(0.8),
                  3: FlexColumnWidth(0.8),
                  4: FlexColumnWidth(0.6),
                  5: FlexColumnWidth(0.9),
                  6: FlexColumnWidth(0.5),
                  7: FlexColumnWidth(0.9),
                  8: FlexColumnWidth(0.8),
                  9: FlexColumnWidth(0.7),
                  10: FlexColumnWidth(0.9),
                  11: FixedColumnWidth(52),
                }
              : const {
                  0: FlexColumnWidth(2),
                  1: FlexColumnWidth(0.7),
                  2: FlexColumnWidth(0.8),
                  3: FlexColumnWidth(0.8),
                  4: FlexColumnWidth(0.6),
                  5: FlexColumnWidth(0.9),
                  6: FlexColumnWidth(0.5),
                  7: FlexColumnWidth(0.9),
                  8: FlexColumnWidth(0.8),
                  9: FixedColumnWidth(52),
                },
          children: [
            TableRow(
              decoration: BoxDecoration(color: AppColors.bgInput),
              children: [
                _tableHeader('Produkt / Tovar'),
                _tableHeader('Skladom'),
                _tableHeader('Šarža'),
                _tableHeader('Expirácia'),
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
        border: Border.all(color: AppColors.borderDefault),
        borderRadius: BorderRadius.circular(_radius),
        color: AppColors.bgInput,
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
                  color: AppColors.textPrimary,
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
      final qty = _tryParseDecimal(row.qtyController.text) ?? 0;
      if (qty <= 0) continue;
      final priceWithout = _tryParseDecimal(row.unitPriceWithoutVatController.text) ?? 0;
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
        border: Border.all(color: AppColors.borderDefault),
        borderRadius: BorderRadius.circular(_radius),
        color: AppColors.successSubtle,
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
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  double _rowTotal(_ReceiptItemRow row) {
    final qty = _tryParseDecimal(row.qtyController.text) ?? 0;
    final priceStr = _pricesIncludeVat
        ? row.unitPriceWithVatController.text.trim()
        : row.unitPriceWithoutVatController.text.trim();
    final price = _tryParseDecimal(priceStr) ?? 0;
    return (qty * price * 100).round() / 100;
  }

  /// Suma riadku s DPH (pre rozpočítanie obstarávacích nákladov podľa hodnoty).
  double _rowTotalWithVat(_ReceiptItemRow row) {
    if (row.product == null) return 0;
    final qty = _tryParseDecimal(row.qtyController.text) ?? 0;
    if (qty <= 0) return 0;
    final priceWithVat = _tryParseDecimal(row.unitPriceWithVatController.text) ?? 0;
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
      final qty = _tryParseDecimal(row.qtyController.text) ?? 0;
      if (qty <= 0) continue;
      validRows.add(i);
      if (_costDistributionMethod == 'manual') {
        manualAmounts.add(
          double.tryParse(row.manualAllocatedCostController.text.trim().replaceAll(',', '.')) ?? 0,
        );
      } else if (_costDistributionMethod == 'by_value') {
        weights.add(_rowTotalWithVat(row));
      } else {
        weights.add(qty); // by_quantity, by_weight (fallback)
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
      if (_rows[i].product != null && (_tryParseDecimal(_rows[i].qtyController.text) ?? 0) > 0) {
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
    final qty = _tryParseDecimal(row.qtyController.text) ?? 0;
    if (qty <= 0) return 0;
    final priceWithVat = _tryParseDecimal(row.unitPriceWithVatController.text) ?? 0;
    final alloc = _getAllocatedCostForRow(rowIndex);
    return _roundPrice((priceWithVat * qty + alloc) / qty);
  }

  TableRow _buildTableRow(int index) {
    final row = _rows[index];
    final hasProduct = row.product != null;
    final allowDecimalsQty = row.product?.ibaCeleMnozstva != true;
    return TableRow(
      decoration: BoxDecoration(
        color: index.isEven ? AppColors.bgCard : AppColors.bgElevated,
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
                      borderSide: const BorderSide(color: AppColors.borderDefault),
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
                icon: const Icon(Icons.add_box_outlined, size: 18, color: AppColors.accentGold),
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
                if (!hasProduct) return Text('—', style: TextStyle(fontSize: 12, color: AppColors.textSecondary));
                if (_selectedWarehouse == null) return Text('—', style: TextStyle(fontSize: 12, color: AppColors.textSecondary));
                final inWarehouse = _products.where((p) =>
                    p.warehouseId == _selectedWarehouse!.id && p.plu == row.product!.plu).toList();
                final qty = inWarehouse.isNotEmpty ? inWarehouse.first.qty : 0;
                return Text(
                  '$qty ${row.unit}',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                );
              },
            ),
          ),
        ),
        // Šarža
        Padding(
          padding: _compactPaddingTiny,
          child: TextFormField(
            controller: row.batchController,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Č. šarže',
              hintStyle: TextStyle(fontSize: 11, color: AppColors.textMuted),
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppColors.borderDefault),
              ),
            ),
          ),
        ),
        // Expirácia
        Padding(
          padding: _compactPaddingTiny,
          child: Builder(builder: (ctx) {
            final expiry = row.expiryController.text.trim();
            final warnColor = expiry.isNotEmpty ? _expiryWarningColor(expiry) : null;
            return Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: row.expiryController,
                    readOnly: true,
                    onTap: () => _pickExpiryDate(row.expiryController),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: warnColor ?? AppColors.textPrimary),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'DD.MM.RRRR',
                      hintStyle: TextStyle(fontSize: 10, color: AppColors.textMuted),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: warnColor ?? AppColors.borderDefault),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: warnColor ?? AppColors.borderDefault),
                      ),
                    ),
                  ),
                ),
                if (warnColor != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: Icon(Icons.warning_amber_rounded, size: 14, color: warnColor),
                  ),
              ],
            );
          }),
        ),
        Padding(
          padding: _compactPaddingTiny,
          child: TextFormField(
            controller: row.qtyController,
            keyboardType: allowDecimalsQty
                ? const TextInputType.numberWithOptions(decimal: true, signed: false)
                : TextInputType.number,
            onChanged: (_) => setState(() {}),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppColors.borderDefault),
              ),
            ),
            inputFormatters: allowDecimalsQty
                ? [_DecimalInputFormatter()]
                : [FilteringTextInputFormatter.digitsOnly],
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
                borderSide: const BorderSide(color: AppColors.borderDefault),
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
                borderSide: const BorderSide(color: AppColors.borderDefault),
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
              fillColor: AppColors.bgInput,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppColors.borderDefault),
              ),
            ),
          ),
        ),
        Padding(
          padding: _compactPaddingTiny,
          child: Center(
            child: Text(
              hasProduct ? '${_rowTotal(row).toStringAsFixed(2)} €' : '—',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
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
                          borderSide: const BorderSide(color: AppColors.borderDefault),
                        ),
                      ),
                      inputFormatters: [_DecimalInputFormatter()],
                    )
                  : Text(
                      '${_getAllocatedCostForRow(index).toStringAsFixed(2)} €',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
            ),
          ),
        if (_isWithCosts)
          Padding(
            padding: _compactPaddingTiny,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.successSubtle,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.success, width: 1),
              ),
              child: Center(
                child: Text(
                  hasProduct && (_tryParseDecimal(row.qtyController.text) ?? 0) > 0
                      ? '${_getTrueUnitPriceWithVatForRow(index).toStringAsFixed(2)} €'
                      : '—',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
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
              color: AppColors.textMuted,
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
