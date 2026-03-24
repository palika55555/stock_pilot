import 'dart:ui';

import 'package:flutter/material.dart';
import '../../models/production_order.dart';
import '../../services/ProductionOrder/production_order_service.dart';
import '../../theme/app_theme.dart';
import 'production_order_detail_screen.dart';
import '../Recipe/recipe_list_screen.dart';

class ProductionOrderListScreen extends StatefulWidget {
  final String userRole;

  const ProductionOrderListScreen({super.key, required this.userRole});

  @override
  State<ProductionOrderListScreen> createState() => _ProductionOrderListScreenState();
}

class _ProductionOrderListScreenState extends State<ProductionOrderListScreen> {
  final ProductionOrderService _orderService = ProductionOrderService();
  List<ProductionOrder> _orders = [];
  bool _loading = true;
  String? _filterStatus;
  String _searchQuery = '';

  List<ProductionOrder> get _visibleOrders {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return _orders;
    return _orders.where((o) {
      final hay = '${o.orderNumber} ${o.recipeName ?? ''}'.toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _orderService.getOrders(status: _filterStatus);
    if (mounted) {
      setState(() {
        _orders = list;
        _loading = false;
      });
    }
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
                leading: Container(
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
                title: Text(
                  'Výrobné príkazy',
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
                        icon: Icon(Icons.menu_book_rounded, color: AppColors.accentGold),
                        tooltip: 'Receptúry',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RecipeListScreen(userRole: widget.userRole),
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
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accentGold),
            )
          : RefreshIndicator(
              color: AppColors.accentGold,
              backgroundColor: AppColors.bgCard,
              onRefresh: _load,
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
                      child: _buildFiltersPanel(),
                    ),
                  ),
                  if (_orders.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(isSearchEmpty: false),
                    )
                  else if (_visibleOrders.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(isSearchEmpty: true),
                    )
                  else if (isWide)
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(horizontalPad, 0, horizontalPad, 36),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 14,
                          childAspectRatio: 1.75,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildOrderCard(_visibleOrders[index]),
                          childCount: _visibleOrders.length,
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(horizontalPad, 0, horizontalPad, 36),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildOrderCard(_visibleOrders[index]),
                          ),
                          childCount: _visibleOrders.length,
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
              Icons.assignment_rounded,
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
                  'PREHĽAD VÝROBY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Sledujte stavy VP, plánované množstvá a termíny. Filtrom zúžite zoznam podľa stavu.',
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

  Widget _buildFiltersPanel() {
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
                'VYHĽADÁVANIE',
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
                  hintText: 'Číslo VP alebo názov receptúry…',
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
              const SizedBox(height: 18),
              const Text(
                'STAV',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _statusChip(
                    label: 'Všetky',
                    selected: _filterStatus == null,
                    color: AppColors.textSecondary,
                    onTap: () {
                      setState(() => _filterStatus = null);
                      _load();
                    },
                  ),
                  ...ProductionOrderStatus.values.map((s) {
                    final c = Color(s.colorValue);
                    return _statusChip(
                      label: s.label,
                      selected: _filterStatus == s.value,
                      color: c,
                      onTap: () {
                        setState(() => _filterStatus = s.value);
                        _load();
                      },
                    );
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChip({
    required String label,
    required bool selected,
    required Color color,
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
              color: selected ? color.withValues(alpha: 0.65) : AppColors.borderSubtle,
              width: selected ? 1.5 : 1,
            ),
            color: selected ? color.withValues(alpha: 0.18) : AppColors.bgInput.withValues(alpha: 0.85),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(Icons.check_rounded, size: 16, color: color),
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

  Widget _buildEmptyState({required bool isSearchEmpty}) {
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
              isSearchEmpty ? Icons.search_off_rounded : Icons.inbox_rounded,
              size: 48,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isSearchEmpty ? 'Žiadna zhoda s vyhľadávaním' : 'Žiadne výrobné príkazy',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isSearchEmpty
                ? 'Skúste iný výraz alebo vymažte filter stavu.'
                : 'Vytvorte VP z receptúry alebo počkajte na synchronizáciu.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(ProductionOrder o) {
    final statusColor = Color(o.status.colorValue);
    final dateStr =
        '${o.productionDate.day.toString().padLeft(2, '0')}.${o.productionDate.month.toString().padLeft(2, '0')}.${o.productionDate.year}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductionOrderDetailScreen(
                orderId: o.id!,
                userRole: widget.userRole,
              ),
            ),
          );
          _load();
        },
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
                          statusColor,
                          statusColor.withValues(alpha: 0.55),
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
                                      o.orderNumber,
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
                                      color: statusColor.withValues(alpha: 0.16),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: statusColor.withValues(alpha: 0.35)),
                                    ),
                                    child: Text(
                                      o.status.label,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: statusColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                o.recipeName?.isNotEmpty == true ? o.recipeName! : 'Receptúra #${o.recipeId}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary,
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Icon(Icons.event_rounded, size: 16, color: AppColors.textMuted),
                              const SizedBox(width: 6),
                              Text(
                                dateStr,
                                style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                              ),
                              const SizedBox(width: 16),
                              Icon(Icons.inventory_2_outlined, size: 16, color: AppColors.textMuted),
                              const SizedBox(width: 6),
                              Text(
                                '${o.plannedQuantity % 1 == 0 ? o.plannedQuantity.toInt() : o.plannedQuantity} ks',
                                style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                              ),
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
