import 'package:flutter/material.dart';
import '../../models/warehouse.dart';
import '../../services/warehouse/warehouse_service.dart';
import '../../l10n/app_localizations.dart';
import 'add_warehouse_modal_widget.dart';

class WarehouseListWidget extends StatefulWidget {
  const WarehouseListWidget({super.key});

  @override
  State<WarehouseListWidget> createState() => WarehouseListWidgetState();
}

class WarehouseListWidgetState extends State<WarehouseListWidget>
    with TickerProviderStateMixin {
  final WarehouseService _warehouseService = WarehouseService();
  final TextEditingController _searchController = TextEditingController();

  List<Warehouse> _warehouses = [];
  List<Warehouse> _filteredWarehouses = [];
  bool _loading = true;
  int _statusFilter = 0; // 0 = všetci, 1 = aktívni, 2 = neaktívni

  late final AnimationController _listController = AnimationController(
    duration: const Duration(milliseconds: 800),
    vsync: this,
  )..forward();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadWarehouses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _listController.dispose();
    super.dispose();
  }

  void _onSearchChanged() => setState(() => _filterWarehouses());

  void _filterWarehouses() {
    var list = _warehouses;
    if (_statusFilter == 1) list = list.where((w) => w.isActive).toList();
    if (_statusFilter == 2) list = list.where((w) => !w.isActive).toList();
    final q = _searchController.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where(
            (w) =>
                w.name.toLowerCase().contains(q) ||
                w.code.toLowerCase().contains(q) ||
                (w.city?.toLowerCase().contains(q) ?? false),
          )
          .toList();
    }
    _filteredWarehouses = list;
  }

  Future<void> _loadWarehouses() async {
    setState(() => _loading = true);
    final list = await _warehouseService.getAllWarehouses();
    if (mounted) {
      setState(() {
        _warehouses = list;
        _filterWarehouses();
        _loading = false;
      });
    }
  }

  // Verejná metóda pre obnovenie zoznamu zvonka
  void refreshWarehouses() {
    _loadWarehouses();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      color: const Color(0xFFF8FAFC), // Svetlé, čisté pozadie
      child: Column(
        children: [
          _buildHeader(l10n),
          if (_loading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF6366F1)),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadWarehouses,
                color: const Color(0xFF6366F1),
                child: _filteredWarehouses.isEmpty
                    ? const Center(child: Text('Žiadne sklady neboli nájdené'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                        physics: const BouncingScrollPhysics(),
                        itemCount: _filteredWarehouses.length,
                        itemBuilder: (context, index) {
                          final w = _filteredWarehouses[index];
                          return _WarehouseCard(
                            warehouse: w,
                            index: index,
                            controller: _listController,
                            onEdit: () => _editWarehouse(w),
                            onDelete: () => _deleteWarehouse(w),
                          );
                        },
                      ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, kToolbarHeight + 10, 20, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: l10n.searchHintWarehouses,
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Color(0xFF6366F1),
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFF1F5F9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _FilterChip(
                label: l10n.all,
                selected: _statusFilter == 0,
                onTap: () => _setStatus(0),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: l10n.allActive,
                selected: _statusFilter == 1,
                onTap: () => _setStatus(1),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: l10n.allInactive,
                selected: _statusFilter == 2,
                onTap: () => _setStatus(2),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _setStatus(int status) {
    setState(() {
      _statusFilter = status;
      _filterWarehouses();
    });
  }

  void _editWarehouse(Warehouse w) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AddWarehouseModal(warehouse: w),
    ).then((result) {
      // Obnoviť zoznam po úprave skladu
      if (result != null) {
        _loadWarehouses();
      }
    });
  }

  Future<void> _deleteWarehouse(Warehouse w) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteWarehouse),
        content: Text(l10n.deleteWarehouseConfirm(w.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await _warehouseService.deleteWarehouse(w.id!);
      if (mounted) {
        _loadWarehouses();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.warehouseDeleted),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }
}

class _WarehouseCard extends StatelessWidget {
  final Warehouse warehouse;
  final int index;
  final AnimationController controller;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _WarehouseCard({
    required this.warehouse,
    required this.index,
    required this.controller,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final w = warehouse;
    final animation = CurvedAnimation(
      parent: controller,
      curve: Interval(
        (0.05 * index).clamp(0.0, 0.9),
        1.0,
        curve: Curves.easeOutBack,
      ),
    );

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.2, 0),
          end: Offset.zero,
        ).animate(animation),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withOpacity(0.03),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onEdit,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _buildIconBox(),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              w.code,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF6366F1),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildStatusDot(w.isActive),
                          ],
                        ),
                        Text(
                          w.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              size: 14,
                              color: Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              w.address != null && w.address!.isNotEmpty
                                  ? w.address!
                                  : (w.city ?? 'Nezadané'),
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {}, // Zastaví propagáciu kliknutia
                    child: _buildActionMenu(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconBox() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(
        Icons.warehouse_rounded,
        color: Color(0xFF6366F1),
        size: 28,
      ),
    );
  }

  Widget _buildStatusDot(bool active) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: active ? Colors.green : Colors.red,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: (active ? Colors.green : Colors.red).withOpacity(0.4),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildActionMenu(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF94A3B8)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'edit',
            child: _MenuEntry(Icons.edit_rounded, 'Upraviť'),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: _MenuEntry(
              Icons.delete_outline_rounded,
              'Zmazať',
              isDestructive: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuEntry extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDestructive;
  const _MenuEntry(this.icon, this.label, {this.isDestructive = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: isDestructive ? Colors.red : const Color(0xFF6366F1),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            color: isDestructive ? Colors.red : const Color(0xFF1E293B),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: selected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}
