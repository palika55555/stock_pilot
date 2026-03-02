import 'package:flutter/material.dart';
import '../../models/production_order.dart';
import '../../services/ProductionOrder/production_order_service.dart';
import 'production_order_detail_screen.dart';
import '../Recipe/recipe_list_screen.dart';

class ProductionOrderListScreen extends StatefulWidget {
  final String userRole;

  const ProductionOrderListScreen({super.key, required this.userRole});

  @override
  State<ProductionOrderListScreen> createState() => _ProductionOrderListScreenState();
}

class _ProductionOrderListScreenState extends State<ProductionOrderListScreen> {
  final ProductionOrderService _orderService = ProductionOrderService();
  List<ProductionOrder> _orders = [];
  bool _loading = true;
  String? _filterStatus;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _orderService.getOrders(status: _filterStatus);
    if (mounted) setState(() {
      _orders = list;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Výrobné príkazy'),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_book_rounded),
            tooltip: 'Receptúry',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RecipeListScreen(userRole: widget.userRole),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Všetky'),
                  selected: _filterStatus == null,
                  onSelected: (_) {
                    setState(() => _filterStatus = null);
                    _load();
                  },
                ),
                ...ProductionOrderStatus.values.map((s) => Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: FilterChip(
                        label: Text(s.label),
                        selected: _filterStatus == s.value,
                        onSelected: (_) {
                          setState(() => _filterStatus = s.value);
                          _load();
                        },
                      ),
                    )),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _orders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.assignment_rounded, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text('Žiadne výrobné príkazy', style: TextStyle(color: Colors.grey[600])),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _orders.length,
                        itemBuilder: (context, index) {
                          final o = _orders[index];
                          final statusColor = Color(o.status.colorValue);
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: statusColor.withOpacity(0.2),
                                child: Icon(Icons.precision_manufacturing_rounded, color: statusColor),
                              ),
                              title: Text(o.orderNumber, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                '${o.recipeName ?? ""} • ${o.plannedQuantity} ks • ${o.productionDate.day}.${o.productionDate.month}.${o.productionDate.year}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  o.status.label,
                                  style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w600),
                                ),
                              ),
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ProductionOrderDetailScreen(orderId: o.id!, userRole: widget.userRole),
                                  ),
                                );
                                _load();
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
