import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/warehouse.dart';
import '../../models/product.dart';
import '../../models/warehouse_transfer.dart';
import '../../services/warehouse/warehouse_service.dart';
import '../../services/Product/product_service.dart';
import '../../l10n/app_localizations.dart';
import 'add_warehouse_modal_widget.dart';
import 'warehouse_inventory_sheet_widget.dart';

class WarehouseListWidget extends StatefulWidget {
  const WarehouseListWidget({super.key});

  @override
  State<WarehouseListWidget> createState() => WarehouseListWidgetState();
}

class WarehouseListWidgetState extends State<WarehouseListWidget>
    with TickerProviderStateMixin {
  final WarehouseService _warehouseService = WarehouseService();
  final ProductService _productService = ProductService();
  final TextEditingController _searchController = TextEditingController();

  List<Warehouse> _warehouses = [];
  List<Warehouse> _filteredWarehouses = [];
  bool _loading = true;
  int _statusFilter = 0; // 0 = všetci, 1 = aktívni, 2 = neaktívni

  late final AnimationController _listController;

  @override
  void initState() {
    super.initState();
    _listController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();
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
    final list = await _warehouseService.getAllWarehousesWithStats();
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
                          return Dismissible(
                            key: ValueKey<String>('warehouse_${w.id ?? index}'),
                            direction: DismissDirection.horizontal,
                            background: _buildSwipeBackground(
                              context,
                              color: Colors.blue,
                              icon: Icons.edit_note,
                              alignment: Alignment.centerLeft,
                            ),
                            secondaryBackground: _buildSwipeBackground(
                              context,
                              color: Colors.orange,
                              icon: Icons.move_up,
                              alignment: Alignment.centerRight,
                              label: 'Presun',
                            ),
                            confirmDismiss: (direction) async {
                              if (direction == DismissDirection.startToEnd) {
                                _showInventorySheet(context, w);
                                return false;
                              }
                              if (direction == DismissDirection.endToStart) {
                                _showTransferDialog(context, w);
                                return false;
                              }
                              return true;
                            },
                            child: _WarehouseCard(
                              warehouse: w,
                              index: index,
                              controller: _listController,
                              onEdit: () => _editWarehouse(w),
                              onDelete: () => _deleteWarehouse(w),
                            ),
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

  Widget _buildSwipeBackground(
    BuildContext context, {
    required Color color,
    required IconData icon,
    required Alignment alignment,
    String? label,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
      ),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: alignment == Alignment.centerRight
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 32),
          if (label != null) ...[
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _onWarehouseDismissed(Warehouse w) {
    setState(() {
      _filteredWarehouses.removeWhere((x) => x.id == w.id);
      _warehouses.removeWhere((x) => x.id == w.id);
    });
  }

  Future<void> _showTransferDialog(BuildContext context, Warehouse sourceWarehouse) async {
    final targetWarehouses =
        _warehouses.where((w) => w.id != sourceWarehouse.id && w.isActive).toList();
    if (targetWarehouses.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nie je k dispozícii žiadny iný aktívny sklad na presun.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => _QuickTransferDialogContent(
        sourceWarehouse: sourceWarehouse,
        targetWarehouses: targetWarehouses,
        productService: _productService,
        warehouseService: _warehouseService,
        onSuccess: () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Presun bol úspešne zaznamenaný.'),
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    );
  }

  void _showInventorySheet(BuildContext context, Warehouse w) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => WarehouseInventorySheetWidget(
        warehouse: w,
        onSaved: () => refreshWarehouses(),
      ),
    );
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

class _QuickTransferDialogContent extends StatefulWidget {
  final Warehouse sourceWarehouse;
  final List<Warehouse> targetWarehouses;
  final ProductService productService;
  final WarehouseService warehouseService;
  final VoidCallback onSuccess;

  const _QuickTransferDialogContent({
    required this.sourceWarehouse,
    required this.targetWarehouses,
    required this.productService,
    required this.warehouseService,
    required this.onSuccess,
  });

  @override
  State<_QuickTransferDialogContent> createState() => _QuickTransferDialogContentState();
}

class _QuickTransferDialogContentState extends State<_QuickTransferDialogContent> {
  Warehouse? _targetWarehouse;
  Product? _product;
  final TextEditingController _amountController = TextEditingController(text: '1');
  bool _loading = true;
  bool _saving = false;
  List<Product> _products = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    final all = await widget.productService.getAllProducts();
    if (mounted) {
      setState(() {
        _products = widget.sourceWarehouse.id != null
            ? all.where((p) => p.warehouseId == widget.sourceWarehouse.id).toList()
            : all;
        _loading = false;
      });
    }
  }

  Future<void> _confirmTransfer() async {
    if (_targetWarehouse == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vyberte cieľový sklad')),
      );
      return;
    }
    if (_product == null && _products.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vyberte tovar na presun')),
      );
      return;
    }
    final amount = int.tryParse(_amountController.text.trim());
    if (amount == null || amount < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zadajte platné množstvo (celé číslo väčšie ako 0)')),
      );
      return;
    }
    if (_product != null && amount > _product!.qty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Na sklade je len ${_product!.qty} ${_product!.unit}. Zadajte nižšie množstvo.',
          ),
        ),
      );
      return;
    }
    if (_product == null && _products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('V zdrojovom sklade nie sú žiadne produkty na presun.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final product = _product!;
      final transfer = WarehouseTransfer(
        fromWarehouseId: widget.sourceWarehouse.id!,
        toWarehouseId: _targetWarehouse!.id!,
        productUniqueId: product.uniqueId!,
        productName: product.name,
        productPlu: product.plu,
        quantity: amount,
        unit: product.unit,
        createdAt: DateTime.now(),
      );
      await widget.warehouseService.createWarehouseTransfer(transfer);
      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba pri presune: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      icon: Icon(Icons.move_up, color: colorScheme.primary, size: 28),
      title: Text(
        'Presun zo skladu: ${widget.sourceWarehouse.name}',
        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 400,
            maxHeight: MediaQuery.of(context).size.height * 0.5,
          ),
          child: _loading
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      'Cieľový sklad',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<Warehouse>(
                      value: _targetWarehouse,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      ),
                      dropdownColor: colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                      hint: const Text('Vyberte sklad'),
                      items: widget.targetWarehouses
                          .map((w) => DropdownMenuItem(
                                value: w,
                                child: Text('${w.name} (${w.code})'),
                              ))
                          .toList(),
                      onChanged: (w) => setState(() => _targetWarehouse = w),
                    ),
                    const SizedBox(height: 16),
                    if (_products.isNotEmpty) ...[
                      Text(
                        'Tovar',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<Product>(
                        value: _product,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        ),
                        dropdownColor: colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                        hint: const Text('Vyberte tovar'),
                        items: _products
                            .map((p) => DropdownMenuItem(
                                  value: p,
                                  child: Text('${p.name} (${p.plu}) · ${p.qty} ${p.unit}'),
                                ))
                            .toList(),
                        onChanged: (p) => setState(() => _product = p),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      'Množstvo',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        hintText: '1',
                        suffixText: _product?.unit ?? 'ks',
                      ),
                    ),
                  ],
                ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Zrušiť'),
        ),
        FilledButton(
          onPressed: _saving ? null : _confirmTransfer,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Potvrdiť presun'),
        ),
      ],
      actionsAlignment: MainAxisAlignment.end,
    );
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
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildMetricItem(
                              Icons.inventory_2_outlined,
                              '${w.itemCount ?? 0} druhov',
                            ),
                            const SizedBox(width: 12),
                            _buildMetricItem(
                              Icons.history,
                              _formatLastUpdate(w.lastUpdate),
                            ),
                            const SizedBox(width: 12),
                            _buildMetricItem(
                              Icons.pie_chart_outline,
                              _formatFillPercent(w.currentStock, w.maxCapacity),
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

  Widget _buildMetricItem(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  /// Formátuje čas poslednej zmeny ako "pred X" alebo 'N/A' ak je null.
  static String _formatLastUpdate(DateTime? lastUpdate) {
    if (lastUpdate == null) return 'N/A';
    final now = DateTime.now();
    final diff = now.difference(lastUpdate);
    if (diff.inMinutes < 60) return 'pred ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'pred ${diff.inHours}h';
    if (diff.inDays < 7) return 'pred ${diff.inDays} dňami';
    return 'pred ${diff.inDays} dní';
  }

  /// Vypočíta percento zaplnenia (currentStock / maxCapacity * 100) alebo vráti 'N/A'.
  static String _formatFillPercent(num? currentStock, num? maxCapacity) {
    if (currentStock == null || maxCapacity == null || maxCapacity <= 0) {
      return 'N/A';
    }
    final percent = (currentStock / maxCapacity * 100).toStringAsFixed(0);
    return '$percent%';
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
