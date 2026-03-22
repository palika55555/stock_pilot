import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/recipe.dart';
import '../../models/production_order.dart';
import '../../services/Recipe/recipe_service.dart';
import '../../services/ProductionOrder/production_order_service.dart';
import 'production_order_detail_screen.dart';

class ProductionOrderCreateScreen extends StatefulWidget {
  final int recipeId;
  final String userRole;

  const ProductionOrderCreateScreen({super.key, required this.recipeId, required this.userRole});

  @override
  State<ProductionOrderCreateScreen> createState() => _ProductionOrderCreateScreenState();
}

class _ProductionOrderCreateScreenState extends State<ProductionOrderCreateScreen> {
  final RecipeService _recipeService = RecipeService();
  final ProductionOrderService _orderService = ProductionOrderService();

  Recipe? _recipe;
  List<RecipeIngredientWithStock> _ingredientsWithStock = [];
  final _plannedQtyController = TextEditingController(text: '1');
  DateTime _productionDate = DateTime.now();
  String? _notes;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _plannedQtyController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _recipe = await _recipeService.getRecipeById(widget.recipeId);
    if (_recipe == null) {
      if (mounted) Navigator.pop(context);
      return;
    }
    await _refreshIngredients();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _refreshIngredients() async {
    final planned = double.tryParse(_plannedQtyController.text.replaceAll(',', '.')) ?? 1;
    final list = await _recipeService.getIngredientsWithStock(
      widget.recipeId,
      _recipe!.productionWarehouseId,
      planned,
    );
    if (mounted) setState(() => _ingredientsWithStock = list);
  }

  bool get _hasInsufficientStock =>
      _ingredientsWithStock.any((e) => !e.hasEnoughStock);

  Future<void> _createOrder({bool submitForApproval = false}) async {
    final planned = double.tryParse(_plannedQtyController.text.replaceAll(',', '.'));
    if (planned == null || planned <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zadajte platné plánované množstvo.')));
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('current_user_username') ?? '';
    final recipe = _recipe!;
    final requiresApproval = recipe.minApprovalQuantity > 0 && planned >= recipe.minApprovalQuantity;
    setState(() => _saving = true);
    final orderNumber = await _orderService.getNextOrderNumber();
    final order = ProductionOrder(
      orderNumber: orderNumber,
      recipeId: recipe.id!,
      recipeName: recipe.name,
      plannedQuantity: planned,
      productionDate: _productionDate,
      sourceWarehouseId: recipe.productionWarehouseId,
      destinationWarehouseId: recipe.outputWarehouseId,
      notes: _notes?.trim().isEmpty == true ? null : _notes?.trim(),
      status: submitForApproval && requiresApproval ? ProductionOrderStatus.pending : ProductionOrderStatus.draft,
      requiresApproval: requiresApproval,
      createdByUsername: username.isEmpty ? null : username,
      createdAt: DateTime.now(),
      submittedAt: submitForApproval && requiresApproval ? DateTime.now() : null,
    );
    final id = await _orderService.createOrder(order: order);
    if (submitForApproval && requiresApproval) {
      await _orderService.submitForApproval(id, username);
    }
    if (mounted) {
      setState(() => _saving = false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ProductionOrderDetailScreen(orderId: id, userRole: widget.userRole),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _recipe == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final recipe = _recipe!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Výrobný príkaz'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Receptúra: ${recipe.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text('Výsledný produkt: ${recipe.finishedProductName ?? recipe.finishedProductUniqueId}'),
                    Text('${recipe.outputQuantity} ${recipe.unit} na dávku'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _plannedQtyController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Plánované množstvo *',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _refreshIngredients(),
            ),
            const SizedBox(height: 12),
            ListTile(
              title: const Text('Dátum výroby'),
              subtitle: Text('${_productionDate.day}. ${_productionDate.month}. ${_productionDate.year}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _productionDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _productionDate = picked);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: (v) => _notes = v,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Poznámka',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Suroviny', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_hasInsufficientStock)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Upozornenie: Niektoré suroviny nemajú dostatočné zásoby. Výrobu je možné uložiť, ale dokončenie bude možné až po doplnení zásob.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ..._ingredientsWithStock.map((e) {
              return Card(
                color: e.hasEnoughStock ? null : Colors.red.shade50,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(e.ingredient.productName ?? e.ingredient.productUniqueId),
                  subtitle: Text(
                    'Potrebné: ${e.requiredForPlanned.toStringAsFixed(2)} ${e.unit} • Skladom: ${e.stockOnHand.toStringAsFixed(2)}'
                    '${!e.hasEnoughStock ? " • Chýba: ${(e.requiredForPlanned - e.stockOnHand).toStringAsFixed(2)}" : ""}',
                  ),
                  trailing: e.hasEnoughStock
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : const Icon(Icons.error, color: Colors.red),
                ),
              );
            }),
            const SizedBox(height: 24),
            if (_saving)
              const Center(child: CircularProgressIndicator())
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton(
                    onPressed: () => _createOrder(submitForApproval: false),
                    child: const Text('Uložiť ako rozpracovaný'),
                  ),
                  const SizedBox(height: 8),
                  if (recipe.minApprovalQuantity > 0)
                    ElevatedButton(
                      onPressed: () => _createOrder(submitForApproval: true),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2196F3)),
                      child: const Text('Uložiť a odoslať na schválenie'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
