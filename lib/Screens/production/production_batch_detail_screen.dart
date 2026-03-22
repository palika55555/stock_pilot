import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:stock_pilot/models/production_batch.dart';
import 'package:stock_pilot/models/pallet.dart';
import 'package:stock_pilot/models/production_batch_recipe_item.dart';
import 'package:stock_pilot/services/Database/database_service.dart';
import 'package:stock_pilot/services/api_sync_service.dart';
import 'package:stock_pilot/screens/production/production_batch_form_screen.dart';
import 'package:stock_pilot/screens/pallet/create_pallets_dialog.dart';
import 'package:stock_pilot/screens/pallet/pallet_labels_screen.dart';
import 'package:stock_pilot/theme/app_theme.dart';

class ProductionBatchDetailScreen extends StatefulWidget {
  final int batchId;

  const ProductionBatchDetailScreen({super.key, required this.batchId});

  @override
  State<ProductionBatchDetailScreen> createState() => _ProductionBatchDetailScreenState();
}

class _ProductionBatchDetailScreenState extends State<ProductionBatchDetailScreen> {
  final DatabaseService _db = DatabaseService();
  ProductionBatch? _batch;
  List<ProductionBatchRecipeItem> _recipe = [];
  List<Pallet> _pallets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final batch = await _db.getProductionBatchById(widget.batchId);
    final recipe = await _db.getRecipeForBatch(widget.batchId);
    final pallets = await _db.getPalletsByBatchId(widget.batchId);
    if (mounted) {
      setState(() {
        _batch = batch;
        _recipe = recipe;
        _pallets = pallets;
        _loading = false;
      });
    }
  }

  Future<void> _edit() async {
    if (_batch == null) return;
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ProductionBatchFormScreen(
          initialDate: DateTime.parse(_batch!.productionDate),
          editBatch: _batch,
        ),
      ),
    );
    if (updated == true) _load();
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Zmazať šaržu?'),
        content: const Text('Táto akcia je nevratná. Naozaj chcete zmazať túto šaržu?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Zrušiť')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Zmazať'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await _db.deleteProductionBatch(widget.batchId);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.bgPrimary,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_batch == null) {
      return Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: AppBar(
          backgroundColor: AppColors.bgPrimary,
          title: const Text('Šarža'),
        ),
        body: const Center(
          child: Text('Šarža nebola nájdená', style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    final payload = DatabaseService.productionBatchQrPayload(widget.batchId);

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
                _batch!.productType,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                ),
              ),
              actions: [
                IconButton(icon: const Icon(Icons.edit, color: AppColors.textPrimary), onPressed: _edit),
                IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.textPrimary), onPressed: _delete),
              ],
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 88, 16, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('QR kód šarže', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(height: 12),
                  QrImageView(
                    data: payload,
                    version: QrVersions.auto,
                    size: 200,
                    backgroundColor: Colors.white,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Dátum: ${DateFormat('d. M. yyyy', 'sk').format(DateTime.parse(_batch!.productionDate))}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  Text('Počet kusov: ${_batch!.quantityProduced}'),
                  if (_batch!.costTotal != null)
                    Text('Náklady (zadané): ${_batch!.costTotal!.toStringAsFixed(2)} €'),
                  if (_batch!.revenueTotal != null)
                    Text('Výnosy (zadané): ${_batch!.revenueTotal!.toStringAsFixed(2)} €'),
                  if (_batch!.marginPercent != null)
                    Text(
                      'Marža: ${_batch!.marginPercent!.toStringAsFixed(1)} %',
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.success),
                    ),
                  if (_batch!.notes != null && _batch!.notes!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('Poznámky: ${_batch!.notes}', style: const TextStyle(fontStyle: FontStyle.italic)),
                    ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () async {
                      final list = await showDialog<List<Pallet>>(
                        context: context,
                        builder: (context) => CreatePalletsDialog(batch: _batch!),
                      );
                      if (list == null || list.isEmpty) return;
                      await _load();
                      if (!context.mounted) return;
                      await syncBatchesToBackend();
                      if (!context.mounted) return;
                      await Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PalletLabelsScreen(
                            pallets: list,
                            productName: _batch!.productType,
                            productionDate: _batch!.productionDate,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.local_shipping_rounded),
                    label: const Text('Vytvoriť palety'),
                  ),
                ],
              ),
            ),
          ),
          if (_pallets.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Palety z tejto šarže', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ..._pallets.map((p) => ListTile(
                        leading: const Icon(Icons.local_shipping_outlined),
                        title: Text('${p.productType} – ${p.quantity} ks'),
                        subtitle: Text('Stav: ${p.status.label}'),
                      )),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.print_outlined),
                    title: const Text('Tlačiť štítky paliet'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PalletLabelsScreen(
                            pallets: _pallets,
                            productName: _batch!.productType,
                            productionDate: _batch!.productionDate,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          const Text('Receptúra', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          if (_recipe.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Žiadne položky receptúry', style: TextStyle(color: AppColors.textMuted)),
            )
          else
            Card(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _recipe.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final r = _recipe[i];
                  return ListTile(
                    title: Text(r.materialName),
                    trailing: Text('${r.quantity} ${r.unit}'),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
