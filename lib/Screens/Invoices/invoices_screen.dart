import 'package:flutter/material.dart';
import '../../models/invoice.dart';
import '../../services/Invoice/invoice_service.dart';
import '../../theme/app_theme.dart' show AppColors;
import 'invoice_detail_screen.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen>
    with SingleTickerProviderStateMixin {
  final InvoiceService _service = InvoiceService();
  late final TabController _tabController;

  List<Invoice> _all = [];
  bool _loading = true;
  String _search = '';

  static const _tabs = [
    ('Všetky', null),
    ('Vydané', 'issuedInvoice'),
    ('Zálohy', 'proformaInvoice'),
    ('Dobropisy', 'creditNote'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _loadInvoices();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInvoices() async {
    setState(() => _loading = true);
    final all = await _service.getAllInvoices();
    setState(() {
      _all = all;
      _loading = false;
    });
  }

  List<Invoice> get _filtered {
    final type = _tabs[_tabController.index].$2;
    return _all.where((inv) {
      if (type != null && inv.invoiceType.value != type) return false;
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        return inv.invoiceNumber.toLowerCase().contains(q) ||
            (inv.customerName?.toLowerCase().contains(q) ?? false);
      }
      return true;
    }).toList();
  }

  Color _statusColor(InvoiceStatus s) {
    switch (s) {
      case InvoiceStatus.draft:     return Colors.grey;
      case InvoiceStatus.issued:    return Colors.blue;
      case InvoiceStatus.sent:      return Colors.orange;
      case InvoiceStatus.paid:      return Colors.green;
      case InvoiceStatus.overdue:   return Colors.red;
      case InvoiceStatus.cancelled: return Colors.red.shade200;
    }
  }

  IconData _typeIcon(InvoiceType t) {
    switch (t) {
      case InvoiceType.issuedInvoice:   return Icons.receipt_long;
      case InvoiceType.proformaInvoice: return Icons.request_quote;
      case InvoiceType.creditNote:      return Icons.undo;
      case InvoiceType.debitNote:       return Icons.add_circle_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    // Štatistiky
    final totalWithVat = filtered.fold<double>(
        0, (s, i) => s + (i.status != InvoiceStatus.cancelled ? i.totalWithVat : 0));
    final paidTotal = filtered
        .where((i) => i.status == InvoiceStatus.paid)
        .fold<double>(0, (s, i) => s + i.totalWithVat);
    final overdueCount = filtered.where((i) => i.status == InvoiceStatus.overdue).length;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgCard,
        elevation: 0,
        title: Text('Faktúry', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.accentGold,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.accentGold,
          tabs: _tabs.map((t) => Tab(text: t.$1)).toList(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInvoices,
            tooltip: 'Obnoviť',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const InvoiceDetailScreen()),
          );
          if (result == true) _loadInvoices();
        },
        backgroundColor: AppColors.accentGold,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nová faktúra', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          // Štatistiky
          if (!_loading && filtered.isNotEmpty)
            Container(
              color: AppColors.bgCard,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _statChip('Celkom', '${filtered.length}', Icons.receipt, Colors.blue),
                  const SizedBox(width: 10),
                  _statChip('Obrat', '${totalWithVat.toStringAsFixed(2)} €', Icons.euro, Colors.green),
                  const SizedBox(width: 10),
                  _statChip('Uhradené', '${paidTotal.toStringAsFixed(2)} €', Icons.check_circle, Colors.teal),
                  if (overdueCount > 0) ...[
                    const SizedBox(width: 10),
                    _statChip('Po splatnosti', '$overdueCount', Icons.warning, Colors.red),
                  ],
                ],
              ),
            ),

          // Vyhľadávanie
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Hľadať podľa čísla alebo odberateľa…',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: AppColors.bgCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.borderDefault, width: 0.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.borderDefault, width: 0.5),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),

          // Zoznam
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 56, color: AppColors.textSecondary),
                            const SizedBox(height: 12),
                            Text('Žiadne faktúry', style: TextStyle(color: AppColors.textSecondary)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) => _buildCard(filtered[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Invoice inv) {
    final isOverdue = inv.status == InvoiceStatus.overdue ||
        (inv.status == InvoiceStatus.issued &&
            inv.dueDate.isBefore(DateTime.now()));
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppColors.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: isOverdue
            ? const BorderSide(color: Colors.red, width: 1.2)
            : BorderSide(color: AppColors.borderDefault, width: 0.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => InvoiceDetailScreen(invoiceId: inv.id)),
          );
          if (result == true) _loadInvoices();
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Ikona
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: AppColors.accentGold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_typeIcon(inv.invoiceType), color: AppColors.accentGold, size: 22),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(inv.invoiceNumber,
                            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        const SizedBox(width: 8),
                        _badge(inv.status.label, _statusColor(inv.status)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(inv.customerName ?? '–',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      'Splatnosť: ${_fmtDate(inv.dueDate)}',
                      style: TextStyle(
                        color: isOverdue ? Colors.red : AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),

              // Suma
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${inv.totalWithVat.toStringAsFixed(2)} €',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'bez DPH: ${inv.totalWithoutVat.toStringAsFixed(2)} €',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _statChip(String label, String value, IconData icon, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
            Text(value, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 11)),
          ],
        ),
      ],
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}
