import 'dart:ui';
import 'package:flutter/material.dart';
import '../../models/inventory_audit.dart';
import '../../models/warehouse.dart';
import '../../services/Database/database_service.dart';
import '../../services/Warehouse/warehouse_service.dart';
import '../../widgets/Warehouse/warehouse_inventory_sheet_widget.dart';
import '../../theme/app_theme.dart';

class InventoryHistoryScreen extends StatefulWidget {
  final String userRole;
  const InventoryHistoryScreen({super.key, required this.userRole});

  @override
  State<InventoryHistoryScreen> createState() => _InventoryHistoryScreenState();
}

class _InventoryHistoryScreenState extends State<InventoryHistoryScreen> {
  final DatabaseService _db = DatabaseService();
  final WarehouseService _warehouseService = WarehouseService();
  List<InventoryAudit> _audits = [];
  List<Warehouse> _warehouses = [];
  int? _filterWarehouseId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadWarehouses();
    _load();
  }

  Future<void> _loadWarehouses() async {
    final list = await _warehouseService.getActiveWarehouses();
    if (mounted) setState(() => _warehouses = list);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final maps = await _db.getInventoryAudits(warehouseId: _filterWarehouseId);
    if (mounted) {
      setState(() {
        _audits = maps.map((m) => InventoryAudit.fromMap(m)).toList();
        _loading = false;
      });
    }
  }

  void _startNewInventory() {
    if (_warehouses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nie sú k dispozícii žiadne sklady.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    _showWarehousePicker();
  }

  void _showWarehousePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Text(
                'Vyberte sklad pre inventúru',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            ..._warehouses.map((w) => ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.accentGoldSubtle,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.warehouse_rounded, color: AppColors.accentGold, size: 20),
                  ),
                  title: Text(w.name, style: TextStyle(color: AppColors.textPrimary)),
                  subtitle: Text(w.code, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openInventorySheet(w);
                  },
                )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _openInventorySheet(Warehouse w) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => WarehouseInventorySheetWidget(
        warehouse: w,
        onSaved: () => _load(),
      ),
    );
  }

  void _showAuditDetail(InventoryAudit audit) async {
    final maps = await _db.getInventoryAuditItems(audit.id!);
    final items = maps.map((m) => InventoryAuditItem.fromMap(m)).toList();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AuditDetailSheet(audit: audit, items: items),
    );
  }

  Future<void> _deleteAudit(InventoryAudit audit) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Vymazať inventúru?', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Záznam inventúry zo dňa ${_formatDate(audit.createdAt)} bude vymazaný. Stavy skladu sa nezmenia.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Zrušiť', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Vymazať', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await _db.deleteInventoryAudit(audit.id!);
      _load();
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}'
        '  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.bgPrimary,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: AppBar(
              backgroundColor: AppColors.bgCard.withValues(alpha: 0.85),
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'Inventúra',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: AppColors.textPrimary,
                ),
              ),
              actions: [
                if (_warehouses.isNotEmpty)
                  PopupMenuButton<int?>(
                    icon: Icon(
                      Icons.filter_list_rounded,
                      color: _filterWarehouseId != null ? AppColors.accentGold : AppColors.textSecondary,
                    ),
                    tooltip: 'Filtrovať podľa skladu',
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onSelected: (id) {
                      setState(() => _filterWarehouseId = id);
                      _load();
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: null,
                        child: Text(
                          'Všetky sklady',
                          style: TextStyle(
                            color: _filterWarehouseId == null ? AppColors.accentGold : AppColors.textPrimary,
                            fontWeight: _filterWarehouseId == null ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                      ..._warehouses.map((w) => PopupMenuItem(
                            value: w.id,
                            child: Text(
                              w.name,
                              style: TextStyle(
                                color: _filterWarehouseId == w.id ? AppColors.accentGold : AppColors.textPrimary,
                                fontWeight: _filterWarehouseId == w.id ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          )),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: AppColors.accentGold))
          : _audits.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.accentGold,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 90, 16, 100),
                    itemCount: _audits.length,
                    itemBuilder: (context, index) {
                      final audit = _audits[index];
                      return _AuditCard(
                        audit: audit,
                        onTap: () => _showAuditDetail(audit),
                        onDelete: widget.userRole == 'admin' ? () => _deleteAudit(audit) : null,
                        formatDate: _formatDate,
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startNewInventory,
        backgroundColor: AppColors.accentGold,
        icon: Icon(Icons.add_chart_rounded, color: AppColors.bgPrimary),
        label: Text('Nová inventúra', style: TextStyle(color: AppColors.bgPrimary, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fact_check_outlined, size: 80, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text(
            'Zatiaľ žiadne inventúry',
            style: TextStyle(fontSize: 18, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Začnite novú inventúru tlačidlom nižšie',
            style: TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _AuditCard extends StatelessWidget {
  final InventoryAudit audit;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final String Function(DateTime) formatDate;

  const _AuditCard({
    required this.audit,
    required this.onTap,
    this.onDelete,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: AppColors.cardDecoration,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.accentGoldSubtle,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.fact_check_rounded, color: AppColors.accentGold, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        audit.warehouseName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatDate(audit.createdAt),
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _statBadge(Icons.person_outline, audit.username, AppColors.textSecondary),
                          const SizedBox(width: 10),
                          _statBadge(Icons.inventory_2_outlined, '${audit.totalProducts} produktov', AppColors.textSecondary),
                          const SizedBox(width: 10),
                          _statBadge(
                            Icons.edit_note_rounded,
                            '${audit.changedProducts} zmien',
                            audit.changedProducts > 0 ? AppColors.accentGold : AppColors.success,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: AppColors.textMuted, size: 20),
                    tooltip: 'Vymazať záznam',
                    onPressed: onDelete,
                  ),
                Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statBadge(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 11, color: color)),
      ],
    );
  }
}

class _AuditDetailSheet extends StatelessWidget {
  final InventoryAudit audit;
  final List<InventoryAuditItem> items;

  const _AuditDetailSheet({required this.audit, required this.items});

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}'
        '  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    int totalSurplus = 0;
    int totalDeficit = 0;
    for (final item in items) {
      if (item.difference > 0) {
        totalSurplus += item.difference;
      } else {
        totalDeficit += item.difference.abs();
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle, width: 1),
          left: BorderSide(color: AppColors.borderSubtle, width: 1),
          right: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.textMuted,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Inventúra: ${audit.warehouseName}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Text(_formatDate(audit.createdAt), style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        const SizedBox(width: 16),
                        Icon(Icons.person_outline, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Text(audit.username, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _summaryChip('Zmien', '${items.length}', AppColors.accentGold),
                        const SizedBox(width: 8),
                        if (totalSurplus > 0) ...[
                          _summaryChip('Prebytok', '+$totalSurplus', Colors.green),
                          const SizedBox(width: 8),
                        ],
                        if (totalDeficit > 0)
                          _summaryChip('Manko', '-$totalDeficit', Colors.red),
                      ],
                    ),
                    if (audit.notes != null && audit.notes!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(audit.notes!, style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontStyle: FontStyle.italic)),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Text('Žiadne zmeny', style: TextStyle(color: AppColors.textSecondary)),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return _AuditItemRow(item: item);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _summaryChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 12)),
          const SizedBox(width: 6),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}

class _AuditItemRow extends StatelessWidget {
  final InventoryAuditItem item;
  const _AuditItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final diff = item.difference;
    final isPositive = diff > 0;
    final diffColor = isPositive ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  item.productPlu,
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${item.systemQty} → ${item.actualQty} ${item.unit}',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: diffColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${isPositive ? "+" : ""}$diff',
                  style: TextStyle(
                    color: diffColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
