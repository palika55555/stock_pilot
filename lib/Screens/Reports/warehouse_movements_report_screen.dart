import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../services/Database/database_service.dart';
import '../../services/Warehouse/warehouse_service.dart';
import '../../models/warehouse.dart';
import '../../models/warehouse_movement_record.dart';

/// Report – kniha skladových pohybov (príjemky, výdajky, presuny).
class WarehouseMovementsReportScreen extends StatefulWidget {
  const WarehouseMovementsReportScreen({super.key});

  @override
  State<WarehouseMovementsReportScreen> createState() => _WarehouseMovementsReportScreenState();
}

class _WarehouseMovementsReportScreenState extends State<WarehouseMovementsReportScreen> {
  final DatabaseService _db = DatabaseService();
  final WarehouseService _warehouseService = WarehouseService();
  List<Warehouse> _warehouses = [];
  List<WarehouseMovementRecord> _filtered = [];
  bool _loading = true;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  int? _warehouseId;
  String _direction = 'ALL';
  final TextEditingController _productCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _productCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _loadWarehouses();
    await _refresh();
  }

  Future<void> _loadWarehouses() async {
    final list = await _warehouseService.getActiveWarehouses();
    if (mounted) setState(() => _warehouses = list);
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    await DatabaseService.restoreCurrentUser();
    final all = await _db.getAllWarehouseMovementRecords(warehouseId: _warehouseId);
    final q = _productCtrl.text.trim().toLowerCase();
    var list = all.where((r) {
      if (_dateFrom != null) {
        final start = DateTime(_dateFrom!.year, _dateFrom!.month, _dateFrom!.day);
        if (r.createdAt.isBefore(start)) return false;
      }
      if (_dateTo != null) {
        final end = DateTime(_dateTo!.year, _dateTo!.month, _dateTo!.day, 23, 59, 59);
        if (r.createdAt.isAfter(end)) return false;
      }
      if (_direction != 'ALL' && r.direction != _direction) return false;
      if (q.isNotEmpty) {
        final name = (r.productName ?? '').toLowerCase();
        final plu = (r.plu ?? '').toLowerCase();
        final uid = r.productUniqueId.toLowerCase();
        if (!name.contains(q) && !plu.contains(q) && !uid.contains(q)) return false;
      }
      return true;
    }).toList();
    if (mounted) {
      setState(() {
        _filtered = list;
        _loading = false;
      });
    }
  }

  String _sourceLabel(String sourceType) {
    switch (sourceType) {
      case 'receipt':
        return 'Príjemka';
      case 'stock_out':
        return 'Výdajka';
      case 'transfer':
        return 'Presun';
      default:
        return sourceType;
    }
  }

  String _whName(int? id) {
    if (id == null) return '—';
    try {
      return _warehouses.firstWhere((w) => w.id == id).name;
    } catch (_) {
      return '#$id';
    }
  }

  String _fmtDate(DateTime d) => DateFormat('d.M.y HH:mm').format(d);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Pohyby skladu'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _refresh,
            tooltip: 'Obnoviť',
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFilters(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text('Žiadne pohyby podľa filtrov', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Dátum')),
                              DataColumn(label: Text('Doklad')),
                              DataColumn(label: Text('Typ')),
                              DataColumn(label: Text('Smer')),
                              DataColumn(label: Text('Sklad')),
                              DataColumn(label: Text('Produkt')),
                              DataColumn(label: Text('PLU')),
                              DataColumn(label: Text('Množstvo')),
                            ],
                            rows: _filtered.map((r) {
                              return DataRow(
                                cells: [
                                  DataCell(Text(_fmtDate(r.createdAt))),
                                  DataCell(Text(r.documentNumber)),
                                  DataCell(Text(_sourceLabel(r.sourceType))),
                                  DataCell(Text(r.direction)),
                                  DataCell(Text(_whName(r.warehouseId))),
                                  DataCell(Text(r.productName ?? r.productUniqueId)),
                                  DataCell(Text(r.plu ?? '—')),
                                  DataCell(Text('${r.qty} ${r.unit}')),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filtre', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(_dateFrom == null ? 'Od' : DateFormat('d.M.y').format(_dateFrom!)),
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (d != null && mounted) setState(() => _dateFrom = d);
                      _refresh();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(_dateTo == null ? 'Do' : DateFormat('d.M.y').format(_dateTo!)),
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (d != null && mounted) setState(() => _dateTo = d);
                      _refresh();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int?>(
              value: _warehouseId,
              decoration: const InputDecoration(labelText: 'Sklad', isDense: true),
              items: [
                const DropdownMenuItem(value: null, child: Text('Všetky')),
                ..._warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))),
              ],
              onChanged: (v) {
                setState(() => _warehouseId = v);
                _refresh();
              },
            ),
            DropdownButtonFormField<String>(
              value: _direction,
              decoration: const InputDecoration(labelText: 'Smer pohybu', isDense: true),
              items: const [
                DropdownMenuItem(value: 'ALL', child: Text('Všetky')),
                DropdownMenuItem(value: 'IN', child: Text('Príjem (IN)')),
                DropdownMenuItem(value: 'OUT', child: Text('Výdaj (OUT)')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _direction = v);
                _refresh();
              },
            ),
            TextField(
              controller: _productCtrl,
              decoration: const InputDecoration(
                labelText: 'Produkt / PLU / ID',
                isDense: true,
                suffixIcon: Icon(Icons.search, size: 20),
              ),
              onSubmitted: (_) => _refresh(),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _loading ? null : _refresh,
              icon: const Icon(Icons.filter_alt_outlined, size: 18),
              label: const Text('Použiť filter'),
            ),
          ],
        ),
      ),
    );
  }
}
