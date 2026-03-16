import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:stock_pilot/models/customer.dart';
import 'package:stock_pilot/screens/price_quote/price_quote_screen.dart';
import 'package:stock_pilot/services/customer/customer_service.dart';
import 'package:stock_pilot/services/api_sync_service.dart';
import 'package:stock_pilot/services/sync_check_service.dart';
import 'package:stock_pilot/services/Database/database_service.dart';
import 'package:stock_pilot/theme/app_theme.dart';
import 'package:stock_pilot/widgets/customers/add_customer_modal_widget.dart';
import 'package:stock_pilot/l10n/app_localizations.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage>
    with TickerProviderStateMixin {
  final CustomerService _customerService = CustomerService();
  final TextEditingController _searchController = TextEditingController();

  List<Customer> _customers = [];
  List<Customer> _filteredCustomers = [];
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
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _listController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() => _filterCustomers());
  }

  void _filterCustomers() {
    var list = _customers;
    if (_statusFilter == 1) list = list.where((c) => c.isActive).toList();
    if (_statusFilter == 2) list = list.where((c) => !c.isActive).toList();
    final q = _searchController.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where(
            (c) =>
                c.name.toLowerCase().contains(q) ||
                c.ico.contains(q) ||
                (c.city?.toLowerCase().contains(q) ?? false) ||
                (c.dic?.contains(q) ?? false),
          )
          .toList();
    }
    _filteredCustomers = list;
  }

  Future<void> _loadCustomers() async {
    setState(() => _loading = true);
    print('CustomersPage: currentUserId = ${DatabaseService.currentUserId}');
    final list = await _customerService.getAllCustomers();
    print('CustomersPage: loaded customers count = ${list.length}');
    if (mounted) {
      setState(() {
        _customers = list;
        _filterCustomers();
        _loading = false;
      });
    }
  }

  Future<void> _loadCustomersAndSync() async {
    await _loadCustomers();
    if (!mounted) return;
    try {
      await syncCustomersToBackend(await _customerService.getAllCustomers());
      await SyncCheckService.instance.updateLastKnownFromServer();
    } catch (_) {
      // offline alebo chyba – ticho
    }
  }

  void _addCustomer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const AddCustomerModal(),
    ).then((_) => _loadCustomersAndSync());
  }

  void _editCustomer(Customer c) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AddCustomerModal(customer: c),
    ).then((_) => _loadCustomersAndSync());
  }

  void _createPriceQuote(Customer c) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PriceQuoteScreen(customer: c)),
    ).then((_) {
      // po návrate môžeme napr. obnoviť zoznam ak by sme zobrazovali počet ponúk
    });
  }

  Future<void> _deleteCustomer(Customer c) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteCustomer),
        content: Text(l10n.deleteCustomerConfirm(c.name)),
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
      await _customerService.deleteCustomer(c.id!);
      if (mounted) {
        await _loadCustomersAndSync();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.customerDeleted),
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
              title: Text(
                l10n.customers,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 26,
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.tune, color: AppColors.textPrimary),
                  onPressed: () {},
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: kToolbarHeight + 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.searchHintCustomers,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _FilterChip(
                  label: l10n.all,
                  selected: _statusFilter == 0,
                  onTap: () => setState(() {
                    _statusFilter = 0;
                    _filterCustomers();
                  }),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: l10n.allActive,
                  selected: _statusFilter == 1,
                  onTap: () => setState(() {
                    _statusFilter = 1;
                    _filterCustomers();
                  }),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: l10n.allInactive,
                  selected: _statusFilter == 2,
                  onTap: () => setState(() {
                    _statusFilter = 2;
                    _filterCustomers();
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: _filteredCustomers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _customers.isEmpty
                                ? l10n.noCustomers
                                : l10n.noResults,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                          if (_customers.isEmpty)
                            TextButton.icon(
                              onPressed: _addCustomer,
                              icon: const Icon(Icons.add),
                              label: Text(l10n.addCustomer),
                            ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      physics: const BouncingScrollPhysics(),
                      itemCount: _filteredCustomers.length,
                      itemBuilder: (context, index) {
                        final c = _filteredCustomers[index];
                        return _CustomerCard(
                          customer: c,
                          index: index,
                          controller: _listController,
                          onEdit: () => _editCustomer(c),
                          onDelete: () => _deleteCustomer(c),
                          onPriceQuote: () => _createPriceQuote(c),
                        );
                      },
                    ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCustomer,
        backgroundColor: Colors.teal,
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
}

class _CustomerCard extends StatefulWidget {
  final Customer customer;
  final int index;
  final AnimationController controller;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onPriceQuote;

  const _CustomerCard({
    required this.customer,
    required this.index,
    required this.controller,
    required this.onEdit,
    required this.onDelete,
    required this.onPriceQuote,
  });

  @override
  State<_CustomerCard> createState() => _CustomerCardState();
}

class _CustomerCardState extends State<_CustomerCard> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final c = widget.customer;
    final l10n = AppLocalizations.of(context)!;
    final animation = CurvedAnimation(
      parent: widget.controller,
      curve: Interval(
        (0.05 * widget.index).clamp(0.0, 0.9),
        1.0,
        curve: Curves.easeOutQuart,
      ),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - animation.value)),
          child: Opacity(opacity: animation.value, child: child),
        );
      },
      child: GestureDetector(
        onTapDown: (_) => setState(() => _scale = 0.98),
        onTapUp: (_) => setState(() => _scale = 1.0),
        onTapCancel: () => setState(() => _scale = 1.0),
        onTap: widget.onEdit,
        child: AnimatedScale(
          scale: _scale,
          duration: const Duration(milliseconds: 120),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: AppColors.cardDecoration,
            child: Row(
              children: [
                _buildAvatar(c.name),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              c.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: c.isActive
                                  ? AppColors.successSubtle
                                  : AppColors.textMuted.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              c.isActive ? l10n.active : l10n.inactive,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: c.isActive
                                    ? AppColors.success
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'IČO: ${c.ico}${c.city != null && c.city!.isNotEmpty ? ' • ${c.city}' : ''}',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                      if (c.defaultVatRate > 0)
                        Text(
                          'DPH: ${c.defaultVatRate}%',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.request_quote, color: AppColors.accentGold),
                  tooltip: l10n.priceQuote,
                  onPressed: widget.onPriceQuote,
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: AppColors.textSecondary),
                  onSelected: (v) {
                    if (v == 'edit') widget.onEdit();
                    if (v == 'quote') widget.onPriceQuote();
                    if (v == 'delete') widget.onDelete();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          const Icon(Icons.edit),
                          const SizedBox(width: 8),
                          Text(l10n.edit),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'quote',
                      child: Row(
                        children: [
                          Icon(Icons.request_quote, color: AppColors.accentGold),
                          const SizedBox(width: 8),
                          Text(l10n.priceQuote),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: AppColors.danger),
                          const SizedBox(width: 8),
                          Text(
                            l10n.delete,
                            style: TextStyle(color: AppColors.danger),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String name) {
    final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.accentGoldSubtle,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.accentGold,
          ),
        ),
      ),
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.teal : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}
