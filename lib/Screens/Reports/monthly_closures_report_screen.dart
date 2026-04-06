import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../models/monthly_closure.dart';
import '../../services/Reports/monthly_closures_report_service.dart';
import '../../theme/app_theme.dart';

/// Report – zoznam mesačných uzávierok, PDF tlač a zdieľanie.
class MonthlyClosuresReportScreen extends StatefulWidget {
  const MonthlyClosuresReportScreen({super.key});

  @override
  State<MonthlyClosuresReportScreen> createState() =>
      _MonthlyClosuresReportScreenState();
}

class _MonthlyClosuresReportScreenState
    extends State<MonthlyClosuresReportScreen> {
  final MonthlyClosuresReportService _service = MonthlyClosuresReportService();
  List<MonthlyClosure> _closures = [];
  bool _loading = true;
  bool _pdfBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _service.loadClosures();
      if (mounted) setState(() => _closures = list);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _runPrint() async {
    if (_pdfBusy) return;
    setState(() => _pdfBusy = true);
    try {
      final company = await _service.loadCompany();
      final bytes = await _service.buildPdf(_closures, company: company);
      if (!mounted) return;
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba pri tlači PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _pdfBusy = false);
    }
  }

  Future<void> _runShare() async {
    if (_pdfBusy) return;
    setState(() => _pdfBusy = true);
    try {
      final company = await _service.loadCompany();
      final bytes = await _service.buildPdf(_closures, company: company);
      await _service.sharePdf(bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba pri PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _pdfBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Mesačné uzávierky – report'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: _pdfBusy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.print_outlined),
            tooltip: 'Tlač / náhľad PDF',
            onPressed: _pdfBusy ? null : _runPrint,
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Zdieľať PDF',
            onPressed: _pdfBusy ? null : _runShare,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Obnoviť',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _closures.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 120),
                        Center(
                          child: Text(
                            'Žiadny uzavretý mesiac',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(
                          'Údaje sú rovnaké ako v PDF. Použite tlač alebo zdieľanie v hornom paneli.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStatePropertyAll(
                              AppColors.bgElevated,
                            ),
                            columns: const [
                              DataColumn(label: Text('Obdobie')),
                              DataColumn(label: Text('Uzavreté')),
                              DataColumn(label: Text('Kto')),
                              DataColumn(label: Text('Poznámka')),
                            ],
                            rows: _closures.map((c) {
                              return DataRow(
                                cells: [
                                  DataCell(Text(c.yearMonth)),
                                  DataCell(Text(
                                    DateFormat('dd.MM.yyyy HH:mm')
                                        .format(c.closedAt.toLocal()),
                                  )),
                                  DataCell(Text(c.closedBy ?? '–')),
                                  DataCell(Text(
                                    (c.notes ?? '').trim().isEmpty
                                        ? '–'
                                        : c.notes!,
                                  )),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
            ),
    );
  }
}
