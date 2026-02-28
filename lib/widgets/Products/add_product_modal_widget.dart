import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/product.dart';
import '../../models/product_kind.dart';
import '../../models/receptura_polozka.dart';
import '../../models/warehouse.dart';
import '../../services/Product/product_service.dart';
import '../../services/Product/product_kind_service.dart';
import '../../services/Receptura/receptura_service.dart';
import '../../services/Warehouse/warehouse_service.dart';

class AddProductModal extends StatefulWidget {
  final String? initialPlu;
  final Product? productToEdit;
  /// Pri vytvorení nového produktu predvyberie typ karty (napr. 'receptúra').
  final String? initialCardType;

  const AddProductModal({
    super.key,
    this.initialPlu,
    this.productToEdit,
    this.initialCardType,
  });

  @override
  State<AddProductModal> createState() => _AddProductModalState();
}

class _AddProductModalState extends State<AddProductModal> {
  final _formKey = GlobalKey<FormState>();
  final ProductService _productService = ProductService();
  final ProductKindService _kindService = ProductKindService();
  final WarehouseService _warehouseService = WarehouseService();
  final RecepturaService _recepturaService = RecepturaService();
  bool _isLoading = false;
  List<ProductKind> _kinds = [];
  List<Warehouse> _warehouses = [];
  List<Product> _allProducts = [];
  int? _selectedKindId;
  int? _selectedWarehouseId;
  List<RecepturaPolozka> _recepturaZlozky = [];

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _pluController = TextEditingController();
  final TextEditingController _eanController = TextEditingController();

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
  final TextEditingController _minQuantityController = TextEditingController(text: '0');
  final TextEditingController _stockGroupController = TextEditingController();

  String _selectedUnit = 'ks';
  String _selectedCategory = WarehouseType.sklad;
  String _selectedCardType = 'jednoduchá';
  bool _allowAtCashRegister = true;
  bool _showInPriceList = true;
  bool _isActive = true;
  bool _temporarilyUnavailable = false;
  bool _hasExtendedPricing = false;

  static const List<String> _cardTypes = [
    'jednoduchá',
    'služba',
    'vratný obal',
    'sada',
    'výrobok',
    'receptúra',
  ];

  final List<String> _units = ['ks', 'l', 'm2', 'm3', 'kg', 'bm', 'bal'];

  bool get _isEditMode => widget.productToEdit != null;

  bool get _isReceptura => _selectedCardType == 'receptúra';

  @override
  void initState() {
    super.initState();
    _loadKinds();
    _loadWarehouses();
    _loadAllProducts();
    if (widget.productToEdit != null) {
      final p = widget.productToEdit!;
      _nameController.text = p.name;
      _pluController.text = p.plu;
      _eanController.text = p.ean ?? '';
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
      _minQuantityController.text = p.minQuantity.toString();
      _stockGroupController.text = p.stockGroup ?? '';
      _selectedCardType = _cardTypes.contains(p.cardType) ? p.cardType : 'jednoduchá';
      _allowAtCashRegister = p.allowAtCashRegister;
      _showInPriceList = p.showInPriceList;
      _isActive = p.isActive;
      _temporarilyUnavailable = p.temporarilyUnavailable;
      _hasExtendedPricing = p.hasExtendedPricing;
      if (p.cardType == 'receptúra') {
        WidgetsBinding.instance.addPostFrameCallback((_) => _loadRecepturaZlozky());
      }
    } else {
      if (widget.initialCardType != null &&
          _cardTypes.contains(widget.initialCardType)) {
        _selectedCardType = widget.initialCardType!;
      }
      if (widget.initialPlu != null) {
        _pluController.text = widget.initialPlu!;
      }
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

  Future<void> _loadAllProducts() async {
    final list = await _productService.getAllProducts();
    if (mounted) setState(() => _allProducts = list);
  }

  Future<void> _loadRecepturaZlozky() async {
    final id = widget.productToEdit?.uniqueId;
    if (id == null) return;
    final karta = await _recepturaService.getSkladovaKarta(id);
    if (mounted && karta != null) {
      setState(() => _recepturaZlozky = List.from(karta.zlozky));
    }
  }

  Future<void> _showAddRecepturaZlozkaDialog() async {
    final currentId = widget.productToEdit?.uniqueId;
    final available = _allProducts.where((p) => p.uniqueId != currentId).toList();
    if (available.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Žiadne produkty na výber. Najprv vytvorte suroviny.')),
        );
      }
      return;
    }
    Product? selectedProduct = available.first;
    final qtyController = TextEditingController(text: '1');
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Pridať surovinu'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<Product>(
                      value: selectedProduct,
                      decoration: InputDecoration(
                        labelText: 'Produkt (surovina)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: available
                          .map((p) => DropdownMenuItem(
                                value: p,
                                child: Text('${p.plu} – ${p.name}', overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (p) => setDialogState(() => selectedProduct = p),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: qtyController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Množstvo',
                        suffixText: selectedProduct?.unit ?? 'ks',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Zrušiť'),
                ),
                FilledButton(
                  onPressed: () {
                    final qty = double.tryParse(qtyController.text.replaceAll(',', '.')) ?? 0;
                    if (qty <= 0) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Zadajte kladné množstvo')),
                      );
                      return;
                    }
                    Navigator.pop(ctx, true);
                  },
                  child: const Text('Pridať'),
                ),
              ],
            );
          },
        );
      },
    );
    if (result != true || !mounted || selectedProduct?.uniqueId == null) return;
    final qty = double.tryParse(qtyController.text.replaceAll(',', '.')) ?? 0;
    if (qty <= 0) return;
    setState(() {
      _recepturaZlozky.add(RecepturaPolozka(
        idSuroviny: selectedProduct!.uniqueId!,
        mnozstvo: (qty * 1000).round() / 1000,
      ));
    });
  }

  void _removeRecepturaZlozka(int index) {
    setState(() => _recepturaZlozky.removeAt(index));
  }

  String _productNameForId(String idSuroviny) {
    try {
      final p = _allProducts.firstWhere((p) => p.uniqueId == idSuroviny);
      return '${p.plu} – ${p.name}';
    } catch (_) {
      return idSuroviny;
    }
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
    _eanController.dispose();
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
      final eanTrimmed = _eanController.text.trim();
      final product = Product(
        uniqueId: existing?.uniqueId ?? 'uuid-${DateTime.now().millisecondsSinceEpoch}',
        name: _nameController.text.trim(),
        plu: _pluController.text.trim(),
        ean: eanTrimmed.isEmpty ? null : eanTrimmed,
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
        minQuantity: int.tryParse(_minQuantityController.text.trim()) ?? 0,
        allowAtCashRegister: _allowAtCashRegister,
        showInPriceList: _showInPriceList,
        isActive: _isActive,
        temporarilyUnavailable: _temporarilyUnavailable,
        stockGroup: _stockGroupController.text.trim().isEmpty ? null : _stockGroupController.text.trim(),
        cardType: _selectedCardType,
        hasExtendedPricing: _hasExtendedPricing,
        ibaCeleMnozstva: existing?.ibaCeleMnozstva ?? false,
      );

      if (_isEditMode) {
        await _productService.updateProduct(product);
      } else {
        await _productService.createProduct(product);
      }
      if (_selectedCardType == 'receptúra' && product.uniqueId != null) {
        await _recepturaService.saveRecepturaZlozky(product.uniqueId!, _recepturaZlozky);
      }
      if (mounted) {
        Navigator.pop(context, product);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode ? 'Produkt bol upravený' : 'Produkt bol vytvorený'),
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
                                child: TextFormField(
                                  controller: _eanController,
                                  decoration: _inputDecoration(
                                    'EAN / Čiarový kód',
                                    prefixIcon: const Icon(Icons.qr_code_2_rounded, size: 22),
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
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
                          const SizedBox(height: 12),
                          _section(
                            'Skladová karta (doplňkové)',
                            [
                              DropdownButtonFormField<String>(
                                value: _selectedCardType,
                                decoration: _inputDecoration('Typ karty'),
                                dropdownColor: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                items: _cardTypes
                                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                                    .toList(),
                                onChanged: (v) => setState(() => _selectedCardType = v ?? 'jednoduchá'),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _minQuantityController,
                                      keyboardType: TextInputType.number,
                                      decoration: _inputDecoration('Min. množstvo (tučné ak pod)'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _stockGroupController,
                                      decoration: _inputDecoration('Skladová skupina'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              CheckboxListTile(
                                value: _allowAtCashRegister,
                                onChanged: (v) => setState(() => _allowAtCashRegister = v ?? true),
                                title: const Text('Umožniť pracovať s položkou na pokladnici'),
                                controlAffinity: ListTileControlAffinity.leading,
                                contentPadding: EdgeInsets.zero,
                              ),
                              CheckboxListTile(
                                value: _showInPriceList,
                                onChanged: (v) => setState(() => _showInPriceList = v ?? true),
                                title: const Text('Uvádzať v tlačovom výstupe Cenník'),
                                controlAffinity: ListTileControlAffinity.leading,
                                contentPadding: EdgeInsets.zero,
                              ),
                              CheckboxListTile(
                                value: _isActive,
                                onChanged: (v) => setState(() => _isActive = v ?? true),
                                title: const Text('Aktívna karta'),
                                controlAffinity: ListTileControlAffinity.leading,
                                contentPadding: EdgeInsets.zero,
                              ),
                              CheckboxListTile(
                                value: _temporarilyUnavailable,
                                onChanged: (v) => setState(() => _temporarilyUnavailable = v ?? false),
                                title: const Text('Dočasne nedostupná (sivá)'),
                                controlAffinity: ListTileControlAffinity.leading,
                                contentPadding: EdgeInsets.zero,
                              ),
                              CheckboxListTile(
                                value: _hasExtendedPricing,
                                onChanged: (v) => setState(() => _hasExtendedPricing = v ?? false),
                                title: const Text('Rozšírená cenotvorba (fialová)'),
                                controlAffinity: ListTileControlAffinity.leading,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                          if (_isReceptura) ...[
                            const SizedBox(height: 12),
                            _section(
                              'Zložky receptúry',
                              [
                                Text(
                                  'Receptúra sa skladá z nasledujúcich surovín (produktov). Pri výdaji sa z každého odpočíta potrebné množstvo.',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                ),
                                const SizedBox(height: 10),
                                ...List.generate(_recepturaZlozky.length, (i) {
                                  final z = _recepturaZlozky[i];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _productNameForId(z.idSuroviny),
                                            style: const TextStyle(fontSize: 14),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        SizedBox(
                                          width: 72,
                                          child: Text(
                                            '${z.mnozstvo}',
                                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 22),
                                          onPressed: () => _removeRecepturaZlozka(i),
                                          tooltip: 'Odstrániť',
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: _showAddRecepturaZlozkaDialog,
                                  icon: const Icon(Icons.add_rounded, size: 20),
                                  label: const Text('Pridať surovinu'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _accent,
                                    side: BorderSide(color: _accent.withValues(alpha: 0.7)),
                                  ),
                                ),
                              ],
                            ),
                          ],
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
