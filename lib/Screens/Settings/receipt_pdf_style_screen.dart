import 'dart:ui';
import 'package:flutter/material.dart';
import '../../models/receipt_pdf_style_config.dart';

/// Konfigurátor štýlu PDF pre príjemky – Nastavenia → Generovanie PDF.
class ReceiptPdfStyleScreen extends StatefulWidget {
  const ReceiptPdfStyleScreen({super.key});

  @override
  State<ReceiptPdfStyleScreen> createState() => _ReceiptPdfStyleScreenState();
}

class _ReceiptPdfStyleScreenState extends State<ReceiptPdfStyleScreen> {
  bool _loading = true;
  bool _saving = false;
  late ReceiptPdfStyleConfig _config;
  final _documentTitleController = TextEditingController();

  static const List<int> _titleFontSizes = [14, 16, 18, 20, 22];
  static const List<int> _bodyFontSizes = [8, 9, 10, 11, 12];
  static const Map<String, String?> _colorPresets = {
    'Predvolená': null,
    'Modrá': '#1E3A5F',
    'Zelená': '#0D9488',
    'Tmavá': '#1E293B',
    'Fialová': '#6366F1',
  };

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _documentTitleController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() => _loading = true);
    final config = await ReceiptPdfStyleConfig.load();
    if (mounted) {
      _config = config;
      _documentTitleController.text = config.documentTitle;
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final updated = _config.copyWith(
      documentTitle: _documentTitleController.text,
    );
    await updated.save();
    if (mounted) {
      setState(() {
        _config = updated;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nastavenia PDF pre príjemky boli uložené'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: AppBar(
              backgroundColor: Colors.white.withOpacity(0.8),
              elevation: 0,
              centerTitle: false,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text(
                'Štýl PDF pre príjemky',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                ),
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 90, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCard(
                    title: 'Vzhľad',
                    children: [
                      _buildDropdown<int>(
                        label: 'Veľkosť nadpisu',
                        value: _config.titleFontSize,
                        items: _titleFontSizes,
                        labelBuilder: (v) => '$v pt',
                        onChanged: (v) =>
                            setState(() => _config = _config.copyWith(titleFontSize: v)),
                      ),
                      const SizedBox(height: 12),
                      _buildDropdown<int>(
                        label: 'Veľkosť textu v tele',
                        value: _config.bodyFontSize,
                        items: _bodyFontSizes,
                        labelBuilder: (v) => '$v pt',
                        onChanged: (v) =>
                            setState(() => _config = _config.copyWith(bodyFontSize: v)),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _documentTitleController,
                        decoration: const InputDecoration(
                          labelText: 'Nadpis dokumentu',
                          hintText: 'PRÍJEMKA TOVARU',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      _buildColorDropdown(
                        label: 'Primárna farba nadpisu',
                        value: _config.primaryColorHex,
                        onChanged: (v) =>
                            setState(() => _config = _config.copyWith(primaryColorHex: v)),
                      ),
                      const SizedBox(height: 12),
                      _buildColorDropdown(
                        label: 'Farba hlavičky tabuľky',
                        value: _config.tableHeaderColorHex,
                        onChanged: (v) =>
                            setState(() => _config = _config.copyWith(tableHeaderColorHex: v)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildCard(
                    title: 'Sekcie',
                    children: [
                      SwitchListTile(
                        title: const Text(
                          'Zobraziť „Vystavil“',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: const Text(
                          'Meno používateľa, ktorý vytvoril príjemku',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        value: _config.showIssuedBy,
                        onChanged: (v) =>
                            setState(() => _config = _config.copyWith(showIssuedBy: v)),
                        activeColor: const Color(0xFF6366F1),
                      ),
                      SwitchListTile(
                        title: const Text(
                          'Blok na podpis a dátum',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: const Text(
                          'Podpis prijímajúceho a dátum prijatia na konci PDF',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        value: _config.showSignatureBlock,
                        onChanged: (v) =>
                            setState(() => _config = _config.copyWith(showSignatureBlock: v)),
                        activeColor: const Color(0xFF6366F1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildCard(
                    title: 'Stĺpce v tabuľke PDF',
                    children: [
                      const Text(
                        'Zaškrtnite stĺpce, ktoré chcete mať v tlačenej tabuľke príjemky.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 12),
                      _buildColumnCheck('Položka (názov)', _config.showColProductName,
                          (v) => setState(() => _config = _config.copyWith(showColProductName: v))),
                      _buildColumnCheck('PLU', _config.showColPlu,
                          (v) => setState(() => _config = _config.copyWith(showColPlu: v))),
                      _buildColumnCheck('Množstvo', _config.showColQty,
                          (v) => setState(() => _config = _config.copyWith(showColQty: v))),
                      _buildColumnCheck('MJ (jednotka)', _config.showColUnit,
                          (v) => setState(() => _config = _config.copyWith(showColUnit: v))),
                      _buildColumnCheck('Cena za MJ s DPH', _config.showColUnitPriceWithVat,
                          (v) => setState(() => _config = _config.copyWith(showColUnitPriceWithVat: v))),
                      _buildColumnCheck('Cena za MJ bez DPH', _config.showColUnitPriceWithoutVat,
                          (v) => setState(() => _config = _config.copyWith(showColUnitPriceWithoutVat: v))),
                      _buildColumnCheck('Celkom', _config.showColTotal,
                          (v) => setState(() => _config = _config.copyWith(showColTotal: v))),
                      _buildColumnCheck('Sadzba DPH (%)', _config.showColVatRate,
                          (v) => setState(() => _config = _config.copyWith(showColVatRate: v))),
                      _buildColumnCheck('Výška DPH (€)', _config.showColVatAmount,
                          (v) => setState(() => _config = _config.copyWith(showColVatAmount: v))),
                      _buildColumnCheck('Posledný dátum nákupu', _config.showColLastPurchaseDate,
                          (v) => setState(() => _config = _config.copyWith(showColLastPurchaseDate: v))),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save),
                      label: Text(_saving ? 'Ukladám...' : 'Uložiť nastavenia'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required String Function(T) labelBuilder,
    required ValueChanged<T> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
      items: items
          .map((v) => DropdownMenuItem(value: v, child: Text(labelBuilder(v))))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  Widget _buildColorDropdown({
    required String label,
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String?>(
      value: _colorPresets.containsValue(value) ? value : null,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
      items: _colorPresets.entries
          .map((e) => DropdownMenuItem<String?>(
                value: e.value,
                child: Row(
                  children: [
                    if (e.value != null)
                      Container(
                        width: 20,
                        height: 20,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: _hexToColor(e.value!),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                      ),
                    Text(e.key),
                  ],
                ),
              ))
          .toList(),
      onChanged: (v) => onChanged(v),
    );
  }

  Widget _buildColumnCheck(String label, bool value, ValueChanged<bool> onChanged) {
    return CheckboxListTile(
      title: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      value: value,
      onChanged: (v) => onChanged(v ?? false),
      activeColor: const Color(0xFF6366F1),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
    );
  }

  static Color _hexToColor(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }
}
