import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../screens/goods_receipt/goods_receipt_screen.dart';
import '../../screens/price_quote/price_quotes_list_screen.dart';
import '../../screens/warehouse/warehouse_supplies.dart';
import '../../screens/stock_out/stock_out_screen.dart';
import '../../screens/customers/customers_page.dart';
import '../../screens/ProductionOrder/production_order_list_screen.dart';
import '../../screens/Search/search_screen.dart';
import '../../services/dashboard/dashboard_service.dart';
import '../../models/user.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';

class HomeOverview extends StatefulWidget {
  final String userRole;
  final User? user;
  final int notificationUnreadCount;
  final VoidCallback? onNotificationTap;
  /// Voliteľné: stiahnuť zákazníkov a produkty z backendu pred obnovením štatistík.
  final Future<void> Function()? onSyncFromBackend;

  const HomeOverview({
    super.key,
    required this.userRole,
    this.user,
    this.notificationUnreadCount = 0,
    this.onNotificationTap,
    this.onSyncFromBackend,
  });

  @override
  State<HomeOverview> createState() => _HomeOverviewState();
}

class _HomeOverviewState extends State<HomeOverview> with TickerProviderStateMixin {
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
  late AnimationController _staggerController;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadStats();
    _loadNotesAndTasks();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _newTaskController.dispose();
    _staggerController.dispose();
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
      _staggerController.forward(from: 0);
    }
  }

  Animation<double> _staggerAnim(int index, {int total = 8}) {
    final start = (index / total).clamp(0.0, 1.0);
    final end = ((index + 1.5) / total).clamp(0.0, 1.0);
    return CurvedAnimation(
      parent: _staggerController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return Container(
      color: AppColors.bgPrimary,
      child: Column(
        children: [
          // Desktop header (sidebar screens don't have app bar)
          if (isDesktop) _buildDesktopHeader(l10n),
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : RefreshIndicator(
                    onRefresh: _loadStats,
                    color: AppColors.accentGold,
                    backgroundColor: AppColors.bgCard,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          isDesktop ? 28 : 16,
                          isDesktop ? 0 : 16,
                          isDesktop ? 28 : 16,
                          32,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Main KPI cards row
                            _buildMainKpiSection(l10n),
                            const SizedBox(height: 24),
                            // Secondary KPI row (receipts + production)
                            _buildSecondaryKpiSection(),
                            const SizedBox(height: 24),
                            // Recent activity
                            _buildRecentActivitySection(l10n),
                            const SizedBox(height: 24),
                            // Notes + Tasks
                            _buildNotesTasksSection(l10n),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopHeader(AppLocalizations l10n) {
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, d MMMM yyyy', 'sk').format(now);

    return Container(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
      decoration: const BoxDecoration(
        color: AppColors.bgPrimary,
        border: Border(bottom: BorderSide(color: AppColors.borderSubtle, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Prehľad',
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateStr,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              _HeaderActionButton(
                icon: Icons.search_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SearchScreen()),
                ),
              ),
              const SizedBox(width: 10),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _HeaderActionButton(
                    icon: Icons.notifications_outlined,
                    onTap: () => widget.onNotificationTap?.call(),
                  ),
                  if (widget.notificationUnreadCount > 0)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: AppColors.danger,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.bgPrimary, width: 1.5),
                        ),
                        child: Center(
                          child: Text(
                            '${widget.notificationUnreadCount}',
                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              _SyncButton(
                onTap: () async {
                  await widget.onSyncFromBackend?.call();
                  _loadStats();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              color: AppColors.accentGold,
              strokeWidth: 2.5,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Načítavam...',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildMainKpiSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label: 'Kľúčové ukazatele', icon: Icons.trending_up_rounded),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, constraints) {
          final crossCount = constraints.maxWidth > 700
              ? 4
              : constraints.maxWidth > 450
                  ? 2
                  : 2;
          return GridView.count(
            crossAxisCount: crossCount,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: constraints.maxWidth > 700 ? 1.5 : 1.4,
            children: [
              _FadeInWidget(
                animation: _staggerAnim(0),
                child: _KpiCard(
                  icon: Icons.inventory_2_rounded,
                  label: 'Produkty',
                  value: _stats['products'].toString(),
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => WarehouseSuppliesScreen(userRole: widget.userRole),
                  )).then((_) => _loadStats()),
                ),
              ),
              _FadeInWidget(
                animation: _staggerAnim(1),
                child: _KpiCard(
                  icon: Icons.people_rounded,
                  label: 'Zákazníci',
                  value: _stats['customers'].toString(),
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const CustomersPage(),
                  )).then((_) => _loadStats()),
                ),
              ),
              _FadeInWidget(
                animation: _staggerAnim(2),
                child: _KpiCard(
                  icon: Icons.euro_rounded,
                  label: 'Tržby',
                  value: _formatCurrencyShort(_stats['revenue']),
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const PriceQuotesListScreen(),
                  )).then((_) => _loadStats()),
                ),
              ),
              _FadeInWidget(
                animation: _staggerAnim(3),
                child: _KpiCard(
                  icon: Icons.request_quote_rounded,
                  label: 'Cenové ponuky',
                  value: (_stats['quotesCount'] ?? _stats['orders'] ?? 0).toString(),
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const PriceQuotesListScreen(),
                  )).then((_) => _loadStats()),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildSecondaryKpiSection() {
    final receiptsToday = _stats['receiptsToday'] is int ? _stats['receiptsToday'] as int : 0;
    final pendingCount = _stats['pendingReceiptCount'] is int ? _stats['pendingReceiptCount'] as int : 0;
    final lowStock = _stats['lowStockCount'] is int ? _stats['lowStockCount'] as int : 0;
    final inProgress = _stats['productionInProgressCount'] is int ? _stats['productionInProgressCount'] as int : 0;
    final valueMonth = _stats['receiptsValueThisMonth'] is num
        ? (_stats['receiptsValueThisMonth'] as num).toDouble()
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label: 'Operačný prehľad', icon: Icons.speed_rounded),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, constraints) {
          final crossCount = constraints.maxWidth > 700
              ? 5
              : constraints.maxWidth > 450
                  ? 3
                  : 2;
          return GridView.count(
            crossAxisCount: crossCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: constraints.maxWidth > 600 ? 1.5 : 1.3,
            children: [
              _FadeInWidget(
                animation: _staggerAnim(4),
                child: _SmallKpiCard(
                  icon: Icons.today_rounded,
                  label: 'Príjemky dnes',
                  value: receiptsToday.toString(),
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const GoodsReceiptScreen(),
                  )).then((_) => _loadStats()),
                ),
              ),
              _FadeInWidget(
                animation: _staggerAnim(4),
                child: _SmallKpiCard(
                  icon: Icons.pending_actions_rounded,
                  label: 'Na schválenie',
                  value: pendingCount.toString(),
                  iconColor: pendingCount > 0 ? AppColors.warning : null,
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const GoodsReceiptScreen(),
                  )).then((_) => _loadStats()),
                ),
              ),
              _FadeInWidget(
                animation: _staggerAnim(5),
                child: _SmallKpiCard(
                  icon: Icons.warning_amber_rounded,
                  label: 'Nízky sklad',
                  value: lowStock.toString(),
                  iconColor: lowStock > 0 ? AppColors.danger : null,
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => WarehouseSuppliesScreen(userRole: widget.userRole),
                  )).then((_) => _loadStats()),
                ),
              ),
              _FadeInWidget(
                animation: _staggerAnim(5),
                child: _SmallKpiCard(
                  icon: Icons.play_circle_rounded,
                  label: 'Prebieha výroba',
                  value: inProgress.toString(),
                  iconColor: inProgress > 0 ? AppColors.success : null,
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ProductionOrderListScreen(userRole: widget.userRole),
                  )).then((_) => _loadStats()),
                ),
              ),
              _FadeInWidget(
                animation: _staggerAnim(6),
                child: _SmallKpiCard(
                  icon: Icons.euro_rounded,
                  label: 'Hodnota / mesiac',
                  value: _formatCurrencyShort(valueMonth),
                  onTap: () {},
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildRecentActivitySection(AppLocalizations l10n) {
    final inboundList = (_stats['recentInbound'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final outboundList = (_stats['recentOutbound'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

    return _FadeInWidget(
      animation: _staggerAnim(7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(label: 'Posledná aktivita', icon: Icons.swap_vert_rounded),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, constraints) {
            if (constraints.maxWidth > 550) {
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _ActivityColumn(
                        title: 'Posledné príjemky',
                        items: inboundList,
                        isInbound: true,
                        onViewAll: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const GoodsReceiptScreen(),
                        )).then((_) => _loadStats()),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _ActivityColumn(
                        title: 'Posledné výdajky',
                        items: outboundList,
                        isInbound: false,
                        onViewAll: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => StockOutScreen(userRole: widget.userRole),
                        )).then((_) => _loadStats()),
                      ),
                    ),
                  ],
                ),
              );
            }
            return Column(
              children: [
                _ActivityColumn(
                  title: 'Posledné príjemky',
                  items: inboundList,
                  isInbound: true,
                  onViewAll: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const GoodsReceiptScreen(),
                  )).then((_) => _loadStats()),
                ),
                const SizedBox(height: 14),
                _ActivityColumn(
                  title: 'Posledné výdajky',
                  items: outboundList,
                  isInbound: false,
                  onViewAll: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => StockOutScreen(userRole: widget.userRole),
                  )).then((_) => _loadStats()),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildNotesTasksSection(AppLocalizations l10n) {
    return _FadeInWidget(
      animation: _staggerAnim(8, total: 9),
      child: LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth > 550) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildNotesCard(l10n, matchHeight: true)),
                const SizedBox(width: 14),
                Expanded(child: _buildTasksCard(l10n, matchHeight: true)),
              ],
            ),
          );
        }
        return Column(
          children: [
            _buildNotesCard(l10n, matchHeight: false),
            const SizedBox(height: 14),
            _buildTasksCard(l10n, matchHeight: false),
          ],
        );
      }),
    );
  }

  Widget _buildNotesCard(AppLocalizations l10n, {required bool matchHeight}) {
    final notesField = TextField(
      controller: _noteController,
      maxLines: matchHeight ? null : 4,
      minLines: 4,
      style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: l10n.overviewNotesPlaceholder,
        hintStyle: GoogleFonts.dmSans(color: AppColors.textMuted, fontSize: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.borderDefault),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.borderDefault),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.accentGold, width: 1.5),
        ),
        filled: true,
        fillColor: AppColors.bgInput,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
      onChanged: _saveNotes,
    );

    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(icon: Icons.notes_rounded, title: l10n.overviewNotesTitle),
          const SizedBox(height: 12),
          if (matchHeight) Expanded(child: notesField) else notesField,
        ],
      ),
    );
  }

  Widget _buildTasksCard(AppLocalizations l10n, {required bool matchHeight}) {
    final tasksList = _overviewTasks.asMap().entries.map((entry) {
      final i = entry.key;
      final task = entry.value;
      final title = task['t'] as String? ?? '';
      final done = task['d'] as bool? ?? false;
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: Checkbox(
                value: done,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                activeColor: AppColors.accentGold,
                side: const BorderSide(color: AppColors.borderDefault, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                onChanged: (v) {
                  _overviewTasks[i]['d'] = v ?? false;
                  _saveTasks();
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title.isEmpty ? '—' : title,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  decoration: done ? TextDecoration.lineThrough : null,
                  color: done ? AppColors.textMuted : AppColors.textPrimary,
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                _overviewTasks.removeAt(i);
                _saveTasks();
              },
              child: const Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }).toList();

    final addRow = Row(
      children: [
        Expanded(
          child: TextField(
            controller: _newTaskController,
            style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: l10n.overviewNewTaskHint,
              hintStyle: GoogleFonts.dmSans(color: AppColors.textMuted, fontSize: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.borderDefault),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.borderDefault),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.accentGold, width: 1.5),
              ),
              filled: true,
              fillColor: AppColors.bgInput,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              isDense: true,
            ),
            onSubmitted: (v) {
              final t = v.trim();
              if (t.isEmpty) return;
              _overviewTasks.add({'t': t, 'd': false});
              _newTaskController.clear();
              _saveTasks();
            },
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            final t = _newTaskController.text.trim();
            if (t.isEmpty) return;
            _overviewTasks.add({'t': t, 'd': false});
            _newTaskController.clear();
            _saveTasks();
          },
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.accentGold,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(color: AppColors.accentGold.withOpacity(0.3), blurRadius: 8),
              ],
            ),
            child: const Icon(Icons.add_rounded, color: AppColors.bgPrimary, size: 20),
          ),
        ),
      ],
    );

    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(icon: Icons.checklist_rounded, title: l10n.overviewTasksTitle),
          const SizedBox(height: 10),
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
                  const SizedBox(height: 8),
                  addRow,
                ],
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [...tasksList, const SizedBox(height: 8), addRow],
            ),
        ],
      ),
    );
  }

  String _formatCurrencyShort(dynamic value) {
    final n = value is num ? value.toDouble() : 0.0;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M €';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k €';
    return '${NumberFormat.decimalPattern('sk_SK').format(n)} €';
  }
}

// ─── Reusable components ──────────────────────────────────────────────────────

class _PremiumCard extends StatelessWidget {
  final Widget child;
  const _PremiumCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle, width: 1),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 24, offset: Offset(0, 8)),
        ],
      ),
      child: child,
    );
  }
}

class _CardHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _CardHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.accentGold,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Icon(icon, size: 15, color: AppColors.accentGold),
        const SizedBox(width: 6),
        Text(
          title,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionLabel({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AppColors.accentGold),
        const SizedBox(width: 6),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.dmSans(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }
}

class _KpiCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _KpiCard({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  State<_KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<_KpiCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          transform: _hovered
              ? (Matrix4.identity()..translateByDouble(0.0, -2.0, 0.0, 1.0))
              : Matrix4.identity(),
          clipBehavior: Clip.hardEdge,
          constraints: const BoxConstraints(minHeight: 120, maxHeight: 140),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hovered ? AppColors.accentGold.withOpacity(0.35) : AppColors.borderSubtle,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _hovered
                    ? AppColors.accentGold.withOpacity(0.1)
                    : Colors.black45,
                blurRadius: _hovered ? 20 : 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.accentGoldSubtle,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(widget.icon, color: AppColors.accentGold, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: _AnimatedNumber(
                  value: widget.value,
                  style: GoogleFonts.outfit(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accentGold,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.label,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallKpiCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;
  final VoidCallback? onTap;

  const _SmallKpiCard({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
    this.onTap,
  });

  @override
  State<_SmallKpiCard> createState() => _SmallKpiCardState();
}

class _SmallKpiCardState extends State<_SmallKpiCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.iconColor ?? AppColors.accentGold;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderSubtle, width: 1),
            boxShadow: const [
              BoxShadow(color: Colors.black38, blurRadius: 12, offset: Offset(0, 4)),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      widget.label,
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(widget.icon, size: 14, color: color.withOpacity(0.7)),
                ],
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: _AnimatedNumber(
                  value: widget.value,
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityColumn extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> items;
  final bool isInbound;
  final VoidCallback onViewAll;

  const _ActivityColumn({
    required this.title,
    required this.items,
    required this.isInbound,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = isInbound ? AppColors.success : AppColors.danger;
    final accentSubtle = isInbound ? AppColors.successSubtle : AppColors.dangerSubtle;
    final arrow = isInbound ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded;
    final dateFormat = DateFormat('dd.MM.yy');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle, width: 1),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 24, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: accentSubtle,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(arrow, size: 16, color: accentColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            _EmptyState(
              icon: isInbound ? Icons.inbox_rounded : Icons.outbox_rounded,
              message: isInbound ? 'Žiadne príjemky' : 'Žiadne výdajky',
            )
          else
            ...items.take(5).map((e) {
              final createdAt = e['created_at'];
              DateTime? dt;
              if (createdAt is String) dt = DateTime.tryParse(createdAt);
              else if (createdAt is int) dt = DateTime.fromMillisecondsSinceEpoch(createdAt);
              final total = (e['total'] as num?)?.toDouble() ?? 0.0;
              final dateStr = dt != null ? dateFormat.format(dt) : '—';
              final timeAgo = dt != null ? _timeAgo(dt) : '';
              final prefix = isInbound ? '+ ' : '- ';

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppColors.bgElevated,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(arrow, size: 14, color: accentColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dateStr,
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (timeAgo.isNotEmpty)
                              Text(
                                timeAgo,
                                style: GoogleFonts.dmSans(
                                  fontSize: 10,
                                  color: AppColors.textMuted,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        '$prefix${NumberFormat.decimalPattern('sk_SK').format(total)} €',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: onViewAll,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Zobraziť všetky',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentGold,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.accentGold),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'pred ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'pred ${diff.inHours} h';
    if (diff.inDays < 7) return 'pred ${diff.inDays} d';
    return '';
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Icon(icon, size: 36, color: AppColors.textMuted),
          const SizedBox(height: 8),
          Text(
            message,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _FadeInWidget extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  const _FadeInWidget({required this.animation, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) => Opacity(
        opacity: animation.value,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - animation.value)),
          child: child,
        ),
      ),
    );
  }
}

/// Animates numeric values (count-up)
class _AnimatedNumber extends StatelessWidget {
  final String value;
  final TextStyle style;
  const _AnimatedNumber({required this.value, required this.style});

  @override
  Widget build(BuildContext context) {
    // Try to extract numeric part for animation
    final numericStr = value.replaceAll(RegExp(r'[^\d]'), '');
    final numericVal = int.tryParse(numericStr);

    if (numericVal == null || numericVal == 0) {
      return Text(value, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
    }

    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: numericVal),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOutCubic,
      builder: (context, animVal, _) {
        String display = value.contains('€')
            ? value.replaceAll(numericStr, NumberFormat.decimalPattern('sk_SK').format(animVal))
            : animVal.toString();
        return Text(display, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
      },
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderActionButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderDefault, width: 1),
        ),
        child: Icon(icon, color: AppColors.textPrimary, size: 20),
      ),
    );
  }
}

class _SyncButton extends StatefulWidget {
  final Future<void> Function() onTap;
  const _SyncButton({required this.onTap});

  @override
  State<_SyncButton> createState() => _SyncButtonState();
}

class _SyncButtonState extends State<_SyncButton> with SingleTickerProviderStateMixin {
  late AnimationController _spin;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat();
    _spin.stop();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  void _trigger() async {
    setState(() => _syncing = true);
    _spin.repeat();
    await Future.delayed(const Duration(milliseconds: 300));
    await widget.onTap();
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      _spin.stop();
      setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _syncing ? null : _trigger,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.accentGoldSubtle,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.accentGold.withOpacity(0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RotationTransition(
              turns: _spin,
              child: const Icon(Icons.sync_rounded, size: 16, color: AppColors.accentGold),
            ),
            const SizedBox(width: 6),
            Text(
              _syncing ? 'Synchronizujem...' : 'Synchronizovať',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.accentGold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
