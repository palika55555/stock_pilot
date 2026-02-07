import 'package:flutter/material.dart';
import 'dart:ui';
import '../../widgets/Products/add_product_modal_widget.dart';
import '../../widgets/purchase/purchase_price_history_sheet_widget.dart';
import '../../widgets/Warehouse/warehouse_supplies_header_widget.dart';
import '../../widgets/Warehouse/warehouse_quick_stats_widget.dart';
import '../../widgets/Warehouse/warehouse_low_stock_modal_widget.dart';
import '../../widgets/Warehouse/warehouse_supplies_card_view_widget.dart';
import '../../services/Product/product_service.dart';
import '../../models/product.dart';

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
  final TextEditingController _searchController = TextEditingController();

  List<Product> _allProducts = [];
  List<Product> _foundProducts = [];
  bool _isLoading = true;
  bool _isAscending = true;
  bool _isCardView = false;
  late int _sortColumnIndex;
  static const double minTableWidth = 1700;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => _runFilter(_searchController.text));
    _loadProducts();
    // Admin má o jeden stĺpec navyše (checkbox), takže sort index sa posunie
    _sortColumnIndex = (widget.userRole == 'admin') ? 2 : 1;
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    final products = await _productService.getAllProducts();
    if (mounted) {
      setState(() {
        _allProducts = products;
        _foundProducts = products;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  void _runFilter(String query) {
    setState(() {
      if (query.isEmpty) {
        _foundProducts = _allProducts;
      } else {
        _foundProducts = _allProducts
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
                WarehouseSuppliesHeader(isAdmin: isAdmin),
                WarehouseQuickStats(
                  totalQty: _allProducts.fold<int>(0, (sum, p) => sum + p.qty),
                  totalValue: _allProducts.fold<double>(
                    0,
                    (sum, p) => sum + (p.price * p.qty),
                  ),
                  lowStockCount: _allProducts.where((p) => p.qty < 10).length,
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
    final lowStockProducts = _allProducts.where((p) => p.qty < 10).toList();
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
                              child: DataTable(
                                columnSpacing: 20,
                                headingRowColor: WidgetStateProperty.all(
                                  Colors.grey[200],
                                ),
                                headingTextStyle: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF263238),
                                ),
                                sortColumnIndex: _sortColumnIndex,
                                sortAscending: _isAscending,
                                showCheckboxColumn: isAdmin,
                                columns: [
                                  const DataColumn(
                                    label: Text(
                                      '#',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: const Text('PLU'),
                                    onSort: (i, a) => _sort((p) => p.plu, i, a),
                                  ),
                                  DataColumn(
                                    label: const Text('Názov tovaru'),
                                    onSort: (i, a) =>
                                        _sort((p) => p.name, i, a),
                                  ),
                                  DataColumn(
                                    label: const Text('Cena s DPH'),
                                    numeric: true,
                                    onSort: (i, a) =>
                                        _sort((p) => p.price, i, a),
                                  ),
                                  DataColumn(
                                    label: const Text('Množstvo'),
                                    numeric: true,
                                    onSort: (i, a) => _sort((p) => p.qty, i, a),
                                  ),
                                  const DataColumn(
                                    label: Text('Bez DPH'),
                                    numeric: true,
                                  ),
                                  const DataColumn(
                                    label: Text('DPH'),
                                    numeric: true,
                                  ),
                                  const DataColumn(
                                    label: Text('Zľava'),
                                    numeric: true,
                                  ),
                                  const DataColumn(
                                    label: Text('Nákup bez DPH'),
                                    numeric: true,
                                  ),
                                  const DataColumn(
                                    label: Text('Nákup s DPH'),
                                    numeric: true,
                                  ),
                                  const DataColumn(
                                    label: Text('Nákup DPH'),
                                    numeric: true,
                                  ),
                                  const DataColumn(
                                    label: Text('Recykl. popl.'),
                                    numeric: true,
                                  ),
                                  const DataColumn(
                                    label: Text('Posl. dátum nákupu'),
                                  ),
                                  const DataColumn(label: Text('Mena')),
                                  const DataColumn(label: Text('Typ')),
                                  const DataColumn(label: Text('Lokácia')),
                                  const DataColumn(
                                    label: Text('História cien'),
                                  ),
                                ],
                                rows: _foundProducts.asMap().entries.map((
                                  entry,
                                ) {
                                  final index = entry.key;
                                  final product = entry.value;
                                  bool lowStock = product.qty < 10;

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
                                    cells: [
                                      DataCell(
                                        Text(
                                          '${index + 1}.',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          product.plu,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      DataCell(Text(product.name)),
                                      DataCell(
                                        Text(
                                          '${product.price.toStringAsFixed(2)} €',
                                        ),
                                      ),
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: lowStock
                                                ? Colors.red[50]
                                                : Colors.green[50],
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Text(
                                            '${product.qty} ${product.unit}',
                                            style: TextStyle(
                                              color: lowStock
                                                  ? Colors.red[700]
                                                  : Colors.green[700],
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          '${product.withoutVat.toStringAsFixed(2)} €',
                                        ),
                                      ),
                                      DataCell(Text('${product.vat} %')),
                                      DataCell(Text('${product.discount} %')),
                                      DataCell(
                                        Text(
                                          '${product.purchasePriceWithoutVat.toStringAsFixed(2)} €',
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          '${product.purchasePrice.toStringAsFixed(2)} €',
                                        ),
                                      ),
                                      DataCell(
                                        Text('${product.purchaseVat} %'),
                                      ),
                                      DataCell(
                                        Text(
                                          '${product.recyclingFee.toStringAsFixed(2)} €',
                                        ),
                                      ),
                                      DataCell(Text(product.lastPurchaseDate)),
                                      DataCell(Text(product.currency)),
                                      DataCell(Text(product.productType)),
                                      DataCell(Text(product.location)),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                Icons.edit_outlined,
                                                size: 22,
                                              ),
                                              tooltip: 'Upraviť produkt',
                                              onPressed: () =>
                                                  _openEditProductModal(product),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.history_edu_outlined,
                                                size: 22,
                                              ),
                                              tooltip: 'História nákupných cien',
                                              onPressed: () {
                                                showModalBottomSheet(
                                                  context: context,
                                                  backgroundColor:
                                                      Colors.transparent,
                                                  isScrollControlled: true,
                                                  builder: (context) =>
                                                      PurchasePriceHistorySheet(
                                                        product: product,
                                                      ),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
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
