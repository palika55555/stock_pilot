import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:stock_pilot/models/paving_stone.dart';
import 'package:stock_pilot/models/production_batch.dart';
import 'package:stock_pilot/models/production_batch_recipe_item.dart';
import 'package:stock_pilot/services/Database/database_service.dart';
import 'package:stock_pilot/services/api_sync_service.dart';
import 'package:stock_pilot/services/paving_stone_service.dart';
import 'package:stock_pilot/theme/app_theme.dart';

const List<String> _defaultProductTypes = [
  'Zamková dlažba',
  'Tvárnice',
  'Obrubníky',
  'Dlažobné kostky',
  'Iné',
];

/// Preddefinované receptúrne položky + vlastné frakcie.
class RecipeRow {
  String materialName;
  double quantity;
  String unit;

  RecipeRow({required this.materialName, this.quantity = 0, this.unit = 'kg'});
}

class ProductionBatchFormScreen extends StatefulWidget {
  final DateTime initialDate;
  final ProductionBatch? editBatch;

  const ProductionBatchFormScreen({
    super.key,
    required this.initialDate,
    this.editBatch,
  });

  @override
  State<ProductionBatchFormScreen> createState() => _ProductionBatchFormScreenState();
}

class _ProductionBatchFormScreenState extends State<ProductionBatchFormScreen> {
  final DatabaseService _db = DatabaseService();
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  late DateTime _productionDate;
  late String _productType;
  late int _quantityProduced;
  String _notes = '';
  double? _costTotal;
  double? _revenueTotal;

  List<PavingStone> _pavingStones = [];
  PavingStone? _selectedPavingStone;
  double _requestedM2 = 0;
  PavingStoneCalculation? _calc;
  bool _hasPallets = false;

  final List<RecipeRow> _recipeRows = [
    RecipeRow(materialName: 'Voda', unit: 'l'),
    RecipeRow(materialName: 'Plastifikátor', unit: 'kg'),
    RecipeRow(materialName: 'Cement', unit: 'kg'),
    RecipeRow(materialName: 'Štrk', unit: 'kg'),
    RecipeRow(materialName: 'Štrk 0–4 mm', unit: 'kg'),
    RecipeRow(materialName: 'Štrk 4–8 mm', unit: 'kg'),
    RecipeRow(materialName: 'Štrk 8–16 mm', unit: 'kg'),
    RecipeRow(materialName: 'Štrk 16–32 mm', unit: 'kg'),
  ];
  final List<RecipeRow> _customFractionRows = [];
  List<String> get _productTypes {
    final list = List<String>.from(_defaultProductTypes);
    if (widget.editBatch != null &&
        widget.editBatch!.productType.isNotEmpty &&
        !list.contains(widget.editBatch!.productType)) {
      list.add(widget.editBatch!.productType);
    }
    return list;
  }

  @override
  void initState() {
    super.initState();
    _productionDate = widget.initialDate;
    _productType = _defaultProductTypes.first;
    _quantityProduced = 0;
    if (widget.editBatch != null) {
      _productionDate = DateTime.parse(widget.editBatch!.productionDate);
      _productType = widget.editBatch!.productType;
      _quantityProduced = widget.editBatch!.quantityProduced;
      _notes = widget.editBatch!.notes ?? '';
      _costTotal = widget.editBatch!.costTotal;
      _revenueTotal = widget.editBatch!.revenueTotal;
      _requestedM2 = widget.editBatch!.requestedM2 ?? 0;
      _loadRecipe();
      _checkHasPallets();
    }
    _loadPavingStones();
  }

  Future<void> _loadRecipe() async {
    if (widget.editBatch?.id == null) return;
    final items = await _db.getRecipeForBatch(widget.editBatch!.id!);
    for (final item in items) {
      final existing = _recipeRows.where((r) => r.materialName == item.materialName).firstOrNull;
      if (existing != null) {
        existing.quantity = item.quantity;
      } else {
        _customFractionRows.add(RecipeRow(
          materialName: item.materialName,
          quantity: item.quantity,
          unit: item.unit,
        ));
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_productionDate);
      final batch = ProductionBatch(
        id: widget.editBatch?.id,
        productionDate: dateStr,
        productType: _productType,
        quantityProduced: _quantityProduced,
        notes: _notes.isEmpty ? null : _notes,
        createdAt: widget.editBatch?.createdAt ?? DateTime.now().toIso8601String(),
        costTotal: _costTotal,
        revenueTotal: _revenueTotal,
        pavingStoneId: _selectedPavingStone?.id,
        requestedM2: _selectedPavingStone != null ? _requestedM2 : null,
        actualStoredM2: _calc?.actualM2,
      );

      int batchId;
      if (widget.editBatch?.id != null) {
        await _db.updateProductionBatch(batch);
        batchId = widget.editBatch!.id!;
        await _db.deleteProductionBatchRecipeItems(batchId);
      } else {
        batchId = await _db.insertProductionBatch(batch);
      }

      final allRows = [..._recipeRows, ..._customFractionRows];
      for (final row in allRows) {
        if (row.quantity <= 0) continue;
        await _db.insertProductionBatchRecipeItem(ProductionBatchRecipeItem(
          batchId: batchId,
          materialName: row.materialName,
          quantity: row.quantity,
          unit: row.unit,
        ));
      }

      if (!mounted) return;
      syncBatchesToBackend();
      // Úprava: späť na detail s výsledkom. Nová šarža: vrátiť ID — zoznam otvorí detail a obnoví sa.
      if (widget.editBatch?.id != null) {
        Navigator.pop(context, true);
      } else {
        Navigator.pop(context, batchId);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chyba pri ukladaní: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addCustomFraction() {
    setState(() {
      _customFractionRows.add(RecipeRow(materialName: 'Frakcia', unit: 'kg'));
    });
  }

  Future<void> _loadPavingStones() async {
    final stones = await PavingStoneService().getPavingStones(DatabaseService.currentUserId);
    if (mounted) setState(() => _pavingStones = stones);
  }

  Future<void> _checkHasPallets() async {
    if (widget.editBatch?.id == null) return;
    final pallets = await _db.getPalletsByBatchId(widget.editBatch!.id!);
    if (mounted) setState(() => _hasPallets = pallets.isNotEmpty);
  }

  void _onPavingStoneSelected(PavingStone? stone) {
    setState(() {
      _selectedPavingStone = stone;
      if (stone != null) _productType = stone.name;
      _calc = null;
    });
  }

  void _onM2Changed(String value) {
    final m2 = double.tryParse(value.replaceAll(',', '.'));
    if (m2 != null && m2 > 0 && _selectedPavingStone != null) {
      setState(() {
        _requestedM2 = m2;
        _calc = PavingStoneService.calculate(m2, _selectedPavingStone!);
        _quantityProduced = _calc!.totalPieces;
      });
    } else {
      setState(() { _calc = null; _quantityProduced = 0; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.bgPrimary,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: false,
              title: Text(
                widget.editBatch != null ? 'Upraviť šaržu' : 'Nová šarža',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                ),
              ),
              actions: [
                if (_saving)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  TextButton(
                    onPressed: _save,
                    child: const Text('Uložiť'),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 88, 16, 32),
          children: [
            const Text('Dátum výroby', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            InkWell(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _productionDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (d != null) setState(() => _productionDate = d);
              },
              child: InputDecorator(
                decoration: const InputDecoration(border: OutlineInputBorder()),
                child: Text(DateFormat('d. M. yyyy', 'sk').format(_productionDate)),
              ),
            ),
            const SizedBox(height: 16),
            if (_pavingStones.isNotEmpty) ...[
              const Text('Typ výrobku — dlažba', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              DropdownButtonFormField<PavingStone>(
                value: _selectedPavingStone,
                decoration: const InputDecoration(labelText: 'Vyberte dlažbu (m²)', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem<PavingStone>(value: null, child: Text('— Žiadna —')),
                  ..._pavingStones.map((s) => DropdownMenuItem(
                    value: s,
                    child: Text('${s.name} (${s.m2PerPallet.toStringAsFixed(2)} m²/paleta)'),
                  )),
                ],
                onChanged: _onPavingStoneSelected,
              ),
              const SizedBox(height: 8),
            ],
            if (_selectedPavingStone == null)
              DropdownButtonFormField<String>(
                value: _productTypes.contains(_productType) ? _productType : null,
                decoration: const InputDecoration(labelText: 'Typ výrobku', border: OutlineInputBorder()),
                items: _productTypes.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() => _productType = v ?? _defaultProductTypes.first),
              ),
            const SizedBox(height: 16),
            if (_selectedPavingStone != null) ...[
              AbsorbPointer(
                absorbing: _hasPallets,
                child: TextFormField(
                  initialValue: _requestedM2 > 0 ? _requestedM2.toString() : '',
                  decoration: InputDecoration(
                    labelText: 'Požadované m²',
                    border: const OutlineInputBorder(),
                    suffixText: 'm²',
                    helperText: _hasPallets ? 'Uzamknuté — palety už existujú' : null,
                    filled: _hasPallets,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Zadajte m²';
                    final n = double.tryParse(v.replaceAll(',', '.'));
                    if (n == null || n <= 0) return 'Zadajte kladné číslo';
                    return null;
                  },
                  onChanged: _onM2Changed,
                ),
              ),
              if (_calc != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.bgPrimary,
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '→ ${_calc!.totalPieces} ks  |  '
                    '${_calc!.fullPallets} paliet'
                    '${_calc!.remainingLayers > 0 ? " + ${_calc!.remainingLayers} vrstvy" : ""}  |  '
                    'skutočné m²: ${_calc!.actualM2.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ] else
              TextFormField(
                initialValue: _quantityProduced == 0 ? '' : _quantityProduced.toString(),
                decoration: const InputDecoration(
                  labelText: 'Počet vyrobených kusov',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Zadajte počet';
                  final n = int.tryParse(v);
                  if (n == null || n < 0) return 'Neplatný počet';
                  return null;
                },
                onSaved: (v) => _quantityProduced = int.tryParse(v ?? '0') ?? 0,
                onChanged: (v) => _quantityProduced = int.tryParse(v) ?? 0,
              ),
            const SizedBox(height: 20),
            const Divider(),
            const Text('Receptúra (materiály)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            ..._recipeRows.map((row) => _recipeRowWidget(row)),
            ..._customFractionRows.map((row) => _recipeRowWidget(row, isCustom: true)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _addCustomFraction,
              icon: const Icon(Icons.add),
              label: const Text('Pridať frakciu / materiál'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _notes,
              decoration: const InputDecoration(
                labelText: 'Poznámky',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 2,
              onChanged: (v) => _notes = v,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _costTotal?.toString(),
                    decoration: const InputDecoration(labelText: 'Náklady (€)', border: OutlineInputBorder()),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) => _costTotal = double.tryParse(v.replaceAll(',', '.')),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    initialValue: _revenueTotal?.toString(),
                    decoration: const InputDecoration(labelText: 'Výnosy (€)', border: OutlineInputBorder()),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) => _revenueTotal = double.tryParse(v.replaceAll(',', '.')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: _saving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Uložiť šaržu a zobraziť QR kód'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recipeRowWidget(RecipeRow row, {bool isCustom = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: isCustom
                ? TextFormField(
                    initialValue: row.materialName,
                    decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                    onChanged: (v) => row.materialName = v,
                  )
                : Text(row.materialName, style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              initialValue: row.quantity > 0 ? row.quantity.toString() : '',
              decoration: InputDecoration(
                isDense: true,
                border: const OutlineInputBorder(),
                suffixText: row.unit,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) => row.quantity = double.tryParse(v.replaceAll(',', '.')) ?? 0,
            ),
          ),
          if (isCustom)
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: () {
                setState(() => _customFractionRows.remove(row));
              },
            ),
        ],
      ),
    );
  }
}
