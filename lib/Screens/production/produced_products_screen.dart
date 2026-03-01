import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:stock_pilot/models/production_batch.dart';
import 'package:stock_pilot/services/Database/database_service.dart';

/// Zobrazuje súhrn vyrobených produktov podľa typu – súčet kusov za zvolené obdobie.
class ProducedProductsScreen extends StatefulWidget {
  const ProducedProductsScreen({super.key});

  @override
  State<ProducedProductsScreen> createState() => _ProducedProductsScreenState();
}

class _ProducedProductsScreenState extends State<ProducedProductsScreen> {
  final DatabaseService _db = DatabaseService();
  DateTime _dateFrom = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _dateTo = DateTime.now();
  List<ProductionBatch> _batches = [];
  bool _loading = true;

  String get _fromStr => DateFormat('yyyy-MM-dd').format(_dateFrom);
  String get _toStr => DateFormat('yyyy-MM-dd').format(_dateTo);

  /// Súhrn podľa typu výrobku: názov -> celkový počet kusov
  Map<String, int> get _byProductType {
    final map = <String, int>{};
    for (final b in _batches) {
      map[b.productType] = (map[b.productType] ?? 0) + b.quantityProduced;
    }
    final sorted = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted);
  }

  int get _totalPieces => _batches.fold(0, (sum, b) => sum + b.quantityProduced);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _db.getProductionBatchesByDateRange(_fromStr, _toStr);
    if (mounted) setState(() {
      _batches = list;
      _loading = false;
    });
  }

  Future<void> _pickDateRange() async {
    final from = await showDatePicker(
      context: context,
      initialDate: _dateFrom,
      firstDate: DateTime(2020),
      lastDate: _dateTo,
    );
    if (from == null || !mounted) return;
    final to = await showDatePicker(
      context: context,
      initialDate: _dateTo.isAfter(from) ? _dateTo : from,
      firstDate: from,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (to != null && mounted) {
      setState(() {
        _dateFrom = from;
        _dateTo = to;
      });
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
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
              title: const Text(
                'Vyrobené produkty',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 26,
                ),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 80),
          Material(
            color: Colors.white,
            elevation: 2,
            child: InkWell(
              onTap: _pickDateRange,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                child: Row(
                  children: [
                    const Icon(Icons.date_range_rounded, color: Color(0xFF3F3D56)),
                    const SizedBox(width: 12),
                    Text(
                      '${DateFormat('d. M. yyyy', 'sk').format(_dateFrom)} – ${DateFormat('d. M. yyyy', 'sk').format(_dateTo)}',
                      style: const TextStyle(
                        fontSize: 16,
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
                            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'V zvolenom období nie sú žiadne šarže',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        children: [
                          Card(
                            color: const Color(0xFF3F3D56).withOpacity(0.08),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Spolu vyrobené',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 18,
                                    ),
                                  ),
                                  Text(
                                    '$_totalPieces ks',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 20,
                                      color: Color(0xFF3F3D56),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ..._byProductType.entries.map((e) => Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: const Color(0xFF3F3D56).withOpacity(0.2),
                                    child: const Icon(Icons.category_rounded, color: Color(0xFF3F3D56)),
                                  ),
                                  title: Text(
                                    e.key,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  trailing: Text(
                                    '${e.value} ks',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                      color: Color(0xFF3F3D56),
                                    ),
                                  ),
                                ),
                              )),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}
