import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/Products/add_product_modal_widget.dart';
import '../../widgets/purchase/purchase_price_history_sheet_widget.dart';
import '../../widgets/Warehouse/warehouse_supplies_header_widget.dart';
import '../../widgets/Warehouse/warehouse_quick_stats_widget.dart';
import '../../widgets/Warehouse/warehouse_low_stock_modal_widget.dart';
import '../../widgets/Warehouse/warehouse_supplies_card_view_widget.dart';
import '../../services/Product/product_service.dart';
import '../../services/Warehouse/warehouse_service.dart';
import '../../l10n/app_localizations.dart';
import '../../models/product.dart';
import '../../models/warehouse.dart';

/// Stĺpce tabuľky, ktoré môže používateľ skryť/zobraziť (v poradí zobrazenia).
const List<({String id, String label})> _warehouseSupplyTableColumns = [
  (id: 'predaj_bez_dph', label: 'Predaj bez DPH'),
  (id: 'predaj_s_dph', label: 'Predaj s DPH'),
  (id: 'marza', label: 'Marža'),
  (id: 'dph', label: 'DPH'),
  (id: 'dph_eur', label: 'DPH (€)'),
  (id: 'mnozstvo', label: 'Množstvo'),
  (id: 'zlava', label: 'Zľava'),
  (id: 'nakup_bez_dph', label: 'Nákup bez DPH'),
  (id: 'nakup_s_dph', label: 'Nákup s DPH'),
  (id: 'nakup_dph', label: 'Nákup DPH'),
  (id: 'recykl', label: 'Recykl. popl.'),
  (id: 'posl_datum', label: 'Posl. dátum nákupu'),
  (id: 'posl_nakup_bez_dph', label: 'Posledný nákup bez DPH'),
  (id: 'dodavatel', label: 'Dodávateľ'),
  (id: 'mena', label: 'Mena'),
  (id: 'typ', label: 'Typ'),
  (id: 'lokacia', label: 'Lokácia'),
];

const String _prefsColumnVisibilityKey = 'warehouse_supplies_visible_columns';

class WarehouseSuppliesScreen extends StatefulWidget {
  final String userRole; // 'admin' alebo 'user'
  const WarehouseSuppliesScreen({super.key, required this.userRole});

  @override
  State<WarehouseSuppliesScreen> createState() =>
      _WarehouseSuppliesScreenState();
}

class _WarehouseSuppliesScreenState extends State<WarehouseSuppliesScreen> {
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();
  final List<String> _selectedIds = []; // Pre admin výber riadkov
  final ProductService _productService = ProductService();
  final WarehouseService _warehouseService = WarehouseService();
  final TextEditingController _searchController = TextEditingController();

  List<Product> _allProducts = [];
  List<Product> _foundProducts = [];
  List<Warehouse> _warehouses = [];
  Warehouse? _selectedWarehouse;
  bool _isLoading = true;
  bool _isAscending = true;
  bool _isCardView = false;
  int _sortColumnIndex = 4; // stĺpec pre indikátor zoradenia (predvolene Predaj s DPH)
  static const double minTableWidth = 1700;

  /// Viditeľnosť stĺpcov tabuľky (id -> true = zobrazený). Predvolene všetky true.
  Map<String, bool> _columnVisibility = {
    for (final c in _warehouseSupplyTableColumns) c.id: true,
  };

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => _applyFilters());
    _loadProducts();
    _loadWarehouses();
    _loadColumnVisibility();
  }

  Future<void> _loadColumnVisibility() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_prefsColumnVisibilityKey);
    if (saved == null) return; // prvý štart – nechaj predvolene všetky zobrazené
    final ids = _warehouseSupplyTableColumns.map((c) => c.id).toSet();
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
    await prefs.setStringList(_prefsColumnVisibilityKey, list);
  }

  List<DataColumn> _buildTableColumns(bool isAdmin) {
    final cols = <DataColumn>[
      const DataColumn(
        label: Text('#', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      DataColumn(
        label: const Text('PLU'),
        onSort: (i, a) => _sort((p) => p.plu, i, a),
      ),
      DataColumn(
        label: const Text('Názov tovaru'),
        onSort: (i, a) => _sort((p) => p.name, i, a),
      ),
    ];
    for (final c in _warehouseSupplyTableColumns) {
      if (_columnVisibility[c.id] != true) continue;
      switch (c.id) {
        case 'predaj_s_dph':
          cols.add(DataColumn(
            label: const Text('Predaj s DPH'),
            numeric: true,
            onSort: (i, a) => _sort((p) => p.price, i, a),
          ));
          break;
        case 'marza':
          cols.add(DataColumn(
            label: Text(AppLocalizations.of(context)!.margin),
            numeric: true,
            onSort: (i, a) => _sort(
                (p) => p.marginPercent ?? -1, i, a),
          ));
          break;
        case 'mnozstvo':
          cols.add(DataColumn(
            label: const Text('Množstvo'),
            numeric: true,
            onSort: (i, a) => _sort((p) => p.qty, i, a),
          ));
          break;
        case 'posl_nakup_bez_dph':
          cols.add(DataColumn(
            label: const Text('Posledný nákup bez DPH'),
            numeric: true,
            onSort: (i, a) => _sort(
                (p) => p.lastPurchasePriceWithoutVat, i, a),
          ));
          break;
        case 'dodavatel':
          cols.add(DataColumn(
            label: const Text('Dodávateľ'),
            onSort: (i, a) => _sort(
                (p) => p.supplierName ?? '', i, a),
          ));
          break;
        default:
          cols.add(DataColumn(
            label: Text(c.label),
            numeric: _isNumericColumn(c.id),
          ));
      }
    }
    cols.add(const DataColumn(label: Text('História cien')));
    return cols;
  }

  bool _isNumericColumn(String id) {
    const numericIds = {
      'predaj_bez_dph', 'predaj_s_dph', 'marza', 'dph', 'dph_eur', 'mnozstvo',
      'zlava', 'nakup_bez_dph', 'nakup_s_dph', 'nakup_dph', 'recykl',
      'posl_nakup_bez_dph',
    };
    return numericIds.contains(id);
  }

  int _computeSortColumnIndex() {
    int idx = 0;
    idx += 3; // #, PLU, Názov
    for (final c in _warehouseSupplyTableColumns) {
      if (_columnVisibility[c.id] != true) continue;
      if (c.id == 'predaj_s_dph') return idx;
      idx++;
    }
    return -1;
  }

  List<DataCell> _buildRowCells(
    Product product,
    int index,
    bool lowStock,
    bool isAdmin,
  ) {
    final cells = <DataCell>[
      DataCell(Text(
        '${index + 1}.',
        style: const TextStyle(color: Colors.grey),
      )),
      DataCell(Text(
        product.plu,
        style: const TextStyle(fontWeight: FontWeight.bold),
      )),
      DataCell(Text(product.name)),
    ];
    for (final c in _warehouseSupplyTableColumns) {
      if (_columnVisibility[c.id] != true) continue;
      cells.add(_cellForColumn(c.id, product, lowStock));
    }
    cells.add(DataCell(
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 22),
            tooltip: 'Upraviť produkt',
            onPressed: () => _openEditProductModal(product),
          ),
          IconButton(
            icon: const Icon(Icons.history_edu_outlined, size: 22),
            tooltip: 'História nákupných cien',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (context) => PurchasePriceHistorySheet(product: product),
              );
            },
          ),
        ],
      ),
    ));
    return cells;
  }

  DataCell _cellForColumn(String id, Product product, bool lowStock) {
    switch (id) {
      case 'predaj_bez_dph':
        return DataCell(Text(
            '${product.withoutVat.toStringAsFixed(2)} €'));
      case 'predaj_s_dph':
        return DataCell(Text('${product.price.toStringAsFixed(2)} €'));
      case 'marza':
        final m = product.marginPercent;
        return DataCell(Text(
            m != null ? '${m.toStringAsFixed(1)} %' : '–'));
      case 'dph':
        return DataCell(Text('${product.vat} %'));
      case 'dph_eur':
        return DataCell(Text(
            '${(product.price - product.withoutVat).toStringAsFixed(2)} €'));
      case 'mnozstvo':
        return DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: lowStock ? Colors.red[50]! : Colors.green[50]!,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${product.qty} ${product.unit}',
              style: TextStyle(
                color: lowStock ? Colors.red[700]! : Colors.green[700]!,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      case 'zlava':
        return DataCell(Text('${product.discount} %'));
      case 'nakup_bez_dph':
        return DataCell(Text(
            '${product.purchasePriceWithoutVat.toStringAsFixed(2)} €'));
      case 'nakup_s_dph':
        return DataCell(Text(
            '${product.purchasePrice.toStringAsFixed(2)} €'));
      case 'nakup_dph':
        return DataCell(Text('${product.purchaseVat} %'));
      case 'recykl':
        return DataCell(Text(
            '${product.recyclingFee.toStringAsFixed(2)} €'));
      case 'posl_datum':
        return DataCell(Text(product.lastPurchaseDate));
      case 'posl_nakup_bez_dph':
        return DataCell(Text(
            '${product.lastPurchasePriceWithoutVat.toStringAsFixed(2)} €'));
      case 'dodavatel':
        return DataCell(Text(product.supplierName ?? '–'));
      case 'mena':
        return DataCell(Text(product.currency));
      case 'typ':
        return DataCell(Text(product.productType));
      case 'lokacia':
        return DataCell(Text(product.location));
      default:
        return const DataCell(Text(''));
    }
  }

  void _showColumnSelector() {
    final localVisibility = Map<String, bool>.from(_columnVisibility);
    const sectionPredaj = [
      'predaj_bez_dph', 'predaj_s_dph', 'marza', 'dph', 'dph_eur', 'zlava',
    ];
    const sectionNakup = [
      'nakup_bez_dph', 'nakup_s_dph', 'nakup_dph', 'recykl',
      'posl_datum', 'posl_nakup_bez_dph',
    ];
    final sectionOstatne = _warehouseSupplyTableColumns
        .map((c) => c.id)
        .where((id) => !sectionPredaj.contains(id) && !sectionNakup.contains(id))
        .toList();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 8,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Hlavička
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.view_column_rounded,
                          size: 28,
                          color: const Color(0xFF6366F1),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Zobrazenie stĺpcov',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1E293B),
                              ),
                        ),
                      ],
                    ),
                  ),
                  // Zoznam v sekciách
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildColumnSection(
                            context,
                            'Predaj',
                            sectionPredaj,
                            localVisibility,
                            setModalState,
                          ),
                          const SizedBox(height: 16),
                          _buildColumnSection(
                            context,
                            'Nákup',
                            sectionNakup,
                            localVisibility,
                            setModalState,
                          ),
                          const SizedBox(height: 16),
                          _buildColumnSection(
                            context,
                            'Sklad a ostatné',
                            sectionOstatne,
                            localVisibility,
                            setModalState,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Spodok – tlačidlá
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            for (final c in _warehouseSupplyTableColumns) {
                              localVisibility[c.id] = true;
                            }
                            setModalState(() {});
                          },
                          icon: const Icon(Icons.restore_rounded, size: 20),
                          label: const Text('Obnoviť predvolené'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF64748B),
                          ),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () {
                            setState(() => _columnVisibility = Map.from(localVisibility));
                            _saveColumnVisibility();
                            Navigator.pop(context);
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Hotovo'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildColumnSection(
    BuildContext context,
    String sectionTitle,
    List<String> columnIds,
    Map<String, bool> localVisibility,
    void Function(void Function()) setModalState,
  ) {
    final columns = columnIds
        .map((id) => _warehouseSupplyTableColumns.firstWhere((c) => c.id == id))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          sectionTitle,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
                letterSpacing: 0.5,
              ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: columns.map((col) {
            final isChecked = localVisibility[col.id] ?? true;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setModalState(() => localVisibility[col.id] = !isChecked);
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isChecked
                        ? const Color(0xFF6366F1).withValues(alpha: 0.12)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isChecked
                          ? const Color(0xFF6366F1).withValues(alpha: 0.4)
                          : Colors.grey.shade300,
                      width: isChecked ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isChecked ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                        size: 22,
                        color: isChecked ? const Color(0xFF6366F1) : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        col.id == 'marza'
                            ? AppLocalizations.of(context)!.margin
                            : col.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isChecked ? FontWeight.w600 : FontWeight.w500,
                          color: isChecked ? const Color(0xFF1E293B) : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<void> _loadWarehouses() async {
    final list = await _warehouseService.getActiveWarehouses();
    if (mounted) setState(() => _warehouses = list);
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    final products = await _productService.getAllProducts();
    if (mounted) {
      setState(() {
        _allProducts = products;
        _isLoading = false;
      });
      _applyFilters();
    }
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
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            ListTile(
              leading: Icon(
                _selectedWarehouse == null
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: _selectedWarehouse == null
                    ? const Color(0xFF6366F1)
                    : null,
              ),
              title: const Text('Všetky sklady'),
              onTap: () {
                setState(() => _selectedWarehouse = null);
                _applyFilters();
                Navigator.pop(context);
              },
            ),
            ..._warehouses.map((w) {
              final isSelected = _selectedWarehouse?.id == w.id;
              return ListTile(
                leading: Icon(
                  isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: isSelected ? const Color(0xFF6366F1) : null,
                ),
                title: Text(w.name),
                subtitle: Text(
                  [w.code, w.warehouseType]
                      .where((s) => s.isNotEmpty)
                      .join(' • '),
                ),
                onTap: () {
                  setState(() => _selectedWarehouse = w);
                  _applyFilters();
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
    _searchController.dispose();
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    setState(() {
      List<Product> base = _selectedWarehouse == null
          ? List.from(_allProducts)
          : _allProducts
              .where((p) => p.productType == _selectedWarehouse!.warehouseType)
              .toList();
      final query = _searchController.text.trim();
      if (query.isEmpty) {
        _foundProducts = base;
      } else {
        _foundProducts = base
            .where(
              (p) =>
                  p.name.toLowerCase().contains(query.toLowerCase()) ||
                  p.plu.toLowerCase().contains(query.toLowerCase()) ||
                  p.category.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();
      }
    });
  }

  void _sort<T>(
    Comparable<T> Function(Product p) getField,
    int columnIndex,
    bool ascending,
  ) {
    _foundProducts.sort((a, b) {
      final aValue = getField(a);
      final bValue = getField(b);
      return ascending
          ? Comparable.compare(aValue, bValue)
          : Comparable.compare(bValue, aValue);
    });
    setState(() {
      _sortColumnIndex = columnIndex;
      _isAscending = ascending;
    });
  }

  Future<void> _deleteSelected() async {
    for (var id in _selectedIds) {
      await _productService.deleteProduct(id);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vymazané položky: ${_selectedIds.length}')),
      );
      setState(() => _selectedIds.clear());
      _loadProducts();
    }
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
    final primaryColor = isAdmin
        ? const Color(0xFFB71C1C)
        : const Color(0xFF1565C0);
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      body: Stack(
        children: [
          // Horný gradientný podklad
          Container(
            height: 160,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, primaryColor.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
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
                  selectedWarehouseName: _selectedWarehouse?.name,
                ),
                WarehouseQuickStats(
                  totalQty: _foundProducts.fold<int>(0, (sum, p) => sum + p.qty),
                  totalValue: _foundProducts.fold<double>(
                    0,
                    (sum, p) => sum + (p.price * p.qty),
                  ),
                  lowStockCount: _foundProducts.where((p) => p.qty < 10).length,
                  onLowStockTap: _showLowStockModal,
                ),
                Expanded(
                  child: _buildContentCard(isAdmin, screenWidth),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: isAdmin && _selectedIds.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _deleteSelected,
              backgroundColor: Colors.redAccent,
              icon: const Icon(Icons.delete_outline),
              label: Text("Vymazať (${_selectedIds.length})"),
            )
          : isAdmin
          ? FloatingActionButton(
              onPressed: _openAddProductModal,
              backgroundColor: primaryColor,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  void _showLowStockModal() {
    final lowStockProducts = _foundProducts.where((p) => p.qty < 10).toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => WarehouseLowStockModal(
        lowStockProducts: lowStockProducts,
      ),
    );
  }

  Widget _buildContentCard(bool isAdmin, double screenWidth) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 5, 20, 0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
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
                      decoration: InputDecoration(
                        hintText: 'Hľadať produkt...',
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
                        fillColor: const Color(0xFFF1F4F8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
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
                            ? Colors.grey[400]
                            : const Color(0xFF6366F1),
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
                            ? const Color(0xFF6366F1)
                            : Colors.grey[400],
                        size: 26,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Obsah: tabuľka alebo karty
            Expanded(
              child: _isCardView
                  ? _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF6366F1),
                          ),
                        )
                      : WarehouseSuppliesCardView(
                          products: _foundProducts,
                          isAdmin: isAdmin,
                          selectedIds: _selectedIds,
                          onSelectionChanged: isAdmin
                              ? (id) {
                                  if (id == null) return;
                                  setState(() {
                                    if (_selectedIds.contains(id)) {
                                      _selectedIds.remove(id);
                                    } else {
                                      _selectedIds.add(id);
                                    }
                                  });
                                }
                              : null,
                          onEditProduct: _openEditProductModal,
                        )
                  : _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF6366F1),
                      ),
                    )
                  : Scrollbar(
                      controller: _verticalController,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _verticalController,
                        scrollDirection: Axis.vertical,
                        child: Scrollbar(
                          controller: _horizontalController,
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            controller: _horizontalController,
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth:
                                    screenWidth >
                                        _WarehouseSuppliesScreenState
                                            .minTableWidth
                                    ? screenWidth
                                    : _WarehouseSuppliesScreenState
                                          .minTableWidth,
                              ),
                              child: Builder(
                                builder: (context) {
                                  final tableColumns =
                                      _buildTableColumns(isAdmin);
                                  final sortIndex = _sortColumnIndex >= 0 &&
                                          _sortColumnIndex <
                                              tableColumns.length
                                      ? _sortColumnIndex
                                      : null;
                                  return DataTable(
                                    columnSpacing: 20,
                                    headingRowColor: WidgetStateProperty.all(
                                      Colors.grey[200],
                                    ),
                                    headingTextStyle: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF263238),
                                    ),
                                    sortColumnIndex: sortIndex,
                                    sortAscending: _isAscending,
                                    showCheckboxColumn: isAdmin,
                                    columns: tableColumns,
                                rows: _foundProducts.asMap().entries.map((
                                  entry,
                                ) {
                                  final index = entry.key;
                                  final product = entry.value;
                                  final lowStock = product.qty < 10;
                                  return DataRow(
                                    selected: _selectedIds.contains(
                                      product.uniqueId,
                                    ),
                                    onSelectChanged: isAdmin
                                        ? (selected) {
                                            setState(() {
                                              if (selected!) {
                                                _selectedIds.add(
                                                  product.uniqueId!,
                                                );
                                              } else {
                                                _selectedIds.remove(
                                                  product.uniqueId,
                                                );
                                              }
                                            });
                                          }
                                        : null,
                                    color:
                                        WidgetStateProperty.resolveWith<Color?>(
                                          (states) => index % 2 == 0
                                              ? Colors.white
                                              : Colors.grey[50],
                                        ),
                                    cells: _buildRowCells(
                                      product,
                                      index,
                                      lowStock,
                                      isAdmin,
                                    ),
                                  );
                                }).toList(),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
