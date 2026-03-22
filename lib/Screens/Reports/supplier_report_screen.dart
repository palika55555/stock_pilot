import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../services/Reports/receipt_report_service.dart';

/// Report – súhrn podľa dodávateľov (príjemky).
class SupplierReportScreen extends StatefulWidget {
  const SupplierReportScreen({super.key});

  @override
  State<SupplierReportScreen> createState() => _SupplierReportScreenState();
}

class _SupplierReportScreenState extends State<SupplierReportScreen> {
  final ReceiptReportService _reportService = ReceiptReportService();
  List<Map<String, dynamic>> _rows = [];
  double _grand = 0;
  bool _loading = true;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() => _loading = true);
    final result = await _reportService.getSupplierSummaryReport(dateFrom: _dateFrom, dateTo: _dateTo);
    if (mounted) {
      setState(() {
        _rows = (result['rows'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
        _grand = (result['grandTotalNet'] as num?)?.toDouble() ?? 0;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Dodávatelia'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loading ? null : _run),
        ],
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Obdobie', style: TextStyle(fontWeight: FontWeight.bold)),
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
                            _run();
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
                            _run();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _rows.isEmpty
                    ? Center(child: Text('Žiadne dáta', style: TextStyle(color: Colors.grey[600])))
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Dodávateľ')),
                              DataColumn(label: Text('Počet príjemiek')),
                              DataColumn(label: Text('Suma riadkov (bez DPH)')),
                            ],
                            rows: _rows.map((r) {
                              final net = (r['sum_net'] as num?)?.toDouble() ?? 0;
                              return DataRow(
                                cells: [
                                  DataCell(Text('${r['supplier_label']}')),
                                  DataCell(Text('${r['receipt_count']}')),
                                  DataCell(Text(NumberFormat.decimalPattern('sk_SK').format(net))),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
          ),
          if (!_loading && _rows.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[200],
              width: double.infinity,
              child: Text(
                'Spolu (bez DPH): ${NumberFormat.decimalPattern('sk_SK').format(_grand)} €',
                style: const TextStyle(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}
