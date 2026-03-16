import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../services/Reports/receipt_report_service.dart';
import '../../services/Warehouse/warehouse_service.dart';
import '../../models/warehouse.dart';

/// Report A – Prehľad príjemiek. Filtre, tabuľka, súhrn.
class ReceiptSummaryReportScreen extends StatefulWidget {
  const ReceiptSummaryReportScreen({super.key});

  @override
  State<ReceiptSummaryReportScreen> createState() => _ReceiptSummaryReportScreenState();
}

class _ReceiptSummaryReportScreenState extends State<ReceiptSummaryReportScreen> {
  final ReceiptReportService _reportService = ReceiptReportService();
  final WarehouseService _warehouseService = WarehouseService();
  List<Map<String, dynamic>> _rows = [];
  Map<String, dynamic> _summary = {};
  List<Warehouse> _warehouses = [];
  bool _loading = true;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  String? _statusFilter;
  int? _warehouseId;
  String? _currentUserRole;
  String? _currentUsername;

  @override
  void initState() {
    super.initState();
    _loadWarehouses();
    _loadUser();
    _runReport();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _currentUserRole = prefs.getString('current_user_role');
        _currentUsername = prefs.getString('current_user_username');
      });
    }
  }

  Future<void> _loadWarehouses() async {
    final list = await _warehouseService.getActiveWarehouses();
    if (mounted) setState(() => _warehouses = list);
  }

  Future<void> _runReport() async {
    setState(() => _loading = true);
    final result = await _reportService.getReceiptSummaryReport(
      dateFrom: _dateFrom,
      dateTo: _dateTo,
      status: _statusFilter,
      warehouseId: _warehouseId,
      currentUserRole: _currentUserRole,
      currentUsername: _currentUsername,
    );
    if (mounted) {
      setState(() {
        _rows = (result['rows'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
        _summary = result;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Prehľad príjemiek'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _runReport,
            tooltip: 'Resetovať filtre',
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
                : _rows.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text('Žiadne dáta podľa filtrov', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Č. príjemky')),
                              DataColumn(label: Text('Dátum')),
                              DataColumn(label: Text('Typ')),
                              DataColumn(label: Text('Sklad')),
                              DataColumn(label: Text('Dodávateľ')),
                              DataColumn(label: Text('Položiek')),
                              DataColumn(label: Text('Suma bez DPH')),
                              DataColumn(label: Text('DPH')),
                              DataColumn(label: Text('Suma s DPH')),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('Schválil')),
                              DataColumn(label: Text('Dátum schv.')),
                            ],
                            rows: _rows.map((r) {
                              final whId = r['warehouse_id'] as int?;
                              String whName = '—';
                              if (whId != null) {
                                try {
                                  final w = _warehouses.firstWhere((w) => w.id == whId);
                                  whName = w.name;
                                } catch (_) {}
                              }
                              return DataRow(
                                cells: [
                                  DataCell(Text('${r['receipt_number']}')),
                                  DataCell(Text(_fmtDate(r['created_at']))),
                                  DataCell(Text('${r['movement_type_code']}')),
                                  DataCell(Text(whName)),
                                  DataCell(Text('${r['supplier_name'] ?? '—'}')),
                                  DataCell(Text('${r['item_count']}')),
                                  DataCell(Text(NumberFormat.decimalPattern('sk_SK').format((r['sum_without_vat'] as num?) ?? 0))),
                                  DataCell(Text(NumberFormat.decimalPattern('sk_SK').format((r['vat'] as num?) ?? 0))),
                                  DataCell(Text(NumberFormat.decimalPattern('sk_SK').format((r['sum_with_vat'] as num?) ?? 0))),
                                  DataCell(Text('${r['status']}')),
                                  DataCell(Text('${r['approver_username'] ?? '—'}')),
                                  DataCell(Text(_fmtDate(r['approved_at']))),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
          ),
          if (!_loading && _rows.isNotEmpty) _buildSummaryBar(),
        ],
      ),
    );
  }

  String _fmtDate(dynamic v) {
    if (v == null) return '—';
    if (v is String) {
      try {
        final dt = DateTime.parse(v);
        return DateFormat('d.M.y').format(dt);
      } catch (_) {}
      return v;
    }
    return '—';
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
                      final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now());
                      if (d != null && mounted) setState(() { _dateFrom = d; _runReport(); });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(_dateTo == null ? 'Do' : DateFormat('d.M.y').format(_dateTo!)),
                    onPressed: () async {
                      final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now());
                      if (d != null && mounted) setState(() { _dateTo = d; _runReport(); });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              value: _statusFilter,
              decoration: const InputDecoration(labelText: 'Status', isDense: true),
              items: const [
                DropdownMenuItem(value: null, child: Text('Všetky')),
                DropdownMenuItem(value: 'rozpracovany', child: Text('Rozpracovaný')),
                DropdownMenuItem(value: 'vykazana', child: Text('Vykázaná')),
                DropdownMenuItem(value: 'pending', child: Text('Čaká na schválenie')),
                DropdownMenuItem(value: 'schvalena', child: Text('Schválená')),
                DropdownMenuItem(value: 'rejected', child: Text('Zamietnutá')),
                DropdownMenuItem(value: 'reversed', child: Text('Stornovaná')),
              ],
              onChanged: (v) => setState(() { _statusFilter = v; _runReport(); }),
            ),
            DropdownButtonFormField<int?>(
              value: _warehouseId,
              decoration: const InputDecoration(labelText: 'Sklad', isDense: true),
              items: [
                const DropdownMenuItem(value: null, child: Text('Všetky')),
                ..._warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))),
              ],
              onChanged: (v) => setState(() { _warehouseId = v; _runReport(); }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryBar() {
    final totalCount = _summary['totalCount'] as int? ?? 0;
    final totalWithoutVat = (_summary['totalWithoutVat'] as num?)?.toDouble() ?? 0;
    final totalVat = (_summary['totalVat'] as num?)?.toDouble() ?? 0;
    final totalWithVat = (_summary['totalWithVat'] as num?)?.toDouble() ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.grey[200],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Text('Počet: $totalCount', style: const TextStyle(fontWeight: FontWeight.w600)),
          Text('Spolu bez DPH: ${NumberFormat.decimalPattern('sk_SK').format(totalWithoutVat)} €'),
          Text('DPH: ${NumberFormat.decimalPattern('sk_SK').format(totalVat)} €'),
          Text('Spolu s DPH: ${NumberFormat.decimalPattern('sk_SK').format(totalWithVat)} €'),
        ],
      ),
    );
  }
}
