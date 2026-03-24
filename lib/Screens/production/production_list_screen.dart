import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:stock_pilot/theme/app_theme.dart';
import 'package:stock_pilot/models/production_batch.dart';
import 'package:stock_pilot/services/Database/database_service.dart';
import 'package:stock_pilot/screens/production/production_batch_form_screen.dart';
import 'package:stock_pilot/screens/production/production_batch_detail_screen.dart';
import 'package:stock_pilot/screens/production/produced_products_screen.dart';

class ProductionListScreen extends StatefulWidget {
  const ProductionListScreen({super.key});

  @override
  State<ProductionListScreen> createState() => _ProductionListScreenState();
}

class _ProductionListScreenState extends State<ProductionListScreen> {
  final DatabaseService _db = DatabaseService();
  DateTime _selectedDate = DateTime.now();
  List<ProductionBatch> _batches = [];
  bool _loading = true;
  String _searchQuery = '';

  String get _dateStr => DateFormat('yyyy-MM-dd').format(_selectedDate);

  List<ProductionBatch> get _visibleBatches {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return _batches;
    return _batches
        .where((b) => b.productType.toLowerCase().contains(q))
        .toList();
  }

  bool get _isToday {
    final n = DateTime.now();
    return _selectedDate.year == n.year &&
        _selectedDate.month == n.month &&
        _selectedDate.day == n.day;
  }

  @override
  void initState() {
    super.initState();
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    setState(() => _loading = true);
    final list = await _db.getProductionBatchesByDate(_dateStr);
    if (mounted) {
      setState(() {
        _batches = list;
        _loading = false;
      });
    }
  }

  void _goToDayOffset(int daysFromToday) {
    final base = DateTime.now();
    final today = DateTime(base.year, base.month, base.day);
    setState(() => _selectedDate = today.add(Duration(days: daysFromToday)));
    _loadBatches();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _loadBatches();
    }
  }

  Future<void> _addBatch() async {
    final result = await Navigator.push<Object?>(
      context,
      MaterialPageRoute(
        builder: (context) => ProductionBatchFormScreen(initialDate: _selectedDate),
      ),
    );
    if (!mounted) return;
    await _loadBatches();
    if (!mounted) return;
    if (result is int) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (context) => ProductionBatchDetailScreen(batchId: result),
        ),
      );
      if (mounted) _loadBatches();
    }
  }

  Future<void> _openBatch(ProductionBatch b) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => ProductionBatchDetailScreen(batchId: b.id!),
      ),
    );
    if (mounted) _loadBatches();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 960;
    final horizontalPad = isWide ? 28.0 : 20.0;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.bgPrimary,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.bgCard.withValues(alpha: 0.9),
                border: Border(
                  bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
                ),
              ),
              child: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: false,
                leading: Navigator.canPop(context)
                    ? Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Container(
                          margin: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.bgInput,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.borderSubtle, width: 1),
                          ),
                          child: IconButton(
                            icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      )
                    : null,
                title: Text(
                  'Výroba',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.bgInput,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderSubtle, width: 1),
                      ),
                      child: IconButton(
                        icon: Icon(Icons.bar_chart_rounded, color: AppColors.accentGold),
                        tooltip: 'Vyrobené produkty',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ProducedProductsScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addBatch,
        backgroundColor: AppColors.accentGold,
        foregroundColor: AppColors.bgPrimary,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Pridať šaržu', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accentGold),
            )
          : RefreshIndicator(
              color: AppColors.accentGold,
              backgroundColor: AppColors.bgCard,
              onRefresh: _loadBatches,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).top + 56)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(horizontalPad, 0, horizontalPad, 8),
                      child: _buildIntroCard(),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(horizontalPad, 0, horizontalPad, 16),
                      child: _buildDateAndSearchPanel(),
                    ),
                  ),
                  if (_batches.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(isFiltered: false),
                    )
                  else if (_visibleBatches.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(isFiltered: true),
                    )
                  else if (isWide)
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(horizontalPad, 0, horizontalPad, 100),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 14,
                          childAspectRatio: 1.9,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildBatchCard(_visibleBatches[index]),
                          childCount: _visibleBatches.length,
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(horizontalPad, 0, horizontalPad, 100),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildBatchCard(_visibleBatches[index]),
                          ),
                          childCount: _visibleBatches.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildIntroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.bgElevated,
            AppColors.bgCard.withValues(alpha: 0.92),
          ],
        ),
        border: Border.all(color: AppColors.borderSubtle, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.accentGoldSubtle,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.accentGold.withValues(alpha: 0.35),
              ),
            ),
            child: const Icon(
              Icons.precision_manufacturing_rounded,
              color: AppColors.accentGold,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ŠARŽE VÝROBY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Prehľad vyrobených množstiev podľa dňa. Pridajte šaržu alebo otvorte detail pre náklady a maržu.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    color: AppColors.textSecondary.withValues(alpha: 0.95),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateAndSearchPanel() {
    final formatted = DateFormat('d. M. yyyy', 'sk').format(_selectedDate);
    final weekday = DateFormat('EEEE', 'sk').format(_selectedDate);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderSubtle, width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'DEŇ VÝROBY',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 10),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.bgInput,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_month_rounded, color: AppColors.accentGold.withValues(alpha: 0.95)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                formatted,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                weekday,
                                style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.expand_more_rounded, color: AppColors.textMuted),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _quickDayChip(
                    label: 'Dnes',
                    selected: _isToday,
                    onTap: () => _goToDayOffset(0),
                  ),
                  _quickDayChip(
                    label: 'Včera',
                    selected: _isYesterday,
                    onTap: () => _goToDayOffset(-1),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'VYHĽADÁVANIE V DNI',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                cursorColor: AppColors.accentGold,
                decoration: InputDecoration(
                  hintText: 'Typ výrobku (napr. dlažba, tvárnica)…',
                  hintStyle: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.85)),
                  prefixIcon: Icon(Icons.search_rounded, color: AppColors.accentGold.withValues(alpha: 0.9)),
                  filled: true,
                  fillColor: AppColors.bgInput,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.borderDefault),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.borderSubtle),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.accentGold.withValues(alpha: 0.6)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _isYesterday {
    final n = DateTime.now();
    final y = DateTime(n.year, n.month, n.day).subtract(const Duration(days: 1));
    return _selectedDate.year == y.year &&
        _selectedDate.month == y.month &&
        _selectedDate.day == y.day;
  }

  Widget _quickDayChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.accentGold.withValues(alpha: 0.65) : AppColors.borderSubtle,
              width: selected ? 1.5 : 1,
            ),
            color: selected ? AppColors.accentGold.withValues(alpha: 0.16) : AppColors.bgInput.withValues(alpha: 0.85),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(Icons.check_rounded, size: 16, color: AppColors.accentGold),
                ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({required bool isFiltered}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.accentGoldSubtle,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Icon(
              isFiltered ? Icons.search_off_rounded : Icons.layers_outlined,
              size: 48,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isFiltered ? 'Žiadna zhoda v tomto dni' : 'V tento deň nie sú šarže',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isFiltered
                ? 'Skúste iný výraz alebo zmeňte dátum.'
                : 'Pridajte prvú šaržu alebo vyberte iný deň.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.35),
          ),
          if (!isFiltered) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _addBatch,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accentGold,
                foregroundColor: AppColors.bgPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Pridať šaržu', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ],
      ),
    );
  }

  String? _marginLabel(ProductionBatch b) {
    final m = b.marginPercent;
    if (m == null) return null;
    return '${m.toStringAsFixed(1)} % marža';
  }

  Widget _buildBatchCard(ProductionBatch b) {
    final accent = AppColors.accentGold;
    final margin = _marginLabel(b);
    final marginVal = b.marginPercent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openBatch(b),
        borderRadius: BorderRadius.circular(20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderSubtle, width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          accent,
                          accent.withValues(alpha: 0.55),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      b.productType,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 17,
                                        letterSpacing: -0.3,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: accent.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: accent.withValues(alpha: 0.35)),
                                    ),
                                    child: Text(
                                      '${b.quantityProduced} ks',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: accent,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (b.notes != null && b.notes!.trim().isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  b.notes!.trim(),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                    height: 1.25,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Row(
                            children: [
                              Icon(Icons.layers_rounded, size: 16, color: AppColors.textMuted),
                              const SizedBox(width: 6),
                              Text(
                                'Šarža #${b.id}',
                                style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                              ),
                              if (margin != null && marginVal != null) ...[
                                const SizedBox(width: 12),
                                Icon(
                                  marginVal >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                                  size: 16,
                                  color: marginVal >= 0 ? AppColors.success : AppColors.danger,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  margin,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: marginVal >= 0 ? AppColors.success : AppColors.danger,
                                  ),
                                ),
                              ],
                              const Spacer(),
                              Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 22),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
