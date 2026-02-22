import 'package:flutter/material.dart';
import '../../models/product.dart';
import '../../models/warehouse.dart';
import '../../models/warehouse_transfer.dart';
import '../../services/Product/product_service.dart';
import '../../services/Warehouse/warehouse_service.dart';

/// Modál na vytvorenie presunu tovaru medzi skladmi.
class WarehouseTransferModal extends StatefulWidget {
  const WarehouseTransferModal({super.key});

  @override
  State<WarehouseTransferModal> createState() => _WarehouseTransferModalState();
}

class _WarehouseTransferModalState extends State<WarehouseTransferModal> {
  final WarehouseService _warehouseService = WarehouseService();
  final ProductService _productService = ProductService();
  List<Warehouse> _warehouses = [];
  List<Product> _products = [];
  Warehouse? _fromWarehouse;
  Warehouse? _toWarehouse;
  Product? _product;
  final TextEditingController _qtyController = TextEditingController(text: '1');
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _productSearchController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  List<Product> _filteredProducts = [];

  @override
  void initState() {
    super.initState();
    _load();
    _productSearchController.addListener(_filterProducts);
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _notesController.dispose();
    _productSearchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final wh = await _warehouseService.getActiveWarehouses();
    if (mounted) {
      setState(() {
        _warehouses = wh;
        _products = [];
        _filteredProducts = [];
        _loading = false;
      });
    }
  }

  /// Načíta produkty len zo zdrojového skladu (pri zmene skladu alebo prvom výbere).
  Future<void> _loadProductsFromSourceWarehouse() async {
    if (_fromWarehouse?.id == null) {
      setState(() {
        _products = [];
        _filteredProducts = [];
        _product = null;
      });
      return;
    }
    setState(() => _loading = true);
    final pr = await _productService.getProductsByWarehouseId(_fromWarehouse!.id!);
    if (mounted) {
      setState(() {
        _products = pr;
        _filteredProducts = pr;
        _loading = false;
        if (_product != null && !pr.any((p) => p.uniqueId == _product!.uniqueId)) {
          _product = null;
        }
      });
      _filterProducts();
    }
  }

  void _filterProducts() {
    final q = _productSearchController.text.trim().toLowerCase();
    setState(() {
      _filteredProducts = q.isEmpty
          ? _products
          : _products
              .where((p) =>
                  p.name.toLowerCase().contains(q) ||
                  (p.plu).toLowerCase().contains(q))
              .toList();
    });
  }

  Future<void> _save() async {
    if (_fromWarehouse == null || _toWarehouse == null || _product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Vyberte zdrojový sklad, cieľový sklad a tovar')),
      );
      return;
    }
    if (_fromWarehouse!.id == _toWarehouse!.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zdrojový a cieľový sklad musia byť rôzne')),
      );
      return;
    }
    final qty = int.tryParse(_qtyController.text);
    if (qty == null || qty < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zadajte platné množstvo')),
      );
      return;
    }
    if (qty > _product!.qty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Na sklade je len ${_product!.qty} ${_product!.unit}. Zadajte nižšie množstvo.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final transfer = WarehouseTransfer(
        fromWarehouseId: _fromWarehouse!.id!,
        toWarehouseId: _toWarehouse!.id!,
        productUniqueId: _product!.uniqueId!,
        productName: _product!.name,
        productPlu: _product!.plu,
        quantity: qty,
        unit: _product!.unit,
        createdAt: DateTime.now(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );
      await _warehouseService.createWarehouseTransfer(transfer);
      if (mounted) {
        setState(() => _saving = false);
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Presun bol zaznamenaný a zásoby upravené')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is Exception ? e.toString().replaceFirst('Exception: ', '') : 'Chyba: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Presun medzi skladmi',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
                    : SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('Zo skladu', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<Warehouse>(
                              value: _fromWarehouse,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              hint: const Text('Vyberte sklad'),
                              items: _warehouses
                                  .map((w) => DropdownMenuItem(
                                        value: w,
                                        child: Text('${w.name} (${w.code})'),
                                      ))
                                  .toList(),
                              onChanged: (w) {
                                setState(() => _fromWarehouse = w);
                                _loadProductsFromSourceWarehouse();
                              },
                            ),
                            const SizedBox(height: 16),
                            const Text('Do skladu', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<Warehouse>(
                              value: _toWarehouse,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              hint: const Text('Vyberte sklad'),
                              items: _warehouses
                                  .map((w) => DropdownMenuItem(
                                        value: w,
                                        child: Text('${w.name} (${w.code})'),
                                      ))
                                  .toList(),
                              onChanged: (w) => setState(() => _toWarehouse = w),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _fromWarehouse == null
                                  ? 'Najprv vyberte zdrojový sklad – potom sa načíta tovar'
                                  : 'Tovar (zo skladu ${_fromWarehouse!.name})',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _productSearchController,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                hintText: 'Hľadať podľa názvu alebo PLU',
                                prefixIcon: Icon(Icons.search),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 200),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: _filteredProducts.length,
                                itemBuilder: (context, i) {
                                  final p = _filteredProducts[i];
                                  final selected = _product?.uniqueId == p.uniqueId;
                                  return ListTile(
                                    title: Text(p.name),
                                    subtitle: Text('PLU: ${p.plu} · ${p.qty} ${p.unit}'),
                                    selected: selected,
                                    onTap: () => setState(() => _product = p),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _qtyController,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'Množstvo',
                                suffixText: 'ks',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _notesController,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'Poznámka (voliteľné)',
                              ),
                              maxLines: 2,
                            ),
                            const SizedBox(height: 24),
                            FilledButton.icon(
                              onPressed: _saving ? null : _save,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF6366F1),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              icon: _saving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.check),
                              label: Text(_saving ? 'Ukladám...' : 'Záznam presunu'),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
