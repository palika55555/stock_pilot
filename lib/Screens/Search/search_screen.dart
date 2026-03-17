import 'package:flutter/material.dart';
import '../../models/product.dart';
import '../../models/customer.dart';
import '../../models/supplier.dart';
import '../../services/Product/product_service.dart';
import '../../services/customer/customer_service.dart';
import '../../services/Supplier/supplier_service.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../warehouse/warehouse_supplies.dart';
import '../customers/customers_page.dart';
import '../suppliers/suppliers_page.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ProductService _productService = ProductService();
  final CustomerService _customerService = CustomerService();
  final SupplierService _supplierService = SupplierService();

  List<Product> _products = [];
  List<Customer> _customers = [];
  List<Supplier> _suppliers = [];

  List<Product> _filteredProducts = [];
  List<Customer> _filteredCustomers = [];
  List<Supplier> _filteredSuppliers = [];

  bool _isLoading = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(_onSearchChanged);
    _loadAllData();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final products = await _productService.getAllProducts();
      final customers = await _customerService.getAllCustomers();
      final suppliers = await _supplierService.getAllSuppliers();

      setState(() {
        _products = products;
        _customers = customers;
        _suppliers = suppliers;
        _filteredProducts = products;
        _filteredCustomers = customers;
        _filteredSuppliers = suppliers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();

    if (query.isEmpty) {
      setState(() {
        _filteredProducts = _products;
        _filteredCustomers = _customers;
        _filteredSuppliers = _suppliers;
      });
      return;
    }

    setState(() {
      // Vyhľadávanie produktov
      _filteredProducts = _products
          .where(
            (p) =>
                p.name.toLowerCase().contains(query) ||
                p.plu.toLowerCase().contains(query) ||
                p.category.toLowerCase().contains(query),
          )
          .toList();

      // Vyhľadávanie zákazníkov
      _filteredCustomers = _customers
          .where(
            (c) =>
                c.name.toLowerCase().contains(query) ||
                c.ico.toLowerCase().contains(query) ||
                (c.city?.toLowerCase().contains(query) ?? false) ||
                (c.email?.toLowerCase().contains(query) ?? false),
          )
          .toList();

      // Vyhľadávanie dodávateľov
      _filteredSuppliers = _suppliers
          .where(
            (s) =>
                s.name.toLowerCase().contains(query) ||
                s.ico.toLowerCase().contains(query) ||
                (s.city?.toLowerCase().contains(query) ?? false) ||
                (s.email?.toLowerCase().contains(query) ?? false),
          )
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: l10n.search,
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
            border: InputBorder.none,
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white),
                    onPressed: () {
                      _searchController.clear();
                    },
                  )
                : null,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.inventory_2, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '${l10n.warehouseSupplies} (${_filteredProducts.length})',
                  ),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.people, size: 18),
                  const SizedBox(width: 8),
                  Text('${l10n.customers} (${_filteredCustomers.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.business_center, size: 18),
                  const SizedBox(width: 8),
                  Text('${l10n.suppliers} (${_filteredSuppliers.length})'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildProductsList(l10n),
                _buildCustomersList(l10n),
                _buildSuppliersList(l10n),
              ],
            ),
    );
  }

  Widget _buildProductsList(AppLocalizations l10n) {
    if (_filteredProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              l10n.noResults,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredProducts.length,
      itemBuilder: (context, index) {
        final product = _filteredProducts[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.accentGoldSubtle,
              child: Icon(Icons.inventory_2, color: AppColors.accentGold),
            ),
            title: Text(
              product.name,
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('PLU: ${product.plu}', style: TextStyle(color: AppColors.textSecondary)),
                Text(
                  '${l10n.warehouseSupplies}: ${product.qty} ${product.unit}',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                Text('${l10n.category}: ${product.category}', style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
            trailing: Text(
              '${product.price.toStringAsFixed(2)} ${product.currency}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.accentGold,
                fontSize: 16,
              ),
            ),
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const WarehouseSuppliesScreen(userRole: 'user'),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCustomersList(AppLocalizations l10n) {
    if (_filteredCustomers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              l10n.noResults,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredCustomers.length,
      itemBuilder: (context, index) {
        final customer = _filteredCustomers[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.accentGoldSubtle,
              child: Icon(Icons.people, color: AppColors.accentGold),
            ),
            title: Text(
              customer.name,
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('IČO: ${customer.ico}', style: TextStyle(color: AppColors.textSecondary)),
                if (customer.city != null)
                  Text('${l10n.city}: ${customer.city}', style: TextStyle(color: AppColors.textSecondary)),
                if (customer.email != null) Text('Email: ${customer.email}', style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
            trailing: Icon(
              customer.isActive ? Icons.check_circle : Icons.cancel,
              color: customer.isActive ? AppColors.success : AppColors.textMuted,
            ),
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const CustomersPage()),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSuppliersList(AppLocalizations l10n) {
    if (_filteredSuppliers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              l10n.noResults,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredSuppliers.length,
      itemBuilder: (context, index) {
        final supplier = _filteredSuppliers[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.accentGoldSubtle,
              child: Icon(Icons.business_center, color: AppColors.accentGold),
            ),
            title: Text(
              supplier.name,
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('IČO: ${supplier.ico}', style: TextStyle(color: AppColors.textSecondary)),
                if (supplier.city != null)
                  Text('${l10n.city}: ${supplier.city}', style: TextStyle(color: AppColors.textSecondary)),
                if (supplier.email != null) Text('Email: ${supplier.email}', style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
            trailing: Icon(
              supplier.isActive ? Icons.check_circle : Icons.cancel,
              color: supplier.isActive ? AppColors.success : AppColors.textMuted,
            ),
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const SuppliersPage()),
              );
            },
          ),
        );
      },
    );
  }
}
