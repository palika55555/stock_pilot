import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../services/Reports/receipt_report_service.dart';

/// Report – obstarávacie náklady pri príjemkách (doprava, clo, …).
class AcquisitionCostsReportScreen extends StatefulWidget {
  const AcquisitionCostsReportScreen({super.key});

  @override
  State<AcquisitionCostsReportScreen> createState() => _AcquisitionCostsReportScreenState();
}

class _AcquisitionCostsReportScreenState extends State<AcquisitionCostsReportScreen> {
  final ReceiptReportService _reportService = ReceiptReportService();
  List<Map<String, dynamic>> _rows = [];
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
    final list = await _reportService.getAcquisitionCostsReport(dateFrom: _dateFrom, dateTo: _dateTo);
    if (mounted) {
      setState(() {
        _rows = list;
        _loading = false;
      });
    }
  }

  String _fmt(dynamic v) {
    if (v == null) return '—';
    if (v is String) {
      try {
        return DateFormat('d.M.y').format(DateTime.parse(v));
      } catch (_) {
        return v;
      }
    }
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Obstarávacie náklady'),
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
                  const Text('Obdobie príjemky', style: TextStyle(fontWeight: FontWeight.bold)),
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
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Žiadne záznamy obstarávacích nákladov (alebo tabuľka ešte nie je v databáze).',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Dátum')),
                              DataColumn(label: Text('Príjemka')),
                              DataColumn(label: Text('Typ nákladu')),
                              DataColumn(label: Text('Popis')),
                              DataColumn(label: Text('Bez DPH')),
                              DataColumn(label: Text('DPH %')),
                              DataColumn(label: Text('S DPH')),
                              DataColumn(label: Text('Dodávateľ nákladu')),
                            ],
                            rows: _rows.map((r) {
                              final w = (r['amount_without_vat'] as num?)?.toDouble() ?? 0;
                              final v = (r['amount_with_vat'] as num?)?.toDouble() ?? 0;
                              return DataRow(
                                cells: [
                                  DataCell(Text(_fmt(r['created_at']))),
                                  DataCell(Text('${r['receipt_number']}')),
                                  DataCell(Text('${r['cost_type']}')),
                                  DataCell(Text('${r['description'] ?? '—'}')),
                                  DataCell(Text(NumberFormat.decimalPattern('sk_SK').format(w))),
                                  DataCell(Text('${r['vat_percent'] ?? '—'}')),
                                  DataCell(Text(NumberFormat.decimalPattern('sk_SK').format(v))),
                                  DataCell(Text('${r['cost_supplier_name'] ?? '—'}')),
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
}
