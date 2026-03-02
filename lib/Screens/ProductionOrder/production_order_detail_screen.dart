import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/production_order.dart';
import '../../services/ProductionOrder/production_order_service.dart';

class ProductionOrderDetailScreen extends StatefulWidget {
  final int orderId;
  final String userRole;

  const ProductionOrderDetailScreen({super.key, required this.orderId, required this.userRole});

  @override
  State<ProductionOrderDetailScreen> createState() => _ProductionOrderDetailScreenState();
}

class _ProductionOrderDetailScreenState extends State<ProductionOrderDetailScreen> {
  final ProductionOrderService _orderService = ProductionOrderService();
  ProductionOrder? _order;
  bool _loading = true;
  String? _currentUsername;
  final _rejectionReasonController = TextEditingController();
  final _actualQtyController = TextEditingController();
  final _laborCostController = TextEditingController(text: '0');
  final _energyCostController = TextEditingController(text: '0');
  final _overheadCostController = TextEditingController(text: '0');
  final _otherCostController = TextEditingController(text: '0');

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) setState(() => _currentUsername = prefs.getString('current_user_username'));
    });
    _load();
  }

  @override
  void dispose() {
    _rejectionReasonController.dispose();
    _actualQtyController.dispose();
    _laborCostController.dispose();
    _energyCostController.dispose();
    _overheadCostController.dispose();
    _otherCostController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final order = await _orderService.getOrderById(widget.orderId);
    if (mounted) {
      setState(() {
        _order = order;
        _loading = false;
        if (order != null) {
          _actualQtyController.text = order.actualQuantity?.toString() ?? order.plannedQuantity.toString();
          _laborCostController.text = order.laborCost?.toString() ?? '0';
          _energyCostController.text = order.energyCost?.toString() ?? '0';
          _overheadCostController.text = order.overheadCost?.toString() ?? '0';
          _otherCostController.text = order.otherCost?.toString() ?? '0';
        }
      });
    }
  }

  bool get _canApprove => (_order?.status.isPending ?? false) &&
      (widget.userRole == 'manager' || widget.userRole == 'admin');
  bool get _canStart => _order?.status.canStartProduction ?? false;
  bool get _canComplete => _order?.status.canComplete ?? false;
  bool get _canEditAndResubmit => _order?.status.isRejected == true;

  @override
  Widget build(BuildContext context) {
    if (_loading || _order == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final order = _order!;
    final statusColor = Color(order.status.colorValue);
    return Scaffold(
      appBar: AppBar(
        title: Text(order.orderNumber),
        actions: [
          if (_canEditAndResubmit)
            TextButton(
              onPressed: () async {
                await _orderService.setOrderBackToDraft(widget.orderId);
                _load();
              },
              child: const Text('Upraviť'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text('Receptúra: ${order.recipeName ?? ""}', style: const TextStyle(fontWeight: FontWeight.bold))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(order.status.label, style: TextStyle(color: statusColor, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Plánované množstvo: ${order.plannedQuantity}'),
                    Text('Dátum výroby: ${order.productionDate.day}. ${order.productionDate.month}. ${order.productionDate.year}'),
                    if (order.notes != null && order.notes!.isNotEmpty) Text('Poznámka: ${order.notes}'),
                    if (order.requiresApproval) const Text('Vyžaduje schválenie', style: TextStyle(fontSize: 12, color: Colors.orange)),
                  ],
                ),
              ),
            ),
            if (order.status.isRejected && order.rejectionReason != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Zamietnuté', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                    Text('Dôvod: ${order.rejectionReason}'),
                  ],
                ),
              ),
            ],
            if (order.status.isCompleted) ...[
              const SizedBox(height: 16),
              const Text('Náklady', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _costRow('Materiálové náklady', order.materialCost),
                      _costRow('Mzdy', order.laborCost),
                      _costRow('Energia', order.energyCost),
                      _costRow('Réžia', order.overheadCost),
                      _costRow('Iné', order.otherCost),
                      const Divider(),
                      _costRow('Celkové náklady výroby', order.totalCost),
                      _costRow('Náklady na 1 ks', order.costPerUnit),
                      if (order.actualQuantity != null)
                        Text('Skutočné množstvo: ${order.actualQuantity} • Odchýlka: ${order.variance?.toStringAsFixed(1) ?? "-"}'),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            if (_canApprove) ...[
              ElevatedButton.icon(
                onPressed: () async {
                  await _orderService.approveOrder(widget.orderId, _currentUsername ?? '');
                  _load();
                },
                icon: const Icon(Icons.check_circle),
                label: const Text('Schváliť'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _showRejectDialog(),
                icon: const Icon(Icons.cancel),
                label: const Text('Zamietnuť'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ],
            if (_canStart && !_canApprove) ...[
              ElevatedButton.icon(
                onPressed: () async {
                  await _orderService.startProduction(widget.orderId);
                  _load();
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Spustiť výrobu'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2196F3), padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ],
            if (_canComplete) ...[
              const SizedBox(height: 8),
              const Text('Dokončiť výrobu', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _actualQtyController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Skutočné množstvo'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _laborCostController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Mzdy (€)'),
              ),
              TextField(
                controller: _energyCostController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Energia (€)'),
              ),
              TextField(
                controller: _overheadCostController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Réžia (€)'),
              ),
              TextField(
                controller: _otherCostController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Iné náklady (€)'),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => _showCompleteDialog(),
                icon: const Icon(Icons.done_all),
                label: const Text('Dokončiť výrobu'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _costRow(String label, double? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value != null ? '${value.toStringAsFixed(2)} €' : '-'),
        ],
      ),
    );
  }

  void _showRejectDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Zamietnuť výrobný príkaz'),
        content: TextField(
          controller: _rejectionReasonController,
          decoration: const InputDecoration(labelText: 'Dôvod zamietnutia'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Zrušiť')),
          ElevatedButton(
            onPressed: () async {
              final reason = _rejectionReasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zadajte dôvod.')));
                return;
              }
              Navigator.pop(ctx);
              await _orderService.rejectOrder(widget.orderId, reason);
              _load();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Zamietnuť'),
          ),
        ],
      ),
    );
  }

  void _showCompleteDialog() {
    final actual = double.tryParse(_actualQtyController.text.replaceAll(',', '.'));
    if (actual == null || actual <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zadajte skutočné množstvo.')));
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dokončiť výrobu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Odpočítať suroviny zo skladu (výdajka).'),
            Text('Pridať $actual ks výrobku na sklad (príjemka).'),
            const SizedBox(height: 8),
            const Text('Naozaj dokončiť?', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Zrušiť')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final labor = double.tryParse(_laborCostController.text.replaceAll(',', '.')) ?? 0;
              final energy = double.tryParse(_energyCostController.text.replaceAll(',', '.')) ?? 0;
              final overhead = double.tryParse(_overheadCostController.text.replaceAll(',', '.')) ?? 0;
              final other = double.tryParse(_otherCostController.text.replaceAll(',', '.')) ?? 0;
              await _orderService.completeProduction(
                orderId: widget.orderId,
                actualQuantity: actual,
                completedByUsername: _currentUsername ?? '',
                laborCost: labor,
                energyCost: energy,
                overheadCost: overhead,
                otherCost: other,
              );
              _load();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50)),
            child: const Text('Dokončiť'),
          ),
        ],
      ),
    );
  }
}
