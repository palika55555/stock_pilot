import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:stock_pilot/models/customer.dart';
import 'package:stock_pilot/models/pallet.dart';
import 'package:stock_pilot/models/production_batch.dart';
import 'package:stock_pilot/services/Database/database_service.dart';
import 'package:stock_pilot/theme/app_theme.dart';

/// Súhrn výroby: vyrobené ks/m², stav paliet (sklad / u zákazníka / predané),
/// rozdelenie podľa typu, top zákazníci a denná výroba pre zvolené obdobie.
class ProducedProductsScreen extends StatefulWidget {
  const ProducedProductsScreen({super.key});

  @override
  State<ProducedProductsScreen> createState() => _ProducedProductsScreenState();
}

class _ProducedProductsScreenState extends State<ProducedProductsScreen> {
  final DatabaseService _db = DatabaseService();
  DateTime _dateFrom = DateTime.now().subtract(const Duration(days: 30));
  DateTime _dateTo = DateTime.now();
  List<ProductionBatch> _batches = [];
  List<Pallet> _pallets = [];
  List<Customer> _customers = [];
  bool _loading = true;

  String get _fromStr => DateFormat('yyyy-MM-dd').format(_dateFrom);
  String get _toStr => DateFormat('yyyy-MM-dd').format(_dateTo);

  int get _totalPieces => _batches.fold(0, (s, b) => s + b.quantityProduced);
  double get _totalM2 => _batches.fold<double>(0, (s, b) => s + (b.actualStoredM2 ?? b.requestedM2 ?? 0));
  double get _totalCost => _batches.fold<double>(0, (s, b) => s + (b.costTotal ?? 0));
  double get _totalRevenue => _batches.fold<double>(0, (s, b) => s + (b.revenueTotal ?? 0));
  double? get _margin => _totalRevenue > 0 ? ((_totalRevenue - _totalCost) / _totalRevenue) * 100 : null;

  int get _onStockPieces => _pallets.where((p) => p.status == PalletStatus.naSklade).fold(0, (s, p) => s + p.quantity);
  int get _atCustomerPieces => _pallets.where((p) => p.status == PalletStatus.uZakaznika).fold(0, (s, p) => s + p.quantity);
  int get _soldPieces => _pallets.where((p) => p.status.isSold).fold(0, (s, p) => s + p.quantity);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _db.getProductionBatchesByDateRange(_fromStr, _toStr);
    final allPallets = <Pallet>[];
    for (final b in list) {
      if (b.id == null) continue;
      allPallets.addAll(await _db.getPalletsByBatchId(b.id!));
    }
    final customers = await _db.getCustomers();
    if (!mounted) return;
    setState(() {
      _batches = list;
      _pallets = allPallets;
      _customers = customers;
      _loading = false;
    });
  }

  Future<void> _pickDateRange() async {
    final from = await showDatePicker(
      context: context,
      initialDate: _dateFrom,
      firstDate: DateTime(2020),
      lastDate: _dateTo,
    );
    if (from == null || !mounted) return;
    final to = await showDatePicker(
      context: context,
      initialDate: _dateTo.isAfter(from) ? _dateTo : from,
      firstDate: from,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (to != null && mounted) {
      setState(() {
        _dateFrom = from;
        _dateTo = to;
      });
      _load();
    }
  }

  void _quickRange(int days) {
    setState(() {
      _dateTo = DateTime.now();
      _dateFrom = _dateTo.subtract(Duration(days: days));
    });
    _load();
  }

  /// Súhrn podľa typu výrobku
  List<_TypeSummary> get _byProductType {
    final out = <String, _TypeSummary>{};
    for (final b in _batches) {
      final key = b.productType;
      out[key] = (out[key] ?? _TypeSummary(productType: key)).merge(b);
    }
    for (final p in _pallets) {
      final key = p.productType;
      final cur = out[key] ?? _TypeSummary(productType: key);
      out[key] = cur.mergePallet(p);
    }
    final list = out.values.toList()..sort((a, b) => b.producedPieces.compareTo(a.producedPieces));
    return list;
  }

  /// Top zákazníci podľa kusov v daných paletách (status u zákazníka / predané / expedované)
  List<MapEntry<String, int>> get _topCustomers {
    final byId = <int, int>{};
    for (final p in _pallets) {
      if (p.customerId == null) continue;
      if (p.status != PalletStatus.uZakaznika && !p.status.isSold) continue;
      byId[p.customerId!] = (byId[p.customerId!] ?? 0) + p.quantity;
    }
    final entries = byId.entries.map((e) {
      final cust = _customers.where((c) => c.id == e.key).cast<Customer?>().firstWhere(
            (_) => true,
            orElse: () => null,
          );
      return MapEntry(cust?.name ?? 'Zákazník #${e.key}', e.value);
    }).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(10).toList();
  }

  /// Denná výroba (kusy)
  List<MapEntry<String, int>> get _daily {
    final byDay = <String, int>{};
    for (final b in _batches) {
      byDay[b.productionDate] = (byDay[b.productionDate] ?? 0) + b.quantityProduced;
    }
    final list = byDay.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return list;
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
              title: const Text(
                'Súhrn výroby',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                ),
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.accentGold,
        backgroundColor: AppColors.bgCard,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 92, 16, 32),
          children: [
            _buildDateBar(),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
            else if (_batches.isEmpty)
              _buildEmpty()
            else ...[
              _buildKpiGrid(),
              const SizedBox(height: 16),
              _buildPalletStatusCard(),
              const SizedBox(height: 16),
              _buildSectionTitle('Podľa typu výrobku'),
              ..._byProductType.map(_buildTypeRow),
              if (_topCustomers.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildSectionTitle('Top zákazníci'),
                ..._topCustomers.map((e) => _buildCustomerRow(e.key, e.value)),
              ],
              if (_daily.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildSectionTitle('Denná výroba'),
                ..._daily.map((e) => _buildDailyRow(e.key, e.value)),
              ],
            ],
          ],
        ),
      ),
    );
  }

  bool _isToday(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  Widget _buildDateBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: _pickDateRange,
            borderRadius: BorderRadius.circular(10),
            child: Row(
              children: [
                const Icon(Icons.date_range_rounded, color: AppColors.accentGold),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${DateFormat('d. M. yyyy', 'sk').format(_dateFrom)} – ${DateFormat('d. M. yyyy', 'sk').format(_dateTo)}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                ),
                const Icon(Icons.expand_more_rounded, color: AppColors.textMuted),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _quickChip('7 dní', () => _quickRange(7)),
              _quickChip('30 dní', () => _quickRange(30)),
              _quickChip('Rok', () => _quickRange(365)),
              _quickChip('Mesiac', () {
                setState(() {
                  _dateFrom = DateTime(DateTime.now().year, DateTime.now().month, 1);
                  _dateTo = DateTime.now();
                });
                _load();
              }),
            ],
          ),
          if (_isToday(_dateTo)) ...[
            const SizedBox(height: 6),
            const Text('do dnes', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ],
        ],
      ),
    );
  }

  Widget _quickChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.bgInput,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text(
            'V zvolenom období nie sú žiadne šarže',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildKpiGrid() {
    final cards = <Widget>[
      _kpi('Vyrobené', '$_totalPieces ks', '${_batches.length} šarží', AppColors.accentGold),
      if (_totalM2 > 0) _kpi('Plocha', '${_totalM2.toStringAsFixed(2)} m²', 'len dlažba', Colors.lightBlueAccent),
      _kpi('Predané', '$_soldPieces ks', '${_pallets.where((p) => p.status.isSold).length} paliet', AppColors.warning),
      if (_totalCost > 0 || _totalRevenue > 0)
        _kpi(
          'Marža',
          _margin != null ? '${_margin!.toStringAsFixed(1)} %' : '—',
          'náklady ${_totalCost.toStringAsFixed(0)} € · výnos ${_totalRevenue.toStringAsFixed(0)} €',
          AppColors.success,
        ),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: cards.map((c) => SizedBox(width: 170, child: c)).toList(),
    );
  }

  Widget _kpi(String title, String value, String? sub, Color accent) {
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
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: accent)),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(sub, style: const TextStyle(fontSize: 11, color: AppColors.textMuted), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }

  Widget _buildPalletStatusCard() {
    final total = _onStockPieces + _atCustomerPieces + _soldPieces;
    if (total == 0) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: const Text('Zatiaľ žiadne palety v období.', style: TextStyle(color: AppColors.textMuted)),
      );
    }
    int flex(int n) => total > 0 ? ((n / total) * 1000).round() : 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('STAV PALIET',
              style: TextStyle(fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.w800, color: AppColors.textMuted)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  Expanded(flex: flex(_onStockPieces), child: Container(color: AppColors.success)),
                  Expanded(flex: flex(_atCustomerPieces), child: Container(color: Colors.lightBlueAccent)),
                  Expanded(flex: flex(_soldPieces), child: Container(color: AppColors.warning)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _legend('Sklad', _onStockPieces, AppColors.success),
              _legend('U zákazníka', _atCustomerPieces, Colors.lightBlueAccent),
              _legend('Predané', _soldPieces, AppColors.warning),
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

  Widget _buildSectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
      ),
    );
  }

  Widget _buildTypeRow(_TypeSummary t) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppColors.bgCard,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(t.productType, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontSize: 15)),
                ),
                Text('${t.producedPieces} ks',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.accentGold, fontSize: 15)),
              ],
            ),
            if (t.producedM2 > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('${t.producedM2.toStringAsFixed(2)} m²',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 10,
              runSpacing: 4,
              children: [
                _miniStat('Sklad', t.inStockPieces, AppColors.success),
                _miniStat('U zák.', t.atCustomerPieces, Colors.lightBlueAccent),
                _miniStat('Predané', t.soldPieces, AppColors.warning),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, int n, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text('$label $n', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _buildCustomerRow(String name, int pieces) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      color: AppColors.bgCard,
      child: ListTile(
        leading: const CircleAvatar(backgroundColor: AppColors.bgInput, child: Icon(Icons.person, color: AppColors.accentGold)),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        trailing: Text('$pieces ks',
            style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.accentGold)),
      ),
    );
  }

  Widget _buildDailyRow(String day, int pieces) {
    String label;
    try {
      label = DateFormat('d. M. yyyy', 'sk').format(DateTime.parse(day));
    } catch (_) {
      label = day;
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      color: AppColors.bgCard,
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.calendar_today_rounded, color: AppColors.textMuted, size: 18),
        title: Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
        trailing: Text('$pieces ks',
            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.accentGold)),
      ),
    );
  }
}

class _TypeSummary {
  final String productType;
  final int producedPieces;
  final double producedM2;
  final int inStockPieces;
  final int atCustomerPieces;
  final int soldPieces;

  const _TypeSummary({
    required this.productType,
    this.producedPieces = 0,
    this.producedM2 = 0,
    this.inStockPieces = 0,
    this.atCustomerPieces = 0,
    this.soldPieces = 0,
  });

  _TypeSummary merge(ProductionBatch b) => _TypeSummary(
        productType: productType,
        producedPieces: producedPieces + b.quantityProduced,
        producedM2: producedM2 + (b.actualStoredM2 ?? b.requestedM2 ?? 0),
        inStockPieces: inStockPieces,
        atCustomerPieces: atCustomerPieces,
        soldPieces: soldPieces,
      );

  _TypeSummary mergePallet(Pallet p) => _TypeSummary(
        productType: productType,
        producedPieces: producedPieces,
        producedM2: producedM2,
        inStockPieces: inStockPieces + (p.status == PalletStatus.naSklade ? p.quantity : 0),
        atCustomerPieces: atCustomerPieces + (p.status == PalletStatus.uZakaznika ? p.quantity : 0),
        soldPieces: soldPieces + (p.status.isSold ? p.quantity : 0),
      );
}
