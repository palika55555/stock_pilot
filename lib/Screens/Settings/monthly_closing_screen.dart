import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../models/monthly_closure.dart';
import '../../models/monthly_closure_validation.dart';
import '../../services/monthly_closure_service.dart';
import '../../services/user_session.dart';
import '../../theme/app_theme.dart';

/// Správa uzavretých kalendárnych mesiacov (mesačné uzávierky).
class MonthlyClosingScreen extends StatefulWidget {
  final String userRole;

  const MonthlyClosingScreen({super.key, required this.userRole});

  @override
  State<MonthlyClosingScreen> createState() => _MonthlyClosingScreenState();
}

class _MonthClosePick {
  final String yearMonth;
  final String note;

  _MonthClosePick(this.yearMonth, this.note);
}

class _MonthlyClosingScreenState extends State<MonthlyClosingScreen> {
  final MonthlyClosureService _service = MonthlyClosureService();
  List<MonthlyClosure> _closures = [];
  bool _loading = true;

  bool get _isAdmin => widget.userRole == 'admin';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _service.listClosures();
      if (mounted) setState(() => _closures = list);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatMonthLabel(String yearMonth, String locale) {
    final parts = yearMonth.split('-');
    if (parts.length != 2) return yearMonth;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (y == null || m == null) return yearMonth;
    try {
      return DateFormat.yMMMM(locale).format(DateTime(y, m));
    } catch (_) {
      return yearMonth;
    }
  }

  Future<void> _showCloseDialog(AppLocalizations l10n, String locale) async {
    final closed = _closures.map((c) => c.yearMonth).toSet();
    final choices = <String>[];
    final now = DateTime.now();
    for (var i = 0; i < 72; i++) {
      final d = DateTime(now.year, now.month - i, 1);
      final ym = formatYearMonth(d);
      if (!closed.contains(ym)) choices.add(ym);
    }
    if (choices.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.monthlyClosingsAlreadyClosed)),
      );
      return;
    }

    String selected = choices.first;
    final noteController = TextEditingController();

    final pick = await showDialog<_MonthClosePick>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(l10n.monthlyClosingsCloseMonth),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l10n.monthlyClosingsPickMonth),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: selected,
                      items: choices
                          .map(
                            (ym) => DropdownMenuItem(
                              value: ym,
                              child: Text(_formatMonthLabel(ym, locale)),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setDialogState(() => selected = v);
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: noteController,
                      decoration: InputDecoration(
                        labelText: l10n.monthlyClosingsNoteOptional,
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(
                    ctx,
                    _MonthClosePick(selected, noteController.text.trim()),
                  ),
                  child: Text(l10n.monthlyClosingsCloseMonth),
                ),
              ],
            );
          },
        );
      },
    );

    noteController.dispose();

    if (pick == null || !mounted) return;

    MonthlyClosureValidationResult validation;
    try {
      validation = await _service.validateBeforeClose(pick.yearMonth);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kontrola zlyhala: $e')),
        );
      }
      return;
    }

    if (!validation.canClose) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Uzavretie nie je možné'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Pred uzavretím mesiaca doplňte alebo dokončite tieto položky:',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                ...validation.blocking.map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• '),
                        Expanded(child: Text(line)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Rozumiem'),
            ),
          ],
        ),
      );
      return;
    }

    if (validation.hasWarnings) {
      if (!mounted) return;
      final force = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Varovania'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Mesiac je možné uzavrieť, ale odporúčame najprv skontrolovať:',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                ...validation.warnings.map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• '),
                        Expanded(child: Text(line)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Uzavrieť aj tak'),
            ),
          ],
        ),
      );
      if (force != true || !mounted) return;
    }

    try {
      await _service.closeMonth(
        yearMonth: pick.yearMonth,
        closedBy: UserSession.username,
        notes: pick.note.isEmpty ? null : pick.note,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
      return;
    }

    if (!mounted) return;
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.monthlyClosingsClosedSuccess)),
    );
  }


  Future<void> _confirmReopen(AppLocalizations l10n, String locale, MonthlyClosure c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.monthlyClosingsReopenMonth),
        content: Text(
          l10n.monthlyClosingsConfirmReopen(_formatMonthLabel(c.yearMonth, locale)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.monthlyClosingsReopenMonth),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _service.reopenMonth(c.yearMonth);
    if (!mounted) return;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toLanguageTag();

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: Text(l10n.monthlyClosingsTitle),
      ),
      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showCloseDialog(l10n, locale),
              icon: const Icon(Icons.lock_clock_rounded),
              label: Text(l10n.monthlyClosingsCloseMonth),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    color: AppColors.bgCard,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        l10n.monthlyClosingsIntro,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                  if (!_isAdmin) ...[
                    const SizedBox(height: 12),
                    Text(
                      l10n.monthlyClosingsAdminOnly,
                      style: TextStyle(color: AppColors.warning, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (_closures.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 32),
                      child: Center(
                        child: Text(
                          l10n.monthlyClosingsEmpty,
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      ),
                    )
                  else
                    ..._closures.map((c) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        color: AppColors.bgCard,
                        child: ListTile(
                          title: Text(
                            _formatMonthLabel(c.yearMonth, locale),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            '${l10n.monthlyClosingsClosedAt}: ${c.closedAt.toLocal()}'
                            '${c.closedBy != null && c.closedBy!.isNotEmpty ? '\n${l10n.monthlyClosingsBy}: ${c.closedBy}' : ''}'
                            '${c.notes != null && c.notes!.isNotEmpty ? '\n${c.notes}' : ''}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          trailing: _isAdmin
                              ? IconButton(
                                  icon: const Icon(Icons.lock_open_rounded),
                                  color: AppColors.accentGold,
                                  tooltip: l10n.monthlyClosingsReopenMonth,
                                  onPressed: () => _confirmReopen(l10n, locale, c),
                                )
                              : null,
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
