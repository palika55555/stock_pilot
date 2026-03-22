import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/Products/add_product_modal_widget.dart';
import '../../widgets/Warehouse/warehouse_supplies_column_selector.dart';
import '../../widgets/Warehouse/warehouse_supplies_constants.dart';
import '../../widgets/Warehouse/warehouse_supplies_desktop_scroll_behavior.dart';
import '../../widgets/Warehouse/warehouse_supplies_header_widget.dart';
import '../../widgets/Warehouse/warehouse_low_stock_modal_widget.dart';
import '../../widgets/Warehouse/warehouse_supplies_pagination_bar.dart';
import '../../widgets/Warehouse/warehouse_supplies_card_view_widget.dart';
import '../../widgets/Warehouse/warehouse_quick_stats_widget.dart';
import '../../widgets/Warehouse/warehouse_supplies_table_data.dart';
import '../../services/Product/product_service.dart';
import '../../services/Warehouse/warehouse_service.dart';
import '../../services/Database/database_service.dart';
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

  /// Stránkovanie: max. [kWarehouseSuppliesPageSize] záznamov na stránku (1, 2, 3…).
  List<Product> _loadedProducts = [];
  int _totalFilteredCount = 0;

  /// 1-based index aktuálnej stránky.
  int _currentPage = 1;
  List<Warehouse> _warehouses = [];
  Warehouse? _selectedWarehouse;
  bool _isLoading = true;
  /// Súhrnné štatistiky a celkový počet ešte nie sú z DB (bežia po načítaní stránky).
  bool _countAndStatsPending = true;
  int _loadGeneration = 0;
  bool _isAscending = false;
  bool _isCardView = false;
  String?
  _statusFilter; // null = všetky, 'neaktivne', 'nedostupne', 'cenotvorba', 'nizky_stav'
  int _sortColumnIndex =
      4; // stĺpec pre indikátor zoradenia (predvolene Predaj s DPH)
  /// Kľúč zoradenia zhodný s SQL v [DatabaseService.getWarehouseSuppliesPage].
  String _sortKey = 'price';
  double _statsTotalQty = 0;
  double _statsTotalValue = 0;
  int _statsLowStock = 0;
  Timer? _searchDebounce;

  int get _totalPages {
    if (_countAndStatsPending) return 1;
    if (_totalFilteredCount <= 0) return 1;
    return (_totalFilteredCount + kWarehouseSuppliesPageSize - 1) ~/
        kWarehouseSuppliesPageSize;
  }

  /// Viditeľnosť stĺpcov tabuľky (id -> true = zobrazený). Predvolene všetky true.
  Map<String, bool> _columnVisibility = {
    for (final c in warehouseSupplyTableColumns) c.id: true,
  };

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchTextChanged);
    // SQL queries bežia na separátnom vlákne – spúšťame okamžite (nečakáme na frame).
    _loadProducts();
    _loadWarehouses();
    _loadColumnVisibility();
  }

  void _onSearchTextChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _reloadFilteredList();
    });
  }

  Future<void> _reloadFilteredList() async {
    final gen = ++_loadGeneration;
    setState(() {
      _isLoading = true;
      _loadedProducts = [];
      _currentPage = 1;
      _countAndStatsPending = true;
      _totalFilteredCount = 0;
    });
    if (!mounted || gen != _loadGeneration) return;
    final wid = _selectedWarehouse?.id;
    final q = _searchController.text;
    final sf = _statusFilter;
    try {
      // 1) Najprv stránka – tabuľka/karty sa zobrazia hneď (SUM/COUNT sú často pomalšie).
      final page = await _productService.getWarehouseSuppliesPage(
        warehouseId: wid,
        searchQuery: q,
        statusFilter: sf,
        sortKey: _sortKey,
        ascending: _isAscending,
        limit: kWarehouseSuppliesPageSize,
        offset: 0,
      );
      if (!mounted || gen != _loadGeneration) return;
      setState(() {
        _loadedProducts = page;
        _currentPage = 1;
        _isLoading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_tableVerticalController.hasClients) _tableVerticalController.jumpTo(0);
        if (_cardGridScrollController.hasClients) _cardGridScrollController.jumpTo(0);
      });

      // 2) Súhrn + počet na pozadí (rovnaké filtre ako vyššie).
      final aggAndCount = await Future.wait([
        _productService.aggregateWarehouseSuppliesFiltered(
          warehouseId: wid,
          searchQuery: q,
          statusFilter: sf,
        ),
        _productService.countWarehouseSuppliesFiltered(
          warehouseId: wid,
          searchQuery: q,
          statusFilter: sf,
        ),
      ]);
      if (!mounted || gen != _loadGeneration) return;
      final agg = aggAndCount[0]
          as ({double totalQty, double totalValue, int lowStockCount});
      final total = aggAndCount[1] as int;
      setState(() {
        _statsTotalQty = agg.totalQty;
        _statsTotalValue = agg.totalValue;
        _statsLowStock = agg.lowStockCount;
        _totalFilteredCount = total;
        _countAndStatsPending = false;
      });
    } catch (_) {
      if (mounted && gen == _loadGeneration) {
        setState(() {
          _isLoading = false;
          _countAndStatsPending = false;
        });
      }
    }
  }

  Future<void> _goToPage(int page) async {
    final last = _totalPages;
    if (page < 1 || page > last) return;
    if (page == _currentPage && !_isLoading) return;
    setState(() => _isLoading = true);
    if (!mounted) return;
    try {
      final offset = (page - 1) * kWarehouseSuppliesPageSize;
      final pageData = await _productService.getWarehouseSuppliesPage(
        warehouseId: _selectedWarehouse?.id,
        searchQuery: _searchController.text,
        statusFilter: _statusFilter,
        sortKey: _sortKey,
        ascending: _isAscending,
        limit: kWarehouseSuppliesPageSize,
        offset: offset,
      );
      if (!mounted) return;
      setState(() {
        _loadedProducts = pageData;
        _currentPage = page;
        _isLoading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_tableVerticalController.hasClients) _tableVerticalController.jumpTo(0);
        if (_cardGridScrollController.hasClients) _cardGridScrollController.jumpTo(0);
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
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

  Future<void> _loadProducts() async {
    await _reloadFilteredList();
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
                _reloadFilteredList();
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
                  _reloadFilteredList();
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
        _reloadFilteredList();
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
    _reloadFilteredList();
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
    double screenWidth = MediaQuery.of(context).size.width;

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
                  isLoading: _countAndStatsPending,
                ),
                Expanded(child: _buildContentCard(isAdmin, screenWidth)),
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
    await DatabaseService.restoreCurrentUser();
    if (UserSession.userId != null) {
      DatabaseService.setCurrentUser(UserSession.userId!);
    }
    final lowStockProducts = await _productService
        .getWarehouseSuppliesLowStockList(
          warehouseId: _selectedWarehouse?.id,
          searchQuery: _searchController.text,
          statusFilter: _statusFilter,
        );
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

  Widget _buildContentCard(bool isAdmin, double screenWidth) {
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
            // Obsah: tabuľka alebo karty + stránkovanie
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: AppColors.accentGold,
                      ),
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: _isCardView
                              ? WarehouseSuppliesCardView(
                                  scrollController: _cardGridScrollController,
                                  products: _loadedProducts,
                                  onEditProduct: _openEditProductModal,
                                  onDeleteProduct: isAdmin
                                      ? _confirmDeleteProduct
                                      : null,
                                )
                              : ScrollConfiguration(
                                  behavior:
                                      WarehouseSuppliesDesktopDragScrollBehavior(),
                                  child: RefreshIndicator(
                                  onRefresh: _loadProducts,
                                  color: AppColors.accentGold,
                                  child: Scrollbar(
                                    controller: _tableVerticalController,
                                    thumbVisibility: true,
                                    child: SingleChildScrollView(
                                      controller: _tableVerticalController,
                                      physics: const AlwaysScrollableScrollPhysics(
                                        parent: ClampingScrollPhysics(),
                                      ),
                                      scrollDirection: Axis.vertical,
                                      child: Scrollbar(
                                        controller: _horizontalController,
                                        thumbVisibility: true,
                                        child: SingleChildScrollView(
                                          controller: _horizontalController,
                                          scrollDirection: Axis.horizontal,
                                          physics: const ClampingScrollPhysics(),
                                          child: ConstrainedBox(
                                            constraints: BoxConstraints(
                                              minWidth: screenWidth >
                                                      kWarehouseSuppliesMinTableWidth
                                                  ? screenWidth
                                                  : kWarehouseSuppliesMinTableWidth,
                                            ),
                                            child: (() {
                                                final tableColumns =
                                                    WarehouseSuppliesTableData
                                                        .buildColumns(
                                                  context,
                                                  isAdmin: isAdmin,
                                                  columnVisibility:
                                                      _columnVisibility,
                                                  onSort: ({
                                                    required String sortKey,
                                                    required int columnIndex,
                                                    required bool ascending,
                                                  }) =>
                                                      _sort(
                                                        sortKey: sortKey,
                                                        columnIndex:
                                                            columnIndex,
                                                        ascending: ascending,
                                                      ),
                                                );
                                                final sortIndex =
                                                    _sortColumnIndex >= 0 &&
                                                        _sortColumnIndex <
                                                            tableColumns.length
                                                    ? _sortColumnIndex
                                                    : null;
                                                return RepaintBoundary(
                                                  child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    DataTable(
                                                      columnSpacing: 20,
                                                      headingRowColor:
                                                          WidgetStateProperty.all(
                                                            AppColors
                                                                .bgElevated,
                                                          ),
                                                      headingTextStyle:
                                                          TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: AppColors
                                                                .textPrimary,
                                                          ),
                                                      sortColumnIndex:
                                                          sortIndex,
                                                      sortAscending:
                                                          _isAscending,
                                                      showCheckboxColumn:
                                                          isAdmin,
                                                      columns: tableColumns,
                                                      rows:
                                                          _loadedProducts
                                                              .isEmpty
                                                          ? [
                                                              DataRow(
                                                                cells: [
                                                                  DataCell(
                                                                    Text(
                                                                      'Žiadne produkty. Potiahnite nadol pre obnovenie.',
                                                                      style: TextStyle(
                                                                        color: AppColors
                                                                            .textSecondary,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  ...List.generate(
                                                                    tableColumns
                                                                            .length -
                                                                        1,
                                                                    (_) =>
                                                                        const DataCell(
                                                                          Text(
                                                                            '',
                                                                          ),
                                                                        ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ]
                                                          : _loadedProducts.asMap().entries.map((
                                                              entry,
                                                            ) {
                                                              final index =
                                                                  entry.key;
                                                              final product =
                                                                  entry.value;
                                                              final lowStock =
                                                                  product.minQuantity >
                                                                      0 &&
                                                                  product.qty <
                                                                      product
                                                                          .minQuantity;
                                                              return DataRow(
                                                                color: WidgetStateProperty.resolveWith<Color?>(
                                                                  (states) =>
                                                                      index %
                                                                              2 ==
                                                                          0
                                                                      ? AppColors
                                                                            .bgCard
                                                                      : AppColors
                                                                            .bgElevated,
                                                                ),
                                                                cells: WarehouseSuppliesTableData
                                                                    .buildRowCells(
                                                                  context,
                                                                  product:
                                                                      product,
                                                                  index: (_currentPage -
                                                                              1) *
                                                                          kWarehouseSuppliesPageSize +
                                                                      index,
                                                                  lowStock:
                                                                      lowStock,
                                                                  isAdmin:
                                                                      isAdmin,
                                                                  columnVisibility:
                                                                      _columnVisibility,
                                                                  warehouses:
                                                                      _warehouses,
                                                                  onEdit:
                                                                      _openEditProductModal,
                                                                  onDelete:
                                                                      _confirmDeleteProduct,
                                                                ),
                                                              );
                                                            }).toList(),
                                                    ),
                                                  ],
                                                  ),
                                                );
                                              })(),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  ),
                                ),
                        WarehouseSuppliesPaginationBar(
                          currentPage: _currentPage,
                          totalPages: _totalPages,
                          totalFilteredCount: _totalFilteredCount,
                          pageSize: kWarehouseSuppliesPageSize,
                          loadedOnPageCount: _loadedProducts.length,
                          isLoading: _isLoading,
                          countAndStatsPending: _countAndStatsPending,
                          onGoToPage: _goToPage,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
