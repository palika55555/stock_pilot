import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../models/customer.dart';
import '../../models/product.dart';
import '../../models/stock_out.dart';
import '../../models/warehouse.dart';
import '../../services/Database/database_service.dart';
import '../../services/StockOut/stock_out_service.dart';
import '../../services/Warehouse/warehouse_service.dart';

class _StockOutItemRow {
  Product? product;
  final TextEditingController qtyController = TextEditingController(text: '1');
  final TextEditingController priceController = TextEditingController();
  /// Číslo šarže / lot číslo.
  final TextEditingController batchController = TextEditingController();
  /// Dátum expirácie (zobrazovaný DD.MM.YYYY, ukladaný YYYY-MM-DD).
  final TextEditingController expiryController = TextEditingController();
  String get unit => product?.unit ?? 'ks';
}

class StockOutModal extends StatefulWidget {
  final int? stockOutId;

  const StockOutModal({super.key, this.stockOutId});

  @override
  State<StockOutModal> createState() => _StockOutModalState();
}

class _StockOutModalState extends State<StockOutModal> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseService _db = DatabaseService();
  final StockOutService _stockOutService = StockOutService();
  final WarehouseService _warehouseService = WarehouseService();

  final TextEditingController _documentNumberController = TextEditingController();
  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _writeOffReasonController = TextEditingController();
  final TextEditingController _recipientIcoController = TextEditingController();
  final TextEditingController _recipientDicController = TextEditingController();

  bool _manualDocumentNumber = false;
  bool _zeroVat = false; // Výdaj za 0 % DPH
  StockOutIssueType _issueType = StockOutIssueType.sale;
  final List<_StockOutItemRow> _rows = [];
  List<Product> _products = [];
  List<Warehouse> _warehouses = [];
  List<Customer> _customers = [];
  Customer? _selectedCustomer;
  int? _selectedWarehouseId;
  bool _productsLoaded = false;
  bool _isSaving = false;
  StockOut? _editStockOut;

  bool get _isEditMode => widget.stockOutId != null;
  bool get _isReadOnly => _editStockOut?.jeVysporiadana == true;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _loadStockOutAndProducts();
    } else {
      _loadProducts();
      _addRow();
      _generateNextDocumentNumber();
    }
  }

  Future<void> _generateNextDocumentNumber() async {
    final next = await _db.getNextStockOutNumber();
    if (mounted && !_manualDocumentNumber) {
      setState(() => _documentNumberController.text = next);
    }
  }

  Future<void> _loadStockOutAndProducts() async {
    final id = widget.stockOutId!;
    final stockOut = await _db.getStockOutById(id);
    final items = await _db.getStockOutItems(id);
    final warehouses = await _warehouseService.getAllWarehouses();
    final customers = await _db.getCustomers();
    final products = stockOut?.warehouseId != null
        ? await _db.getProductsByWarehouseId(stockOut!.warehouseId!)
        : await _db.getProducts();
    if (!mounted) return;
    setState(() {
      _warehouses = warehouses;
      _customers = customers;
      _products = products;
      _editStockOut = stockOut;
      _selectedWarehouseId = stockOut?.warehouseId;
      if (stockOut != null) {
        _documentNumberController.text = stockOut.documentNumber;
        _recipientController.text = stockOut.recipientName ?? '';
        _notesController.text = stockOut.notes ?? '';
        _manualDocumentNumber = true;
        _zeroVat = stockOut.isZeroVat;
        _issueType = stockOut.issueType;
        _writeOffReasonController.text = stockOut.writeOffReason ?? '';
        _recipientIcoController.text = stockOut.recipientIco ?? '';
        _recipientDicController.text = stockOut.recipientDic ?? '';
        if (stockOut.customerId != null) {
          _selectedCustomer = customers.where((c) => c.id == stockOut.customerId).firstOrNull;
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
        final row = _StockOutItemRow();
        row.product = product;
        row.qtyController.text = item.qty.toString();
        row.priceController.text = item.unitPrice.toStringAsFixed(2);
        if (item.batchNumber != null && item.batchNumber!.isNotEmpty) {
          row.batchController.text = item.batchNumber!;
        }
        if (item.expiryDate != null && item.expiryDate!.isNotEmpty) {
          row.expiryController.text = _isoToDisplay(item.expiryDate!);
        }
        _rows.add(row);
      }
      if (_rows.isEmpty) _addRow();
      _productsLoaded = true;
    });
  }

  Future<void> _loadProducts() async {
    final warehouses = await _warehouseService.getAllWarehouses();
    final customers = await _db.getCustomers();
    final products = _selectedWarehouseId != null
        ? await _db.getProductsByWarehouseId(_selectedWarehouseId!)
        : await _db.getProducts();
    if (mounted) {
      setState(() {
        _warehouses = warehouses;
        _customers = customers;
        _products = products;
        _productsLoaded = true;
      });
    }
  }

  void _addRow() {
    setState(() => _rows.add(_StockOutItemRow()));
  }

  void _removeRow(int index) {
    if (_rows.length <= 1) return;
    setState(() {
      _rows[index].qtyController.dispose();
      _rows[index].priceController.dispose();
      _rows[index].batchController.dispose();
      _rows[index].expiryController.dispose();
      _rows.removeAt(index);
    });
  }

  String _rowTotal(_StockOutItemRow row) {
    final qty = int.tryParse(row.qtyController.text.trim()) ?? 0;
    final price = double.tryParse(
            row.priceController.text.trim().replaceAll(',', '.')) ??
        0.0;
    return (qty * price).toStringAsFixed(2);
  }

  double _rowTotalValue(_StockOutItemRow row) {
    final qty = int.tryParse(row.qtyController.text.trim()) ?? 0;
    final price = double.tryParse(
            row.priceController.text.trim().replaceAll(',', '.')) ??
        0.0;
    return qty * price;
  }

  double get _subtotal {
    double sum = 0;
    for (final row in _rows) {
      if (row.product != null) sum += _rowTotalValue(row);
    }
    return sum;
  }

  /// DPH vypočítané z každej položky podľa sadzby produktu (product.vat).
  double get _vatAmount {
    if (_zeroVat) return 0;
    double sum = 0;
    for (final row in _rows) {
      if (row.product != null) {
        final lineTotal = _rowTotalValue(row);
        final vatPercent = row.product!.vat;
        sum += lineTotal * (vatPercent / 100);
      }
    }
    return sum;
  }

  double get _total => _subtotal + _vatAmount;

  /// Jedna sadzba DPH ak majú všetky položky rovnakú, inak null (zobrazíme „DPH“).
  int? get _singleVatPercent {
    if (_zeroVat || _rows.isEmpty) return 0;
    final withProduct = _rows.where((r) => r.product != null).toList();
    if (withProduct.isEmpty) return null;
    final first = withProduct.first.product!.vat;
    if (withProduct.every((r) => r.product!.vat == first)) return first;
    return null;
  }

  static const _radius = 12.0;

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

  void _onProductSelected(int rowIndex, Product? product) {
    setState(() {
      _rows[rowIndex].product = product;
      if (product != null) {
        if (_rows[rowIndex].qtyController.text.isEmpty) {
          _rows[rowIndex].qtyController.text = '1';
        }
        if (_rows[rowIndex].priceController.text.isEmpty) {
          _rows[rowIndex].priceController.text =
              product.price.toStringAsFixed(2);
        }
        if (product.linkedProductUniqueId != null &&
            product.linkedProductUniqueId!.trim().isNotEmpty) {
          final linkedList = _products
              .where((p) => p.uniqueId == product.linkedProductUniqueId)
              .toList();
          if (linkedList.isNotEmpty) {
            final linked = linkedList.first;
            final qty = _rows[rowIndex].qtyController.text.trim();
            final nextRow = _StockOutItemRow();
            nextRow.product = linked;
            nextRow.qtyController.text = qty.isEmpty ? '1' : qty;
            nextRow.priceController.text = linked.price.toStringAsFixed(2);
            _rows.insert(rowIndex + 1, nextRow);
          }
        }
      }
    });
    // FEFO: auto-vyplniť šaržu s najskoršou expiráciou z príjemiek
    if (product != null) {
      _autoFillFefo(rowIndex);
    }
  }

  Future<void> _onWarehouseChanged(int? warehouseId) async {
    setState(() => _selectedWarehouseId = warehouseId);
    final products = warehouseId != null
        ? await _db.getProductsByWarehouseId(warehouseId)
        : await _db.getProducts();
    if (mounted) setState(() => _products = products);
  }

  Future<List<StockOutItem>?> _collectItems({bool allowEmpty = false}) async {
    final items = <StockOutItem>[];
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
      if (qty > row.product!.qty && !allowEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Riadok ${i + 1}: na sklade je len ${row.product!.qty} ${row.product!.unit}. Nie je možné vydať $qty.',
            ),
            backgroundColor: AppColors.danger,
          ),
        );
        return null;
      }
      final priceRaw = double.tryParse(
          row.priceController.text.trim().replaceAll(',', '.'));
      final price = (priceRaw != null && priceRaw >= 0)
          ? priceRaw
          : (row.product!.price);
      if (price < 0 && !allowEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Riadok ${i + 1}: zadajte platnú cenu za jednotku'),
            backgroundColor: AppColors.danger,
          ),
        );
        return null;
      }
      final batchText = row.batchController.text.trim();
      final expiryText = row.expiryController.text.trim();
      items.add(StockOutItem(
        stockOutId: 0,
        productUniqueId: row.product!.uniqueId!,
        productName: row.product!.name,
        plu: row.product!.plu,
        qty: qty,
        unit: row.unit,
        unitPrice: price,
        batchNumber: batchText.isNotEmpty ? batchText : null,
        expiryDate: expiryText.isNotEmpty ? _displayToIso(expiryText) : null,
      ));
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
    if (!_isEditMode && _selectedWarehouseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vyberte sklad pre výdajku'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      var docNumber = _documentNumberController.text.trim();
      if (docNumber.isEmpty) {
        docNumber = await _db.getNextStockOutNumber();
        if (mounted) _documentNumberController.text = docNumber;
      }
      final recipient = _recipientController.text.trim().isEmpty
          ? null
          : _recipientController.text.trim();
      final notes = _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim();
      final recipientIco = _recipientIcoController.text.trim().isEmpty ? null : _recipientIcoController.text.trim();
      final recipientDic = _recipientDicController.text.trim().isEmpty ? null : _recipientDicController.text.trim();
      final recipientAddress = _selectedCustomer != null ? _buildCustomerAddress(_selectedCustomer!) : null;

      if (_isEditMode && _editStockOut != null) {
        final so = _editStockOut!.copyWith(
          documentNumber: docNumber,
          recipientName: recipient,
          notes: notes,
          status: StockOutStatus.rozpracovany,
          warehouseId: _selectedWarehouseId,
          vatRate: _zeroVat ? 0 : null,
          issueType: _issueType,
          writeOffReason: _issueType == StockOutIssueType.writeOff
              ? _writeOffReasonController.text.trim()
              : null,
          customerId: _selectedCustomer?.id,
          recipientIco: recipientIco,
          recipientDic: recipientDic,
          recipientAddress: recipientAddress,
        );
        await _stockOutService.updateStockOut(stockOut: so, items: items);
      } else {
        final so = StockOut(
          documentNumber: docNumber,
          createdAt: DateTime.now(),
          recipientName: recipient,
          notes: notes,
          warehouseId: _selectedWarehouseId,
          vatRate: _zeroVat ? 0 : null,
          issueType: _issueType,
          writeOffReason: _issueType == StockOutIssueType.writeOff
              ? _writeOffReasonController.text.trim()
              : null,
          customerId: _selectedCustomer?.id,
          recipientIco: recipientIco,
          recipientDic: recipientDic,
          recipientAddress: recipientAddress,
        );
        await _stockOutService.createStockOut(
          stockOut: so,
          items: items,
          isDraft: true,
        );
      }
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Výdajka uložená ako rozpracovaná'),
            backgroundColor: AppColors.success,
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_issueType == StockOutIssueType.writeOff) {
      final reason = _writeOffReasonController.text.trim();
      if (reason.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pri type Odpis / Likvidácia je povinný dôvod odpisu (napr. expirácia, poškodenie).'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
    }
    final items = await _collectItems(allowEmpty: false);
    if (items == null) return;

    setState(() => _isSaving = true);
    try {
      final docNumber = _documentNumberController.text.trim();
      final recipient = _recipientController.text.trim().isEmpty
          ? null
          : _recipientController.text.trim();
      final notes = _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim();
      final recipientIco = _recipientIcoController.text.trim().isEmpty ? null : _recipientIcoController.text.trim();
      final recipientDic = _recipientDicController.text.trim().isEmpty ? null : _recipientDicController.text.trim();
      final recipientAddress = _selectedCustomer != null ? _buildCustomerAddress(_selectedCustomer!) : null;

      if (_isEditMode && _editStockOut != null) {
        final status = _editStockOut!.isDraft
            ? StockOutStatus.vykazana
            : _editStockOut!.status;
        final so = _editStockOut!.copyWith(
          documentNumber: docNumber,
          recipientName: recipient,
          notes: notes,
          status: status,
          warehouseId: _selectedWarehouseId,
          vatRate: _zeroVat ? 0 : null,
          issueType: _issueType,
          writeOffReason: _issueType == StockOutIssueType.writeOff
              ? _writeOffReasonController.text.trim()
              : null,
          customerId: _selectedCustomer?.id,
          recipientIco: recipientIco,
          recipientDic: recipientDic,
          recipientAddress: recipientAddress,
        );
        await _stockOutService.updateStockOut(stockOut: so, items: items);
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _editStockOut!.isDraft
                    ? 'Výdajka bola vykázaná'
                    : 'Výdajka bola upravená',
              ),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        if (_selectedWarehouseId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vyberte sklad pre výdajku'),
              backgroundColor: AppColors.danger,
            ),
          );
          setState(() => _isSaving = false);
          return;
        }
        final so = StockOut(
          documentNumber: docNumber,
          createdAt: DateTime.now(),
          recipientName: recipient,
          notes: notes,
          warehouseId: _selectedWarehouseId,
          vatRate: _zeroVat ? 0 : null,
          issueType: _issueType,
          writeOffReason: _issueType == StockOutIssueType.writeOff
              ? _writeOffReasonController.text.trim()
              : null,
          customerId: _selectedCustomer?.id,
          recipientIco: recipientIco,
          recipientDic: recipientDic,
          recipientAddress: recipientAddress,
        );
        await _stockOutService.createStockOut(stockOut: so, items: items);
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Výdajka bola uložená'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } on InsufficientStockException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
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
    _documentNumberController.dispose();
    _recipientController.dispose();
    _notesController.dispose();
    _writeOffReasonController.dispose();
    _recipientIcoController.dispose();
    _recipientDicController.dispose();
    for (final row in _rows) {
      row.qtyController.dispose();
      row.priceController.dispose();
      row.batchController.dispose();
      row.expiryController.dispose();
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
                    _isEditMode ? 'Upraviť výdajku' : 'Nová výdajka',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_isReadOnly)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Vysporiadaná výdajka – len na prezeranie',
                    style: const TextStyle(fontSize: 13, color: AppColors.warning),
                  ),
                ),
              TextFormField(
                controller: _documentNumberController,
                readOnly: _isReadOnly || (!_manualDocumentNumber && !_isEditMode),
                decoration: _styledInputDecoration('Číslo výdajky',
                        prefixIcon: const Icon(Icons.tag, size: 22, color: AppColors.textMuted))
                    .copyWith(
                  hintText: '# VD-2026-0001',
                  suffixIcon: _isEditMode
                      ? null
                      : IconButton(
                          icon: Icon(
                            _manualDocumentNumber
                                ? Icons.auto_fix_high
                                : Icons.edit_rounded,
                            color: AppColors.accentGold,
                            size: 22,
                          ),
                          onPressed: () {
                            setState(() {
                              _manualDocumentNumber = !_manualDocumentNumber;
                              if (!_manualDocumentNumber)
                                _generateNextDocumentNumber();
                            });
                          },
                        ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                value: _selectedWarehouseId,
                decoration: _styledInputDecoration('Sklad *',
                    prefixIcon: const Icon(Icons.warehouse_outlined, size: 22, color: AppColors.textMuted)),
                dropdownColor: AppColors.bgInput,
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('— Vyberte sklad —')),
                  ..._warehouses.map(
                    (w) => DropdownMenuItem<int?>(value: w.id, child: Text(w.name)),
                  ),
                ],
                onChanged: _isReadOnly ? null : (id) => _onWarehouseChanged(id),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Customer?>(
                value: _selectedCustomer,
                decoration: _styledInputDecoration('Zákazník (voliteľné)',
                    prefixIcon: const Icon(Icons.business_outlined, size: 22, color: AppColors.textMuted)),
                dropdownColor: AppColors.bgInput,
                borderRadius: BorderRadius.circular(_radius),
                items: [
                  const DropdownMenuItem<Customer?>(value: null, child: Text('— Bez zákazníka (manuálne) —')),
                  ..._customers.map((c) => DropdownMenuItem<Customer?>(value: c, child: Text(c.name))),
                ],
                onChanged: _isReadOnly
                    ? null
                    : (c) {
                        setState(() {
                          _selectedCustomer = c;
                          if (c != null) {
                            _recipientController.text = c.name;
                            _recipientIcoController.text = c.ico;
                            _recipientDicController.text = c.dic ?? '';
                          }
                        });
                      },
              ),
              const SizedBox(height: 12),
              if (_selectedCustomer != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.bgInput,
                    borderRadius: BorderRadius.circular(_radius),
                    border: Border.all(color: AppColors.borderDefault),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.textMuted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          [
                            if (_selectedCustomer!.ico.isNotEmpty) 'IČO: ${_selectedCustomer!.ico}',
                            if (_selectedCustomer!.dic != null && _selectedCustomer!.dic!.isNotEmpty) 'DIČ: ${_selectedCustomer!.dic}',
                            if (_selectedCustomer!.address != null) _selectedCustomer!.address!,
                          ].join('  •  '),
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _recipientController,
                readOnly: _isReadOnly,
                decoration: _styledInputDecoration('Odberateľ / účel',
                    prefixIcon: const Icon(Icons.person_outline_rounded, size: 22, color: AppColors.textMuted)),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _recipientIcoController,
                      readOnly: _isReadOnly,
                      decoration: _styledInputDecoration('IČO príjemcu',
                          prefixIcon: const Icon(Icons.badge_outlined, size: 22, color: AppColors.textMuted)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _recipientDicController,
                      readOnly: _isReadOnly,
                      decoration: _styledInputDecoration('DIČ príjemcu',
                          prefixIcon: const Icon(Icons.receipt_long_outlined, size: 22, color: AppColors.textMuted)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<StockOutIssueType>(
                value: _issueType,
                decoration: _styledInputDecoration('Typ výdaja',
                    prefixIcon: const Icon(Icons.folder_outlined, size: 22, color: AppColors.textMuted)),
                dropdownColor: AppColors.bgInput,
                items: StockOutIssueType.values
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(t.label),
                        ))
                    .toList(),
                onChanged: _isReadOnly ? null : (t) => setState(() => _issueType = t ?? StockOutIssueType.sale),
                borderRadius: BorderRadius.circular(_radius),
              ),
              if (_issueType == StockOutIssueType.writeOff) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _writeOffReasonController,
                  decoration: _styledInputDecoration('Dôvod odpisu *',
                      prefixIcon: const Icon(Icons.warning_amber_rounded, size: 22, color: AppColors.textMuted)),
                  maxLines: 2,
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: _styledInputDecoration('Poznámka',
                    prefixIcon: const Icon(Icons.note_outlined, size: 22, color: AppColors.textMuted)),
              ),
              const SizedBox(height: 8),
              Material(
                color: Colors.transparent,
                child: CheckboxListTile(
                  value: _zeroVat,
                  onChanged: (v) => setState(() => _zeroVat = v ?? false),
                  title: const Text('Výdaj za 0 % DPH', style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                  subtitle: const Text('Výber pre vývoz alebo oslobodené dodania', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.accentGold,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Položky',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                  ),
                  if (!_isReadOnly)
                    FilledButton.icon(
                      onPressed: _addRow,
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text('Pridať položku'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accentGold,
                        foregroundColor: AppColors.bgPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (!_productsLoaded)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                _buildItemsTable(),
              const SizedBox(height: 20),
              _buildSummaryCard(),
              const SizedBox(height: 24),
              if (!_isReadOnly)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _isSaving ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accentGold,
                    foregroundColor: AppColors.bgPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bgPrimary),
                        )
                      : Text(
                          _isEditMode && _editStockOut?.isDraft == true
                              ? 'Vykázať výdaj'
                              : (_isEditMode ? 'Uložiť zmeny' : 'Uložiť výdajku'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              if (!_isReadOnly && (!_isEditMode || _editStockOut?.isDraft == true)) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _isSaving ? null : _saveDraft,
                    icon: const Icon(Icons.save_outlined, size: 20),
                    label: const Text('Uložiť ako rozpracovaný'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.borderDefault),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
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

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgInput,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        children: [
          _summaryRow('Medzisučet:', _subtotal),
          const SizedBox(height: 8),
          _summaryRow(
              _zeroVat
                  ? 'DPH (0%):'
                  : (_singleVatPercent != null
                      ? 'DPH ($_singleVatPercent%):'
                      : 'DPH:'),
              _vatAmount),
          const Divider(height: 20),
          _summaryRow('Celkom k úhrade:', _total, bold: true, valueColor: AppColors.accentGold),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, double value, {bool bold = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: bold ? FontWeight.w600 : FontWeight.w500)),
        Text('${value.toStringAsFixed(2)} €', style: TextStyle(fontSize: 14, fontWeight: bold ? FontWeight.bold : FontWeight.w600, color: valueColor ?? AppColors.textPrimary)),
      ],
    );
  }

  static String? _buildCustomerAddress(Customer c) {
    final parts = [
      if (c.address != null && c.address!.isNotEmpty) c.address!,
      if (c.city != null && c.city!.isNotEmpty || c.postalCode != null && c.postalCode!.isNotEmpty)
        '${c.city ?? ''} ${c.postalCode ?? ''}'.trim(),
    ];
    if (parts.isEmpty) return null;
    return parts.join(', ');
  }

  Widget _buildItemsTable() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderDefault),
        borderRadius: BorderRadius.circular(_radius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_radius),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(2.2),
            1: FlexColumnWidth(0.9),
            2: FlexColumnWidth(0.8),
            3: FlexColumnWidth(0.85),
            4: FlexColumnWidth(0.8),
            5: FlexColumnWidth(0.9),
            6: FlexColumnWidth(0.9),
            7: FixedColumnWidth(52),
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
                _tableHeader('Cena/jed. (€)'),
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

  /// Vráti farbu upozornenia pre expiry: červená ak expirované, oranžová ak do 30 dní.
  Color? _expiryWarningColor(String displayDate) {
    final iso = _displayToIso(displayDate);
    if (iso == null) return null;
    final date = DateTime.tryParse(iso);
    if (date == null) return null;
    final now = DateTime.now();
    if (date.isBefore(now)) return Colors.red;
    if (date.difference(now).inDays <= 30) return Colors.orange;
    return null;
  }

  /// FEFO: načíta dostupné šarže pre produkt zo schválených príjemiek a auto-vyplní riadok.
  Future<void> _autoFillFefo(int rowIndex) async {
    if (_selectedWarehouseId == null) return;
    final row = _rows[rowIndex];
    if (row.product == null) return;
    final batches = await _db.getAvailableBatchesForProduct(
      row.product!.uniqueId!,
      _selectedWarehouseId!,
    );
    if (batches.isEmpty || !mounted) return;
    // FEFO: prvá šarža má najstarší dátum expirácie
    final first = batches.first;
    setState(() {
      row.batchController.text = first['batch_number'] as String? ?? '';
      final expIso = first['expiry_date'] as String?;
      row.expiryController.text = (expIso != null && expIso.isNotEmpty) ? _isoToDisplay(expIso) : '';
    });
  }

  Widget _tableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary)),
    );
  }

  TableRow _buildTableRow(int index) {
    final row = _rows[index];
    final hasProduct = row.product != null;
    return TableRow(
      decoration: BoxDecoration(
        color: index.isEven ? AppColors.bgCard : AppColors.bgElevated,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: DropdownButtonFormField<Product?>(
            value: row.product,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: AppColors.bgInput,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.borderDefault)),
            ),
            dropdownColor: AppColors.bgInput,
            items: [
              const DropdownMenuItem(value: null, child: Text('— Vyberte tovar —', style: TextStyle(fontSize: 13))),
              ..._products.map((p) => DropdownMenuItem(value: p, child: Text('${p.name} (${p.plu})', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)))),
            ],
            onChanged: _isReadOnly ? null : (p) => _onProductSelected(index, p),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Center(child: Text(hasProduct ? '${row.product!.qty} ${row.unit}' : '—', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
        ),
        // Šarža
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: TextFormField(
            controller: row.batchController,
            readOnly: _isReadOnly,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: AppColors.bgInput,
              hintText: 'Č. šarže',
              hintStyle: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.borderDefault)),
            ),
          ),
        ),
        // Expirácia
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Builder(builder: (ctx) {
            final expiry = row.expiryController.text.trim();
            final warnColor = expiry.isNotEmpty ? _expiryWarningColor(expiry) : null;
            return Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: row.expiryController,
                    readOnly: true,
                    onTap: _isReadOnly ? null : () => _pickExpiryDate(row.expiryController),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: warnColor ?? AppColors.textPrimary),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: AppColors.bgInput,
                      hintText: 'DD.MM.RRRR',
                      hintStyle: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: warnColor ?? AppColors.borderDefault),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
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
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: TextFormField(
            controller: row.qtyController,
            readOnly: _isReadOnly,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: AppColors.bgInput,
              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.borderDefault)),
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: TextFormField(
            controller: row.priceController,
            readOnly: _isReadOnly,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
            onChanged: (_) => setState(() {}),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: AppColors.bgInput,
              hintText: hasProduct ? row.product!.price.toStringAsFixed(2) : '0.00',
              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.borderDefault)),
            ),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Center(child: Text(hasProduct ? '${_rowTotal(row)} €' : '—', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 22, color: AppColors.textMuted),
            onPressed: _isReadOnly ? null : (_rows.length > 1 ? () => _removeRow(index) : null),
            tooltip: 'Odstrániť',
          ),
        ),
      ],
    );
  }
}
