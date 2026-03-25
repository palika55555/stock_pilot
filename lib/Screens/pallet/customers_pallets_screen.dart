import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stock_pilot/models/customer.dart';
import 'package:stock_pilot/screens/scanner/scan_product.dart';
import 'package:stock_pilot/services/Database/database_service.dart';
import 'package:stock_pilot/theme/app_theme.dart';

/// Zoznam zákazníkov s bilanciou paliet, expedícia a vrátenie paliet.
class CustomersPalletsScreen extends StatefulWidget {
  const CustomersPalletsScreen({super.key});

  @override
  State<CustomersPalletsScreen> createState() => _CustomersPalletsScreenState();
}

class _CustomersPalletsScreenState extends State<CustomersPalletsScreen> {
  final DatabaseService _db = DatabaseService();
  final TextEditingController _searchController = TextEditingController();

  List<Customer> _customers = [];
  Customer? _selectedCustomerForExpedition;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await _db.getCustomers();
    if (!mounted) return;
    setState(() {
      _customers = list;
      _loading = false;
      if (_selectedCustomerForExpedition != null) {
        final id = _selectedCustomerForExpedition!.id;
        final matches = list.where((c) => c.id == id);
        _selectedCustomerForExpedition =
            matches.isEmpty ? null : matches.first;
      }
    });
  }

  int get _totalPalletsOutstanding =>
      _customers.fold<int>(0, (s, c) => s + c.palletBalance);

  int get _customersWithPallets =>
      _customers.where((c) => c.palletBalance > 0).length;

  /// Najvyššia bilancia – pre „smart“ rýchlu voľbu expedície.
  List<Customer> get _topPalletCustomers {
    final withBal = _customers.where((c) => c.palletBalance > 0).toList()
      ..sort((a, b) => b.palletBalance.compareTo(a.palletBalance));
    return withBal.take(4).toList();
  }

  String get _searchQuery => _searchController.text.trim().toLowerCase();

  List<Customer> _matchesSearch(List<Customer> list) {
    if (_searchQuery.isEmpty) return list;
    return list.where((c) {
      final name = c.name.toLowerCase();
      final addr = [c.address, c.city].whereType<String>().join(' ').toLowerCase();
      return name.contains(_searchQuery) || addr.contains(_searchQuery);
    }).toList();
  }

  Future<void> _returnPallets(Customer customer) async {
    if (customer.palletBalance <= 0) return;
    final controller = TextEditingController(text: '1');
    final count = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Vrátiť palety – ${customer.name}',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: TextField(
          controller: controller,
          style: GoogleFonts.dmSans(color: AppColors.textPrimary),
          decoration: InputDecoration(
            labelText: 'Počet paliet (max. ${customer.palletBalance})',
            labelStyle: GoogleFonts.dmSans(color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.bgInput,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Zrušiť', style: GoogleFonts.dmSans(color: AppColors.textSecondary)),
          ),
          FilledButton(
            onPressed: () {
              final n = int.tryParse(controller.text);
              if (n == null || n <= 0 || n > customer.palletBalance) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Zadajte platný počet')),
                );
                return;
              }
              Navigator.pop(context, n);
            },
            child: Text('Vrátiť', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (count == null || !mounted) return;
    await _db.returnPalletsForCustomer(customer.id!, count);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Vrátených $count paliet'),
        backgroundColor: AppColors.success,
      ),
    );
    _load();
  }

  Future<void> _openScanner() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScanProductScreen(
          expeditionCustomer: _selectedCustomerForExpedition,
        ),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.bgPrimary,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.accentGold),
        ),
      );
    }

    final withPallets = _customers.where((c) => c.palletBalance > 0).toList();
    final others = _customers.where((c) => c.palletBalance <= 0).toList();

    final filteredWith = _matchesSearch(withPallets);
    final filteredOthers = _matchesSearch(others);
    final showTwoSections = withPallets.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: Text(
          'Zákazníci / Palety',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _buildSmartHeader(),
          const SizedBox(height: 14),
          _buildStatsRow(),
          const SizedBox(height: 18),
          _buildExpeditionCard(),
          const SizedBox(height: 10),
          if (_topPalletCustomers.isNotEmpty) _buildQuickPickChips(),
          const SizedBox(height: 20),
          TextField(
            controller: _searchController,
            style: GoogleFonts.dmSans(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Hľadať zákazníka podľa mena alebo adresy…',
              hintStyle: GoogleFonts.dmSans(color: AppColors.textMuted),
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.bgInput,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.borderDefault),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.borderDefault),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.accentGold, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (showTwoSections) ...[
            _sectionTitle('Zákazníci s paletami', Icons.local_shipping_rounded),
            const SizedBox(height: 10),
            if (filteredWith.isEmpty)
              _emptySearchNote()
            else
              ...filteredWith.map((c) => _customerCard(c, highlight: true)),
            const SizedBox(height: 22),
          ],
          _sectionTitle(
            showTwoSections ? 'Ostatní zákazníci' : 'Zákazníci',
            Icons.people_outline_rounded,
          ),
          const SizedBox(height: 10),
          if ((showTwoSections ? filteredOthers : _matchesSearch(_customers))
              .isEmpty)
            _emptySearchNote()
          else
            ...(showTwoSections ? filteredOthers : _matchesSearch(_customers))
                .map((c) => _customerCard(c)),
        ],
      ),
    );
  }

  Widget _buildSmartHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.accentGold.withValues(alpha: 0.15),
            AppColors.bgElevated,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.accentGoldSubtle,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: AppColors.accentGold, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Expedícia paliet',
                  style: GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Vyberte zákazníka, prípadne použiť rýchlu voľbu nižšie. '
                  'Po skenovaní sa paleta sama priradí k vybranému účtu.',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _statTile(
            Icons.inventory_2_outlined,
            'Celkom u zákazníkov',
            '$_totalPalletsOutstanding pal.',
            AppColors.accentGold,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statTile(
            Icons.groups_outlined,
            'Zákazníci s bilanciou',
            '$_customersWithPallets',
            AppColors.info,
          ),
        ),
      ],
    );
  }

  Widget _statTile(
    IconData icon,
    String label,
    String value,
    Color accent,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpeditionCard() {
    final ready = _selectedCustomerForExpedition != null;
    return Container(
      decoration: AppColors.cardDecorationSmall(16),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ready ? Icons.check_circle_rounded : Icons.touch_app_rounded,
                color: ready ? AppColors.success : AppColors.textMuted,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ready
                      ? 'Pripravené na sken – ${_selectedCustomerForExpedition!.name}'
                      : 'Najprv vyberte zákazníka pre expedíciu',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ready ? AppColors.success : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<Customer>(
            value: _selectedCustomerForExpedition, // ignore: deprecated_member_use
            isExpanded: true,
            dropdownColor: AppColors.bgElevated,
            style: GoogleFonts.dmSans(color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: 'Zákazník pre sken',
              labelStyle: GoogleFonts.dmSans(color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.bgInput,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: _customers
                .map(
                  (c) => DropdownMenuItem(
                    value: c,
                    child: Text(
                      c.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (c) => setState(() => _selectedCustomerForExpedition = c),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: ready ? _openScanner : null,
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 22),
              label: Text(
                'Skenovať palety zákazníkovi',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPickChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rýchla voľba (najvyššia bilancia)',
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _topPalletCustomers.map((c) {
            final selected = _selectedCustomerForExpedition?.id == c.id;
            return FilterChip(
              label: Text(
                '${c.name.split(' ').first} · ${c.palletBalance} pal.',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              selected: selected,
              showCheckmark: false,
              selectedColor: AppColors.accentGoldSubtle,
              backgroundColor: AppColors.bgElevated,
              side: BorderSide(
                color: selected ? AppColors.accentGold : AppColors.borderDefault,
              ),
              labelStyle: GoogleFonts.dmSans(
                color: selected ? AppColors.accentGold : AppColors.textSecondary,
              ),
              onSelected: (_) {
                setState(() => _selectedCustomerForExpedition = c);
                HapticFeedback.lightImpact();
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.accentGold),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _emptySearchNote() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        'Žiadna zhoda s hľadaným textom.',
        style: GoogleFonts.dmSans(color: AppColors.textMuted, fontSize: 13),
      ),
    );
  }

  Widget _customerCard(Customer c, {bool highlight = false}) {
    final addr = [c.address, c.city].whereType<String>().join(', ');
    final bal = c.palletBalance;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: highlight ? AppColors.accentGold.withValues(alpha: 0.06) : AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight
              ? AppColors.accentGold.withValues(alpha: 0.35)
              : AppColors.borderSubtle,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          backgroundColor:
              highlight ? AppColors.accentGoldSubtle : AppColors.bgElevated,
          child: Icon(
            highlight ? Icons.local_shipping_rounded : Icons.storefront_outlined,
            color: highlight ? AppColors.accentGold : AppColors.textSecondary,
            size: 22,
          ),
        ),
        title: Text(
          c.name,
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: addr.isNotEmpty
            ? Text(
                addr,
                style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textMuted),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: bal > 0
                    ? AppColors.accentGoldSubtle
                    : AppColors.bgElevated,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$bal pal.',
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: bal > 0 ? AppColors.accentGold : AppColors.textMuted,
                ),
              ),
            ),
            if (bal > 0) ...[
              const SizedBox(width: 6),
              TextButton(
                onPressed: () => _returnPallets(c),
                child: Text(
                  'Vrátiť',
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w600,
                    color: AppColors.info,
                  ),
                ),
              ),
            ],
          ],
        ),
        onTap: () {
          setState(() => _selectedCustomerForExpedition = c);
          HapticFeedback.selectionClick();
        },
      ),
    );
  }
}
