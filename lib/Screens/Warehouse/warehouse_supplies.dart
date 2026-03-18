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
import '../../services/Database/database_service.dart';
import '../../services/user_session.dart';
import '../../l10n/app_localizations.dart';
import '../../models/product.dart';
import '../../models/warehouse.dart';
import '../../theme/app_theme.dart';

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
  (id: 'sklad', label: 'Sklad'),
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
        case 'sklad':
          cols.add(DataColumn(
            label: const Text('Sklad'),
            onSort: (i, a) => _sort((p) {
              final wh = p.warehouseId != null
                  ? _warehouses.where((w) => w.id == p.warehouseId).firstOrNull
                  : null;
              return wh?.name ?? '';
            }, i, a),
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

  /// Vizuálne stavy skladovej karty (OBERON): neaktívna = prečiarknuté, nedostupná = sivá, rozšírená cenotvorba = fialová.
  TextStyle? _rowStyleForProduct(Product product) {
    if (!product.isActive) {
      return TextStyle(decoration: TextDecoration.lineThrough, color: AppColors.textMuted);
    }
    if (product.temporarilyUnavailable) {
      return TextStyle(color: AppColors.textMuted);
    }
    if (product.hasExtendedPricing) {
      return TextStyle(color: AppColors.accentGold);
    }
    return null;
  }

  static TextStyle get _defaultRowStyle => TextStyle(color: AppColors.textPrimary);

  List<DataCell> _buildRowCells(
    Product product,
    int index,
    bool lowStock,
    bool isAdmin,
  ) {
    final rowStyle = _rowStyleForProduct(product);
    final baseStyle = rowStyle ?? _defaultRowStyle;
    final cells = <DataCell>[
      DataCell(Text('${index + 1}.', style: baseStyle)),
      DataCell(Text(product.plu, style: baseStyle.copyWith(fontWeight: FontWeight.bold))),
      DataCell(Text(product.name, style: baseStyle)),
    ];
    for (final c in _warehouseSupplyTableColumns) {
      if (_columnVisibility[c.id] != true) continue;
      cells.add(_cellForColumn(c.id, product, lowStock, rowStyle));
    }
    cells.add(DataCell(
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.edit_outlined, size: 22, color: AppColors.textSecondary),
            tooltip: 'Upraviť produkt',
            onPressed: () => _openEditProductModal(product),
          ),
          IconButton(
            icon: Icon(Icons.history_edu_outlined, size: 22, color: AppColors.textSecondary),
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
          if (isAdmin)
            IconButton(
              icon: Icon(Icons.delete_outline, size: 22, color: AppColors.danger),
              tooltip: 'Vymazať produkt',
              onPressed: () => _confirmDeleteProduct(product),
            ),
        ],
      ),
    ));
    return cells;
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
            child: Text(
              l10n.delete,
              style: const TextStyle(color: Colors.red),
            ),
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

  DataCell _cellForColumn(String id, Product product, bool lowStock, TextStyle? rowStyle) {
    TextStyle merge(TextStyle base) => (rowStyle ?? _defaultRowStyle).merge(base);
    switch (id) {
      case 'predaj_bez_dph':
        return DataCell(Text('${product.withoutVat.toStringAsFixed(2)} €', style: merge(const TextStyle())));
      case 'predaj_s_dph':
        return DataCell(Text('${product.price.toStringAsFixed(2)} €', style: merge(const TextStyle())));
      case 'marza':
        final m = product.marginPercent;
        return DataCell(Text(m != null ? '${m.toStringAsFixed(1)} %' : '–', style: merge(const TextStyle())));
      case 'dph':
        return DataCell(Text('${product.vat} %', style: merge(const TextStyle())));
      case 'dph_eur':
        return DataCell(Text('${(product.price - product.withoutVat).toStringAsFixed(2)} €', style: merge(const TextStyle())));
      case 'mnozstvo':
        return DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: lowStock ? AppColors.dangerSubtle : AppColors.successSubtle,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${product.qty} ${product.unit}',
              style: merge(TextStyle(
                color: lowStock ? AppColors.danger : AppColors.success,
                fontWeight: FontWeight.bold,
              )),
            ),
          ),
        );
      case 'zlava':
        return DataCell(Text('${product.discount} %', style: merge(const TextStyle())));
      case 'nakup_bez_dph':
        return DataCell(Text('${product.purchasePriceWithoutVat.toStringAsFixed(2)} €', style: merge(const TextStyle())));
      case 'nakup_s_dph':
        return DataCell(Text('${product.purchasePrice.toStringAsFixed(2)} €', style: merge(const TextStyle())));
      case 'nakup_dph':
        return DataCell(Text('${product.purchaseVat} %', style: merge(const TextStyle())));
      case 'recykl':
        return DataCell(Text('${product.recyclingFee.toStringAsFixed(2)} €', style: merge(const TextStyle())));
      case 'posl_datum':
        return DataCell(Text(product.lastPurchaseDate, style: merge(const TextStyle())));
      case 'posl_nakup_bez_dph':
        return DataCell(Text('${product.lastPurchasePriceWithoutVat.toStringAsFixed(2)} €', style: merge(const TextStyle())));
      case 'dodavatel':
        return DataCell(Text(product.supplierName ?? '–', style: merge(const TextStyle())));
      case 'mena':
        return DataCell(Text(product.currency, style: merge(const TextStyle())));
      case 'typ':
        return DataCell(Text(product.productType, style: merge(const TextStyle())));
      case 'lokacia':
        return DataCell(Text(product.location.isEmpty ? '–' : product.location, style: merge(const TextStyle())));
      case 'sklad': {
        Warehouse? wh;
        if (product.warehouseId != null) {
          try {
            wh = _warehouses.firstWhere((w) => w.id == product.warehouseId);
          } catch (_) {
            wh = null;
          }
        }
        final skladName = wh?.name ?? '–';
        return DataCell(Text(skladName, style: merge(const TextStyle())));
      }
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
                      color: AppColors.accentGoldSubtle,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.view_column_rounded,
                          size: 28,
                          color: AppColors.accentGold,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Zobrazenie stĺpcov',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
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
                          icon: Icon(Icons.restore_rounded, size: 20, color: AppColors.textSecondary),
                          label: Text('Obnoviť predvolené', style: TextStyle(color: AppColors.textSecondary)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
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
                            backgroundColor: AppColors.accentGold,
                            foregroundColor: AppColors.bgPrimary,
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
                color: AppColors.textSecondary,
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
                        ? AppColors.accentGoldSubtle
                        : AppColors.bgInput,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isChecked
                          ? AppColors.accentGold.withOpacity(0.5)
                          : AppColors.borderDefault,
                      width: isChecked ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isChecked ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                        size: 22,
                        color: isChecked ? AppColors.accentGold : AppColors.textMuted,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        col.id == 'marza'
                            ? AppLocalizations.of(context)!.margin
                            : col.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isChecked ? FontWeight.w600 : FontWeight.w500,
                          color: isChecked ? AppColors.textPrimary : AppColors.textSecondary,
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
    // Obnov aktuálneho používateľa (session/SharedPreferences), aby getProducts() vrátil produkty pre toho istého usera ako dashboard.
    await DatabaseService.restoreCurrentUser();
    if (UserSession.userId != null) {
      DatabaseService.setCurrentUser(UserSession.userId!);
    }
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
                    ? AppColors.accentGold
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
                  color: isSelected ? AppColors.accentGold : null,
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
      // Pri zvolenom sklade zobraz aj produkty bez priradeného skladu (warehouseId == null),
      // aby sa napr. produkty stiahnuté z webu vždy zobrazili.
      List<Product> base = _selectedWarehouse == null
          ? List.from(_allProducts)
          : _allProducts
              .where((p) =>
                  p.warehouseId == _selectedWarehouse!.id || p.warehouseId == null)
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
                  totalQty: _foundProducts.fold<int>(0, (sum, p) => sum + p.qty.round()),
                  totalValue: _foundProducts.fold<double>(
                    0,
                    (sum, p) => sum + (p.price * p.qty),
                  ),
                  lowStockCount: _foundProducts.where((p) => p.minQuantity > 0 && p.qty < p.minQuantity).length,
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
              backgroundColor: AppColors.danger,
              icon: const Icon(Icons.delete_outline),
              label: Text("Vymazať (${_selectedIds.length})"),
            )
          : isAdmin
          ? FloatingActionButton(
              onPressed: _openAddProductModal,
              backgroundColor: AppColors.accentGold,
              child: Icon(Icons.add, color: AppColors.bgPrimary),
            )
          : null,
    );
  }

  void _showLowStockModal() {
    final lowStockProducts = _foundProducts.where((p) => p.minQuantity > 0 && p.qty < p.minQuantity).toList();
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
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 20, offset: Offset(0, 4))],
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
                                icon: Icon(Icons.close_rounded, color: AppColors.textSecondary),
                                onPressed: () => _searchController.clear(),
                              )
                            : null,
                        filled: true,
                        fillColor: AppColors.bgInput,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(color: AppColors.borderDefault),
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
            // Obsah: tabuľka alebo karty
            Expanded(
              child: _isCardView
                  ? _isLoading
                      ? Center(
                          child: CircularProgressIndicator(
                            color: AppColors.accentGold,
                          ),
                        )
                      :                       WarehouseSuppliesCardView(
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
                          onDeleteProduct: isAdmin ? _confirmDeleteProduct : null,
                        )
                  : _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: AppColors.accentGold,
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadProducts,
                      color: AppColors.accentGold,
                      child: Scrollbar(
                        controller: _verticalController,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _verticalController,
                          physics: const AlwaysScrollableScrollPhysics(),
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
                                      AppColors.bgElevated,
                                    ),
                                    headingTextStyle: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                    sortColumnIndex: sortIndex,
                                    sortAscending: _isAscending,
                                    showCheckboxColumn: isAdmin,
                                    columns: tableColumns,
                                rows: _foundProducts.isEmpty && !_isLoading
                                    ? [
                                        DataRow(
                                          cells: [
                                            DataCell(Text(
                                              'Žiadne produkty. Potiahnite nadol pre obnovenie.',
                                              style: TextStyle(color: AppColors.textSecondary),
                                            )),
                                            ...List.generate(
                                              tableColumns.length - 1,
                                              (_) => const DataCell(Text('')),
                                            ),
                                          ],
                                        ),
                                      ]
                                    : _foundProducts.asMap().entries.map((
                                  entry,
                                ) {
                                  final index = entry.key;
                                  final product = entry.value;
                                  final lowStock = product.minQuantity > 0 && product.qty < product.minQuantity;
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
                                              ? AppColors.bgCard
                                              : AppColors.bgElevated,
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
            ),
          ],
        ),
      ),
    );
  }
}
