import 'package:flutter/material.dart';
import 'package:stock_pilot/models/pallet.dart';
import 'package:stock_pilot/models/production_batch.dart';
import 'package:stock_pilot/services/Database/database_service.dart';

/// Dialog: počet kusov na paletu, počet paliet. Po potvrdení vytvorí palety a vráti ich zoznam.
class CreatePalletsDialog extends StatefulWidget {
  final ProductionBatch batch;

  const CreatePalletsDialog({super.key, required this.batch});

  @override
  State<CreatePalletsDialog> createState() => _CreatePalletsDialogState();
}

class _CreatePalletsDialogState extends State<CreatePalletsDialog> {
  late final TextEditingController _qtyController;
  late final TextEditingController _countController;
  bool _recalculating = false;

  @override
  void initState() {
    super.initState();
    final total = widget.batch.quantityProduced;
    final defaultCount = total > 0 ? 5.clamp(1, total) : 1;
    final defaultQty = total > 0 ? (total / defaultCount).floor().clamp(1, total) : 1;
    _qtyController = TextEditingController(text: '$defaultQty');
    _countController = TextEditingController(text: '$defaultCount');
    _qtyController.addListener(_onQtyChanged);
    _countController.addListener(_onCountChanged);
  }

  void _onQtyChanged() {
    if (_recalculating) return;
    final total = widget.batch.quantityProduced;
    final qty = int.tryParse(_qtyController.text);
    if (qty == null || qty <= 0 || total <= 0) return;
    final count = (total / qty).ceil().clamp(1, total);
    if (int.tryParse(_countController.text) == count) return;
    _recalculating = true;
    _countController.text = '$count';
    _recalculating = false;
  }

  void _onCountChanged() {
    if (_recalculating) return;
    final total = widget.batch.quantityProduced;
    final count = int.tryParse(_countController.text);
    if (count == null || count <= 0 || total <= 0) return;
    final qty = (total / count).floor().clamp(1, total);
    if (int.tryParse(_qtyController.text) == qty) return;
    _recalculating = true;
    _qtyController.text = '$qty';
    _recalculating = false;
  }

  @override
  void dispose() {
    _qtyController.removeListener(_onQtyChanged);
    _countController.removeListener(_onCountChanged);
    _qtyController.dispose();
    _countController.dispose();
    super.dispose();
  }

  Future<List<Pallet>?> _create() async {
    final qty = int.tryParse(_qtyController.text);
    final count = int.tryParse(_countController.text);
    if (qty == null || qty <= 0 || count == null || count <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zadajte platný počet kusov a počet paliet')),
      );
      return null;
    }
    final total = qty * count;
    if (total > widget.batch.quantityProduced) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Celkom $total kusov prevyšuje počet vyrobených (${widget.batch.quantityProduced}).',
          ),
        ),
      );
      return null;
    }
    final db = DatabaseService();
    final created = <Pallet>[];
    for (var i = 0; i < count; i++) {
      final id = await db.insertPallet(Pallet(
        batchId: widget.batch.id!,
        productType: widget.batch.productType,
        quantity: qty,
        status: PalletStatus.naSklade,
      ));
      final p = await db.getPalletById(id);
      if (p != null) created.add(p);
    }
    return created;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Vytvoriť palety'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Šarža: ${widget.batch.productType} (${widget.batch.quantityProduced} ks)',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _qtyController,
            decoration: const InputDecoration(
              labelText: 'Počet kusov na jednu paletu',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _countController,
            decoration: const InputDecoration(
              labelText: 'Počet paliet',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Zrušiť'),
        ),
        FilledButton(
          onPressed: () async {
            final list = await _create();
            if (!mounted || list == null) return;
            Navigator.pop(context, list);
          },
          child: const Text('Vytvoriť'),
        ),
      ],
    );
  }
}
