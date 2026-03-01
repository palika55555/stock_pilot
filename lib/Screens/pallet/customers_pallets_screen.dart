import 'package:flutter/material.dart';
import 'package:stock_pilot/models/customer.dart';
import 'package:stock_pilot/services/Database/database_service.dart';
import 'package:stock_pilot/screens/scanner/scan_product.dart';

/// Zoznam zákazníkov s bilanciou paliet, expedícia (vyber zákazníka + skenuj palety) a "Vrátiť palety".
class CustomersPalletsScreen extends StatefulWidget {
  const CustomersPalletsScreen({super.key});

  @override
  State<CustomersPalletsScreen> createState() => _CustomersPalletsScreenState();
}

class _CustomersPalletsScreenState extends State<CustomersPalletsScreen> {
  final DatabaseService _db = DatabaseService();
  List<Customer> _customers = [];
  Customer? _selectedCustomerForExpedition;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _db.getCustomers();
    if (mounted) {
      setState(() {
        _customers = list;
        _loading = false;
        if (_selectedCustomerForExpedition != null) {
          final id = _selectedCustomerForExpedition!.id;
          _selectedCustomerForExpedition = list.where((c) => c.id == id).firstOrNull;
        }
      });
    }
  }

  Future<void> _returnPallets(Customer customer) async {
    if (customer.palletBalance <= 0) return;
    final controller = TextEditingController(text: '1');
    final count = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Vrátiť palety – ${customer.name}'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Počet paliet (max. ${customer.palletBalance})',
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Zrušiť')),
          FilledButton(
            onPressed: () {
              final n = int.tryParse(controller.text);
              if (n == null || n <= 0 || n > customer.palletBalance) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Zadajte platný počet')),
                );
                return;
              }
              Navigator.pop(context, n);
            },
            child: const Text('Vrátiť'),
          ),
        ],
      ),
    );
    if (count == null || !mounted) return;
    await _db.returnPalletsForCustomer(customer.id!, count);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Vrátených $count paliet')),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final withPallets = _customers.where((c) => c.palletBalance > 0).toList();
    final others = _customers.where((c) => c.palletBalance <= 0).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zákazníci / Palety'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Predaj / Expedícia paliet',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Vyberte zákazníka a naskenujte palety – každá paleta sa automaticky priradí zákazníkovi.',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Customer>(
                    value: _selectedCustomerForExpedition,
                    decoration: const InputDecoration(
                      labelText: 'Zákazník',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: _customers
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c.name),
                            ))
                        .toList(),
                    onChanged: (c) => setState(() => _selectedCustomerForExpedition = c),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _selectedCustomerForExpedition == null
                        ? null
                        : () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ScanProductScreen(
                                  expeditionCustomer: _selectedCustomerForExpedition,
                                ),
                              ),
                            );
                            if (mounted) _load();
                          },
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Skenovať palety zákazníkovi'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      minimumSize: const Size(double.infinity, 44),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (withPallets.isNotEmpty) ...[
            const Text(
              'Zákazníci s paletami',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ...withPallets.map((c) => _customerCard(context, c, highlight: true)),
            const SizedBox(height: 24),
          ],
          Text(
            withPallets.isNotEmpty ? 'Ostatní zákazníci' : 'Zákazníci',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 8),
          ...(withPallets.isNotEmpty ? others : _customers).map((c) => _customerCard(context, c)),
        ],
      ),
    );
  }

  Widget _customerCard(BuildContext context, Customer c, {bool highlight = false}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(c.name),
        subtitle: c.address != null || c.city != null
            ? Text([c.address, c.city].whereType<String>().join(', '))
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${c.palletBalance} pal.',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: c.palletBalance > 0 ? Theme.of(context).colorScheme.primary : null,
              ),
            ),
            if (c.palletBalance > 0) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => _returnPallets(c),
                child: const Text('Vrátiť palety'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
