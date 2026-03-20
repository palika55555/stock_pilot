import 'package:flutter/material.dart';
import '../../models/company.dart';
import '../../models/customer.dart';
import '../../models/invoice.dart';
import '../../models/product.dart';
import '../../services/Customer/customer_service.dart';
import '../../services/Invoice/invoice_service.dart';
import '../../services/Product/product_service.dart';
import '../../theme/app_theme.dart' show AppColors;

/// Formulár na vytvorenie/úpravu faktúry vrátane položiek.
/// Vráti výsledok cez [onSave].
class InvoiceFormWidget extends StatefulWidget {
  final Invoice? invoice;       // null = nová faktúra
  final List<InvoiceItem> items;
  final Company? company;
  final Future<void> Function(Invoice invoice, List<InvoiceItem> items) onSave;

  const InvoiceFormWidget({
    super.key,
    required this.invoice,
    required this.items,
    required this.company,
    required this.onSave,
  });

  @override
  State<InvoiceFormWidget> createState() => _InvoiceFormWidgetState();
}

class _InvoiceFormWidgetState extends State<InvoiceFormWidget> {
  final InvoiceService _service = InvoiceService();
  final CustomerService _customerService = CustomerService();
  final ProductService _productService = ProductService();

  late final TextEditingController _numberCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _varSymCtrl;
  late final TextEditingController _constSymCtrl;

  DateTime _issueDate = DateTime.now();
  DateTime _taxDate   = DateTime.now();
  DateTime _dueDate   = DateTime.now().add(const Duration(days: 14));

  InvoiceType   _type   = InvoiceType.issuedInvoice;
  InvoiceStatus _status = InvoiceStatus.draft;
  PaymentMethod _paymentMethod = PaymentMethod.transfer;

  Customer? _selectedCustomer;
  List<Customer> _customers = [];
  List<Product> _products = [];

  List<_ItemRow> _rows = [];

  bool _loadingCustomers = true;
  bool _loadingProducts = true;

  @override
  void initState() {
    super.initState();
    final inv = widget.invoice;
    _type          = inv?.invoiceType   ?? InvoiceType.issuedInvoice;
    _status        = inv?.status        ?? InvoiceStatus.draft;
    _paymentMethod = inv?.paymentMethod ?? PaymentMethod.transfer;
    if (inv != null) {
      _issueDate = inv.issueDate;
      _taxDate   = inv.taxDate;
      _dueDate   = inv.dueDate;
    }

    _numberCtrl   = TextEditingController(text: inv?.invoiceNumber   ?? '');
    _notesCtrl    = TextEditingController(text: inv?.notes           ?? '');
    _varSymCtrl   = TextEditingController(text: inv?.variableSymbol  ?? '');
    _constSymCtrl = TextEditingController(text: inv?.constantSymbol  ?? '0308');

    _rows = widget.items.map((i) => _ItemRow.fromItem(i)).toList();
    if (_rows.isEmpty) _rows.add(_ItemRow.empty());

    _loadCustomers(inv?.customerId);
    _loadProducts();
    _maybeGenerateNumber(inv);
  }

  @override
  void dispose() {
    _numberCtrl.dispose();
    _notesCtrl.dispose();
    _varSymCtrl.dispose();
    _constSymCtrl.dispose();
    for (final r in _rows) r.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers(int? preselectedId) async {
    final customers = await _customerService.getAllCustomers();
    setState(() {
      _customers = customers;
      if (preselectedId != null) {
        _selectedCustomer = customers.firstWhere(
          (c) => c.id == preselectedId,
          orElse: () => customers.isNotEmpty ? customers.first : Customer(name: '', ico: ''),
        );
      }
      _loadingCustomers = false;
    });
  }

  Future<void> _loadProducts() async {
    final products = await _productService.getAllProducts();
    if (!mounted) return;
    setState(() {
      _products = products.where((p) => p.isActive && !p.temporarilyUnavailable).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      _loadingProducts = false;
    });
  }

  Future<void> _maybeGenerateNumber(Invoice? inv) async {
    if (inv == null || _numberCtrl.text.isEmpty) {
      final number = await _service.getNextInvoiceNumber(_type);
      if (mounted) {
        setState(() {
          _numberCtrl.text = number;
          _varSymCtrl.text = number.replaceAll(RegExp(r'[^0-9]'), '');
        });
      }
    }
  }

  void _addItem() => setState(() => _rows.add(_ItemRow.empty()));

  void _removeItem(int idx) {
    _rows[idx].dispose();
    setState(() => _rows.removeAt(idx));
  }

  Future<void> _pickProductForRow(_ItemRow row) async {
    if (_products.isEmpty) {
      _showError('V sklade nie sú dostupné produkty');
      return;
    }
    Product? selected;
    String query = '';
    final product = await showDialog<Product>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final filtered = _products.where((p) {
              if (query.isEmpty) return true;
              final q = query.toLowerCase();
              return p.name.toLowerCase().contains(q) ||
                  p.plu.toLowerCase().contains(q) ||
                  (p.ean?.toLowerCase().contains(q) ?? false);
            }).toList();
            return AlertDialog(
              title: const Text('Vybrať zo skladových zásob'),
              content: SizedBox(
                width: 620,
                height: 420,
                child: Column(
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Hľadať názov / PLU / EAN',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (v) => setDialogState(() => query = v.trim()),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final p = filtered[i];
                          final isLow = p.qty <= 0;
                          return ListTile(
                            dense: true,
                            title: Text(p.name),
                            subtitle: Text('PLU: ${p.plu}  |  Sklad: ${p.qty.toStringAsFixed(3)} ${p.unit}'),
                            trailing: isLow
                                ? const Text('Nedostatok', style: TextStyle(color: Colors.red))
                                : null,
                            onTap: () {
                              selected = p;
                              Navigator.of(ctx).pop(p);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Zrušiť')),
              ],
            );
          },
        );
      },
    );
    final picked = product ?? selected;
    if (picked == null) return;
    setState(() {
      row.productUniqueId = picked.uniqueId;
      row.stockQty = picked.qty;
      row.nameCtrl.text = picked.name;
      row.unitCtrl.text = picked.unit;
      row.priceCtrl.text = picked.withoutVat.toStringAsFixed(2);
      row.vatPercent = picked.vat;
      row.itemType = picked.productType == 'Služba' ? 'Služba' : 'Tovar';
      if (row.qtyCtrl.text.trim().isEmpty || (double.tryParse(row.qtyCtrl.text.replaceAll(',', '.')) ?? 0) <= 0) {
        row.qtyCtrl.text = '1';
      }
    });
  }

  // ── Výpočty ──────────────────────────────────────────────────────────────

  double get _totalWithoutVat => _rows.fold(0, (s, r) => s + r.lineBase);
  double get _totalVat        => _rows.fold(0, (s, r) => s + r.lineVat);
  double get _totalWithVat    => _rows.fold(0, (s, r) => s + r.lineTotal);

  // ── Uloženie ─────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_numberCtrl.text.isEmpty) {
      _showError('Číslo faktúry je povinné');
      return;
    }
    if (_selectedCustomer == null) {
      _showError('Vyberte odberateľa');
      return;
    }
    if (_rows.every((r) => r.nameCtrl.text.isEmpty)) {
      _showError('Pridajte aspoň jednu položku');
      return;
    }

    final items = _rows
        .where((r) => r.nameCtrl.text.isNotEmpty)
        .map((r) => r.toItem(widget.invoice?.id ?? 0))
        .toList();

    final c = _selectedCustomer!;
    final invoice = (widget.invoice ?? Invoice(
      invoiceNumber: _numberCtrl.text,
      issueDate: _issueDate,
      taxDate: _taxDate,
      dueDate: _dueDate,
    )).copyWith(
      invoiceNumber: _numberCtrl.text,
      invoiceType: _type,
      issueDate: _issueDate,
      taxDate: _taxDate,
      dueDate: _dueDate,
      customerId: c.id,
      customerName: c.name,
      customerAddress: c.address,
      customerCity: c.city,
      customerPostalCode: c.postalCode,
      customerIco: c.ico,
      customerDic: c.dic,
      customerIcDph: c.icDph,
      paymentMethod: _paymentMethod,
      variableSymbol: _varSymCtrl.text.isEmpty
          ? _numberCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')
          : _varSymCtrl.text,
      constantSymbol: _constSymCtrl.text.isEmpty ? '0308' : _constSymCtrl.text,
      status: _status,
      notes: _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
      isVatPayer: widget.company?.vatPayer ?? true,
      totalWithoutVat: _totalWithoutVat,
      totalVat: _totalVat,
      totalWithVat: _totalWithVat,
    );

    await widget.onSave(invoice, items);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  Future<void> _pickDate(DateTime current, ValueChanged<DateTime> onPicked) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) onPicked(picked);
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
        return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Typ + Stav ───────────────────────────────────────────────────
          Row(children: [
            Expanded(child: _section('Typ faktúry', _buildTypeDropdown())),
            const SizedBox(width: 12),
            Expanded(child: _section('Stav', _buildStatusDropdown())),
          ]),
          const SizedBox(height: 12),

          // ── Číslo faktúry ────────────────────────────────────────────────
          Row(children: [
            Expanded(
              flex: 2,
              child: _section('Číslo faktúry *', _field(_numberCtrl, 'FAK-2026-0001')),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _section('Variabilný symbol', _field(_varSymCtrl, '20260001')),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _section('Konštantný symbol', _field(_constSymCtrl, '0308')),
            ),
          ]),
          const SizedBox(height: 12),

          // ── Dátumy ───────────────────────────────────────────────────────
          Row(children: [
            Expanded(child: _section('Dátum vystavenia *', _datePicker(_issueDate, (d) => setState(() => _issueDate = d)))),
            const SizedBox(width: 12),
            Expanded(child: _section('DUZP *', _datePicker(_taxDate, (d) => setState(() => _taxDate = d)))),
            const SizedBox(width: 12),
            Expanded(child: _section('Dátum splatnosti *', _datePicker(_dueDate, (d) => setState(() => _dueDate = d)))),
          ]),
          const SizedBox(height: 12),

          // ── Odberateľ ────────────────────────────────────────────────────
          _section('Odberateľ *', _loadingCustomers
              ? const LinearProgressIndicator()
              : _buildCustomerDropdown()),
          const SizedBox(height: 4),
          if (_selectedCustomer != null)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                [
                  if (_selectedCustomer!.ico.isNotEmpty) 'IČO: ${_selectedCustomer!.ico}',
                  if (_selectedCustomer!.dic?.isNotEmpty == true) 'DIČ: ${_selectedCustomer!.dic}',
                  if (_selectedCustomer!.icDph?.isNotEmpty == true) 'IČ DPH: ${_selectedCustomer!.icDph}',
                ].join('   '),
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            ),
          const SizedBox(height: 12),

          // ── Spôsob úhrady ────────────────────────────────────────────────
          _section('Spôsob úhrady', _buildPaymentDropdown()),
          const SizedBox(height: 12),

          // ── Položky ──────────────────────────────────────────────────────
          Row(
            children: [
              Text('Položky faktúry', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const Spacer(),
              if (_loadingProducts)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Text('Načítavam sklad...', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ),
              TextButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Pridať položku'),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Hlavička tabuľky
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.accentGold.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(children: [
              Expanded(flex: 4, child: Text('Popis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.textPrimary))),
              _hdr('Mn.', 50),
              _hdr('Jed.', 40),
              _hdr('Cena/j.', 70),
              _hdr('Zľava%', 55),
              _hdr('DPH%', 50),
              _hdr('Spolu', 70),
              const SizedBox(width: 36),
            ]),
          ),
          const SizedBox(height: 4),

          // Riadky položiek
          ...List.generate(_rows.length, (idx) => _buildItemRow(idx)),

          const SizedBox(height: 12),

          // ── Súčty ────────────────────────────────────────────────────────
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: 280,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderDefault, width: 0.5),
              ),
              child: Column(
                children: [
                  _sumLine('Základ bez DPH:', _totalWithoutVat, bold: false),
                  _sumLine('DPH spolu:', _totalVat, bold: false),
                  const Divider(height: 10),
                  _sumLine('CELKOM K ÚHRADE:', _totalWithVat, bold: true, big: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Poznámka ─────────────────────────────────────────────────────
          _section('Poznámka', TextField(
            controller: _notesCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Poznámka k faktúre…',
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
              contentPadding: const EdgeInsets.all(10),
            ),
          )),

          const SizedBox(height: 20),

          // ── Uložiť ───────────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.save, color: Colors.white),
              label: const Text('Uložiť faktúru', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentGold,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helper builders ───────────────────────────────────────────────────────

  Widget _section(String label, Widget child) {
        return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        child,
      ],
    );
  }

  Widget _field(TextEditingController ctrl, String hint) {
        return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.bgCard,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.borderDefault, width: 0.5)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.borderDefault, width: 0.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
    );
  }

  Widget _datePicker(DateTime date, ValueChanged<DateTime> onPicked) {
    return InkWell(
      onTap: () => _pickDate(date, onPicked),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderDefault, width: 0.5),
        ),
        child: Row(children: [
          Icon(Icons.calendar_today, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(_fmtDate(date), style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
        ]),
      ),
    );
  }

  Widget _buildTypeDropdown() {
    return DropdownButtonFormField<InvoiceType>(
      value: _type,
      decoration: InputDecoration(
        filled: true, fillColor: AppColors.bgCard,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.borderDefault, width: 0.5)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.borderDefault, width: 0.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      items: InvoiceType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.label, style: const TextStyle(fontSize: 13)))).toList(),
      onChanged: (t) async {
        if (t == null) return;
        setState(() => _type = t);
        final num = await _service.getNextInvoiceNumber(t);
        if (mounted) setState(() {
          _numberCtrl.text = num;
          _varSymCtrl.text = num.replaceAll(RegExp(r'[^0-9]'), '');
        });
      },
    );
  }

  Widget _buildStatusDropdown() {
    return DropdownButtonFormField<InvoiceStatus>(
      value: _status,
      decoration: InputDecoration(
        filled: true, fillColor: AppColors.bgCard,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.borderDefault, width: 0.5)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.borderDefault, width: 0.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      items: InvoiceStatus.values.map((s) => DropdownMenuItem(value: s, child: Text(s.label, style: const TextStyle(fontSize: 13)))).toList(),
      onChanged: (s) { if (s != null) setState(() => _status = s); },
    );
  }

  Widget _buildCustomerDropdown() {
    return DropdownButtonFormField<Customer>(
      value: _selectedCustomer,
      isExpanded: true,
      decoration: InputDecoration(
        filled: true, fillColor: AppColors.bgCard,
        hintText: 'Vyberte odberateľa…',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.borderDefault, width: 0.5)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.borderDefault, width: 0.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      items: _customers.map((c) => DropdownMenuItem(
        value: c,
        child: Text(c.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
      )).toList(),
      onChanged: (c) => setState(() => _selectedCustomer = c),
    );
  }

  Widget _buildPaymentDropdown() {
    return DropdownButtonFormField<PaymentMethod>(
      value: _paymentMethod,
      decoration: InputDecoration(
        filled: true, fillColor: AppColors.bgCard,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.borderDefault, width: 0.5)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.borderDefault, width: 0.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      items: PaymentMethod.values.map((p) => DropdownMenuItem(value: p, child: Text(p.label, style: const TextStyle(fontSize: 13)))).toList(),
      onChanged: (p) { if (p != null) setState(() => _paymentMethod = p); },
    );
  }

  Widget _buildItemRow(int idx) {
    final row = _rows[idx];
    final qty = double.tryParse(row.qtyCtrl.text.replaceAll(',', '.')) ?? 0;
    final stockExceeded = row.stockQty != null && qty > row.stockQty!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: _compactField(row.nameCtrl, 'Názov / popis', onChanged: (_) => setState(() {}))),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 32,
                      child: IconButton(
                        tooltip: 'Vybrať zo skladu',
                        onPressed: _loadingProducts ? null : () => _pickProductForRow(row),
                        icon: const Icon(Icons.inventory_2_outlined, size: 17),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                if (row.stockQty != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2, left: 2),
                    child: Text(
                      'Sklad: ${row.stockQty!.toStringAsFixed(3)} ${row.unitCtrl.text.isEmpty ? 'ks' : row.unitCtrl.text}',
                      style: TextStyle(
                        fontSize: 10,
                        color: stockExceeded ? Colors.red : AppColors.textSecondary,
                        fontWeight: stockExceeded ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(width: 50, child: _compactField(row.qtyCtrl, '1', onChanged: (_) => setState(() {}), textAlign: TextAlign.right, numeric: true)),
          const SizedBox(width: 4),
          SizedBox(width: 40, child: _compactField(row.unitCtrl, 'ks')),
          const SizedBox(width: 4),
          SizedBox(width: 70, child: _compactField(row.priceCtrl, '0,00', onChanged: (_) => setState(() {}), textAlign: TextAlign.right, numeric: true)),
          const SizedBox(width: 4),
          SizedBox(width: 55, child: _compactField(row.discCtrl, '0', onChanged: (_) => setState(() {}), textAlign: TextAlign.right, numeric: true)),
          const SizedBox(width: 4),
          SizedBox(
            width: 50,
            child: DropdownButtonFormField<int>(
              value: row.vatPercent,
              isDense: true,
              decoration: InputDecoration(
                filled: true, fillColor: AppColors.bgCard,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.borderDefault, width: 0.5)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.borderDefault, width: 0.5)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              ),
              items: [23, 19, 5, 0].map((v) => DropdownMenuItem(value: v, child: Text('$v%', style: const TextStyle(fontSize: 12)))).toList(),
              onChanged: (v) { if (v != null) setState(() => row.vatPercent = v); },
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 70,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.accentGold.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${row.lineTotal.toStringAsFixed(2)} €',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.textPrimary),
                textAlign: TextAlign.right,
              ),
            ),
          ),
          SizedBox(
            width: 36,
            child: IconButton(
              icon: const Icon(Icons.remove_circle_outline, size: 18, color: Colors.red),
              onPressed: () => _removeItem(idx),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactField(
    TextEditingController ctrl,
    String hint, {
    ValueChanged<String>? onChanged,
    TextAlign textAlign = TextAlign.left,
    bool numeric = false,
  }) {
        return TextField(
      controller: ctrl,
      onChanged: onChanged,
      textAlign: textAlign,
      keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      style: const TextStyle(fontSize: 12),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 11),
        filled: true,
        fillColor: AppColors.bgCard,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.borderDefault, width: 0.5)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.borderDefault, width: 0.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      ),
    );
  }

  Widget _hdr(String label, double width) {
        return SizedBox(
      width: width,
      child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: AppColors.textPrimary), textAlign: TextAlign.right),
    );
  }

  Widget _sumLine(String label, double amount, {required bool bold, bool big = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(
            fontSize: big ? 12 : 11,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: big ? AppColors.accentGold : AppColors.textPrimary,
          )),
          Text(
            '${amount.toStringAsFixed(2)} €',
            style: TextStyle(
              fontSize: big ? 14 : 11,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: big ? AppColors.accentGold : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pomocná trieda pre riadok položky formulára ───────────────────────────────

class _ItemRow {
  String? productUniqueId;
  double? stockQty;
  final TextEditingController nameCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController unitCtrl;
  final TextEditingController priceCtrl;
  final TextEditingController discCtrl;
  int vatPercent;
  String itemType;

  _ItemRow({
    this.productUniqueId,
    this.stockQty,
    required this.nameCtrl,
    required this.qtyCtrl,
    required this.unitCtrl,
    required this.priceCtrl,
    required this.discCtrl,
    this.vatPercent = 23,
    this.itemType = 'Tovar',
  });

  factory _ItemRow.empty() => _ItemRow(
    nameCtrl:  TextEditingController(),
    qtyCtrl:   TextEditingController(text: '1'),
    unitCtrl:  TextEditingController(text: 'ks'),
    priceCtrl: TextEditingController(text: '0'),
    discCtrl:  TextEditingController(text: '0'),
  );

  factory _ItemRow.fromItem(InvoiceItem item) => _ItemRow(
    productUniqueId: item.productUniqueId,
    nameCtrl:  TextEditingController(text: item.productName ?? ''),
    qtyCtrl:   TextEditingController(text: item.qty.toStringAsFixed(item.qty == item.qty.truncateToDouble() ? 0 : 3)),
    unitCtrl:  TextEditingController(text: item.unit),
    priceCtrl: TextEditingController(text: item.unitPrice.toStringAsFixed(2)),
    discCtrl:  TextEditingController(text: item.discountPercent.toString()),
    vatPercent: item.vatPercent,
    itemType:   item.itemType,
  );

  double get _qty   => double.tryParse(qtyCtrl.text.replaceAll(',', '.'))   ?? 1;
  double get _price => double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? 0;
  double get _disc  => double.tryParse(discCtrl.text.replaceAll(',', '.'))  ?? 0;

  double get lineBase  => (_price * _qty * (1 - _disc / 100) * 100).round() / 100;
  double get lineVat   => (lineBase * vatPercent / 100 * 100).round() / 100;
  double get lineTotal => (lineBase * (1 + vatPercent / 100) * 100).round() / 100;

  InvoiceItem toItem(int invoiceId) => InvoiceItem(
    invoiceId: invoiceId,
    productUniqueId: productUniqueId,
    productName: nameCtrl.text,
    qty: _qty,
    unit: unitCtrl.text.isEmpty ? 'ks' : unitCtrl.text,
    unitPrice: _price,
    discountPercent: _disc.toInt(),
    vatPercent: vatPercent,
    itemType: itemType,
  );

  void dispose() {
    nameCtrl.dispose();
    qtyCtrl.dispose();
    unitCtrl.dispose();
    priceCtrl.dispose();
    discCtrl.dispose();
  }
}
