import 'package:flutter/material.dart';
import '../Services/database_service.dart';
import '../Models/product.dart';

class WarehouseSuppliesScreen extends StatefulWidget {
  final String userRole; // 'admin' alebo 'user'
  const WarehouseSuppliesScreen({super.key, required this.userRole});

  @override
  State<WarehouseSuppliesScreen> createState() => _WarehouseSuppliesScreenState();
}

class _WarehouseSuppliesScreenState extends State<WarehouseSuppliesScreen> {
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();
  final List<String> _selectedIds = []; // Pre admin výber riadkov
  final DatabaseService _dbService = DatabaseService();

  List<Product> _allProducts = [];
  List<Product> _foundProducts = [];
  bool _isLoading = true;
  bool _isAscending = true;
  late int _sortColumnIndex;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    // Admin má o jeden stĺpec navyše (checkbox), takže sort index sa posunie
    _sortColumnIndex = (widget.userRole == 'admin') ? 2 : 1;
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    final products = await _dbService.getProducts();
    setState(() {
      _allProducts = products;
      _foundProducts = products;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  void _runFilter(String query) {
    setState(() {
      _foundProducts = _allProducts.where((p) =>
        p.name.toLowerCase().contains(query.toLowerCase()) ||
        p.plu.toLowerCase().contains(query.toLowerCase()) ||
        p.category.toLowerCase().contains(query.toLowerCase())
      ).toList();
    });
  }

  void _sort<T>(Comparable<T> Function(Product p) getField, int columnIndex, bool ascending) {
    _foundProducts.sort((a, b) {
      final aValue = getField(a);
      final bValue = getField(b);
      return ascending ? Comparable.compare(aValue, bValue) : Comparable.compare(bValue, aValue);
    });
    setState(() {
      _sortColumnIndex = columnIndex;
      _isAscending = ascending;
    });
  }

  Future<void> _deleteSelected() async {
    for (var id in _selectedIds) {
      await _dbService.deleteProduct(id);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Vymazané položky: ${_selectedIds.length}')),
    );
    setState(() => _selectedIds.clear());
    _loadProducts();
  }

  @override
  Widget build(BuildContext context) {
    bool isAdmin = widget.userRole == 'admin';
    const double minTableWidth = 1700;
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: Text('Skladové zásoby - ${isAdmin ? "ADMIN" : "USER"}'),
        backgroundColor: isAdmin ? Colors.red[800] : Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          if (isAdmin && _selectedIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteSelected,
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: isAdmin ? Colors.red[800] : Colors.blue[800],
                child: TextField(
                  onChanged: _runFilter,
                  decoration: InputDecoration(
                    hintText: 'Hľadať podľa PLU, názvu alebo kategórie...',
                    prefixIcon: const Icon(Icons.search, color: Colors.white),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              Expanded(
                child: Scrollbar(
                  controller: _verticalController,
                  thumbVisibility: true,
                  thickness: 10,
                  child: SingleChildScrollView(
                    controller: _verticalController,
                    physics: const ClampingScrollPhysics(),
                    child: Scrollbar(
                      controller: _horizontalController,
                      thumbVisibility: true,
                      thickness: 10,
                      child: SingleChildScrollView(
                        controller: _horizontalController,
                        physics: const ClampingScrollPhysics(),
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: screenWidth > minTableWidth ? screenWidth : minTableWidth,
                          ),
                          child: DataTable(
                            columnSpacing: 20,
                            headingRowColor: WidgetStateProperty.all(Colors.grey[200]),
                            sortColumnIndex: _sortColumnIndex,
                            sortAscending: _isAscending,
                            showCheckboxColumn: isAdmin, // Len admin vidí checkboxy
                            columns: [
                              const DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: const Text('PLU'), onSort: (i, a) => _sort((p) => p.plu, i, a)),
                              DataColumn(label: const Text('Názov tovaru'), onSort: (i, a) => _sort((p) => p.name, i, a)),
                              DataColumn(label: const Text('Cena s DPH'), numeric: true, onSort: (i, a) => _sort((p) => p.price, i, a)),
                              DataColumn(label: const Text('Množstvo'), numeric: true, onSort: (i, a) => _sort((p) => p.qty, i, a)),
                              const DataColumn(label: Text('Bez DPH'), numeric: true),
                              const DataColumn(label: Text('DPH'), numeric: true),
                              const DataColumn(label: Text('Zľava'), numeric: true),
                              const DataColumn(label: Text('Posl. nákupná cena'), numeric: true),
                              const DataColumn(label: Text('Posl. dátum nákupu')),
                              const DataColumn(label: Text('Mena')),
                              const DataColumn(label: Text('Kategória')),
                              const DataColumn(label: Text('Lokácia')),
                            ],
                            rows: _foundProducts.asMap().entries.map((entry) {
                              final index = entry.key;
                              final product = entry.value;

                              return DataRow(
                                selected: _selectedIds.contains(product.uniqueId),
                                onSelectChanged: isAdmin ? (selected) {
                                  setState(() {
                                    if (selected!) {
                                      _selectedIds.add(product.uniqueId!);
                                    } else {
                                      _selectedIds.remove(product.uniqueId);
                                    }
                                  });
                                } : null,
                                color: WidgetStateProperty.resolveWith<Color?>((states) => 
                                  index % 2 == 0 ? Colors.white : Colors.grey[50]),
                                cells: [
                                  DataCell(Text('${index + 1}.', style: const TextStyle(color: Colors.grey))),
                                  DataCell(Text(product.plu, style: const TextStyle(fontWeight: FontWeight.bold))),
                                  DataCell(Text(product.name)),
                                  DataCell(Text('${product.price.toStringAsFixed(2)} €')),
                                  DataCell(Text('${product.qty} ${product.unit}')),
                                  DataCell(Text('${product.withoutVat.toStringAsFixed(2)} €')),
                                  DataCell(Text('${product.vat} %')),
                                  DataCell(Text('${product.discount} %')),
                                  DataCell(Text('${product.lastPurchasePrice.toStringAsFixed(2)} €')),
                                  DataCell(Text(product.lastPurchaseDate)),
                                  DataCell(Text(product.currency)),
                                  DataCell(Text(product.category)),
                                  DataCell(Text(product.location)),
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
    );
  }
}
