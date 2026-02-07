import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:stock_pilot/widgets/warehouse/warehouse_list_widget.dart';
import 'package:stock_pilot/widgets/warehouse/add_warehouse_modal_widget.dart';
import 'package:stock_pilot/l10n/app_localizations.dart';

class WarehousesPage extends StatefulWidget {
  const WarehousesPage({super.key});

  @override
  State<WarehousesPage> createState() => _WarehousesPageState();
}

class _WarehousesPageState extends State<WarehousesPage> {
  final GlobalKey<State<WarehouseListWidget>> _warehouseListKey =
      GlobalKey<State<WarehouseListWidget>>();

  void _addWarehouse() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const AddWarehouseModal(),
    ).then((result) {
      // Obnoviť zoznam po pridaní alebo úprave skladu
      if (result != null) {
        final state = _warehouseListKey.currentState;
        if (state != null) {
          // Volanie refreshWarehouses cez dynamic
          (state as dynamic).refreshWarehouses();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AppBar(
              backgroundColor: Colors.white.withOpacity(0.7),
              elevation: 0,
              centerTitle: false,
              title: Text(
                l10n.warehouses,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 26,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.tune, color: Colors.black87),
                  onPressed: () {},
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
      body: WarehouseListWidget(key: _warehouseListKey),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addWarehouse,
        backgroundColor: Colors.black,
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
