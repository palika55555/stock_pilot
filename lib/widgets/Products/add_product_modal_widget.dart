import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/product.dart';
import '../../models/product_kind.dart';
import '../../models/warehouse.dart';
import '../../services/Product/product_service.dart';
import '../../services/Product/product_kind_service.dart';
import '../../services/Warehouse/warehouse_service.dart';

class AddProductModal extends StatefulWidget {
  final String? initialPlu;
  final Product? productToEdit;

  const AddProductModal({
    super.key,
    this.initialPlu,
    this.productToEdit,
  });

  @override
  State<AddProductModal> createState() => _AddProductModalState();
}

class _AddProductModalState extends State<AddProductModal> {
  final _formKey = GlobalKey<FormState>();
  final ProductService _productService = ProductService();
  final ProductKindService _kindService = ProductKindService();
  final WarehouseService _warehouseService = WarehouseService();
  bool _isLoading = false;
  List<ProductKind> _kinds = [];
  List<Warehouse> _warehouses = [];
  int? _selectedKindId;
  int? _selectedWarehouseId;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _pluController = TextEditingController();

  // Sales prices
  final TextEditingController _salesPriceWithoutVatController =
      TextEditingController();
  final TextEditingController _salesVatController = TextEditingController(
    text: '20',
  );
  final TextEditingController _salesPriceWithVatController =
      TextEditingController();

  // Purchase prices
  final TextEditingController _purchasePriceWithoutVatController =
      TextEditingController();
  final TextEditingController _purchaseVatController = TextEditingController(
    text: '20',
  );
  final TextEditingController _purchasePriceWithVatController =
      TextEditingController();

  final TextEditingController _recyclingFeeController = TextEditingController(
    text: '0.0',
  );
  final TextEditingController _locationController = TextEditingController();

  String _selectedUnit = 'ks';
  String _selectedCategory = WarehouseType.sklad;

  final List<String> _units = ['ks', 'l', 'm2', 'm3', 'kg', 'bm', 'bal'];

  bool get _isEditMode => widget.productToEdit != null;

  @override
  void initState() {
    super.initState();
    _loadKinds();
    _loadWarehouses();
    if (widget.productToEdit != null) {
      final p = widget.productToEdit!;
      _nameController.text = p.name;
      _pluController.text = p.plu;
      _selectedCategory = WarehouseType.all.contains(p.category)
          ? p.category
          : (WarehouseType.all.contains(p.productType) ? p.productType : WarehouseType.sklad);
      _selectedUnit = p.unit;
      _selectedKindId = p.kindId;
      _selectedWarehouseId = p.warehouseId;
      _salesPriceWithoutVatController.text = p.withoutVat.toStringAsFixed(2);
      _salesVatController.text = p.vat.toString();
      _salesPriceWithVatController.text = p.price.toStringAsFixed(2);
      _purchasePriceWithoutVatController.text =
          p.purchasePriceWithoutVat.toStringAsFixed(2);
      _purchaseVatController.text = p.purchaseVat.toString();
      _purchasePriceWithVatController.text =
          p.purchasePrice.toStringAsFixed(2);
      _recyclingFeeController.text = p.recyclingFee.toStringAsFixed(2);
      _locationController.text = p.location;
    } else if (widget.initialPlu != null) {
      _pluController.text = widget.initialPlu!;
    }

    // Listeners for auto-calculation
    _salesPriceWithoutVatController.addListener(_calculateSalesWithVat);
    _salesVatController.addListener(_calculateSalesWithVat);
    _purchasePriceWithoutVatController.addListener(_calculatePurchaseWithVat);
    _purchaseVatController.addListener(_calculatePurchaseWithVat);
    _salesPriceWithVatController.addListener(() => setState(() {}));
    _purchasePriceWithVatController.addListener(() => setState(() {}));
  }

  Future<void> _loadKinds() async {
    final list = await _kindService.getKinds();
    if (mounted) setState(() => _kinds = list);
  }

  Future<void> _loadWarehouses() async {
    final list = await _warehouseService.getActiveWarehouses();
    if (mounted) setState(() => _warehouses = list);
  }

  Future<void> _showAddKindDialog() async {
    final nameController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Nový druh produktu'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Názov druhu',
              hintText: 'napr. klince, montážna pena',
            ),
            autofocus: true,
            onSubmitted: (_) => Navigator.pop(ctx, true),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Zrušiť'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Pridať'),
            ),
          ],
        );
      },
    );
    if (result != true || !mounted) return;
    final name = nameController.text.trim();
    if (name.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zadajte názov druhu')),
        );
      }
      return;
    }
    try {
      final id = await _kindService.createKind(ProductKind(name: name));
      await _loadKinds();
      if (mounted) setState(() => _selectedKindId = id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Druh bol pridaný'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Marža v % z predajnej ceny. Null ak predajná cena je 0.
  double? get _marginPercent {
    final sell = double.tryParse(
          _salesPriceWithVatController.text.trim().replaceAll(',', '.')) ??
        0.0;
    if (sell <= 0) return null;
    final buy = double.tryParse(
          _purchasePriceWithVatController.text.trim().replaceAll(',', '.')) ??
        0.0;
    return ((sell - buy) / sell) * 100;
  }

  void _calculateSalesWithVat() {
    final price =
        double.tryParse(
          _salesPriceWithoutVatController.text.replaceAll(',', '.'),
        ) ??
        0.0;
    final vat = int.tryParse(_salesVatController.text) ?? 0;
    final withVat = _productService.calculateWithVat(price, vat);
    _salesPriceWithVatController.text = withVat.toStringAsFixed(2);
    if (mounted) setState(() {});
  }

  void _calculatePurchaseWithVat() {
    final price =
        double.tryParse(
          _purchasePriceWithoutVatController.text.replaceAll(',', '.'),
        ) ??
        0.0;
    final vat = int.tryParse(_purchaseVatController.text) ?? 0;
    final withVat = _productService.calculateWithVat(price, vat);
    _purchasePriceWithVatController.text = withVat.toStringAsFixed(2);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pluController.dispose();
    _salesPriceWithoutVatController.dispose();
    _salesVatController.dispose();
    _salesPriceWithVatController.dispose();
    _purchasePriceWithoutVatController.dispose();
    _purchaseVatController.dispose();
    _purchasePriceWithVatController.dispose();
    _recyclingFeeController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final salesPriceWithoutVat =
          double.tryParse(
            _salesPriceWithoutVatController.text.replaceAll(',', '.'),
          ) ??
          0.0;
      final salesVat = int.tryParse(_salesVatController.text) ?? 20;
      final salesPriceWithVat = _productService.calculateWithVat(
        salesPriceWithoutVat,
        salesVat,
      );

      final purchasePriceWithoutVat =
          double.tryParse(
            _purchasePriceWithoutVatController.text.replaceAll(',', '.'),
          ) ??
          0.0;
      final purchaseVat = int.tryParse(_purchaseVatController.text) ?? 20;
      final purchasePriceWithVat = _productService.calculateWithVat(
        purchasePriceWithoutVat,
        purchaseVat,
      );

      final recyclingFee =
          double.tryParse(_recyclingFeeController.text.replaceAll(',', '.')) ??
          0.0;

      final existing = widget.productToEdit;
      final product = Product(
        uniqueId: existing?.uniqueId ?? 'uuid-${DateTime.now().millisecondsSinceEpoch}',
        name: _nameController.text.trim(),
        plu: _pluController.text.trim(),
        category: _selectedCategory,
        qty: existing?.qty ?? 0,
        unit: _selectedUnit,
        price: salesPriceWithVat,
        withoutVat: salesPriceWithoutVat,
        vat: salesVat,
        discount: existing?.discount ?? 0,
        lastPurchasePrice: purchasePriceWithVat,
        lastPurchasePriceWithoutVat: existing?.lastPurchasePriceWithoutVat ?? 0.0,
        lastPurchaseDate: existing?.lastPurchaseDate ?? '',
        currency: existing?.currency ?? 'EUR',
        location: _locationController.text.trim(),
        purchasePrice: purchasePriceWithVat,
        purchasePriceWithoutVat: purchasePriceWithoutVat,
        purchaseVat: purchaseVat,
        recyclingFee: recyclingFee,
        productType: _selectedCategory,
        supplierName: existing?.supplierName,
        kindId: _selectedKindId,
        warehouseId: _selectedWarehouseId,
      );

      if (_isEditMode) {
        await _productService.updateProduct(product);
        if (mounted) {
          Navigator.pop(context, product);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Produkt bol upravený'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        await _productService.createProduct(product);
        if (mounted) {
          Navigator.pop(context, product);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Produkt bol vytvorený'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  static const _radius = 20.0;
  static const _accent = Color(0xFF6366F1);

  InputDecoration _inputDecoration(String label, {Widget? prefixIcon, String? suffixText}) {
    return InputDecoration(
      labelText: label,
      suffixText: suffixText,
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.7),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.9)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _accent, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 12),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(_radius),
              border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _isEditMode ? 'Upraviť produkt' : 'Nový produkt',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => Navigator.pop(context),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close_rounded, size: 22),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _nameController,
                            decoration: _inputDecoration(
                              'Názov produktu',
                              prefixIcon: const Icon(Icons.inventory_2_outlined, size: 22),
                            ),
                            validator: (v) =>
                                v == null || v.isEmpty ? 'Zadajte názov' : null,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _pluController,
                                  decoration: _inputDecoration(
                                    'PLU / Kód',
                                    prefixIcon: const Icon(Icons.qr_code_2_rounded, size: 22),
                                  ),
                                  validator: (v) =>
                                      v == null || v.isEmpty ? 'Zadajte PLU' : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<int?>(
                                  value: _selectedWarehouseId != null &&
                                          _warehouses.any((w) => w.id == _selectedWarehouseId)
                                      ? _selectedWarehouseId
                                      : null,
                                  decoration: _inputDecoration('Sklad'),
                                  dropdownColor: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  items: [
                                    const DropdownMenuItem<int?>(
                                      value: null,
                                      child: Text('— Žiadny —'),
                                    ),
                                    ..._warehouses.map(
                                      (w) => DropdownMenuItem<int?>(
                                        value: w.id,
                                        child: Text(w.name),
                                      ),
                                    ),
                                  ],
                                  onChanged: (v) => setState(() => _selectedWarehouseId = v),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _selectedCategory,
                                  decoration: _inputDecoration('Kategória'),
                                  dropdownColor: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  items: WarehouseType.all
                                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                                      .toList(),
                                  onChanged: (v) => setState(() => _selectedCategory = v ?? WarehouseType.sklad),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _selectedUnit,
                                  decoration: _inputDecoration('Jednotka'),
                                  dropdownColor: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  items: _units
                                      .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                                      .toList(),
                                  onChanged: (v) => setState(() => _selectedUnit = v!),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<int?>(
                                  value: _selectedKindId != null &&
                                          _kinds.any((k) => k.id == _selectedKindId)
                                      ? _selectedKindId
                                      : null,
                                  decoration: _inputDecoration('Druh (pre sklady)'),
                                  dropdownColor: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  items: [
                                    const DropdownMenuItem<int?>(
                                      value: null,
                                      child: Text('— Žiadny —'),
                                    ),
                                    ..._kinds.map(
                                      (k) => DropdownMenuItem<int?>(
                                        value: k.id,
                                        child: Text(k.name),
                                      ),
                                    ),
                                  ],
                                  onChanged: (v) => setState(() => _selectedKindId = v),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _showAddKindDialog,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: _accent.withValues(alpha: 0.5)),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.add_rounded, color: _accent, size: 22),
                                        SizedBox(width: 6),
                                        Text('Pridať druh', style: TextStyle(color: _accent, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _section(
                            'Nákupná cena',
                            [
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      controller: _purchasePriceWithoutVatController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: _inputDecoration('Cena bez DPH', suffixText: '€'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _purchaseVatController,
                                      keyboardType: TextInputType.number,
                                      decoration: _inputDecoration('DPH %'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      controller: _purchasePriceWithVatController,
                                      readOnly: true,
                                      decoration: _inputDecoration('Cena s DPH', suffixText: '€').copyWith(
                                        fillColor: Colors.white.withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _section(
                            'Predajná cena',
                            [
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      controller: _salesPriceWithoutVatController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: _inputDecoration('Cena bez DPH', suffixText: '€'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _salesVatController,
                                      keyboardType: TextInputType.number,
                                      decoration: _inputDecoration('DPH %'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      controller: _salesPriceWithVatController,
                                      readOnly: true,
                                      decoration: _inputDecoration('Cena s DPH', suffixText: '€').copyWith(
                                        fillColor: Colors.white.withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_marginPercent != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Marža: ${_marginPercent!.toStringAsFixed(1)} %',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _recyclingFeeController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: _inputDecoration('Recyklačný poplatok', suffixText: '€'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _locationController,
                                  decoration: _inputDecoration(
                                    'Lokácia',
                                    prefixIcon: const Icon(Icons.place_outlined, size: 22),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _accent,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      _isEditMode ? 'Uložiť zmeny' : 'Vytvoriť produkt',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
