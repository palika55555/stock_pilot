import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:stock_pilot/theme/app_theme.dart';
import 'package:stock_pilot/models/production_batch.dart';
import 'package:stock_pilot/services/Database/database_service.dart';
import 'package:stock_pilot/screens/production/production_batch_form_screen.dart';
import 'package:stock_pilot/screens/production/production_batch_detail_screen.dart';
import 'package:stock_pilot/screens/production/produced_products_screen.dart';

class ProductionListScreen extends StatefulWidget {
  const ProductionListScreen({super.key});

  @override
  State<ProductionListScreen> createState() => _ProductionListScreenState();
}

class _ProductionListScreenState extends State<ProductionListScreen> {
  final DatabaseService _db = DatabaseService();
  DateTime _selectedDate = DateTime.now();
  List<ProductionBatch> _batches = [];
  bool _loading = true;

  String get _dateStr => DateFormat('yyyy-MM-dd').format(_selectedDate);

  @override
  void initState() {
    super.initState();
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    setState(() => _loading = true);
    final list = await _db.getProductionBatchesByDate(_dateStr);
    if (mounted) setState(() {
      _batches = list;
      _loading = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _loadBatches();
    }
  }

  Future<void> _addBatch() async {
    final result = await Navigator.push<Object?>(
      context,
      MaterialPageRoute(
        builder: (context) => ProductionBatchFormScreen(initialDate: _selectedDate),
      ),
    );
    if (!mounted) return;
    await _loadBatches();
    if (!mounted) return;
    if (result is int) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (context) => ProductionBatchDetailScreen(batchId: result),
        ),
      );
      if (mounted) _loadBatches();
    }
  }

  @override
  Widget build(BuildContext context) {
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
                'Výroba',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 26,
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.bar_chart_rounded, color: AppColors.accentGold),
                  tooltip: 'Vyrobené produkty',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProducedProductsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 80),
          Material(
            color: AppColors.bgCard,
            elevation: 2,
            child: InkWell(
              onTap: _pickDate,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, color: Color(0xFF3F3D56)),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('d. M. yyyy', 'sk').format(_selectedDate),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _batches.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.precision_manufacturing_rounded, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'V tento deň nie sú žiadne šarže',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: _addBatch,
                              icon: const Icon(Icons.add),
                              label: const Text('Pridať šaržu'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _batches.length,
                        itemBuilder: (context, index) {
                          final b = _batches[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFF3F3D56).withOpacity(0.2),
                                child: const Icon(Icons.layers_rounded, color: Color(0xFF3F3D56)),
                              ),
                              title: Text(b.productType, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text('${b.quantityProduced} ks'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ProductionBatchDetailScreen(batchId: b.id!),
                                  ),
                                );
                                _loadBatches();
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addBatch,
        backgroundColor: Colors.black,
        elevation: 10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        label: const Text('Pridať šaržu', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        icon: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
