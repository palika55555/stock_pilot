import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  bool _manualDocumentNumber = false;
  bool _zeroVat = false; // Výdaj za 0 % DPH
  StockOutIssueType _issueType = StockOutIssueType.sale;
  final List<_StockOutItemRow> _rows = [];
  List<Product> _products = [];
  List<Warehouse> _warehouses = [];
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
    final products = stockOut?.warehouseId != null
        ? await _db.getProductsByWarehouseId(stockOut!.warehouseId!)
        : await _db.getProducts();
    if (!mounted) return;
    setState(() {
      _warehouses = warehouses;
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
        _rows.add(row);
      }
      if (_rows.isEmpty) _addRow();
      _productsLoaded = true;
    });
  }

  Future<void> _loadProducts() async {
    final warehouses = await _warehouseService.getAllWarehouses();
    final products = _selectedWarehouseId != null
        ? await _db.getProductsByWarehouseId(_selectedWarehouseId!)
        : await _db.getProducts();
    if (mounted) {
      setState(() {
        _warehouses = warehouses;
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
  static const _primaryBlue = Color(0xFF2563EB);
  static const _borderColor = Color(0xFFE2E8F0);
  static const _fillColor = Color(0xFFF8FAFC);

  InputDecoration _styledInputDecoration(String label, {Widget? prefixIcon}) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: _fillColor,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(_radius)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: const BorderSide(color: _borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: const BorderSide(color: _primaryBlue, width: 1.5),
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
            backgroundColor: Colors.red,
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
            backgroundColor: Colors.red,
          ),
        );
        return null;
      }
      items.add(StockOutItem(
        stockOutId: 0,
        productUniqueId: row.product!.uniqueId!,
        productName: row.product!.name,
        plu: row.product!.plu,
        qty: qty,
        unit: row.unit,
        unitPrice: price,
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
          backgroundColor: Colors.red,
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
            backgroundColor: Colors.green,
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_issueType == StockOutIssueType.writeOff) {
      final reason = _writeOffReasonController.text.trim();
      if (reason.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pri type Odpis / Likvidácia je povinný dôvod odpisu (napr. expirácia, poškodenie).'),
            backgroundColor: Colors.red,
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
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (_selectedWarehouseId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vyberte sklad pre výdajku'),
              backgroundColor: Colors.red,
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
        );
        await _stockOutService.createStockOut(stockOut: so, items: items);
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Výdajka bola uložená'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } on InsufficientStockException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
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
    _documentNumberController.dispose();
    _recipientController.dispose();
    _notesController.dispose();
    _writeOffReasonController.dispose();
    for (final row in _rows) {
      row.qtyController.dispose();
      row.priceController.dispose();
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
                          color: const Color(0xFF1E293B),
                        ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
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
                    style: TextStyle(fontSize: 13, color: Colors.orange[800]),
                  ),
                ),
              TextFormField(
                controller: _documentNumberController,
                readOnly: _isReadOnly || (!_manualDocumentNumber && !_isEditMode),
                decoration: _styledInputDecoration('Číslo výdajky',
                        prefixIcon: const Icon(Icons.tag, size: 22, color: Color(0xFF64748B)))
                    .copyWith(
                  hintText: '# VD-2026-0001',
                  suffixIcon: _isEditMode
                      ? null
                      : IconButton(
                          icon: Icon(
                            _manualDocumentNumber
                                ? Icons.auto_fix_high
                                : Icons.edit_rounded,
                            color: const Color(0xFF2563EB),
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
                    prefixIcon: const Icon(Icons.warehouse_outlined, size: 22, color: Color(0xFF64748B))),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('— Vyberte sklad —')),
                  ..._warehouses.map(
                    (w) => DropdownMenuItem<int?>(value: w.id, child: Text(w.name)),
                  ),
                ],
                onChanged: _isReadOnly ? null : (id) => _onWarehouseChanged(id),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _recipientController,
                readOnly: _isReadOnly,
                decoration: _styledInputDecoration('Odberateľ / účel',
                    prefixIcon: const Icon(Icons.person_outline_rounded, size: 22, color: Color(0xFF64748B))),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<StockOutIssueType>(
                value: _issueType,
                decoration: _styledInputDecoration('Typ výdaja',
                    prefixIcon: const Icon(Icons.folder_outlined, size: 22, color: Color(0xFF64748B))),
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
                      prefixIcon: const Icon(Icons.warning_amber_rounded, size: 22, color: Color(0xFF64748B))),
                  maxLines: 2,
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: _styledInputDecoration('Poznámka',
                    prefixIcon: const Icon(Icons.note_outlined, size: 22, color: Color(0xFF64748B))),
              ),
              const SizedBox(height: 8),
              Material(
                color: Colors.transparent,
                child: CheckboxListTile(
                  value: _zeroVat,
                  onChanged: (v) => setState(() => _zeroVat = v ?? false),
                  title: const Text('Výdaj za 0 % DPH', style: TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF1E293B))),
                  subtitle: const Text('Výber pre vývoz alebo oslobodené dodania', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  activeColor: _primaryBlue,
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
                          color: const Color(0xFF1E293B),
                        ),
                  ),
                  if (!_isReadOnly)
                    FilledButton.icon(
                      onPressed: _addRow,
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text('Pridať položku'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _primaryBlue,
                        foregroundColor: Colors.white,
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
                    backgroundColor: _primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
                      foregroundColor: const Color(0xFF64748B),
                      side: const BorderSide(color: _borderColor),
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
        color: _fillColor,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: _borderColor),
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
          _summaryRow('Celkom k úhrade:', _total, bold: true, valueColor: _primaryBlue),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, double value, {bool bold = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: const Color(0xFF64748B), fontWeight: bold ? FontWeight.w600 : FontWeight.w500)),
        Text('${value.toStringAsFixed(2)} €', style: TextStyle(fontSize: 14, fontWeight: bold ? FontWeight.bold : FontWeight.w600, color: valueColor ?? const Color(0xFF1E293B))),
      ],
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
            0: FlexColumnWidth(2.2),
            1: FlexColumnWidth(0.9),
            2: FlexColumnWidth(0.8),
            3: FlexColumnWidth(0.9),
            4: FlexColumnWidth(0.9),
            5: FixedColumnWidth(52),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(color: _fillColor),
              children: [
                _tableHeader('Produkt / Tovar'),
                _tableHeader('Skladom'),
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

  Widget _tableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF64748B))),
    );
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: DropdownButtonFormField<Product?>(
            value: row.product,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _borderColor)),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('— Vyberte tovar —', style: TextStyle(fontSize: 13))),
              ..._products.map((p) => DropdownMenuItem(value: p, child: Text('${p.name} (${p.plu})', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)))),
            ],
            onChanged: _isReadOnly ? null : (p) => _onProductSelected(index, p),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Center(child: Text(hasProduct ? '${row.product!.qty} ${row.unit}' : '—', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)))),
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _borderColor)),
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
              hintText: hasProduct ? row.product!.price.toStringAsFixed(2) : '0.00',
              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _borderColor)),
            ),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Center(child: Text(hasProduct ? '${_rowTotal(row)} €' : '—', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)))),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 22, color: Color(0xFF94A3B8)),
            onPressed: _isReadOnly ? null : (_rows.length > 1 ? () => _removeRow(index) : null),
            tooltip: 'Odstrániť',
          ),
        ),
      ],
    );
  }
}
