import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/stock_out.dart';
import '../../models/warehouse.dart';
import '../../services/StockOut/stock_out_pdf_service.dart';
import '../../services/StockOut/stock_out_service.dart';
import '../../services/Warehouse/warehouse_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/Common/grid_background.dart';
import '../../widgets/Receipts/stock_out_list_widget.dart';
import '../../widgets/Receipts/stock_out_modal_widget.dart';

class StockOutScreen extends StatefulWidget {
  /// 'admin' = môže upravovať aj schválené výdajky, 'user' = len neschválené
  final String userRole;

  const StockOutScreen({super.key, this.userRole = 'user'});

  @override
  State<StockOutScreen> createState() => _StockOutScreenState();
}

class _StockOutScreenState extends State<StockOutScreen> {
  final StockOutService _stockOutService = StockOutService();
  final WarehouseService _warehouseService = WarehouseService();
  List<StockOut> _stockOuts = [];
  List<Warehouse> _warehouses = [];
  int? _selectedWarehouseId; // null = všetky sklady
  bool _isLoading = true;
  StockOutIssueType? _issueTypeFilter; // null = všetky typy
  DateTime _selectedDate = DateTime.now();

  /// Minimized draft (for the restore bar)
  StockOutModalDraft? _minimizedDraft;

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  void initState() {
    super.initState();
    _loadWarehouses();
    _loadStockOuts();
  }

  Future<void> _loadWarehouses() async {
    final list = await _warehouseService.getAllWarehouses();
    if (mounted) setState(() => _warehouses = list);
  }

  List<StockOut> get _filteredStockOuts {
    var list =
        _stockOuts.where((s) => _isSameDay(s.createdAt, _selectedDate)).toList();
    if (_issueTypeFilter != null) {
      list = list.where((s) => s.issueType == _issueTypeFilter).toList();
    }
    return list;
  }

  /// Dni (bez času), v ktorých existuje aspoň jedna výdajka – na zvýraznenie v kalendári.
  Set<DateTime> get _datesWithStockOuts {
    return _stockOuts
        .map((s) =>
            DateTime(s.createdAt.year, s.createdAt.month, s.createdAt.day))
        .toSet();
  }

  Future<void> _pickDate() async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (context) => _StockOutCalendarDialog(
        initialDate: _selectedDate,
        datesWithStockOuts: _datesWithStockOuts,
      ),
    );
    if (picked != null && mounted) setState(() => _selectedDate = picked);
  }

  Future<void> _loadStockOuts() async {
    setState(() => _isLoading = true);
    final list =
        await _stockOutService.getStockOutsByWarehouseId(_selectedWarehouseId);
    if (mounted) {
      setState(() {
        _stockOuts = list;
        _isLoading = false;
      });
    }
  }

  /// Filtre Sklad + Druh pohybu v spodnej časti AppBar.
  Widget _buildAppBarFilters() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom:
              BorderSide(color: Colors.black.withOpacity(0.06), width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.warehouse_rounded, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<int?>(
              value: _selectedWarehouseId,
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                filled: true,
                fillColor: Colors.grey.withOpacity(0.08),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      BorderSide(color: Colors.grey.withOpacity(0.25)),
                ),
              ),
              items: [
                const DropdownMenuItem<int?>(
                    value: null, child: Text('Všetky sklady')),
                ..._warehouses.map(
                  (w) => DropdownMenuItem<int?>(
                      value: w.id, child: Text(w.name)),
                ),
              ],
              onChanged: (id) {
                setState(() {
                  _selectedWarehouseId = id;
                  _loadStockOuts();
                });
              },
            ),
          ),
          const SizedBox(width: 12),
          Icon(Icons.category_rounded, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<StockOutIssueType?>(
              value: _issueTypeFilter,
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                filled: true,
                fillColor: Colors.grey.withOpacity(0.08),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      BorderSide(color: Colors.grey.withOpacity(0.25)),
                ),
              ),
              items: [
                const DropdownMenuItem<StockOutIssueType?>(
                    value: null, child: Text('Všetky')),
                ...StockOutIssueType.values.map(
                  (t) => DropdownMenuItem<StockOutIssueType?>(
                    value: t,
                    child: Text(t.label),
                  ),
                ),
              ],
              onChanged: (t) => setState(() => _issueTypeFilter = t),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Date bar
  // -------------------------------------------------------------------------

  Widget _buildDateBar() {
    final now = DateTime.now();
    final isToday = _isSameDay(_selectedDate, now);
    final isYesterday =
        _isSameDay(_selectedDate, now.subtract(const Duration(days: 1)));
    final isTomorrow =
        _isSameDay(_selectedDate, now.add(const Duration(days: 1)));
    String dateStr;
    if (isToday) {
      dateStr = 'Dnes';
    } else if (isYesterday) {
      dateStr = 'Včera';
    } else if (isTomorrow) {
      dateStr = 'Zajtra';
    } else {
      dateStr =
          '${_selectedDate.day}. ${_selectedDate.month}. ${_selectedDate.year}';
    }
    final count = _filteredStockOuts.length;
    return Container(
      color: AppColors.bgCard,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          _dateNavBtn(
            Icons.chevron_left_rounded,
            () => setState(() =>
                _selectedDate =
                    _selectedDate.subtract(const Duration(days: 1))),
          ),
          Expanded(
            child: InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_today_rounded,
                        size: 16,
                        color: isToday
                            ? AppColors.danger
                            : AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isToday
                            ? AppColors.danger
                            : AppColors.textPrimary,
                      ),
                    ),
                    if (count > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.dangerSubtle,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.danger),
                        ),
                      ),
                    ],
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down_rounded,
                        size: 20, color: AppColors.textMuted),
                  ],
                ),
              ),
            ),
          ),
          if (!isToday)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: TextButton(
                onPressed: () =>
                    setState(() => _selectedDate = DateTime.now()),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Dnes',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ),
          _dateNavBtn(
            Icons.chevron_right_rounded,
            () => setState(() =>
                _selectedDate =
                    _selectedDate.add(const Duration(days: 1))),
          ),
        ],
      ),
    );
  }

  Widget _dateNavBtn(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 22, color: AppColors.textSecondary),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Modals
  // -------------------------------------------------------------------------

  void _openNewModal() {
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StockOutModal(
        initialDraft:
            _minimizedDraft?.stockOutId == null ? _minimizedDraft : null,
        onMinimize: (draft) {
          if (mounted) setState(() => _minimizedDraft = draft);
        },
      ),
    ).then((saved) {
      if (saved == true) {
        _minimizedDraft = null;
        _loadStockOuts();
      }
    });
  }

  void _openEditModal(StockOut stockOut) {
    if (stockOut.id == null || stockOut.isStorned) return;
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StockOutModal(
        stockOutId: stockOut.id,
        onMinimize: (draft) {
          if (mounted) setState(() => _minimizedDraft = draft);
        },
      ),
    ).then((saved) {
      if (saved == true) {
        _minimizedDraft = null;
        _loadStockOuts();
      }
    });
  }

  // -------------------------------------------------------------------------
  // Minimized bar
  // -------------------------------------------------------------------------

  Widget _buildMinimizedBar() {
    if (_minimizedDraft == null) return const SizedBox.shrink();
    final docNum = _minimizedDraft!.documentNumber.isNotEmpty
        ? _minimizedDraft!.documentNumber
        : 'Nová výdajka';
    return Material(
      borderRadius: BorderRadius.circular(14),
      elevation: 8,
      color: AppColors.bgCard,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _openNewModal,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: AppColors.accentGold.withOpacity(0.4)),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.accentGoldSubtle,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit_document,
                    size: 18, color: AppColors.accentGold),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(docNum,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    const Text(
                        'Rozpracovaná výdajka – kliknite pre pokračovanie',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary)),
                  ],
                ),
              ),
              IconButton(
                onPressed: () =>
                    setState(() => _minimizedDraft = null),
                icon: const Icon(Icons.close_rounded, size: 18),
                style: IconButton.styleFrom(
                  foregroundColor: AppColors.textMuted,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(28, 28),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Stock out actions
  // -------------------------------------------------------------------------

  Future<void> _approveStockOut(StockOut stockOut) async {
    if (stockOut.id == null || stockOut.isApproved) return;
    await _stockOutService.approveStockOut(stockOut.id!);
    if (mounted) {
      _loadStockOuts();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Výdajka bola schválená'),
          backgroundColor: Colors.teal,
        ),
      );
    }
  }

  Future<void> _stornoStockOut(StockOut stockOut) async {
    if (stockOut.id == null || stockOut.isStorned) return;
    final id = stockOut.id!;
    final docNumber = stockOut.documentNumber;
    final verified = await _showStornoVerificationDialog(
      documentNumber: docNumber,
      isApproved: stockOut.isApproved,
    );
    if (verified == null || !mounted) return;
    if (stockOut.isApproved) {
      await _stockOutService.stornoStockOut(id, returnToStock: verified);
    } else {
      await _stockOutService.stornoStockOut(id, returnToStock: false);
    }
    if (mounted) {
      _loadStockOuts();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Výdajka bola stornovaná')),
      );
    }
  }

  /// Vráti null = zrušené, false = storno bez vrátenia zásob, true = storno s vrátením zásob.
  Future<bool?> _showStornoVerificationDialog({
    required String documentNumber,
    required bool isApproved,
  }) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _StornoVerifyDialog(
        documentNumber: documentNumber,
        isApproved: isApproved,
      ),
    );
  }

  Future<void> _exportStockOutPdf(StockOut stockOut) async {
    if (stockOut.id == null) return;
    final choice = await showDialog<({String title, bool hidePrices})>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Tlač výdajky'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(
                ctx, (title: 'VÝDAJKA TOVARU', hidePrices: false)),
            child: const Text('Výdajka (s cenami)'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(
                ctx, (title: 'DODACÍ LIST', hidePrices: false)),
            child: const Text('Dodací list (s cenami)'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(
                ctx, (title: 'DODACÍ LIST', hidePrices: true)),
            child: const Text('Dodací list bez cien (pre kuriéra)'),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    final items = await _stockOutService.getStockOutItems(stockOut.id!);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pripravujem PDF...')),
      );
    }
    try {
      String? issuedBy;
      try {
        final prefs = await SharedPreferences.getInstance();
        issuedBy = prefs.getString('current_user_fullname') ??
            prefs.getString('current_user_username');
      } catch (_) {}
      final pdfBytes = await StockOutPdfService.buildPdf(
        stockOut: stockOut,
        items: items,
        issuedBy: issuedBy,
        documentTitle: choice.title,
        hidePrices: choice.hidePrices,
      );
      final filename =
          'vydajka_${stockOut.documentNumber.replaceAll(RegExp(r'[^\w\-.]'), '_')}.pdf';
      try {
        await Printing.sharePdf(bytes: pdfBytes, filename: filename);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF pripravené na uloženie / zdieľanie'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } on MissingPluginException {
        await _saveAndOpenPdf(pdfBytes, filename);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba pri generovaní PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveAndOpenPdf(Uint8List pdfBytes, String filename) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(pdfBytes);
      if (Platform.isWindows) {
        await Process.run('start', ['', file.path], runInShell: true);
      } else if (Platform.isMacOS) {
        await Process.run('open', [file.path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [file.path]);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF uložené: ${file.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba pri ukladaní PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  static const double _appBarHeight = 70;
  static const double _appBarFilterHeight = 56;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF080C0F),
      appBar: PreferredSize(
        preferredSize:
            const Size.fromHeight(_appBarHeight + _appBarFilterHeight),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: false,
              leading: IconButton(
                icon: Icon(Icons.arrow_back,
                    color: AppColors.textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'Výdaj tovaru',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                ),
              ),
              bottom: PreferredSize(
                preferredSize:
                    const Size.fromHeight(_appBarFilterHeight),
                child: _buildAppBarFilters(),
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: StockOutBackground()),
          Padding(
            padding: const EdgeInsets.only(
                top: _appBarHeight + _appBarFilterHeight),
            child: Stack(
              children: [
                Column(
                  children: [
                    _buildDateBar(),
                    Expanded(
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                  color: Color(0xFFEF4444)))
                          : StockOutList(
                              stockOuts: _filteredStockOuts,
                              canEditApproved:
                                  widget.userRole == 'admin',
                              onAddTap: _openNewModal,
                              onApprove: _approveStockOut,
                              onEdit: _openEditModal,
                              onStorno: _stornoStockOut,
                              onExportPdf: _exportStockOutPdf,
                            ),
                    ),
                  ],
                ),
                if (_minimizedDraft != null)
                  Positioned(
                    bottom: 80,
                    left: 16,
                    right: 16,
                    child: _buildMinimizedBar(),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewModal,
        backgroundColor: const Color(0xFFDC2626),
        elevation: 10,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18)),
        label: Text(
          _minimizedDraft != null ? 'Pokračovať' : 'Nová výdajka',
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: Colors.white),
        ),
        icon: Icon(
            _minimizedDraft != null
                ? Icons.edit_rounded
                : Icons.add,
            color: Colors.white),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Storno verify dialog
// ---------------------------------------------------------------------------

class _StornoVerifyDialog extends StatefulWidget {
  final String documentNumber;
  final bool isApproved;

  const _StornoVerifyDialog({
    required this.documentNumber,
    required this.isApproved,
  });

  @override
  State<_StornoVerifyDialog> createState() =>
      _StornoVerifyDialogState();
}

class _StornoVerifyDialogState extends State<_StornoVerifyDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final match = _controller.text.trim().toUpperCase() ==
        widget.documentNumber.toUpperCase();
    return AlertDialog(
      title: Text(widget.isApproved
          ? 'Stornovať výdajku'
          : 'Zrušiť výdajku'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.isApproved)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Výdajka bola schválená (zásoby boli odpočítané). '
                  'Chcete vrátiť zásoby späť na sklad?',
                  style: TextStyle(fontSize: 14),
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Naozaj chcete zrušiť túto výdajku?',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            const Text(
              'Pre potvrdenie zadajte číslo výdajky:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.documentNumber,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Zadajte ${widget.documentNumber}',
                border: const OutlineInputBorder(),
                errorText:
                    _controller.text.isNotEmpty && !match
                        ? 'Nesedí s číslom výdajky'
                        : null,
              ),
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) {
                if (match && widget.isApproved) {
                  Navigator.pop(context, true);
                } else if (match && !widget.isApproved) {
                  Navigator.pop(context, false);
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Zrušiť'),
        ),
        if (widget.isApproved)
          FilledButton(
            onPressed:
                match ? () => Navigator.pop(context, true) : null,
            child: const Text('Áno, vrátiť na sklad'),
          ),
        FilledButton(
          onPressed:
              match ? () => Navigator.pop(context, false) : null,
          style: FilledButton.styleFrom(
            backgroundColor:
                widget.isApproved ? null : Colors.red,
          ),
          child: Text(
            widget.isApproved
                ? 'Stornovať bez vrátenia'
                : 'Áno, zrušiť',
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Calendar dialog – dark themed
// ---------------------------------------------------------------------------

/// Kalendár na výber dňa so zvýraznením dní, v ktorých bola výdajka (zelená).
class _StockOutCalendarDialog extends StatefulWidget {
  final DateTime initialDate;
  final Set<DateTime> datesWithStockOuts;

  const _StockOutCalendarDialog({
    required this.initialDate,
    required this.datesWithStockOuts,
  });

  @override
  State<_StockOutCalendarDialog> createState() =>
      _StockOutCalendarDialogState();
}

class _StockOutCalendarDialogState
    extends State<_StockOutCalendarDialog> {
  static const _weekdays = ['Po', 'Ut', 'St', 'Št', 'Pi', 'So', 'Ne'];

  late DateTime _viewMonth;

  @override
  void initState() {
    super.initState();
    _viewMonth =
        DateTime(widget.initialDate.year, widget.initialDate.month);
  }

  bool _hasStockOut(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return widget.datesWithStockOuts.any((x) =>
        x.year == d.year && x.month == d.month && x.day == d.day);
  }

  List<DateTime?> _daysInMonth() {
    final year = _viewMonth.year;
    final month = _viewMonth.month;
    final first = DateTime(year, month, 1);
    final weekday = first.weekday - 1;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final list = <DateTime?>[];
    for (int i = 0; i < weekday; i++) list.add(null);
    for (int d = 1; d <= daysInMonth; d++) {
      list.add(DateTime(year, month, d));
    }
    while (list.length % 7 != 0) list.add(null);
    return list;
  }

  String _monthName(int month) {
    const names = [
      'Január', 'Február', 'Marec', 'Apríl', 'Máj', 'Jún',
      'Júl', 'August', 'September', 'Október', 'November', 'December',
    ];
    return names[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = _daysInMonth();
    return Dialog(
      backgroundColor: AppColors.bgElevated,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: AppColors.bgCard,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_monthName(_viewMonth.month)} ${_viewMonth.year}',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded,
                        color: AppColors.textSecondary),
                    onPressed: () => setState(() {
                      _viewMonth = DateTime(
                          _viewMonth.year, _viewMonth.month - 1);
                    }),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                        minWidth: 36, minHeight: 36),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textSecondary),
                    onPressed: () => setState(() {
                      _viewMonth = DateTime(
                          _viewMonth.year, _viewMonth.month + 1);
                    }),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                        minWidth: 36, minHeight: 36),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.borderDefault),
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  // Weekday headers
                  Row(
                    children: _weekdays
                        .map((w) => Expanded(
                              child: Text(w,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textMuted)),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  // Days grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics:
                        const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      childAspectRatio: 1,
                      mainAxisSpacing: 2,
                      crossAxisSpacing: 2,
                    ),
                    itemCount: days.length,
                    itemBuilder: (context, index) {
                      final day = days[index];
                      if (day == null) return const SizedBox();
                      final isSelected =
                          day.year == widget.initialDate.year &&
                              day.month ==
                                  widget.initialDate.month &&
                              day.day == widget.initialDate.day;
                      final isToday =
                          day.year == today.year &&
                              day.month == today.month &&
                              day.day == today.day;
                      final hasStockOut = _hasStockOut(day);
                      return InkWell(
                        onTap: () =>
                            Navigator.pop(context, day),
                        borderRadius:
                            BorderRadius.circular(8),
                        child: AnimatedContainer(
                          duration:
                              const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.danger
                                : (hasStockOut
                                    ? AppColors.success
                                        .withOpacity(0.15)
                                    : (isToday
                                        ? AppColors.bgInput
                                        : null)),
                            borderRadius:
                                BorderRadius.circular(8),
                            border: isToday && !isSelected
                                ? Border.all(
                                    color: AppColors.danger
                                        .withOpacity(0.5),
                                    width: 1)
                                : (hasStockOut && !isSelected
                                    ? Border.all(
                                        color: AppColors.success
                                            .withOpacity(0.3),
                                        width: 1)
                                    : null),
                          ),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Text(
                                '${day.day}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isToday || isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : (hasStockOut
                                          ? AppColors.success
                                          : AppColors
                                              .textPrimary),
                                ),
                              ),
                              if (hasStockOut && !isSelected)
                                Container(
                                  width: 4,
                                  height: 4,
                                  margin: const EdgeInsets.only(
                                      top: 2),
                                  decoration: const BoxDecoration(
                                    color: AppColors.success,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.borderDefault),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  const Text('Deň s výdajkou',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                    ),
                    child: const Text('Zavrieť'),
                  ),
                  const SizedBox(width: 6),
                  FilledButton(
                    onPressed: () =>
                        Navigator.pop(context, today),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(8)),
                    ),
                    child: const Text('Dnes',
                        style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
