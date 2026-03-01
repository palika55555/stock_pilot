import 'package:flutter/material.dart';
import 'package:stock_pilot/models/customer.dart';
import 'package:stock_pilot/models/pallet.dart';
import 'package:stock_pilot/services/Database/database_service.dart';
import 'package:stock_pilot/services/api_sync_service.dart';

/// Expedícia palety: výber zákazníka a priradenie palety (zvýšenie palletBalance).
class PalletExpeditionScreen extends StatefulWidget {
  final int palletId;

  const PalletExpeditionScreen({super.key, required this.palletId});

  @override
  State<PalletExpeditionScreen> createState() => _PalletExpeditionScreenState();
}

class _PalletExpeditionScreenState extends State<PalletExpeditionScreen> {
  final DatabaseService _db = DatabaseService();
  Pallet? _pallet;
  List<Customer> _customers = [];
  Customer? _selectedCustomer;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pallet = await _db.getPalletById(widget.palletId);
    final customers = await _db.getActiveCustomers();
    if (mounted) {
      setState(() {
        _pallet = pallet;
        _customers = customers;
        _loading = false;
      });
    }
  }

  Future<void> _assign() async {
    if (_selectedCustomer == null || _pallet == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vyberte zákazníka')),
      );
      return;
    }
    if (_pallet!.status == PalletStatus.uZakaznika) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paleta je už priradená zákazníkovi')),
      );
      return;
    }
    setState(() => _saving = true);
    await _db.assignPalletToCustomer(widget.palletId, _selectedCustomer!.id!);
    if (!mounted) return;
    setState(() => _saving = false);
    syncBatchesToBackend();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Paleta priradená zákazníkovi ${_selectedCustomer!.name}'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_pallet == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Expedícia palety')),
        body: const Center(child: Text('Paleta nebola nájdená')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expedícia palety'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _pallet!.productType,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text('Počet kusov: ${_pallet!.quantity}'),
                  Text('Stav: ${_pallet!.status.label}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Priradiť zákazníkovi', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 8),
          DropdownButtonFormField<Customer>(
            value: _selectedCustomer,
            decoration: const InputDecoration(
              labelText: 'Zákazník',
              border: OutlineInputBorder(),
            ),
            items: _customers
                .map((c) => DropdownMenuItem(
                      value: c,
                      child: Text('${c.name}${c.palletBalance > 0 ? ' (${c.palletBalance} pal.)' : ''}'),
                    ))
                .toList(),
            onChanged: (c) => setState(() => _selectedCustomer = c),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _assign,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Potvrdiť expedíciu'),
          ),
        ],
      ),
    );
  }
}
