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
    var list = _stockOuts.where((s) => _isSameDay(s.createdAt, _selectedDate)).toList();
    if (_issueTypeFilter != null) {
      list = list.where((s) => s.issueType == _issueTypeFilter).toList();
    }
    return list;
  }

  /// Dni (bez času), v ktorých existuje aspoň jedna výdajka – na zvýraznenie v kalendári.
  Set<DateTime> get _datesWithStockOuts {
    return _stockOuts.map((s) => DateTime(s.createdAt.year, s.createdAt.month, s.createdAt.day)).toSet();
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
    final list = await _stockOutService.getStockOutsByWarehouseId(_selectedWarehouseId);
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
          bottom: BorderSide(color: Colors.black.withOpacity(0.06), width: 1),
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                filled: true,
                fillColor: Colors.grey.withOpacity(0.08),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.withOpacity(0.25)),
                ),
              ),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('Všetky sklady')),
                ..._warehouses.map(
                  (w) => DropdownMenuItem<int?>(value: w.id, child: Text(w.name)),
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                filled: true,
                fillColor: Colors.grey.withOpacity(0.08),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.withOpacity(0.25)),
                ),
              ),
              items: [
                const DropdownMenuItem<StockOutIssueType?>(value: null, child: Text('Všetky')),
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

  Widget _buildDateBar() {
    final now = DateTime.now();
    final isToday = _isSameDay(_selectedDate, now);
    final dateStr = isToday
        ? 'Dnes'
        : '${_selectedDate.day}. ${_selectedDate.month}. ${_selectedDate.year}';
    return Material(
      color: Colors.white,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: () => setState(() {
                _selectedDate = _selectedDate.subtract(const Duration(days: 1));
              }),
              icon: const Icon(Icons.chevron_left_rounded),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFF1F5F9),
                foregroundColor: const Color(0xFF64748B),
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 20, color: const Color(0xFFDC2626).withOpacity(0.9)),
                      const SizedBox(width: 10),
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isToday ? const Color(0xFFDC2626) : const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: () => setState(() {
                _selectedDate = _selectedDate.add(const Duration(days: 1));
              }),
              icon: const Icon(Icons.chevron_right_rounded),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFF1F5F9),
                foregroundColor: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openNewModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const StockOutModal(),
    ).then((saved) {
      if (saved == true) _loadStockOuts();
    });
  }

  void _openEditModal(StockOut stockOut) {
    if (stockOut.id == null || stockOut.isStorned) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StockOutModal(stockOutId: stockOut.id),
    ).then((saved) {
      if (saved == true) _loadStockOuts();
    });
  }

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

  /// Vráti null = zrušené, false = storno bez vrátenia zásob, true = storno s vrátením zásob (len pri schválených).
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
            onPressed: () => Navigator.pop(ctx, (title: 'VÝDAJKA TOVARU', hidePrices: false)),
            child: const Text('Výdajka (s cenami)'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, (title: 'DODACÍ LIST', hidePrices: false)),
            child: const Text('Dodací list (s cenami)'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, (title: 'DODACÍ LIST', hidePrices: true)),
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

  static const double _appBarHeight = 70;
  static const double _appBarFilterHeight = 56;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(_appBarHeight + _appBarFilterHeight),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AppBar(
              backgroundColor: Colors.white.withOpacity(0.85),
              elevation: 0,
              centerTitle: false,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text(
                'Výdaj tovaru',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(_appBarFilterHeight),
                child: _buildAppBarFilters(),
              ),
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.only(top: _appBarHeight + _appBarFilterHeight),
        child: Column(
          children: [
            _buildDateBar(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
                  : StockOutList(
                      stockOuts: _filteredStockOuts,
                      canEditApproved: widget.userRole == 'admin',
                      onAddTap: _openNewModal,
                      onApprove: _approveStockOut,
                      onEdit: _openEditModal,
                      onStorno: _stornoStockOut,
                      onExportPdf: _exportStockOutPdf,
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewModal,
        backgroundColor: const Color(0xFFDC2626),
        elevation: 10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        label: const Text(
          'Nová výdajka',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        icon: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _StornoVerifyDialog extends StatefulWidget {
  final String documentNumber;
  final bool isApproved;

  const _StornoVerifyDialog({
    required this.documentNumber,
    required this.isApproved,
  });

  @override
  State<_StornoVerifyDialog> createState() => _StornoVerifyDialogState();
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
      title: Text(widget.isApproved ? 'Stornovať výdajku' : 'Zrušiť výdajku'),
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
                errorText: _controller.text.isNotEmpty && !match
                    ? 'Nesedí s číslom výdajky'
                    : null,
              ),
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) {
                if (match && widget.isApproved) Navigator.pop(context, true);
                else if (match && !widget.isApproved) Navigator.pop(context, false);
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
            onPressed: match ? () => Navigator.pop(context, true) : null,
            child: const Text('Áno, vrátiť na sklad'),
          ),
        FilledButton(
          onPressed: match ? () => Navigator.pop(context, false) : null,
          style: FilledButton.styleFrom(
            backgroundColor: widget.isApproved ? null : Colors.red,
          ),
          child: Text(
            widget.isApproved ? 'Stornovať bez vrátenia' : 'Áno, zrušiť',
          ),
        ),
      ],
    );
  }
}

/// Kalendár na výber dňa so zvýraznením dní, v ktorých bola výdajka (zelená).
class _StockOutCalendarDialog extends StatefulWidget {
  final DateTime initialDate;
  final Set<DateTime> datesWithStockOuts;

  const _StockOutCalendarDialog({
    required this.initialDate,
    required this.datesWithStockOuts,
  });

  @override
  State<_StockOutCalendarDialog> createState() => _StockOutCalendarDialogState();
}

class _StockOutCalendarDialogState extends State<_StockOutCalendarDialog> {
  static const _weekdays = ['Po', 'Ut', 'St', 'Št', 'Pi', 'So', 'Ne'];
  static const _greenHighlight = Color(0xFF22C55E);

  late DateTime _viewMonth;

  @override
  void initState() {
    super.initState();
    _viewMonth = DateTime(widget.initialDate.year, widget.initialDate.month);
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
    int weekday = first.weekday - 1;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final list = <DateTime?>[];
    for (int i = 0; i < weekday; i++) list.add(null);
    for (int d = 1; d <= daysInMonth; d++) list.add(DateTime(year, month, d));
    while (list.length % 7 != 0) list.add(null);
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = _daysInMonth();
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${_monthName(_viewMonth.month)} ${_viewMonth.year}',
            style: const TextStyle(fontSize: 18),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(() {
                  _viewMonth = DateTime(_viewMonth.year, _viewMonth.month - 1);
                }),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setState(() {
                  _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + 1);
                }),
              ),
            ],
          ),
        ],
      ),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _weekdays.map((w) => SizedBox(
                width: 32,
                child: Text(w, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600])),
              )).toList(),
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: days.length,
              itemBuilder: (context, index) {
                final day = days[index];
                if (day == null) return const SizedBox();
                final isSelected = day.year == widget.initialDate.year &&
                    day.month == widget.initialDate.month &&
                    day.day == widget.initialDate.day;
                final isToday = day.year == today.year &&
                    day.month == today.month && day.day == today.day;
                final hasHighlight = _hasStockOut(day);
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.pop(context, day),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFDC2626)
                            : (hasHighlight ? _greenHighlight.withOpacity(0.2) : null),
                        borderRadius: BorderRadius.circular(8),
                        border: isToday && !isSelected
                            ? Border.all(color: _greenHighlight, width: 1.5)
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : (hasHighlight ? _greenHighlight : Colors.black87),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: _greenHighlight.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 6),
                Text('Deň s výdajkou', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Zrušiť'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, today),
          child: const Text('Dnes'),
        ),
      ],
    );
  }

  String _monthName(int month) {
    const names = ['Január', 'Február', 'Marec', 'Apríl', 'Máj', 'Jún', 'Júl', 'August', 'September', 'Október', 'November', 'December'];
    return names[month - 1];
  }
}
