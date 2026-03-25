import 'package:flutter/material.dart';
import 'package:stock_pilot/models/paving_stone.dart';
import 'package:stock_pilot/services/paving_stone_service.dart';
import 'package:stock_pilot/services/Database/database_service.dart';
import 'package:stock_pilot/theme/app_theme.dart';

class PavingStoneListScreen extends StatefulWidget {
  const PavingStoneListScreen({super.key});

  @override
  State<PavingStoneListScreen> createState() => _PavingStoneListScreenState();
}

class _PavingStoneListScreenState extends State<PavingStoneListScreen> {
  final _service = PavingStoneService();
  List<PavingStone> _stones = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final stones = await _service.getPavingStones(DatabaseService.currentUserId);
    if (mounted) setState(() { _stones = stones; _loading = false; });
  }

  Future<void> _openForm({PavingStone? stone}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _PavingStoneFormDialog(stone: stone),
    );
    if (result == true) _load();
  }

  Future<void> _delete(PavingStone stone) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Vymazať dlažbu?'),
        content: Text('${stone.name} bude vymazaná. Výrobné šarže ostanú, ale stratia väzbu na dlažbu.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Zrušiť')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Vymazať')),
        ],
      ),
    );
    if (confirm == true) {
      await _service.deletePavingStone(stone.id!);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Katalóg dlažieb', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w900)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _stones.isEmpty
              ? const Center(child: Text('Žiadne dlažby. Pridajte prvú.', style: TextStyle(color: AppColors.textSecondary)))
              : ListView.builder(
                  itemCount: _stones.length,
                  itemBuilder: (_, i) {
                    final s = _stones[i];
                    return ListTile(
                      title: Text(s.name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '${s.lengthMm.toInt()}×${s.widthMm.toInt()}×${s.thicknessMm.toInt()} mm  |  '
                        '${s.piecesPerLayer} ks/vrstva  |  ${s.layersPerPallet} vrstiev/paleta  |  '
                        '${s.m2PerPallet.toStringAsFixed(2)} m²/paleta',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _openForm(stone: s)),
                          IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(s)),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

class _PavingStoneFormDialog extends StatefulWidget {
  final PavingStone? stone;
  const _PavingStoneFormDialog({this.stone});

  @override
  State<_PavingStoneFormDialog> createState() => _PavingStoneFormDialogState();
}

class _PavingStoneFormDialogState extends State<_PavingStoneFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _service = PavingStoneService();

  late final TextEditingController _name;
  late final TextEditingController _length;
  late final TextEditingController _width;
  late final TextEditingController _thickness;
  late final TextEditingController _pcsPerLayer;
  late final TextEditingController _layersPerPallet;

  @override
  void initState() {
    super.initState();
    final s = widget.stone;
    _name          = TextEditingController(text: s?.name ?? '');
    _length        = TextEditingController(text: s?.lengthMm.toString() ?? '');
    _width         = TextEditingController(text: s?.widthMm.toString() ?? '');
    _thickness     = TextEditingController(text: s?.thicknessMm.toString() ?? '');
    _pcsPerLayer   = TextEditingController(text: s?.piecesPerLayer.toString() ?? '');
    _layersPerPallet = TextEditingController(text: s?.layersPerPallet.toString() ?? '');
  }

  @override
  void dispose() {
    for (final c in [_name, _length, _width, _thickness, _pcsPerLayer, _layersPerPallet]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _positiveDouble(String? v) {
    if (v == null || v.isEmpty) return 'Povinné';
    final n = double.tryParse(v.replaceAll(',', '.'));
    if (n == null || n <= 0) return 'Zadajte kladné číslo';
    return null;
  }

  String? _positiveInt(String? v) {
    if (v == null || v.isEmpty) return 'Povinné';
    final n = int.tryParse(v);
    if (n == null || n <= 0) return 'Minimálne 1';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final stone = PavingStone(
      id: widget.stone?.id,
      name: _name.text.trim(),
      lengthMm: double.parse(_length.text.replaceAll(',', '.')),
      widthMm: double.parse(_width.text.replaceAll(',', '.')),
      thicknessMm: double.parse(_thickness.text.replaceAll(',', '.')),
      piecesPerLayer: int.parse(_pcsPerLayer.text),
      layersPerPallet: int.parse(_layersPerPallet.text),
      userId: DatabaseService.currentUserId,
    );
    if (widget.stone?.id != null) {
      await _service.updatePavingStone(stone);
    } else {
      await _service.insertPavingStone(stone);
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.stone != null ? 'Upraviť dlažbu' : 'Nová dlažba'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Názov', border: OutlineInputBorder()), validator: (v) => v == null || v.trim().isEmpty ? 'Povinné' : null),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextFormField(controller: _length, decoration: const InputDecoration(labelText: 'Dĺžka (mm)', border: OutlineInputBorder()), keyboardType: TextInputType.number, validator: _positiveDouble)),
                const SizedBox(width: 8),
                Expanded(child: TextFormField(controller: _width, decoration: const InputDecoration(labelText: 'Šírka (mm)', border: OutlineInputBorder()), keyboardType: TextInputType.number, validator: _positiveDouble)),
                const SizedBox(width: 8),
                Expanded(child: TextFormField(controller: _thickness, decoration: const InputDecoration(labelText: 'Výška (mm)', border: OutlineInputBorder()), keyboardType: TextInputType.number, validator: _positiveDouble)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextFormField(controller: _pcsPerLayer, decoration: const InputDecoration(labelText: 'Ks/vrstva', border: OutlineInputBorder()), keyboardType: TextInputType.number, validator: _positiveInt)),
                const SizedBox(width: 8),
                Expanded(child: TextFormField(controller: _layersPerPallet, decoration: const InputDecoration(labelText: 'Vrstvy/paleta', border: OutlineInputBorder()), keyboardType: TextInputType.number, validator: _positiveInt)),
              ]),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Zrušiť')),
        FilledButton(onPressed: _save, child: const Text('Uložiť')),
      ],
    );
  }
}
