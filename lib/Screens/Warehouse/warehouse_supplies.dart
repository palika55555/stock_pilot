import 'dart:async';
import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/Products/add_product_modal_widget.dart';
import '../../widgets/Warehouse/warehouse_supplies_column_selector.dart';
import '../../widgets/Warehouse/warehouse_supplies_constants.dart';
import '../../widgets/Warehouse/warehouse_supplies_header_widget.dart';
import '../../widgets/Warehouse/warehouse_low_stock_modal_widget.dart';
import '../../widgets/Warehouse/warehouse_supplies_card_view_widget.dart';
import '../../widgets/Warehouse/warehouse_quick_stats_widget.dart';
import '../../widgets/Warehouse/warehouse_supplies_table_data.dart';
import '../../widgets/Purchase/purchase_price_history_sheet_widget.dart';
import '../../services/Product/product_service.dart';
import '../../services/Warehouse/warehouse_service.dart';
import '../../services/product_cache.dart';
import '../../services/user_session.dart';
import '../../l10n/app_localizations.dart';
import '../../models/product.dart';
import '../../models/warehouse.dart';
import '../../theme/app_theme.dart';

class WarehouseSuppliesScreen extends StatefulWidget {
  final String userRole; // 'admin' alebo 'user'
  const WarehouseSuppliesScreen({super.key, required this.userRole});

  @override
  State<WarehouseSuppliesScreen> createState() =>
      _WarehouseSuppliesScreenState();
}

class _WarehouseSuppliesScreenState extends State<WarehouseSuppliesScreen> {
  /// Samostatné kontroléry – zdieľanie jedného medzi tabuľkou a GridView spôsobovalo chyby semantiky (parentDataDirty).
  final ScrollController _tableVerticalController = ScrollController();
  final ScrollController _cardGridScrollController = ScrollController();
  final ScrollController _horizontalController = ScrollController();
  final ProductService _productService = ProductService();
  final WarehouseService _warehouseService = WarehouseService();
  final TextEditingController _searchController = TextEditingController();

  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];

  /// 1-based index aktuálnej stránky (zachované kvôli kompatibilite).
  int _currentPage = 1;
  List<Warehouse> _warehouses = [];
  Warehouse? _selectedWarehouse;
  bool _isLoading = true;
  bool _isAscending = false;
  bool _isCardView = false;
  String?
  _statusFilter; // null = všetky, 'neaktivne', 'nedostupne', 'cenotvorba', 'nizky_stav'
  int _sortColumnIndex = -1; // -1 = žiadny vizuálny indikátor DataTable (používame vlastný header)
  /// Kľúč zoradenia zhodný s SQL v [DatabaseService.getWarehouseSuppliesPage].
  String _sortKey = 'price';
  double _statsTotalQty = 0;
  double _statsTotalValue = 0;
  int _statsLowStock = 0;
  Timer? _searchDebounce;

  /// Vybrané produkty pre bulk akcie (admin).
  final Set<String> _selectedIds = {};

  /// Viditeľnosť stĺpcov tabuľky (id -> true = zobrazený). Predvolene všetky true.
  Map<String, bool> _columnVisibility = {
    for (final c in warehouseSupplyTableColumns) c.id: true,
  };

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchTextChanged);
    _loadAll();
    _loadWarehouses();
    _loadColumnVisibility();
  }

  void _onSearchTextChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 50), () {
      if (mounted) _applyFilterAndSort();
    });
  }

  /// Načíta VŠETKY produkty raz z ProductCache (SQLite query iba raz).
  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final all = await ProductCache.instance.load();
      if (!mounted) return;
      _allProducts = List<Product>.from(all);
      _applyFilterAndSort();
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Filtruje a triedí _allProducts v pamäti – žiadna DB query.
  void _applyFilterAndSort() {
    final q = _searchController.text.trim().toLowerCase();
    final wid = _selectedWarehouse?.id;
    final sf = _statusFilter;

    var list = _allProducts.where((p) {
      if (wid != null && p.warehouseId != wid) return false;
      if (q.isNotEmpty &&
          !p.name.toLowerCase().contains(q) &&
          !p.plu.toLowerCase().contains(q) &&
          !p.category.toLowerCase().contains(q)) return false;
      switch (sf) {
        case 'neaktivne':
          if (p.isActive) return false;
        case 'nedostupne':
          if (!p.temporarilyUnavailable) return false;
        case 'cenotvorba':
          if (!p.hasExtendedPricing) return false;
        case 'nizky_stav':
          if (!(p.minQuantity > 0 && p.qty < p.minQuantity)) return false;
      }
      return true;
    }).toList();

    // Triedenie v pamäti
    final asc = _isAscending ? 1 : -1;
    list.sort((a, b) {
      switch (_sortKey) {
        case 'plu':
          return asc * a.plu.compareTo(b.plu);
        case 'name':
          return asc * a.name.compareTo(b.name);
        case 'price':
          return asc * a.price.compareTo(b.price);
        case 'qty':
          return asc * a.qty.compareTo(b.qty);
        case 'margin':
          return asc * (a.marginPercent ?? 0.0).compareTo(b.marginPercent ?? 0.0);
        case 'last_purchase_price_without_vat':
          return asc *
              a.lastPurchasePriceWithoutVat
                  .compareTo(b.lastPurchasePriceWithoutVat);
        case 'supplier_name':
          return asc * (a.supplierName ?? '').compareTo(b.supplierName ?? '');
        case 'warehouse_id':
          return asc * (a.warehouseId ?? 0).compareTo(b.warehouseId ?? 0);
        default:
          return asc * a.name.compareTo(b.name);
      }
    });

    // Štatistiky v pamäti
    double tq = 0, tv = 0;
    int ls = 0;
    for (final p in list) {
      tq += p.qty;
      tv += p.price * p.qty;
      if (p.minQuantity > 0 && p.qty < p.minQuantity) ls++;
    }

    if (mounted) {
      setState(() {
        _filteredProducts = list;
        _statsTotalQty = tq;
        _statsTotalValue = tv;
        _statsLowStock = ls;
        _isLoading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_tableVerticalController.hasClients) _tableVerticalController.jumpTo(0);
        if (_cardGridScrollController.hasClients) _cardGridScrollController.jumpTo(0);
      });
    }
  }

  /// Invaliduje cache a obnoví zoznam (po create/edit/delete).
  Future<void> _loadProducts() async {
    ProductCache.instance.invalidate();
    await _loadAll();
  }

  Future<void> _loadColumnVisibility() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(kWarehouseSuppliesColumnPrefsKey);
    if (saved == null)
      return; // prvý štart – nechaj predvolene všetky zobrazené
    final ids = warehouseSupplyTableColumns.map((c) => c.id).toSet();
    final map = <String, bool>{};
    for (final id in ids) {
      map[id] = saved.contains(id);
    }
    if (mounted) setState(() => _columnVisibility = map);
  }

  Future<void> _saveColumnVisibility() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _columnVisibility.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
    await prefs.setStringList(kWarehouseSuppliesColumnPrefsKey, list);
  }

  Future<void> _confirmDeleteProduct(Product product) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.delete),
        content: Text(
          'Naozaj chcete vymazať produkt "${product.name}" (${product.plu})?',
        ),
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
    if (confirm == true && mounted && product.uniqueId != null) {
      await _productService.deleteProduct(product.uniqueId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Produkt "${product.name}" bol vymazaný'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadProducts();
      }
    }
  }

  void _showColumnSelector() {
    showWarehouseSuppliesColumnSelector(
      context,
      initialVisibility: Map<String, bool>.from(_columnVisibility),
      onApply: (m) => setState(() => _columnVisibility = m),
      onSave: _saveColumnVisibility,
    );
  }

  Future<void> _loadWarehouses() async {
    final list = await _warehouseService.getActiveWarehouses();
    if (mounted) setState(() => _warehouses = list);
  }

  void _showWarehouseFilter() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Filtrovať podľa skladu',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: Icon(
                _selectedWarehouse == null
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: _selectedWarehouse == null ? AppColors.accentGold : null,
              ),
              title: const Text('Všetky sklady'),
              onTap: () {
                setState(() => _selectedWarehouse = null);
                _applyFilterAndSort();
                Navigator.pop(context);
              },
            ),
            ..._warehouses.map((w) {
              final isSelected = _selectedWarehouse?.id == w.id;
              return ListTile(
                leading: Icon(
                  isSelected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: isSelected ? AppColors.accentGold : null,
                ),
                title: Text(w.name),
                subtitle: Text(
                  [
                    w.code,
                    w.warehouseType,
                  ].where((s) => s.isNotEmpty).join(' • '),
                ),
                onTap: () {
                  setState(() => _selectedWarehouse = w);
                  _applyFilterAndSort();
                  Navigator.pop(context);
                },
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    _tableVerticalController.dispose();
    _cardGridScrollController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  Widget _buildStatusChip({
    required String label,
    required String? value,
    required IconData icon,
    Color? color,
  }) {
    final isSelected = _statusFilter == value;
    final chipColor = color ?? AppColors.accentGold;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      avatar: Icon(
        icon,
        size: 15,
        color: isSelected ? chipColor : AppColors.textSecondary,
      ),
      labelStyle: TextStyle(
        fontSize: 12,
        color: isSelected ? chipColor : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
      ),
      backgroundColor: AppColors.bgInput,
      selectedColor: chipColor.withValues(alpha: 0.12),
      checkmarkColor: chipColor,
      side: BorderSide(
        color: isSelected
            ? chipColor.withValues(alpha: 0.5)
            : AppColors.borderDefault,
        width: 1,
      ),
      showCheckmark: false,
      onSelected: (_) {
        setState(() => _statusFilter = isSelected ? null : value);
        _applyFilterAndSort();
      },
    );
  }

  void _sort({
    required String sortKey,
    required int columnIndex,
    required bool ascending,
  }) {
    setState(() {
      _sortKey = sortKey;
      _sortColumnIndex = columnIndex;
      _isAscending = ascending;
    });
    _applyFilterAndSort();
  }

  void _openAddProductModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AddProductModal(),
    ).then((result) {
      if (result != null) _loadProducts();
    });
  }

  void _openAddRecipeModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AddProductModal(initialCardType: 'receptúra'),
    ).then((result) {
      if (result != null) _loadProducts();
    });
  }

  void _openEditProductModal(Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AddProductModal(productToEdit: product),
    ).then((result) {
      if (result != null) _loadProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isAdmin = widget.userRole == 'admin';

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Stack(
        children: [
          // Horný tmavý pás
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: AppColors.bgElevated,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
              border: Border(
                bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                WarehouseSuppliesHeader(
                  isAdmin: isAdmin,
                  onFilterTap: _showWarehouseFilter,
                  onColumnsTap: _showColumnSelector,
                  onAddRecipeTap: _openAddRecipeModal,
                  selectedWarehouseName: _selectedWarehouse?.name,
                ),
                WarehouseQuickStats(
                  totalQty: _statsTotalQty.round(),
                  totalValue: _statsTotalValue,
                  lowStockCount: _statsLowStock,
                  onLowStockTap: _showLowStockModal,
                  isLoading: _isLoading,
                ),
                Expanded(child: _buildContentCard(isAdmin)),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: _openAddProductModal,
              backgroundColor: AppColors.accentGold,
              child: Icon(Icons.add, color: AppColors.bgPrimary),
            )
          : null,
    );
  }

  Future<void> _showLowStockModal() async {
    final lowStockProducts = _filteredProducts
        .where((p) => p.minQuantity > 0 && p.qty < p.minQuantity)
        .toList();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) =>
          WarehouseLowStockModal(lowStockProducts: lowStockProducts),
    );
  }

  Widget _buildContentCard(bool isAdmin) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 5, 20, 0),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
        border: Border(
          left: BorderSide(color: AppColors.borderSubtle, width: 1),
          right: BorderSide(color: AppColors.borderSubtle, width: 1),
          top: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
        child: Column(
          children: [
            // Vyhľadávanie + prepínač zobrazenia
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Hľadať produkt...',
                        hintStyle: TextStyle(color: AppColors.textMuted),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: AppColors.accentGold,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: AppColors.textSecondary,
                                ),
                                onPressed: () => _searchController.clear(),
                              )
                            : null,
                        filled: true,
                        fillColor: AppColors.bgInput,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(
                            color: AppColors.borderDefault,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Tooltip(
                    message: 'Tabuľkové zobrazenie',
                    child: IconButton(
                      onPressed: () => setState(() => _isCardView = false),
                      icon: Icon(
                        Icons.table_chart_rounded,
                        color: _isCardView
                            ? AppColors.textMuted
                            : AppColors.accentGold,
                        size: 26,
                      ),
                    ),
                  ),
                  Tooltip(
                    message: 'Kartové zobrazenie',
                    child: IconButton(
                      onPressed: () => setState(() => _isCardView = true),
                      icon: Icon(
                        Icons.view_module_rounded,
                        color: _isCardView
                            ? AppColors.accentGold
                            : AppColors.textMuted,
                        size: 26,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Statusové filtre
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  _buildStatusChip(
                    label: 'Všetky',
                    value: null,
                    icon: Icons.list_rounded,
                  ),
                  const SizedBox(width: 8),
                  _buildStatusChip(
                    label: 'Neaktívne',
                    value: 'neaktivne',
                    icon: Icons.block_rounded,
                    color: AppColors.danger,
                  ),
                  const SizedBox(width: 8),
                  _buildStatusChip(
                    label: 'Nedostupné',
                    value: 'nedostupne',
                    icon: Icons.pause_circle_outline_rounded,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  _buildStatusChip(
                    label: 'Rozš. cenotvorba',
                    value: 'cenotvorba',
                    icon: Icons.auto_awesome_rounded,
                    color: AppColors.accentPurple,
                  ),
                  const SizedBox(width: 8),
                  _buildStatusChip(
                    label: 'Nízky stav',
                    value: 'nizky_stav',
                    icon: Icons.warning_amber_rounded,
                    color: AppColors.danger,
                  ),
                ],
              ),
            ),
            // Obsah: tabuľka alebo karty
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: AppColors.accentGold,
                      ),
                    )
                  : _isCardView
                      ? WarehouseSuppliesCardView(
                          scrollController: _cardGridScrollController,
                          products: _filteredProducts,
                          onEditProduct: _openEditProductModal,
                          onDeleteProduct: isAdmin
                              ? _confirmDeleteProduct
                              : null,
                        )
                      : _buildVirtualTable(isAdmin),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Virtualizovaná tabuľka
  // ──────────────────────────────────────────────────────────────────────────

  /// Virtualizovaná tabuľka – ListView.builder + itemExtent + sticky header.
  /// Renderuje len viditeľné riadky (≈15-20 namiesto všetkých).
  Widget _buildVirtualTable(bool isAdmin) {
    const double headerH = 48.0;
    const double rowH = 52.0;

    // Vypočítaj šírku tabuľky podľa viditeľných stĺpcov
    double tableW = (isAdmin ? 48.0 : 0.0) +
        (kWarehouseColumnWidths['#'] ?? 44) +
        (kWarehouseColumnWidths['plu'] ?? 90) +
        (kWarehouseColumnWidths['name'] ?? 190) +
        warehouseSupplyTableColumns
            .where((c) => _columnVisibility[c.id] == true)
            .fold(0.0, (s, c) => s + (kWarehouseColumnWidths[c.id] ?? 100)) +
        (kWarehouseColumnWidths['actions'] ?? 116);

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final w = max(tableW, constraints.maxWidth);
        return Column(
          children: [
            // ── Tabuľka ──────────────────────────────────────────
            Expanded(
              child: Scrollbar(
                controller: _horizontalController,
                thumbVisibility: true,
                scrollbarOrientation: ScrollbarOrientation.bottom,
                child: SingleChildScrollView(
                  controller: _horizontalController,
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  child: SizedBox(
                    width: w,
                    height: constraints.maxHeight - 36, // miesto pre count bar
                    child: Column(
                      children: [
                        // Sticky header
                        SizedBox(
                          height: headerH,
                          child: _buildTableHeader(isAdmin, w),
                        ),
                        // Virtuálne riadky
                        Expanded(
                          child: Scrollbar(
                            controller: _tableVerticalController,
                            thumbVisibility: true,
                            child: ListView.builder(
                              controller: _tableVerticalController,
                              physics: const ClampingScrollPhysics(),
                              itemExtent: rowH,
                              itemCount: _filteredProducts.isEmpty
                                  ? 1
                                  : _filteredProducts.length,
                              itemBuilder: (context, index) {
                                if (_filteredProducts.isEmpty) {
                                  return SizedBox(
                                    width: w,
                                    child: Center(
                                      child: Text(
                                        'Žiadne produkty. Skúste iný filter.',
                                        style: TextStyle(color: AppColors.textSecondary),
                                      ),
                                    ),
                                  );
                                }
                                return _buildTableDataRow(context, index, isAdmin);
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
            // ── Počet záznamov (namiesto stránkovania) ──────────
            Material(
              color: AppColors.bgElevated,
              child: SizedBox(
                height: 36,
                child: Center(
                  child: Text(
                    _isLoading
                        ? 'Načítavam…'
                        : '${_filteredProducts.length} produktov'
                            '${_allProducts.length != _filteredProducts.length ? ' z ${_allProducts.length} celkom' : ''}',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Sticky header s klikateľnými stĺpcami pre triedenie.
  Widget _buildTableHeader(bool isAdmin, double tableWidth) {
    final cols = <Widget>[];
    if (isAdmin) {
      cols.add(_hCell(w: 48, label: '', sortKey: null));
    }
    cols.add(_hCell(w: kWarehouseColumnWidths['#']!, label: '#', sortKey: null));
    cols.add(_hCell(w: kWarehouseColumnWidths['plu']!, label: 'PLU', sortKey: 'plu'));
    cols.add(_hCell(w: kWarehouseColumnWidths['name']!, label: 'Názov tovaru', sortKey: 'name'));
    for (final c in warehouseSupplyTableColumns) {
      if (_columnVisibility[c.id] != true) continue;
      final sk = _columnSortKey(c.id);
      cols.add(_hCell(
        w: kWarehouseColumnWidths[c.id] ?? 100,
        label: c.label,
        sortKey: sk,
        numeric: WarehouseSuppliesTableData.isNumericColumn(c.id),
      ));
    }
    cols.add(_hCell(w: kWarehouseColumnWidths['actions']!, label: 'Akcie', sortKey: null));

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        border: Border(bottom: BorderSide(color: AppColors.borderSubtle, width: 1)),
      ),
      child: Row(children: cols),
    );
  }

  String? _columnSortKey(String id) {
    switch (id) {
      case 'predaj_s_dph': return 'price';
      case 'marza': return 'margin';
      case 'mnozstvo': return 'qty';
      case 'posl_nakup_bez_dph': return 'last_purchase_price_without_vat';
      case 'dodavatel': return 'supplier_name';
      case 'sklad': return 'warehouse_id';
      default: return null;
    }
  }

  Widget _hCell({required double w, required String label, required String? sortKey, bool numeric = false}) {
    final isSorted = sortKey != null && _sortKey == sortKey;
    return GestureDetector(
      onTap: sortKey == null ? null : () {
        final newAsc = isSorted ? !_isAscending : true;
        _sort(sortKey: sortKey, columnIndex: -1, ascending: newAsc);
      },
      child: SizedBox(
        width: w,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: numeric ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: isSorted ? AppColors.accentGold : AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isSorted)
                Icon(
                  _isAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  size: 13,
                  color: AppColors.accentGold,
                )
              else if (sortKey != null)
                Icon(Icons.unfold_more_rounded, size: 13, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  /// Jeden dátový riadok tabuľky.
  Widget _buildTableDataRow(BuildContext context, int index, bool isAdmin) {
    final product = _filteredProducts[index];
    final lowStock = product.minQuantity > 0 && product.qty < product.minQuantity;
    final isSelected = _selectedIds.contains(product.uniqueId);
    final rowStyle = WarehouseSuppliesTableData.rowStyleForProduct(product);
    final base = (rowStyle ?? WarehouseSuppliesTableData.defaultRowStyle).copyWith(fontSize: 13);
    final bg = isSelected
        ? AppColors.accentGold.withValues(alpha: 0.1)
        : (index % 2 == 0 ? AppColors.bgCard : AppColors.bgElevated);

    return RepaintBoundary(
      child: Material(
        color: bg,
        child: InkWell(
          onTap: isAdmin && product.uniqueId != null
              ? () => setState(() {
                    if (_selectedIds.contains(product.uniqueId)) {
                      _selectedIds.remove(product.uniqueId);
                    } else {
                      _selectedIds.add(product.uniqueId!);
                    }
                  })
              : null,
          child: Row(
            children: [
              if (isAdmin)
                SizedBox(
                  width: 48,
                  child: Checkbox(
                    value: isSelected,
                    onChanged: product.uniqueId == null
                        ? null
                        : (v) => setState(() {
                              if (v == true) {
                                _selectedIds.add(product.uniqueId!);
                              } else {
                                _selectedIds.remove(product.uniqueId);
                              }
                            }),
                    activeColor: AppColors.accentGold,
                  ),
                ),
              _dCell(w: kWarehouseColumnWidths['#']!, child: Text('${index + 1}.', style: base)),
              _dCell(w: kWarehouseColumnWidths['plu']!, child: Text(product.plu, style: base.copyWith(fontWeight: FontWeight.bold))),
              _dCell(w: kWarehouseColumnWidths['name']!, child: Text(product.name, style: base, overflow: TextOverflow.ellipsis)),
              for (final c in warehouseSupplyTableColumns)
                if (_columnVisibility[c.id] == true)
                  _dCell(
                    w: kWarehouseColumnWidths[c.id] ?? 100,
                    child: WarehouseSuppliesTableData.buildCellWidget(c.id, product, lowStock, rowStyle, _warehouses),
                  ),
              _dCell(
                w: kWarehouseColumnWidths['actions']!,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit_outlined, size: 20, color: AppColors.textSecondary),
                      tooltip: 'Upraviť',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () => _openEditProductModal(product),
                    ),
                    IconButton(
                      icon: Icon(Icons.history_edu_outlined, size: 20, color: AppColors.textSecondary),
                      tooltip: 'História nákupných cien',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () => showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        isScrollControlled: true,
                        builder: (_) => PurchasePriceHistorySheet(product: product),
                      ),
                    ),
                    if (isAdmin)
                      IconButton(
                        icon: Icon(Icons.delete_outline, size: 20, color: AppColors.danger),
                        tooltip: 'Vymazať',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        onPressed: () => _confirmDeleteProduct(product),
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

  static Widget _dCell({required double w, required Widget child}) => SizedBox(
        width: w,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Align(alignment: Alignment.centerLeft, child: child),
        ),
      );
}
