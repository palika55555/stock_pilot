import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../screens/goods_receipt/goods_receipt_screen.dart';
import '../../screens/price_quote/price_quotes_list_screen.dart';
import '../../screens/warehouse/warehouse_supplies.dart';
import '../../screens/stock_out/stock_out_screen.dart';
import '../../screens/customers/customers_page.dart';
import '../../screens/ProductionOrder/production_order_list_screen.dart';
import '../../services/dashboard/dashboard_service.dart';
import '../../l10n/app_localizations.dart';

class HomeOverview extends StatefulWidget {
  final String userRole;

  const HomeOverview({super.key, required this.userRole});

  @override
  State<HomeOverview> createState() => _HomeOverviewState();
}

const Color _kHomeBg = Color(0xFF111114);
const Color _kHomeCard = Color(0xFF212124);
const Color _kHomeAccent = Color(0xFFFFC107);
const Color _kHomeText = Color(0xFFFFFFFF);
const Color _kHomeTextMuted = Color(0xFF9CA3AF);
const Color _kHomeBorder = Color(0x40FFC107); // accent 25%

class _HomeOverviewState extends State<HomeOverview> {
  final DashboardService _dashboardService = DashboardService();
  Map<String, dynamic> _stats = {
    'products': 0,
    'orders': 0,
    'customers': 0,
    'revenue': 0.0,
    'inboundCount': 0,
    'outboundCount': 0,
    'quotesCount': 0,
    'recentInbound': <Map<String, dynamic>>[],
    'recentOutbound': <Map<String, dynamic>>[],
  };
  bool _isLoading = true;
  static const String _prefKeyNotes = 'overview_notes';
  static const String _prefKeyTasks = 'overview_tasks';
  String _overviewNote = '';
  List<Map<String, dynamic>> _overviewTasks = [];
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _newTaskController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadNotesAndTasks();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _newTaskController.dispose();
    super.dispose();
  }

  Future<void> _loadNotesAndTasks() async {
    final prefs = await SharedPreferences.getInstance();
    _overviewNote = prefs.getString(_prefKeyNotes) ?? '';
    final tasksJson = prefs.getString(_prefKeyTasks);
    if (tasksJson != null) {
      try {
        final list = jsonDecode(tasksJson) as List<dynamic>?;
        _overviewTasks = list?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
      } catch (_) {
        _overviewTasks = [];
      }
    } else {
      _overviewTasks = [];
    }
    if (mounted) {
      _noteController.text = _overviewNote;
      setState(() {});
    }
  }

  Future<void> _saveNotes(String value) async {
    _overviewNote = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyNotes, value);
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyTasks, jsonEncode(_overviewTasks));
    if (mounted) setState(() {});
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    final stats = await _dashboardService.getOverviewStats();
    if (mounted) {
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_isLoading) {
      return Container(
        color: _kHomeBg,
        child: Center(
          child: CircularProgressIndicator(
            color: _kHomeAccent,
            strokeWidth: 2,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadStats,
      color: _kHomeAccent,
      backgroundColor: _kHomeCard,
      child: Container(
        color: _kHomeBg,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 6,
              left: 14.0,
              right: 14.0,
              bottom: 24.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: title + refresh button
                Row(
                  children: [
                    Text(
                      l10n.overview,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _kHomeText,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _loadStats,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _kHomeCard,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _kHomeBorder, width: 1),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.refresh_rounded, size: 13, color: _kHomeAccent),
                            const SizedBox(width: 4),
                            const Text(
                              'Obnoviť',
                              style: TextStyle(fontSize: 11, color: _kHomeTextMuted, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final useRow = constraints.maxWidth > 500;
                    if (useRow) {
                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: _buildNotesCard(context, l10n, matchHeight: true)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildTasksCard(context, l10n, matchHeight: true)),
                          ],
                        ),
                      );
                    }
                    return Column(
                      children: [
                        _buildNotesCard(context, l10n, matchHeight: false),
                        const SizedBox(height: 10),
                        _buildTasksCard(context, l10n, matchHeight: false),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),
                _buildReceiptKpiCards(context),
                const SizedBox(height: 14),
                _buildProductionKpiCards(context),
                const SizedBox(height: 14),
                _buildKpiCards(context, l10n),
                const SizedBox(height: 14),
                _buildRecentMovementsCard(context, l10n),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 13, color: _kHomeAccent),
          const SizedBox(width: 5),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _kHomeTextMuted,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptKpiCards(BuildContext context) {
    final receiptsToday = _stats['receiptsToday'] is int ? _stats['receiptsToday'] as int : 0;
    final pendingCount = _stats['pendingReceiptCount'] is int ? _stats['pendingReceiptCount'] as int : 0;
    final valueMonth = _stats['receiptsValueThisMonth'] is num ? (_stats['receiptsValueThisMonth'] as num).toDouble() : 0.0;
    final lowStock = _stats['lowStockCount'] is int ? _stats['lowStockCount'] as int : 0;
    final lastR = _stats['lastReceipt'] as Map<String, dynamic>?;
    String lastReceiptText = '—';
    if (lastR != null) {
      final numStr = lastR['receipt_number'] as String? ?? '—';
      final createdAt = lastR['created_at'] as String?;
      if (createdAt != null) {
        try {
          final dt = DateTime.parse(createdAt);
          final diff = DateTime.now().difference(dt);
          if (diff.inMinutes < 60) {
            lastReceiptText = '$numStr (${diff.inMinutes}min)';
          } else if (diff.inHours < 24) {
            lastReceiptText = '$numStr (${diff.inHours}h)';
          } else if (diff.inDays < 7) {
            lastReceiptText = '$numStr (${diff.inDays}d)';
          } else {
            lastReceiptText = numStr;
          }
        } catch (_) {
          lastReceiptText = numStr;
        }
      } else {
        lastReceiptText = numStr;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('Príjemky & Sklad', Icons.inventory_2_rounded),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 700 ? 5 : (constraints.maxWidth > 450 ? 3 : 2);
            return GridView.count(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.45,
              children: [
                _DashboardKpiCard(
                  title: 'Príjemky dnes',
                  value: receiptsToday.toString(),
                  icon: Icons.today_rounded,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const GoodsReceiptScreen())).then((_) => _loadStats()),
                ),
                _DashboardKpiCard(
                  title: 'Čaká na schválenie',
                  value: pendingCount.toString(),
                  icon: Icons.pending_actions_rounded,
                  iconColor: pendingCount > 0 ? Colors.orangeAccent : null,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const GoodsReceiptScreen())).then((_) => _loadStats()),
                ),
                _DashboardKpiCard(
                  title: 'Hodnota tento mesiac',
                  value: '${NumberFormat.decimalPattern('sk_SK').format(valueMonth)} €',
                  icon: Icons.euro_rounded,
                  onTap: () {},
                ),
                _DashboardKpiCard(
                  title: 'Pod min. zásobou',
                  value: lowStock.toString(),
                  icon: Icons.warning_amber_rounded,
                  iconColor: lowStock > 0 ? Colors.redAccent : null,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => WarehouseSuppliesScreen(userRole: widget.userRole))).then((_) => _loadStats()),
                ),
                _DashboardKpiCard(
                  title: 'Posledná príjemka',
                  value: lastReceiptText,
                  icon: Icons.receipt_long_rounded,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const GoodsReceiptScreen())).then((_) => _loadStats()),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildProductionKpiCards(BuildContext context) {
    final ordersToday = _stats['productionOrdersToday'] is int ? _stats['productionOrdersToday'] as int : 0;
    final inProgress = _stats['productionInProgressCount'] is int ? _stats['productionInProgressCount'] as int : 0;
    final pendingApproval = _stats['productionPendingApprovalCount'] is int ? _stats['productionPendingApprovalCount'] as int : 0;
    final costMonth = _stats['productionCostThisMonth'] is num ? (_stats['productionCostThisMonth'] as num).toDouble() : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('Výroba', Icons.precision_manufacturing_rounded),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
            return GridView.count(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.45,
              children: [
                _DashboardKpiCard(
                  title: 'Príkazy dnes',
                  value: ordersToday.toString(),
                  icon: Icons.assignment_rounded,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ProductionOrderListScreen(userRole: widget.userRole))).then((_) => _loadStats()),
                ),
                _DashboardKpiCard(
                  title: 'Prebieha výroba',
                  value: inProgress.toString(),
                  icon: Icons.play_circle_rounded,
                  iconColor: inProgress > 0 ? const Color(0xFF22C55E) : null,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ProductionOrderListScreen(userRole: widget.userRole))).then((_) => _loadStats()),
                ),
                _DashboardKpiCard(
                  title: 'Čaká na schválenie',
                  value: pendingApproval.toString(),
                  icon: Icons.pending_rounded,
                  iconColor: pendingApproval > 0 ? Colors.orangeAccent : null,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ProductionOrderListScreen(userRole: widget.userRole))).then((_) => _loadStats()),
                ),
                _DashboardKpiCard(
                  title: 'Náklady tento mesiac',
                  value: '${NumberFormat.decimalPattern('sk_SK').format(costMonth)} €',
                  icon: Icons.payments_rounded,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ProductionOrderListScreen(userRole: widget.userRole))).then((_) => _loadStats()),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildKpiCards(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('Prehľad', Icons.bar_chart_rounded),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
            return GridView.count(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.45,
              children: [
                _DashboardKpiCard(
                  title: 'Produkty',
                  value: _stats['products'].toString(),
                  icon: Icons.inventory_rounded,
                  onTap: () => _navigateTo(context, 'products'),
                ),
                _DashboardKpiCard(
                  title: 'Objednávky',
                  value: _stats['orders'].toString(),
                  icon: Icons.shopping_bag_rounded,
                  onTap: () => _navigateTo(context, 'orders'),
                ),
                _DashboardKpiCard(
                  title: 'Zákazníci',
                  value: _stats['customers'].toString(),
                  icon: Icons.people_rounded,
                  onTap: () => _navigateTo(context, 'customers'),
                ),
                _DashboardKpiCard(
                  title: 'Tržby',
                  value: _formatCurrency(_stats['revenue']),
                  icon: Icons.trending_up_rounded,
                  iconColor: const Color(0xFF22C55E),
                  onTap: () => _navigateTo(context, 'revenue'),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildNotesCard(BuildContext context, AppLocalizations l10n, {bool matchHeight = false}) {
    final notesField = TextField(
      controller: _noteController,
      maxLines: matchHeight ? null : 3,
      minLines: 3,
      decoration: InputDecoration(
        hintText: l10n.overviewNotesPlaceholder,
        hintStyle: const TextStyle(color: _kHomeTextMuted, fontSize: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _kHomeTextMuted.withOpacity(0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kHomeAccent, width: 1.5),
        ),
        filled: true,
        fillColor: _kHomeBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
      style: const TextStyle(fontSize: 13, color: _kHomeText),
      onChanged: _saveNotes,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kHomeCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kHomeTextMuted.withOpacity(0.12), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  color: _kHomeAccent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.overviewNotesTitle,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _kHomeText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (matchHeight) Expanded(child: notesField) else notesField,
        ],
      ),
    );
  }

  Widget _buildTasksCard(BuildContext context, AppLocalizations l10n, {bool matchHeight = false}) {
    final tasksList = _overviewTasks.asMap().entries.map((entry) {
      final i = entry.key;
      final task = entry.value;
      final title = task['t'] as String? ?? '';
      final done = task['d'] as bool? ?? false;
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            SizedBox(
              height: 20,
              width: 20,
              child: Checkbox(
                value: done,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                activeColor: _kHomeAccent,
                fillColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) return _kHomeAccent;
                  return _kHomeTextMuted;
                }),
                onChanged: (v) {
                  _overviewTasks[i]['d'] = v ?? false;
                  _saveTasks();
                },
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title.isEmpty ? '—' : title,
                style: TextStyle(
                  fontSize: 13,
                  decoration: done ? TextDecoration.lineThrough : null,
                  color: done ? _kHomeTextMuted : _kHomeText,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 16, color: _kHomeTextMuted),
              onPressed: () {
                _overviewTasks.removeAt(i);
                _saveTasks();
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ],
        ),
      );
    }).toList();

    final addTaskRow = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: TextField(
            controller: _newTaskController,
            decoration: InputDecoration(
              hintText: l10n.overviewNewTaskHint,
              hintStyle: const TextStyle(color: _kHomeTextMuted, fontSize: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: _kHomeTextMuted.withOpacity(0.15)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _kHomeAccent, width: 1.5),
              ),
              filled: true,
              fillColor: _kHomeBg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              isDense: true,
            ),
            style: const TextStyle(fontSize: 13, color: _kHomeText),
            onSubmitted: (value) {
              final t = value.trim();
              if (t.isEmpty) return;
              _overviewTasks.add({'t': t, 'd': false});
              _newTaskController.clear();
              _saveTasks();
            },
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: () {
            final t = _newTaskController.text.trim();
            if (t.isEmpty) return;
            _overviewTasks.add({'t': t, 'd': false});
            _newTaskController.clear();
            _saveTasks();
          },
          icon: const Icon(Icons.add_rounded, size: 18, color: Color(0xFF111114)),
          label: Text(
            l10n.overviewAddTask,
            style: const TextStyle(
              color: Color(0xFF111114),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: _kHomeAccent,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            minimumSize: Size.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kHomeCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kHomeTextMuted.withOpacity(0.12), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  color: _kHomeAccent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.overviewTasksTitle,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _kHomeText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (matchHeight)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: tasksList,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  addTaskRow,
                ],
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ...tasksList,
                const SizedBox(height: 6),
                addTaskRow,
              ],
            ),
        ],
      ),
    );
  }

  void _navigateTo(BuildContext context, String cardType) {
    switch (cardType) {
      case 'products':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                WarehouseSuppliesScreen(userRole: widget.userRole),
          ),
        ).then((_) => _loadStats());
        break;
      case 'orders':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const PriceQuotesListScreen(),
          ),
        ).then((_) => _loadStats());
        break;
      case 'customers':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const CustomersPage(),
          ),
        ).then((_) => _loadStats());
        break;
      case 'revenue':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const PriceQuotesListScreen(),
          ),
        ).then((_) => _loadStats());
        break;
      default:
        break;
    }
  }

  String _formatCurrency(dynamic value) {
    final n = value is num ? value.toDouble() : 0.0;
    return '${NumberFormat.decimalPattern('sk_SK').format(n)} €';
  }

  Widget _buildRecentMovementsCard(
      BuildContext context, AppLocalizations l10n) {
    final inbound = _stats['recentInbound'] as List<dynamic>? ?? [];
    final outbound = _stats['recentOutbound'] as List<dynamic>? ?? [];
    final inboundList = inbound.cast<Map<String, dynamic>>();
    final outboundList = outbound.cast<Map<String, dynamic>>();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kHomeCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kHomeBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.swap_vert_rounded, size: 14, color: _kHomeAccent),
              const SizedBox(width: 6),
              Text(
                l10n.recentMovements.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _kHomeTextMuted,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const GoodsReceiptScreen(),
                      ),
                    ).then((_) => _loadStats());
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: _buildMovementColumn(
                      title: '${l10n.inboundReceipts} (${inboundList.length})',
                      items: inboundList,
                      positive: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => StockOutScreen(userRole: widget.userRole),
                      ),
                    ).then((_) => _loadStats());
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: _buildMovementColumn(
                      title: '${l10n.outboundReceipts} (${outboundList.length})',
                      items: outboundList,
                      positive: false,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMovementColumn({
    required String title,
    required List<Map<String, dynamic>> items,
    required bool positive,
  }) {
    final color = positive ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    final prefix = positive ? '+ ' : '- ';
    final dateFormat = DateFormat('dd.MM.yy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _kHomeTextMuted,
          ),
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          const Text(
            '—',
            style: TextStyle(fontSize: 12, color: _kHomeTextMuted),
          )
        else
          ...items.map((e) {
            final createdAt = e['created_at'];
            DateTime? dt;
            if (createdAt is String) {
              dt = DateTime.tryParse(createdAt);
            } else if (createdAt is int) {
              dt = DateTime.fromMillisecondsSinceEpoch(createdAt);
            }
            final total = (e['total'] as num?)?.toDouble() ?? 0.0;
            final dateStr =
                dt != null ? dateFormat.format(dt) : '—';
            final amountStr =
                '$prefix${NumberFormat.decimalPattern('sk_SK').format(total)} €';
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    dateStr,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _kHomeTextMuted,
                    ),
                  ),
                  Text(
                    amountStr,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

class _DashboardKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? iconColor;
  final VoidCallback? onTap;

  const _DashboardKpiCard({
    required this.title,
    required this.value,
    required this.icon,
    this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = iconColor ?? _kHomeAccent;

    return Container(
      decoration: BoxDecoration(
        color: _kHomeCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kHomeBorder, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _kHomeTextMuted,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(icon, size: 14, color: accent.withOpacity(0.65)),
                  ],
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: accent,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
