import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:stock_pilot/models/supplier.dart';
import 'package:stock_pilot/services/supplier/supplier_service.dart';
import 'package:stock_pilot/widgets/suppliers/add_supplier_modal_widget.dart';
import 'package:stock_pilot/l10n/app_localizations.dart';

class SuppliersPage extends StatefulWidget {
  const SuppliersPage({super.key});

  @override
  State<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends State<SuppliersPage>
    with TickerProviderStateMixin {
  final SupplierService _supplierService = SupplierService();
  final TextEditingController _searchController = TextEditingController();

  List<Supplier> _suppliers = [];
  List<Supplier> _filteredSuppliers = [];
  bool _loading = true;
  int _statusFilter = 0; // 0 = všetci, 1 = aktívni, 2 = neaktívni

  late final AnimationController _listController = AnimationController(
    duration: const Duration(milliseconds: 600),
    vsync: this,
  )..forward();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadSuppliers();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _listController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() => _filterSuppliers());
  }

  void _filterSuppliers() {
    var list = _suppliers;
    if (_statusFilter == 1) list = list.where((s) => s.isActive).toList();
    if (_statusFilter == 2) list = list.where((s) => !s.isActive).toList();
    final q = _searchController.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where(
            (s) =>
                s.name.toLowerCase().contains(q) ||
                s.ico.contains(q) ||
                (s.city?.toLowerCase().contains(q) ?? false) ||
                (s.dic?.contains(q) ?? false),
          )
          .toList();
    }
    _filteredSuppliers = list;
  }

  Future<void> _loadSuppliers() async {
    setState(() => _loading = true);
    final list = await _supplierService.getAllSuppliers();
    if (mounted) {
      setState(() {
        _suppliers = list;
        _filterSuppliers();
        _loading = false;
      });
    }
  }

  void _addSupplier() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const AddSupplierModal(),
    ).then((result) {
      // Obnoviť zoznam po pridaní alebo úprave dodávateľa
      if (result != null) {
        _loadSuppliers();
      }
    });
  }

  void _editSupplier(Supplier s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AddSupplierModal(supplier: s),
    ).then((result) {
      // Obnoviť zoznam po úprave dodávateľa
      if (result != null) {
        _loadSuppliers();
      }
    });
  }

  Future<void> _deleteSupplier(Supplier s) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteSupplier),
        content: Text(l10n.deleteSupplierConfirm(s.name)),
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
      await _supplierService.deleteSupplier(s.id!);
      if (mounted) {
        _loadSuppliers();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.supplierDeleted),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AppBar(
              backgroundColor: Colors.white.withOpacity(0.7),
              elevation: 0,
              centerTitle: false,
              title: Text(
                l10n.suppliers,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 26,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.tune, color: Colors.black87),
                  onPressed: () {},
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
      body: Container(
        color: const Color(0xFFF8FAFC),
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
                  onRefresh: _loadSuppliers,
                  color: const Color(0xFF6366F1),
                  child: _filteredSuppliers.isEmpty
                      ? const Center(child: Text('Žiadni dodávatelia neboli nájdení'))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                          physics: const BouncingScrollPhysics(),
                          itemCount: _filteredSuppliers.length,
                          itemBuilder: (context, index) {
                            final s = _filteredSuppliers[index];
                            return _SupplierCard(
                              supplier: s,
                              index: index,
                              controller: _listController,
                              onEdit: () => _editSupplier(s),
                              onDelete: () => _deleteSupplier(s),
                            );
                          },
                        ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSupplier,
        backgroundColor: Colors.black,
        elevation: 10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        label: Text(
          l10n.add,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        icon: const Icon(Icons.add, color: Colors.white),
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
              hintText: l10n.searchHintSuppliers,
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
      _filterSuppliers();
    });
  }
}

class _SupplierCard extends StatelessWidget {
  final Supplier supplier;
  final int index;
  final AnimationController controller;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SupplierCard({
    required this.supplier,
    required this.index,
    required this.controller,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final s = supplier;
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
                              s.ico,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF6366F1),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildStatusDot(s.isActive),
                          ],
                        ),
                        Text(
                          s.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (s.city != null && s.city!.isNotEmpty) ...[
                              const Icon(
                                Icons.location_on_rounded,
                                size: 14,
                                color: Color(0xFF94A3B8),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                s.city!,
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                            if (s.defaultVatRate > 0) ...[
                              if (s.city != null && s.city!.isNotEmpty)
                                const Text(' • ', style: TextStyle(color: Color(0xFF94A3B8))),
                              Text(
                                'DPH: ${s.defaultVatRate}%',
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 13,
                                ),
                              ),
                            ],
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
    final letter = supplier.name.isNotEmpty
        ? supplier.name[0].toUpperCase()
        : '?';
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          letter,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF6366F1),
          ),
        ),
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
