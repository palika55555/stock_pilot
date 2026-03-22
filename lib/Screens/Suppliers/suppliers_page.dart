import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stock_pilot/models/supplier.dart';
import 'package:stock_pilot/services/Supplier/supplier_service.dart';
import 'package:stock_pilot/theme/app_theme.dart';
import 'package:stock_pilot/widgets/suppliers/add_supplier_modal_widget.dart';
import 'package:stock_pilot/l10n/app_localizations.dart';

enum _SupplierSort {
  nameAsc,
  nameDesc,
  icoAsc,
  cityAsc,
  activeFirst,
  inactiveFirst,
}

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
  _SupplierSort _sortOrder = _SupplierSort.nameAsc;

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
    list = _applySort(list);
    _filteredSuppliers = list;
  }

  List<Supplier> _applySort(List<Supplier> list) {
    final sorted = List<Supplier>.from(list);
    switch (_sortOrder) {
      case _SupplierSort.nameAsc:
        sorted.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case _SupplierSort.nameDesc:
        sorted.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case _SupplierSort.icoAsc:
        sorted.sort((a, b) => a.ico.compareTo(b.ico));
        break;
      case _SupplierSort.cityAsc:
        sorted.sort((a, b) => (a.city ?? '').toLowerCase().compareTo((b.city ?? '').toLowerCase()));
        break;
      case _SupplierSort.activeFirst:
        sorted.sort((a, b) => (b.isActive ? 1 : 0).compareTo(a.isActive ? 1 : 0));
        break;
      case _SupplierSort.inactiveFirst:
        sorted.sort((a, b) => (a.isActive ? 1 : 0).compareTo(b.isActive ? 1 : 0));
        break;
    }
    return sorted;
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
            child: Text(l10n.delete, style: const TextStyle(color: AppColors.danger)),
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
            backgroundColor: AppColors.bgElevated,
            behavior: SnackBarBehavior.floating,
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
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.suppliers,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 26,
                    ),
                  ),
                  if (!_loading && _filteredSuppliers.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '${_filteredSuppliers.length} ${_filteredSuppliers.length == 1 ? 'dodávateľ' : _filteredSuppliers.length < 5 ? 'dodávatelia' : 'dodávateľov'}',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
              actions: [
                Tooltip(
                  message: 'Filtre a nastavenia',
                  child: IconButton(
                    icon: Icon(Icons.tune_rounded, color: AppColors.textPrimary),
                    onPressed: _showFilterAndSortOptions,
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          _buildHeader(l10n),
          if (_loading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.accentGold),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadSuppliers,
                color: AppColors.accentGold,
                child: _filteredSuppliers.isEmpty
                    ? _buildEmptyState(l10n)
                    : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                          physics: const ClampingScrollPhysics(),
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
      floatingActionButton: Tooltip(
        message: l10n.addSupplier,
        child: FloatingActionButton.extended(
          onPressed: _addSupplier,
          backgroundColor: AppColors.accentGold,
          elevation: 10,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          label: Text(
            l10n.add,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.bgPrimary,
            ),
          ),
          icon: const Icon(Icons.add, color: AppColors.bgPrimary),
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, kToolbarHeight + 10, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
        border: const Border(
          bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: l10n.searchHintSuppliers,
              hintStyle: const TextStyle(color: AppColors.textMuted),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.accentGold,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              filled: true,
              fillColor: AppColors.bgInput,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.borderDefault),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.borderDefault),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Tooltip(
                message: 'Zobraziť všetkých dodávateľov',
                child: _FilterChip(
                  label: l10n.all,
                  selected: _statusFilter == 0,
                  onTap: () => _setStatus(0),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Len aktívnych dodávateľov',
                child: _FilterChip(
                  label: l10n.allActive,
                  selected: _statusFilter == 1,
                  onTap: () => _setStatus(1),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Len neaktívnych dodávateľov',
                child: _FilterChip(
                  label: l10n.allInactive,
                  selected: _statusFilter == 2,
                  onTap: () => _setStatus(2),
                ),
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

  void _setSortOrder(_SupplierSort order) {
    setState(() {
      _sortOrder = order;
      _filterSuppliers();
    });
  }

  void _showFilterAndSortOptions() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              const SizedBox(height: 20),
              Text(
                'Filtre a zoradenie',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Zobraziť',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _SheetChip(
                      label: l10n.all,
                      selected: _statusFilter == 0,
                      onTap: () {
                        Navigator.pop(ctx);
                        _setStatus(0);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SheetChip(
                      label: l10n.allActive,
                      selected: _statusFilter == 1,
                      onTap: () {
                        Navigator.pop(ctx);
                        _setStatus(1);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SheetChip(
                      label: l10n.allInactive,
                      selected: _statusFilter == 2,
                      onTap: () {
                        Navigator.pop(ctx);
                        _setStatus(2);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Zoradiť podľa',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ..._SupplierSort.values.map((order) => _SortTile(
                    sort: order,
                    selected: _sortOrder == order,
                    onTap: () {
                      Navigator.pop(ctx);
                      _setSortOrder(order);
                    },
                  )),
              if (_searchController.text.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Divider(color: AppColors.borderSubtle),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _searchController.clear();
                    setState(() => _filterSuppliers());
                  },
                  icon: const Icon(Icons.clear_rounded, color: AppColors.textSecondary, size: 20),
                  label: const Text(
                    'Vymazať vyhľadávanie',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    final isSearchOrFilter = _searchController.text.isNotEmpty || _statusFilter != 0;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderSubtle, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentGold.withOpacity(0.15),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                isSearchOrFilter ? Icons.search_off_rounded : Icons.local_shipping_rounded,
                size: 56,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isSearchOrFilter ? 'Žiadne výsledky' : l10n.noSuppliers,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isSearchOrFilter
                  ? 'Skúste zmeniť hľadaný výraz alebo filter'
                  : 'Pridajte prvého dodávateľa a začnite evidovať',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            if (!isSearchOrFilter) ...[
              const SizedBox(height: 24),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _addSupplier,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.accentGold.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.accentGold, width: 1.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_rounded, color: AppColors.accentGold, size: 22),
                        const SizedBox(width: 10),
                        Text(
                          l10n.addSupplier,
                          style: const TextStyle(
                            color: AppColors.accentGold,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
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
    final l10n = AppLocalizations.of(context)!;
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
        child: Tooltip(
          message: 'Skopírovať IČO',
          preferBelow: false,
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: AppColors.cardDecoration,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: s.ico));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('IČO ${s.ico} skopírované'),
                      backgroundColor: AppColors.bgElevated,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                splashColor: AppColors.accentGold.withOpacity(0.15),
                highlightColor: AppColors.accentGold.withOpacity(0.08),
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
                                Tooltip(
                                  message: 'IČO – identifikačné číslo organizácie',
                                  child: Text(
                                    s.ico,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.accentGold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Tooltip(
                                  message: s.isActive ? l10n.active : l10n.inactive,
                                  child: _buildStatusDot(s.isActive),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              s.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 4,
                              runSpacing: 2,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (s.city != null && s.city!.isNotEmpty) ...[
                                  Icon(
                                    Icons.location_on_rounded,
                                    size: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                  Text(
                                    s.city!,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                                if (s.email != null && s.email!.isNotEmpty) ...[
                                  if (s.city != null && s.city!.isNotEmpty)
                                    Text(' • ', style: TextStyle(color: AppColors.textSecondary)),
                                  Icon(
                                    Icons.email_outlined,
                                    size: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 2),
                                  Tooltip(
                                    message: s.email!,
                                    child: Text(
                                      s.email!,
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 13,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                                if (s.defaultVatRate > 0) ...[
                                  if ((s.city != null && s.city!.isNotEmpty) ||
                                      (s.email != null && s.email!.isNotEmpty))
                                    Text(' • ', style: TextStyle(color: AppColors.textSecondary)),
                                  Text(
                                    'DPH: ${s.defaultVatRate}%',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      Tooltip(
                        message: 'Možnosti',
                        child: GestureDetector(
                          onTap: () {},
                          child: _buildActionMenu(context),
                        ),
                      ),
                    ],
                  ),
                ),
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
        color: AppColors.accentGoldSubtle,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.accentGold,
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
        color: active ? AppColors.success : AppColors.danger,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: (active ? AppColors.success : AppColors.danger).withOpacity(0.4),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildActionMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: Colors.transparent,
      child: PopupMenuButton<String>(
        icon: Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: AppColors.bgCard,
        onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'edit',
            child: _MenuEntry(Icons.edit_rounded, l10n.edit),
          ),
          PopupMenuItem(
            value: 'delete',
            child: _MenuEntry(
              Icons.delete_outline_rounded,
              l10n.delete,
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
          color: isDestructive ? AppColors.danger : AppColors.accentGold,
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            color: isDestructive ? AppColors.danger : AppColors.textPrimary,
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
          color: selected ? AppColors.accentGold : AppColors.bgInput,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.accentGold : AppColors.borderDefault,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: selected ? AppColors.bgPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _SheetChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SheetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.accentGold : AppColors.bgInput,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.accentGold : AppColors.borderDefault,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.bgPrimary : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SortTile extends StatelessWidget {
  final _SupplierSort sort;
  final bool selected;
  final VoidCallback onTap;

  const _SortTile({
    required this.sort,
    required this.selected,
    required this.onTap,
  });

  static String _label(_SupplierSort s) {
    switch (s) {
      case _SupplierSort.nameAsc:
        return 'Názov (A → Z)';
      case _SupplierSort.nameDesc:
        return 'Názov (Z → A)';
      case _SupplierSort.icoAsc:
        return 'IČO';
      case _SupplierSort.cityAsc:
        return 'Mesto';
      case _SupplierSort.activeFirst:
        return 'Aktívni prví';
      case _SupplierSort.inactiveFirst:
        return 'Neaktívni prví';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Row(
            children: [
              Icon(
                selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                size: 22,
                color: selected ? AppColors.accentGold : AppColors.textMuted,
              ),
              const SizedBox(width: 12),
              Text(
                _label(sort),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
