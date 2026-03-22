import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../services/Reports/receipt_report_service.dart';

/// Report – jednotkové ceny z položiek príjemiek v čase.
class PriceHistoryReportScreen extends StatefulWidget {
  const PriceHistoryReportScreen({super.key});

  @override
  State<PriceHistoryReportScreen> createState() => _PriceHistoryReportScreenState();
}

class _PriceHistoryReportScreenState extends State<PriceHistoryReportScreen> {
  final ReceiptReportService _reportService = ReceiptReportService();
  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() => _loading = true);
    final list = await _reportService.getPriceHistoryReport(
      dateFrom: _dateFrom,
      dateTo: _dateTo,
      productSearch: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
    );
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
        title: const Text('Vývoj cien (nákup)'),
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  const SizedBox(height: 8),
                  TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Hľadať produkt / PLU',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _run(),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(onPressed: _loading ? null : _run, child: const Text('Hľadať')),
                ],
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _rows.isEmpty
                    ? Center(child: Text('Žiadne položky', style: TextStyle(color: Colors.grey[600])))
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Dátum')),
                              DataColumn(label: Text('Príjemka')),
                              DataColumn(label: Text('Produkt')),
                              DataColumn(label: Text('PLU')),
                              DataColumn(label: Text('Množstvo')),
                              DataColumn(label: Text('Jedn. cena')),
                            ],
                            rows: _rows.map((r) {
                              final price = (r['unit_price'] as num?)?.toDouble() ?? 0;
                              final qty = r['qty'];
                              final qtyStr = qty is num ? qty.toString() : '$qty';
                              return DataRow(
                                cells: [
                                  DataCell(Text(_fmt(r['created_at']))),
                                  DataCell(Text('${r['receipt_number']}')),
                                  DataCell(Text('${r['product_name'] ?? r['product_unique_id']}')),
                                  DataCell(Text('${r['plu'] ?? '—'}')),
                                  DataCell(Text('$qtyStr ${r['unit']}')),
                                  DataCell(Text(NumberFormat.decimalPattern('sk_SK').format(price))),
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
