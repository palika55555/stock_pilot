import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../services/Reports/receipt_report_service.dart';

/// Report – metriky schvaľovania príjemiek (len zmysluplné pre administrátora).
class ApprovalPerformanceReportScreen extends StatefulWidget {
  const ApprovalPerformanceReportScreen({super.key});

  @override
  State<ApprovalPerformanceReportScreen> createState() => _ApprovalPerformanceReportScreenState();
}

class _ApprovalPerformanceReportScreenState extends State<ApprovalPerformanceReportScreen> {
  final ReceiptReportService _reportService = ReceiptReportService();
  bool _loading = true;
  String? _role;
  int _approved = 0;
  int _rejected = 0;
  double? _avgHours;
  int _withTimes = 0;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _role = prefs.getString('current_user_role'));
    await _run();
  }

  Future<void> _run() async {
    setState(() => _loading = true);
    final m = await _reportService.getApprovalPerformanceReport(dateFrom: _dateFrom, dateTo: _dateTo);
    if (mounted) {
      setState(() {
        _approved = (m['approvedCount'] as num?)?.toInt() ?? 0;
        _rejected = (m['rejectedCount'] as num?)?.toInt() ?? 0;
        _avgHours = (m['avgHoursApproval'] as num?)?.toDouble();
        _withTimes = (m['submittedWithApprovalData'] as num?)?.toInt() ?? 0;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _role == 'admin';

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Výkon schvaľovania'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loading || !isAdmin ? null : _run),
        ],
      ),
      body: !isAdmin
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Tento report je určený pre administrátora (prehľad časov schvaľovania a zamietnutí).',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                ),
              ),
            )
          : Column(
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
                      : ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            _tile('Schválené príjemky', '$_approved', Icons.check_circle_outline),
                            _tile('Zamietnuté', '$_rejected', Icons.cancel_outlined),
                            _tile(
                              'Priemerný čas schválenia',
                              _avgHours != null
                                  ? '${NumberFormat.decimalPattern('sk_SK').format(_avgHours!)} h'
                                  : '— (chýba submitted_at / approved_at)',
                              Icons.schedule,
                            ),
                            _tile(
                              'Príjemky s vyplneným časom schválenia',
                              '$_withTimes',
                              Icons.event_available_outlined,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Podiel zamietnutí: ${_approved + _rejected == 0 ? '—' : '${((_rejected / (_approved + _rejected)) * 100).toStringAsFixed(1)} %'}',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                ),
              ],
            ),
    );
  }

  Widget _tile(String title, String value, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.accentGoldSubtle,
          child: Icon(icon, color: AppColors.accentGold),
        ),
        title: Text(title, style: TextStyle(color: AppColors.textPrimary)),
        subtitle: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
