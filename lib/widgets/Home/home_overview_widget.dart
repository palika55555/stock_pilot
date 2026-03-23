import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../screens/goods_receipt/goods_receipt_screen.dart';
import '../../screens/price_quote/price_quotes_list_screen.dart';
import '../../screens/warehouse/warehouse_supplies.dart';
import '../../screens/stock_out/stock_out_screen.dart';
import '../../screens/customers/customers_page.dart';
import '../../screens/Projects/projects_page.dart';
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
  final Future<void> Function()? onSyncFromBackend;
  final Future<void> Function()? onSyncToBackend;

  const HomeOverview({
    super.key,
    required this.userRole,
    this.user,
    this.notificationUnreadCount = 0,
    this.onNotificationTap,
    this.onSyncFromBackend,
    this.onSyncToBackend,
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
      duration: const Duration(milliseconds: 900),
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
    if (!mounted) return;
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
                        parent: ClampingScrollPhysics(),
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
                            _buildMainKpiSection(l10n),
                            const SizedBox(height: 28),
                            _buildSecondaryKpiSection(),
                            const SizedBox(height: 28),
                            _buildRecentActivitySection(l10n),
                            const SizedBox(height: 28),
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
    final dateStr = DateFormat('EEEE, d. MMMM yyyy', 'sk').format(now);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgPrimary,
        border: Border(bottom: BorderSide(color: AppColors.borderSubtle, width: 1)),
      ),
      child: Column(
        children: [
          // Status micro-bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 7),
            decoration: const BoxDecoration(
              color: Color(0xFF0D0F18),
              border: Border(bottom: BorderSide(color: AppColors.borderSubtle, width: 1)),
            ),
            child: Row(
              children: [
                _LivePulse(color: AppColors.success),
                const SizedBox(width: 8),
                Text(
                  'SYSTÉM ONLINE',
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(width: 20),
                Container(width: 1, height: 12, color: AppColors.borderDefault),
                const SizedBox(width: 20),
                Text(
                  'STOCK PILOT',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMuted,
                    letterSpacing: 2.0,
                  ),
                ),
                const Spacer(),
                Icon(Icons.schedule_rounded, size: 12, color: AppColors.textMuted),
                const SizedBox(width: 5),
                Text(
                  dateStr,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          // Main header row
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 18, 28, 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PREHĽAD',
                      style: GoogleFonts.outfit(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      'Sklad v reálnom čase',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    _HeaderQuickButton(
                      icon: Icons.arrow_downward_rounded,
                      label: 'Nová príjemka',
                      color: const Color(0xFF6366F1),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const GoodsReceiptScreen()),
                      ).then((_) => _loadStats()),
                    ),
                    const SizedBox(width: 8),
                    _HeaderQuickButton(
                      icon: Icons.arrow_upward_rounded,
                      label: 'Nová výdajka',
                      color: const Color(0xFFDC2626),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => StockOutScreen(userRole: widget.userRole)),
                      ).then((_) => _loadStats()),
                    ),
                    const SizedBox(width: 16),
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
                    if (!kIsWeb) ...[
                      const SizedBox(width: 10),
                      _SyncButton(
                        onSyncFromWeb: () async {
                          await widget.onSyncFromBackend?.call();
                          _loadStats();
                        },
                        onSyncToWeb: () async {
                          await widget.onSyncToBackend?.call();
                          _loadStats();
                        },
                      ),
                    ],
                  ],
                ),
              ],
            ),
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
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              color: AppColors.accentGold,
              strokeWidth: 2,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'NAČÍTAVAM DÁTA...',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label: 'Rýchle akcie', icon: Icons.bolt_rounded),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, constraints) {
          return Row(
            children: [
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.arrow_downward_rounded,
                  label: 'Nová príjemka',
                  color: const Color(0xFF6366F1),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const GoodsReceiptScreen()),
                  ).then((_) => _loadStats()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.arrow_upward_rounded,
                  label: 'Nová výdajka',
                  color: const Color(0xFFDC2626),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => StockOutScreen(userRole: widget.userRole)),
                  ).then((_) => _loadStats()),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildMainKpiSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label: 'Kľúčové ukazatele', icon: Icons.trending_up_rounded),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, constraints) {
          final crossCount = constraints.maxWidth > 700
              ? 4
              : constraints.maxWidth > 450
                  ? 2
                  : 2;
          return GridView.count(
            crossAxisCount: crossCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: constraints.maxWidth > 700 ? 1.55 : 1.4,
            children: [
              _FadeInWidget(
                animation: _staggerAnim(0),
                child: _KpiCard(
                  icon: Icons.inventory_2_rounded,
                  label: 'Produkty',
                  value: _stats['products'].toString(),
                  accentColor: AppColors.accentGold,
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
                  accentColor: const Color(0xFF6366F1),
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
                  accentColor: AppColors.success,
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
                  accentColor: const Color(0xFF8B5CF6),
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const PriceQuotesListScreen(),
                  )).then((_) => _loadStats()),
                ),
              ),
              _FadeInWidget(
                animation: _staggerAnim(4),
                child: _KpiCard(
                  icon: Icons.construction_rounded,
                  label: 'Zákazky',
                  value: '',
                  accentColor: AppColors.warning,
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const ProjectsPage(),
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
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, constraints) {
          final crossCount = constraints.maxWidth > 700
              ? 5
              : constraints.maxWidth > 450
                  ? 3
                  : 2;
          return GridView.count(
            crossAxisCount: crossCount,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: constraints.maxWidth > 600 ? 1.6 : 1.3,
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
          const SizedBox(height: 14),
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
                    const SizedBox(width: 12),
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
                const SizedBox(height: 12),
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
                const SizedBox(width: 12),
                Expanded(child: _buildTasksCard(l10n, matchHeight: true)),
              ],
            ),
          );
        }
        return Column(
          children: [
            _buildNotesCard(l10n, matchHeight: false),
            const SizedBox(height: 12),
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

    return _CommandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(icon: Icons.notes_rounded, title: l10n.overviewNotesTitle),
          const SizedBox(height: 14),
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
                BoxShadow(color: AppColors.accentGold.withOpacity(0.3), blurRadius: 10, spreadRadius: 0),
              ],
            ),
            child: const Icon(Icons.add_rounded, color: AppColors.bgPrimary, size: 20),
          ),
        ),
      ],
    );

    return _CommandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(icon: Icons.checklist_rounded, title: l10n.overviewTasksTitle),
          const SizedBox(height: 12),
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

/// Animated pulsing live indicator dot
class _LivePulse extends StatefulWidget {
  final Color color;
  const _LivePulse({required this.color});

  @override
  State<_LivePulse> createState() => _LivePulseState();
}

class _LivePulseState extends State<_LivePulse> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withOpacity(_anim.value),
          boxShadow: [
            BoxShadow(
              color: widget.color.withOpacity(_anim.value * 0.6),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}

class _CommandCard extends StatelessWidget {
  final Widget child;
  const _CommandCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderDefault, width: 1),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 20, offset: Offset(0, 6)),
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
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.accentGold, Color(0xFFF5A62380)],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Icon(icon, size: 14, color: AppColors.accentGold),
        const SizedBox(width: 6),
        Text(
          title,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: 0.3,
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
        Icon(icon, size: 12, color: AppColors.accentGold),
        const SizedBox(width: 7),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.dmSans(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: AppColors.textSecondary,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.borderDefault, AppColors.borderSubtle.withOpacity(0)],
              ),
            ),
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
  final Color accentColor;
  final VoidCallback? onTap;

  const _KpiCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accentColor,
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
          duration: const Duration(milliseconds: 200),
          transform: _hovered
              ? (Matrix4.identity()..translateByDouble(0.0, -3.0, 0.0, 1.0))
              : Matrix4.identity(),
          clipBehavior: Clip.hardEdge,
          constraints: const BoxConstraints(minHeight: 115, maxHeight: 145),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderDefault, width: 1),
            boxShadow: [
              BoxShadow(
                color: _hovered
                    ? widget.accentColor.withOpacity(0.12)
                    : Colors.black.withOpacity(0.3),
                blurRadius: _hovered ? 24 : 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Left accent strip kept separate so rounded border works on all Flutter backends.
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: _hovered ? widget.accentColor : widget.accentColor.withOpacity(0.7),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                    ),
                  ),
                ),
              ),
              // Subtle background gradient
              Positioned(
                right: -20,
                top: -20,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.accentColor.withOpacity(_hovered ? 0.07 : 0.04),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            widget.label.toUpperCase(),
                            style: GoogleFonts.dmSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                              letterSpacing: 1.0,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: widget.accentColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(widget.icon, color: widget.accentColor, size: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: _AnimatedNumber(
                        value: widget.value,
                        style: GoogleFonts.outfit(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          height: 1.0,
                          letterSpacing: -1.0,
                        ),
                      ),
                    ),
                  ],
                ),
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
            border: Border.all(color: AppColors.borderDefault, width: 1),
            boxShadow: const [
              BoxShadow(color: Color(0x26000000), blurRadius: 10, offset: Offset(0, 3)),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                      boxShadow: [
                        BoxShadow(color: color.withOpacity(0.5), blurRadius: 4, spreadRadius: 1),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
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
                  Icon(widget.icon, size: 13, color: color.withOpacity(0.5)),
                ],
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: _AnimatedNumber(
                  value: widget.value,
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: -0.5,
                    height: 1.1,
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
    final arrow = isInbound ? Icons.south_rounded : Icons.north_rounded;
    final dateFormat = DateFormat('dd.MM.yy');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderDefault, width: 1),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: accentColor.withOpacity(0.25), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(arrow, size: 12, color: accentColor),
                    const SizedBox(width: 4),
                    Text(
                      isInbound ? 'PRÍJEMKY' : 'VÝDAJKY',
                      style: GoogleFonts.dmSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (items.isNotEmpty)
                _LivePulse(color: accentColor),
            ],
          ),
          const SizedBox(height: 14),
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
              final prefix = isInbound ? '+' : '-';

              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D0F18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border(
                      left: BorderSide(color: accentColor.withOpacity(0.5), width: 2),
                    ),
                  ),
                  child: Row(
                    children: [
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
                        '$prefix ${NumberFormat.decimalPattern('sk_SK').format(total)} €',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: accentColor,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: onViewAll,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Zobraziť všetky',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentGold,
                  ),
                ),
                const SizedBox(width: 3),
                const Icon(Icons.arrow_forward_rounded, size: 13, color: AppColors.accentGold),
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
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(icon, size: 32, color: AppColors.textMuted),
          const SizedBox(height: 8),
          Text(
            message,
            style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textMuted),
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
          offset: Offset(0, 16 * (1 - animation.value)),
          child: child,
        ),
      ),
    );
  }
}

/// Count-up animated number
class _AnimatedNumber extends StatelessWidget {
  final String value;
  final TextStyle style;
  const _AnimatedNumber({required this.value, required this.style});

  @override
  Widget build(BuildContext context) {
    final numericStr = value.replaceAll(RegExp(r'[^\d]'), '');
    final numericVal = int.tryParse(numericStr);

    if (numericVal == null || numericVal == 0) {
      return Text(value.isEmpty ? '—' : value, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
    }

    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: numericVal),
      duration: const Duration(milliseconds: 1100),
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

class _HeaderActionButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderActionButton({required this.icon, required this.onTap});

  @override
  State<_HeaderActionButton> createState() => _HeaderActionButtonState();
}

class _HeaderActionButtonState extends State<_HeaderActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _hovered ? AppColors.bgElevated : AppColors.bgCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hovered ? AppColors.borderDefault : AppColors.borderSubtle,
              width: 1,
            ),
          ),
          child: Icon(widget.icon, color: _hovered ? AppColors.textPrimary : AppColors.textSecondary, size: 19),
        ),
      ),
    );
  }
}

class _SyncButton extends StatefulWidget {
  final Future<void> Function()? onSyncFromWeb;
  final Future<void> Function()? onSyncToWeb;

  const _SyncButton({this.onSyncFromWeb, this.onSyncToWeb});

  @override
  State<_SyncButton> createState() => _SyncButtonState();
}

class _SyncButtonState extends State<_SyncButton> with SingleTickerProviderStateMixin {
  late AnimationController _spin;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat();
    _spin.stop();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function()? action) async {
    if (action == null) return;
    setState(() => _syncing = true);
    _spin.repeat();
    await Future.delayed(const Duration(milliseconds: 150));
    await action();
    if (mounted) {
      _spin.stop();
      setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasFrom = widget.onSyncFromWeb != null;
    final hasTo = widget.onSyncToWeb != null;
    final showMenu = (hasFrom || hasTo) && !_syncing;

    return PopupMenuButton<String>(
      enabled: showMenu,
      onSelected: (value) async {
        if (value == 'from_web') await _run(widget.onSyncFromWeb);
        if (value == 'to_web') await _run(widget.onSyncToWeb);
      },
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: AppColors.bgCard,
      itemBuilder: (context) => [
        if (hasFrom)
          const PopupMenuItem<String>(
            value: 'from_web',
            child: Row(
              children: [
                Icon(Icons.cloud_download_rounded, size: 20, color: AppColors.accentGold),
                SizedBox(width: 12),
                Text('Stiahnuť z webu', style: TextStyle(fontSize: 14)),
              ],
            ),
          ),
        if (hasTo)
          const PopupMenuItem<String>(
            value: 'to_web',
            child: Row(
              children: [
                Icon(Icons.cloud_upload_rounded, size: 20, color: AppColors.accentGold),
                SizedBox(width: 12),
                Text('Nahrať na web', style: TextStyle(fontSize: 14)),
              ],
            ),
          ),
      ],
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.accentGoldSubtle,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.accentGold.withOpacity(0.25), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RotationTransition(
              turns: _spin,
              child: const Icon(Icons.sync_rounded, size: 15, color: AppColors.accentGold),
            ),
            const SizedBox(width: 6),
            Text(
              _syncing ? 'Sync...' : 'Sync',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.accentGold,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down_rounded, size: 16, color: AppColors.accentGold),
          ],
        ),
      ),
    );
  }
}

class _HeaderQuickButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _HeaderQuickButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_HeaderQuickButton> createState() => _HeaderQuickButtonState();
}

class _HeaderQuickButtonState extends State<_HeaderQuickButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: _hovered ? widget.color.withOpacity(0.18) : widget.color.withOpacity(0.09),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hovered ? widget.color.withOpacity(0.55) : widget.color.withOpacity(0.22),
              width: 1,
            ),
            boxShadow: _hovered
                ? [BoxShadow(color: widget.color.withOpacity(0.15), blurRadius: 10)]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 14, color: widget.color),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: widget.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<_QuickActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: _hovered ? widget.color.withOpacity(0.15) : widget.color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hovered ? widget.color.withOpacity(0.55) : widget.color.withOpacity(0.22),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(widget.icon, color: widget.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.label,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 13, color: widget.color.withOpacity(0.6)),
            ],
          ),
        ),
      ),
    );
  }
}
