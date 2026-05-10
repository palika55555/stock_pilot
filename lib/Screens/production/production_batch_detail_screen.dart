import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:stock_pilot/models/customer.dart';
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
  List<Customer> _customers = [];
  bool _loading = true;
  int? _busyPalletId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final batch = await _db.getProductionBatchById(widget.batchId);
    final recipe = await _db.getRecipeForBatch(widget.batchId);
    final pallets = await _db.getPalletsByBatchId(widget.batchId);
    final customers = await _db.getCustomers();
    if (mounted) {
      setState(() {
        _batch = batch;
        _recipe = recipe;
        _pallets = pallets;
        _customers = customers;
        _loading = false;
      });
    }
  }

  int get _allocated => _pallets.fold(0, (sum, p) => sum + p.quantity);
  int get _onStock => _pallets.where((p) => p.status == PalletStatus.naSklade).fold(0, (s, p) => s + p.quantity);
  int get _atCustomer => _pallets.where((p) => p.status == PalletStatus.uZakaznika).fold(0, (s, p) => s + p.quantity);
  int get _sold => _pallets.where((p) => p.status.isSold).fold(0, (s, p) => s + p.quantity);
  int get _free => (_batch == null) ? 0 : (_batch!.quantityProduced - _allocated).clamp(0, 1 << 31);

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
    if (updated == true) {
      await _load();
      await syncBatchesToBackend();
    }
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
    await syncBatchesToBackend();
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _markPallet(Pallet p, PalletStatus status) async {
    setState(() => _busyPalletId = p.id);
    try {
      if (status == PalletStatus.naSklade) {
        await _db.returnPalletToStock(p.id!);
      } else if (status.isSold) {
        await _showSaleDialog(p, status);
      } else if (status == PalletStatus.uZakaznika) {
        await _showAssignCustomerDialog(p);
      } else {
        await _db.updatePallet(p.copyWith(status: status));
      }
      await _load();
      await syncBatchesToBackend();
    } finally {
      if (mounted) setState(() => _busyPalletId = null);
    }
  }

  Future<void> _showSaleDialog(Pallet p, PalletStatus status) async {
    final noteCtrl = TextEditingController(text: p.saleNote ?? '');
    DateTime when = DateTime.now();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          backgroundColor: AppColors.bgCard,
          title: Text('Označiť ako ${status.label.toLowerCase()}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_rounded, color: AppColors.accentGold),
                title: Text('Dátum: ${DateFormat('d. M. yyyy', 'sk').format(when)}'),
                trailing: TextButton(
                  child: const Text('Zmeniť'),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: when,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 30)),
                    );
                    if (picked != null) setSt(() => when = picked);
                  },
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Poznámka (faktúra, dodací list…)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Zrušiť')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Uložiť')),
          ],
        ),
      ),
    );
    noteCtrl.dispose();
    if (ok == true) {
      await _db.markPalletSold(
        p.id!,
        status: status,
        soldAt: when,
        saleNote: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
      );
    }
  }

  Future<void> _showAssignCustomerDialog(Pallet p) async {
    if (_customers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Najprv pridajte zákazníka v sekcii Zákazníci.')),
      );
      return;
    }
    int? selected = p.customerId;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          backgroundColor: AppColors.bgCard,
          title: const Text('Priradiť zákazníkovi'),
          content: SizedBox(
            width: 320,
            child: DropdownButtonFormField<int>(
              initialValue: selected,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Zákazník',
                border: OutlineInputBorder(),
              ),
              items: _customers
                  .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                  .toList(),
              onChanged: (v) => setSt(() => selected = v),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Zrušiť')),
            FilledButton(onPressed: () => Navigator.pop(ctx, selected != null), child: const Text('Priradiť')),
          ],
        ),
      ),
    );
    if (ok == true && selected != null) {
      await _db.assignPalletToCustomer(p.id!, selected!);
    }
  }

  Future<void> _deletePallet(Pallet p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Zmazať paletu?'),
        content: Text('Paleta #${p.id} – ${p.quantity} ks bude trvalo zmazaná.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Zrušiť')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Zmazať'),
          ),
        ],
      ),
    );
    if (ok == true) {
      setState(() => _busyPalletId = p.id);
      await _db.deletePallet(p.id!);
      await _load();
      await syncBatchesToBackend();
      if (mounted) setState(() => _busyPalletId = null);
    }
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
    final isPaving = _batch!.pavingStoneId != null;

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
          _buildKpiGrid(isPaving),
          const SizedBox(height: 14),
          _buildAllocationBar(),
          const SizedBox(height: 16),
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
                    size: 180,
                    backgroundColor: Colors.white,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Dátum: ${DateFormat('d. M. yyyy', 'sk').format(DateTime.parse(_batch!.productionDate))}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (_batch!.notes != null && _batch!.notes!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('Poznámky: ${_batch!.notes}', style: const TextStyle(fontStyle: FontStyle.italic)),
                    ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _free <= 0
                        ? null
                        : () async {
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
                    label: Text(_free <= 0 ? 'Všetky kusy sú na paletách' : 'Vytvoriť palety ($_free voľných)'),
                  ),
                ],
              ),
            ),
          ),
          if (_pallets.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Palety a expedícia',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ..._pallets.map(_buildPalletTile),
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
          ],
          const SizedBox(height: 16),
          const Text(
            'Receptúra',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.textPrimary),
          ),
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

  Widget _buildKpiGrid(bool isPaving) {
    final cards = <Widget>[
      _kpiCard('Vyrobené', '${_batch!.quantityProduced} ks', null, AppColors.accentGold),
      if (isPaving)
        _kpiCard(
          'Plocha',
          '${(_batch!.actualStoredM2 ?? _batch!.requestedM2 ?? 0).toStringAsFixed(2)} m²',
          _batch!.requestedM2 != null && _batch!.actualStoredM2 != null
              ? 'pož. ${_batch!.requestedM2!.toStringAsFixed(2)} m²'
              : null,
          Colors.lightBlueAccent,
        ),
      _kpiCard('Voľné kusy', '$_free', '$_allocated / ${_batch!.quantityProduced} alokované', AppColors.textSecondary),
      _kpiCard('Predané', '$_sold', 'sklad: $_onStock · u zák.: $_atCustomer', AppColors.success),
      if (_batch!.costTotal != null || _batch!.revenueTotal != null)
        _kpiCard(
          'Marža',
          _batch!.marginPercent != null ? '${_batch!.marginPercent!.toStringAsFixed(1)} %' : '—',
          'náklady ${(_batch!.costTotal ?? 0).toStringAsFixed(2)} € / výnos ${(_batch!.revenueTotal ?? 0).toStringAsFixed(2)} €',
          AppColors.warning,
        ),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: cards.map((c) => SizedBox(width: 170, child: c)).toList(),
    );
  }

  Widget _kpiCard(String title, String value, String? sub, Color accent) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(),
              style: const TextStyle(fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.w800, color: AppColors.textMuted)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: accent),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(
              sub,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAllocationBar() {
    final total = _batch!.quantityProduced;
    if (total <= 0) return const SizedBox.shrink();
    double pct(int n) => total > 0 ? n / total : 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ALOKÁCIA',
              style: TextStyle(fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.w800, color: AppColors.textMuted)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  Expanded(flex: (pct(_onStock) * 1000).round(), child: Container(color: AppColors.success)),
                  Expanded(flex: (pct(_atCustomer) * 1000).round(), child: Container(color: Colors.lightBlueAccent)),
                  Expanded(flex: (pct(_sold) * 1000).round(), child: Container(color: AppColors.warning)),
                  Expanded(flex: (pct(_free) * 1000).round(), child: Container(color: AppColors.bgInput)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _legend('Sklad', _onStock, AppColors.success),
              _legend('U zák.', _atCustomer, Colors.lightBlueAccent),
              _legend('Predané', _sold, AppColors.warning),
              _legend('Voľné', _free, AppColors.bgInput),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(String label, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text('$label: $count', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildPalletTile(Pallet p) {
    final isBusy = _busyPalletId == p.id;
    final Customer? cust = p.customerId == null
        ? null
        : _customers.where((c) => c.id == p.customerId).cast<Customer?>().firstWhere(
              (_) => true,
              orElse: () => null,
            );
    Color statusColor;
    switch (p.status) {
      case PalletStatus.naSklade:
        statusColor = AppColors.success;
        break;
      case PalletStatus.uZakaznika:
        statusColor = Colors.lightBlueAccent;
        break;
      case PalletStatus.predane:
      case PalletStatus.expedovane:
        statusColor = AppColors.warning;
        break;
      default:
        statusColor = AppColors.textMuted;
    }
    final subtitleParts = <String>[];
    if (cust != null) {
      subtitleParts.add(cust.name);
    } else if (p.customerId != null) {
      subtitleParts.add('Zákazník #${p.customerId}');
    }
    if (p.soldAt != null) {
      try {
        subtitleParts.add('predaj ${DateFormat('d. M. yyyy', 'sk').format(DateTime.parse(p.soldAt!))}');
      } catch (_) {}
    }
    if (p.saleNote != null && p.saleNote!.isNotEmpty) subtitleParts.add('📝 ${p.saleNote}');

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.local_shipping_outlined, color: statusColor),
      ),
      title: Row(
        children: [
          Text('Paleta #${p.id} · ${p.quantity} ks',
              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: statusColor.withValues(alpha: 0.5)),
            ),
            child: Text(
              p.status.label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
            ),
          ),
        ],
      ),
      subtitle: subtitleParts.isEmpty ? null : Text(subtitleParts.join(' · ')),
      trailing: isBusy
          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
          : PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (v) async {
                switch (v) {
                  case 'predane':
                    await _markPallet(p, PalletStatus.predane);
                    break;
                  case 'expedovane':
                    await _markPallet(p, PalletStatus.expedovane);
                    break;
                  case 'customer':
                    await _markPallet(p, PalletStatus.uZakaznika);
                    break;
                  case 'sklad':
                    await _markPallet(p, PalletStatus.naSklade);
                    break;
                  case 'delete':
                    await _deletePallet(p);
                    break;
                }
              },
              itemBuilder: (ctx) => [
                if (p.status != PalletStatus.predane)
                  const PopupMenuItem(value: 'predane', child: Text('Predané')),
                if (p.status != PalletStatus.expedovane)
                  const PopupMenuItem(value: 'expedovane', child: Text('Expedované')),
                if (p.status != PalletStatus.uZakaznika)
                  const PopupMenuItem(value: 'customer', child: Text('Priradiť zákazníkovi')),
                if (p.status != PalletStatus.naSklade)
                  const PopupMenuItem(value: 'sklad', child: Text('Vrátiť na sklad')),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'delete', child: Text('Zmazať paletu')),
              ],
            ),
    );
  }
}
