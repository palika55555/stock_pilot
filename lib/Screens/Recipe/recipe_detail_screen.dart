import 'package:flutter/material.dart';
import '../../models/recipe.dart';
import '../../models/product.dart';
import '../../models/warehouse.dart';
import '../../services/Recipe/recipe_service.dart';
import '../../services/Database/database_service.dart';
import '../../services/Warehouse/warehouse_service.dart';
import '../ProductionOrder/production_order_create_screen.dart';

class RecipeDetailScreen extends StatefulWidget {
  final int? recipeId;
  final String userRole;

  const RecipeDetailScreen({super.key, required this.recipeId, required this.userRole});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  final RecipeService _recipeService = RecipeService();
  final DatabaseService _db = DatabaseService();
  final WarehouseService _warehouseService = WarehouseService();

  final _nameController = TextEditingController();
  final _outputQtyController = TextEditingController(text: '1');
  final _unitController = TextEditingController(text: 'ks');
  final _productionTimeController = TextEditingController();
  final _noteController = TextEditingController();
  final _minApprovalController = TextEditingController(text: '0');
  final _marginPercentController = TextEditingController(text: '30');

  List<Product> _products = [];
  List<Warehouse> _warehouses = [];
  List<RecipeIngredient> _ingredients = [];
  String? _finishedProductUniqueId;
  int? _productionWarehouseId;
  int? _outputWarehouseId;
  bool _isActive = true;
  bool _loading = true;
  double _materialCostPerUnit = 0;
  Product? _finishedProduct;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _outputQtyController.dispose();
    _unitController.dispose();
    _productionTimeController.dispose();
    _noteController.dispose();
    _minApprovalController.dispose();
    _marginPercentController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    _products = await _db.getProducts();
    _warehouses = await _warehouseService.getActiveWarehouses();
    if (widget.recipeId != null) {
      final recipe = await _recipeService.getRecipeById(widget.recipeId!);
      if (recipe != null) {
        _nameController.text = recipe.name;
        _finishedProductUniqueId = recipe.finishedProductUniqueId;
        _outputQtyController.text = recipe.outputQuantity.toString();
        _unitController.text = recipe.unit;
        _productionWarehouseId = recipe.productionWarehouseId;
        _outputWarehouseId = recipe.outputWarehouseId;
        _productionTimeController.text = recipe.productionTimeMinutes?.toString() ?? '';
        _noteController.text = recipe.note ?? '';
        _minApprovalController.text = recipe.minApprovalQuantity.toString();
        _isActive = recipe.isActive;
        _ingredients = await _recipeService.getRecipeIngredients(widget.recipeId!);
        try {
          _finishedProduct = _products.firstWhere((p) => p.uniqueId == recipe.finishedProductUniqueId);
        } catch (_) {
          _finishedProduct = null;
        }
      }
    }
    await _refreshCost();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _refreshCost() async {
    if (widget.recipeId == null) return;
    final cost = await _recipeService.materialCostPerUnit(widget.recipeId!, _productionWarehouseId);
    if (mounted) setState(() => _materialCostPerUnit = cost);
  }

  Future<bool> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Názov receptúry je povinný.')));
      return false;
    }
    final outputQty = double.tryParse(_outputQtyController.text.replaceAll(',', '.')) ?? 1;
    if (outputQty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Výsledné množstvo musí byť väčšie ako 0.')));
      return false;
    }
    if (_finishedProductUniqueId == null || _finishedProductUniqueId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vyberte výsledný produkt.')));
      return false;
    }
    final recipe = Recipe(
      id: widget.recipeId,
      name: name,
      finishedProductUniqueId: _finishedProductUniqueId!,
      finishedProductName: _finishedProduct?.name,
      outputQuantity: outputQty,
      unit: _unitController.text.trim().isEmpty ? 'ks' : _unitController.text.trim(),
      productionWarehouseId: _productionWarehouseId,
      outputWarehouseId: _outputWarehouseId,
      productionTimeMinutes: int.tryParse(_productionTimeController.text),
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      isActive: _isActive,
      minApprovalQuantity: double.tryParse(_minApprovalController.text.replaceAll(',', '.')) ?? 0,
    );
    final ings = _ingredients
        .map((e) => RecipeIngredient(
              recipeId: 0,
              productUniqueId: e.productUniqueId,
              productName: e.productName,
              plu: e.plu,
              quantity: e.quantity,
              unit: e.unit,
            ))
        .toList();
    await _recipeService.saveRecipe(recipe, ings);
    return true;
  }

  void _addIngredient() {
    setState(() {
      _ingredients.add(RecipeIngredient(
        recipeId: widget.recipeId ?? 0,
        productUniqueId: _products.isNotEmpty ? _products.first.uniqueId ?? '' : '',
        productName: _products.isNotEmpty ? _products.first.name : null,
        plu: _products.isNotEmpty ? _products.first.plu : null,
        quantity: 1,
        unit: 'ks',
      ));
    });
  }

  void _removeIngredient(int index) {
    setState(() => _ingredients.removeAt(index));
  }

  void _updateIngredientProduct(int index, String uniqueId) {
    Product? p;
    try {
      p = _products.firstWhere((x) => x.uniqueId == uniqueId);
    } catch (_) {
      p = null;
    }
    setState(() {
      _ingredients[index] = _ingredients[index].copyWith(
        productUniqueId: uniqueId,
        productName: p?.name,
        plu: p?.plu,
        unit: p?.unit ?? _ingredients[index].unit,
      );
    });
  }

  void _updateIngredientQty(int index, String v) {
    final qty = double.tryParse(v.replaceAll(',', '.')) ?? _ingredients[index].quantity;
    setState(() => _ingredients[index] = _ingredients[index].copyWith(quantity: qty));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipeId == null ? 'Nová receptúra' : 'Receptúra'),
        actions: [
          TextButton(
            onPressed: () async {
              if (await _save()) {
                if (mounted) Navigator.pop(context, true);
              }
            },
            child: const Text('Uložiť'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Názov receptúry *'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              value: _finishedProductUniqueId,
              decoration: const InputDecoration(labelText: 'Výsledný produkt *'),
              items: [
                const DropdownMenuItem(value: null, child: Text('-- Vyberte produkt --')),
                ..._products.map((p) => DropdownMenuItem(value: p.uniqueId, child: Text('${p.name} (${p.plu})'))),
              ],
              onChanged: (v) {
                setState(() {
                  _finishedProductUniqueId = v;
                  if (v == null) {
                    _finishedProduct = null;
                  } else {
                    try {
                      _finishedProduct = _products.firstWhere((p) => p.uniqueId == v);
                    } catch (_) {
                      _finishedProduct = null;
                    }
                  }
                });
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _outputQtyController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Výsledné množstvo *'),
                    onChanged: (_) => _refreshCost(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _unitController,
                    decoration: const InputDecoration(labelText: 'Jednotka'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _productionWarehouseId,
              decoration: const InputDecoration(labelText: 'Sklad výroby'),
              items: _warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
              onChanged: (v) {
                setState(() {
                  _productionWarehouseId = v;
                  _refreshCost();
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _outputWarehouseId,
              decoration: const InputDecoration(labelText: 'Sklad výrobku'),
              items: _warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
              onChanged: (v) => setState(() => _outputWarehouseId = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _productionTimeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Čas výroby (min)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Poznámka'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _minApprovalController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Min. množstvo pre schválenie',
                hintText: 'Nad touto hranicou musí VP na schválenie',
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Aktívna receptúra'),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
            ),
            const Divider(height: 24),
            const Text('Suroviny', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...List.generate(_ingredients.length, (i) {
              final ing = _ingredients[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<String>(
                          value: ing.productUniqueId.isEmpty ? null : ing.productUniqueId,
                          decoration: const InputDecoration(isDense: true, labelText: 'Produkt'),
                          items: _products
                              .map((p) => DropdownMenuItem(
                                    value: p.uniqueId,
                                    child: Text('${p.name}', overflow: TextOverflow.ellipsis),
                                  ))
                              .toList(),
                          onChanged: (v) => _updateIngredientProduct(i, v ?? ''),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          initialValue: ing.quantity.toString(),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(isDense: true, labelText: 'Množstvo'),
                          onChanged: (v) => _updateIngredientQty(i, v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 48,
                        child: IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                          onPressed: () => _removeIngredient(i),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _addIngredient,
              icon: const Icon(Icons.add),
              label: const Text('Pridať surovinu'),
            ),
            const Divider(height: 24),
            const Text('Kalkulácia nákladov', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Materiálové náklady na 1 ks: ${_materialCostPerUnit.toStringAsFixed(2)} €'),
                    const SizedBox(height: 12),
                    const Text('Odporúčaná predajná cena', style: TextStyle(fontWeight: FontWeight.w600)),
                    TextField(
                      controller: _marginPercentController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Požadovaná marža %'),
                    ),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) {
                        final margin = double.tryParse(_marginPercentController.text) ?? 30;
                        final cost = _materialCostPerUnit;
                        final recommendedWithoutVat = cost > 0 ? cost / (1 - margin / 100) : 0.0;
                        final vat = _finishedProduct?.vat ?? 20;
                        final recommendedWithVat = recommendedWithoutVat * (1 + vat / 100);
                        final currentPrice = _finishedProduct?.price ?? 0.0;
                        final diff = currentPrice - recommendedWithVat;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Odporúčaná cena bez DPH: ${recommendedWithoutVat.toStringAsFixed(2)} €'),
                            Text('DPH $vat %: ${recommendedWithVat.toStringAsFixed(2)} €'),
                            Text('Aktuálna predajná cena: ${currentPrice.toStringAsFixed(2)} €'),
                            Text(
                              'Rozdiel: ${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(2)} €',
                              style: TextStyle(
                                color: diff >= 0 ? Colors.green : Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (widget.recipeId != null && _isActive)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProductionOrderCreateScreen(
                        recipeId: widget.recipeId!,
                        userRole: widget.userRole,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Spustiť výrobu'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFF2E7D32),
                ),
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
