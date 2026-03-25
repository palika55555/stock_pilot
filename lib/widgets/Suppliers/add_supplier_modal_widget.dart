import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/supplier.dart';
import '../../services/External/finstat_service.dart';
import '../../services/Supplier/supplier_service.dart';
import '../../theme/app_theme.dart';

class AddSupplierModal extends StatefulWidget {
  final Supplier? supplier;

  const AddSupplierModal({super.key, this.supplier});

  @override
  State<AddSupplierModal> createState() => _AddSupplierModalState();
}

class _AddSupplierModalState extends State<AddSupplierModal> {
  final _formKey = GlobalKey<FormState>();
  final FinstatService _finstatService = FinstatService();
  final SupplierService _supplierService = SupplierService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _icoController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _postalCodeController = TextEditingController();
  final TextEditingController _dicController = TextEditingController();
  final TextEditingController _icDphController = TextEditingController();
  final TextEditingController _vatController = TextEditingController(
    text: '20',
  );

  final FocusNode _icoFocus = FocusNode();
  Timer? _icoDebounce;

  bool _isSaving = false;
  bool _isActive = true;

  /// Či práve beží lookup (manuálny alebo auto).
  bool _lookupInFlight = false;

  /// Posledný výsledok smart načítania (null = ešte žiadny pokus v tejto session).
  bool? _lookupSuccess;
  String? _lookupHint;

  bool get _isEditMode => widget.supplier != null;

  static const List<int> _vatPresets = [0, 5, 10, 19, 20, 23];

  @override
  void initState() {
    super.initState();
    if (_isEditMode && widget.supplier != null) {
      final s = widget.supplier!;
      _nameController.text = s.name;
      _icoController.text = s.ico;
      _emailController.text = s.email ?? '';
      _addressController.text = s.address ?? '';
      _cityController.text = s.city ?? '';
      _postalCodeController.text = s.postalCode ?? '';
      _dicController.text = s.dic ?? '';
      _icDphController.text = s.icDph ?? '';
      _vatController.text = s.defaultVatRate.toString();
      _isActive = s.isActive;
    }
    _icoController.addListener(_onIcoTextChanged);
    for (final c in <TextEditingController>[
      _nameController,
      _emailController,
      _addressController,
      _cityController,
      _postalCodeController,
      _dicController,
      _icDphController,
      _vatController,
    ]) {
      c.addListener(_refreshCompleteness);
    }
  }

  void _refreshCompleteness() {
    if (mounted) setState(() {});
  }

  void _onIcoTextChanged() {
    setState(() {
      if (_lookupSuccess != null || _lookupHint != null) {
        _lookupSuccess = null;
        _lookupHint = null;
      }
    });
    if (_isEditMode) return;
    _icoDebounce?.cancel();
    final ico = _icoController.text.trim();
    if (ico.length != 8 || !RegExp(r'^\d{8}$').hasMatch(ico)) return;
    _icoDebounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _fetchFinstatData(silent: true);
    });
  }

  @override
  void dispose() {
    _icoDebounce?.cancel();
    _icoController.removeListener(_onIcoTextChanged);
    for (final c in <TextEditingController>[
      _nameController,
      _emailController,
      _addressController,
      _cityController,
      _postalCodeController,
      _dicController,
      _icDphController,
      _vatController,
    ]) {
      c.removeListener(_refreshCompleteness);
    }
    _icoFocus.dispose();
    _nameController.dispose();
    _icoController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    _dicController.dispose();
    _icDphController.dispose();
    _vatController.dispose();
    super.dispose();
  }

  double get _formCompleteness {
    int ok = 0;
    const total = 9;
    if (_icoController.text.trim().length == 8) ok++;
    if (_nameController.text.trim().isNotEmpty) ok++;
    if (_vatController.text.trim().isNotEmpty) ok++;
    if (_emailController.text.trim().isNotEmpty) ok++;
    if (_addressController.text.trim().isNotEmpty) ok++;
    if (_cityController.text.trim().isNotEmpty) ok++;
    if (_postalCodeController.text.trim().isNotEmpty) ok++;
    if (_dicController.text.trim().isNotEmpty) ok++;
    if (_icDphController.text.trim().isNotEmpty) ok++;
    return ok / total;
  }

  Future<void> _fetchFinstatData({bool silent = false}) async {
    final ico = _icoController.text.trim();
    if (ico.isEmpty) {
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zadajte najprv IČO')),
        );
      }
      return;
    }
    if (ico.length != 8 || !RegExp(r'^\d+$').hasMatch(ico)) {
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('IČO musí obsahovať presne 8 číslic')),
        );
      }
      return;
    }

    setState(() {
      _lookupInFlight = true;
      _lookupSuccess = null;
      _lookupHint = null;
    });

    try {
      final supplier = await _finstatService.fetchSupplierData(ico);
      if (!mounted) return;
      if (_icoController.text.trim() != ico) return;
      if (supplier != null) {
        setState(() {
          _nameController.text = supplier.name;
          _emailController.text = supplier.email ?? '';
          _addressController.text = supplier.address ?? '';
          _cityController.text = supplier.city ?? '';
          _postalCodeController.text = supplier.postalCode ?? '';
          _dicController.text = supplier.dic ?? '';
          _icDphController.text = supplier.icDph ?? '';
          _lookupSuccess = true;
          _lookupHint = supplier.name;
        });
        HapticFeedback.lightImpact();
      } else {
        setState(() {
          _lookupSuccess = false;
          _lookupHint = 'Pre toto IČO sa nepodarilo získať údaje.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      if (_icoController.text.trim() != ico) return;
      setState(() {
        _lookupSuccess = false;
        _lookupHint = silent
            ? 'Chyba siete alebo registra. Skúste znova.'
            : e.toString();
      });
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba pri načítaní dát: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _lookupInFlight = false);
      }
    }
  }

  Future<void> _submitData() async {
    if (!_formKey.currentState!.validate()) return;

    final vat = int.tryParse(_vatController.text.trim()) ?? 20;
    final vatClamped = vat.clamp(0, 27);

    setState(() => _isSaving = true);
    try {
      if (_isEditMode && widget.supplier != null) {
        final updated = widget.supplier!.copyWith(
          name: _nameController.text.trim(),
          ico: _icoController.text.trim(),
          email: _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
          address: _addressController.text.trim().isEmpty
              ? null
              : _addressController.text.trim(),
          city: _cityController.text.trim().isEmpty
              ? null
              : _cityController.text.trim(),
          postalCode: _postalCodeController.text.trim().isEmpty
              ? null
              : _postalCodeController.text.trim(),
          dic: _dicController.text.trim().isEmpty
              ? null
              : _dicController.text.trim(),
          icDph: _icDphController.text.trim().isEmpty
              ? null
              : _icDphController.text.trim().toUpperCase(),
          defaultVatRate: vatClamped,
          isActive: _isActive,
        );
        await _supplierService.updateSupplier(updated);
        if (mounted) {
          Navigator.pop(context, updated);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dodávateľ bol upravený'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        final newSupplier = Supplier(
          name: _nameController.text.trim(),
          ico: _icoController.text.trim(),
          email: _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
          address: _addressController.text.trim().isEmpty
              ? null
              : _addressController.text.trim(),
          city: _cityController.text.trim().isEmpty
              ? null
              : _cityController.text.trim(),
          postalCode: _postalCodeController.text.trim().isEmpty
              ? null
              : _postalCodeController.text.trim(),
          dic: _dicController.text.trim().isEmpty
              ? null
              : _dicController.text.trim(),
          icDph: _icDphController.text.trim().isEmpty
              ? null
              : _icDphController.text.trim().toUpperCase(),
          defaultVatRate: vatClamped,
          isActive: _isActive,
        );
        final id = await _supplierService.createSupplier(newSupplier);
        if (mounted) {
          final created = newSupplier.copyWith(id: id);
          Navigator.pop(context, created);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dodávateľ bol pridaný'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String? _validateEmail(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return null;
    final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(t);
    return ok ? null : 'Neplatný formát e-mailu';
  }

  String? _validateDic(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return null;
    return RegExp(r'^\d{10}$').hasMatch(t) ? null : 'DIČ má 10 číslic';
  }

  String? _validateIcDph(String? v) {
    final t = v?.trim().toUpperCase() ?? '';
    if (t.isEmpty) return null;
    return RegExp(r'^SK\d{10}$').hasMatch(t)
        ? null
        : 'Očakávaný tvar SK + 10 číslic';
  }

  Widget _sectionLabel(String title, String subtitle, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accentGoldSubtle,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.accentGold),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    height: 1.25,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _smartStatusBanner() {
    if (_lookupInFlight) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppColors.infoSubtle,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.info.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.info,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Načítavam údaje z obchodného registra…',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (_lookupSuccess == true && _lookupHint != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppColors.successSubtle,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.auto_awesome_rounded,
                color: AppColors.success, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Smart doplnenie',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Polia boli vyplnené podľa IČO. Skontrolujte údaje pred uložením.',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      height: 1.35,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _lookupHint!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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
    if (_lookupSuccess == false && _lookupHint != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppColors.warningSubtle,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded,
                color: AppColors.warning, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _lookupHint!,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  height: 1.35,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _completenessStrip() {
    final p = _formCompleteness;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Úplnosť údajov',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                  letterSpacing: 0.3,
                ),
              ),
              Text(
                '${(p * 100).round()} %',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentGold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: p,
              minHeight: 6,
              backgroundColor: AppColors.borderDefault,
              color: AppColors.accentGold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _vatChips() {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _vatPresets.map((v) {
          final selected =
              _vatController.text.trim() == v.toString();
          return FilterChip(
            label: Text('$v %'),
            selected: selected,
            showCheckmark: false,
            selectedColor: AppColors.accentGoldSubtle,
            backgroundColor: AppColors.bgElevated,
            side: BorderSide(
              color: selected ? AppColors.accentGold : AppColors.borderDefault,
            ),
            labelStyle: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.accentGold : AppColors.textSecondary,
            ),
            onSelected: (_) {
              setState(() => _vatController.text = v.toString());
            },
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.bgElevated.withValues(alpha: 0.45),
            AppColors.bgCard,
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: const Border(
          top: BorderSide(color: AppColors.borderDefault, width: 1),
        ),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, bottomInset + 24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.borderDefault,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.accentGold.withValues(alpha: 0.25),
                          AppColors.bgElevated,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: const Icon(
                      Icons.local_shipping_rounded,
                      color: AppColors.accentGold,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEditMode
                              ? 'Upraviť dodávateľa'
                              : 'Pridať nového dodávateľa',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          _isEditMode
                              ? 'Upravte údaje a uložte zmeny.'
                              : 'IČO → automatické doplnenie z registra',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.bgElevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.borderDefault),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _completenessStrip(),
              _sectionLabel(
                'Identifikácia',
                'IČO vyhľadá automaticky po zadaní 8 číslic, alebo ťuknite na lupu.',
                Icons.tag_rounded,
              ),
              TextFormField(
                controller: _icoController,
                focusNode: _icoFocus,
                readOnly: _isEditMode,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.search,
                style: GoogleFonts.dmSans(
                  color: _isEditMode
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                ),
                onFieldSubmitted: (_) => _fetchFinstatData(),
                decoration: InputDecoration(
                  labelText: 'IČO',
                  hintText:
                      _isEditMode ? null : '8 číslic — doplní sa automaticky',
                  prefixIcon: const Icon(Icons.numbers,
                      color: AppColors.textSecondary, size: 20),
                  suffixIcon: _isEditMode
                      ? null
                      : (_lookupInFlight
                          ? const Padding(
                              padding: EdgeInsets.all(10),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.accentGold,
                                ),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.search_rounded,
                                  color: AppColors.accentGold),
                              onPressed: () => _fetchFinstatData(),
                              tooltip: 'Načítať z registra',
                            )),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Zadajte IČO' : null,
              ),
              const SizedBox(height: 12),
              _smartStatusBanner(),
              _sectionLabel(
                'Fakturačné údaje',
                'Názov a adresa pre doklady.',
                Icons.apartment_rounded,
              ),
              TextFormField(
                controller: _nameController,
                style: GoogleFonts.dmSans(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Názov firmy',
                  prefixIcon: Icon(Icons.business_rounded,
                      color: AppColors.textSecondary, size: 20),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Zadajte názov' : null,
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _vatController,
                      keyboardType: TextInputType.number,
                      style:
                          GoogleFonts.dmSans(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'DPH %',
                        hintText: '20',
                        prefixIcon: Icon(Icons.percent,
                            color: AppColors.textSecondary, size: 20),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(2),
                      ],
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        if (n == null || n < 0 || n > 27) return '0–27';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style:
                          GoogleFonts.dmSans(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'E-mail',
                        prefixIcon: Icon(Icons.email_outlined,
                            color: AppColors.textSecondary, size: 20),
                      ),
                      validator: _validateEmail,
                    ),
                  ),
                ],
              ),
              _vatChips(),
              const SizedBox(height: 6),
              TextFormField(
                controller: _addressController,
                style: GoogleFonts.dmSans(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Adresa',
                  hintText: 'Ulica a číslo',
                  prefixIcon: Icon(Icons.location_on_outlined,
                      color: AppColors.textSecondary, size: 20),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _cityController,
                      style:
                          GoogleFonts.dmSans(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Mesto',
                        prefixIcon: Icon(Icons.location_city_rounded,
                            color: AppColors.textSecondary, size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _postalCodeController,
                      keyboardType: TextInputType.number,
                      style:
                          GoogleFonts.dmSans(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'PSČ',
                        hintText: '067 45',
                        prefixIcon: Icon(Icons.markunread_mailbox_outlined,
                            color: AppColors.textSecondary, size: 20),
                      ),
                      maxLength: 6,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d\s]')),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _sectionLabel(
                'Daňové identifikátory',
                'DIČ a IČ DPH podľa výpisu z Finančnej správy.',
                Icons.receipt_long_rounded,
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _dicController,
                      keyboardType: TextInputType.number,
                      style:
                          GoogleFonts.dmSans(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'DIČ',
                        hintText: '10 číslic',
                        prefixIcon: Icon(Icons.receipt_outlined,
                            color: AppColors.textSecondary, size: 20),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      validator: _validateDic,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _icDphController,
                      style:
                          GoogleFonts.dmSans(color: AppColors.textPrimary),
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'IČ DPH',
                        hintText: 'SK1234567890',
                        prefixIcon: Icon(Icons.badge_outlined,
                            color: AppColors.textSecondary, size: 20),
                      ),
                      validator: _validateIcDph,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.bgElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: SwitchListTile(
                  title: Text(
                    'Aktívny',
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    _isActive
                        ? 'Zobrazený pri výbere pri príjemkách'
                        : 'Skrytý – nepoužíva sa pri nových príjemkách',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  value: _isActive,
                  activeThumbColor: AppColors.accentGold,
                  activeTrackColor: AppColors.accentGoldSubtle,
                  onChanged: (v) => setState(() => _isActive = v),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submitData,
                  child: _isSaving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.bgPrimary,
                          ),
                        )
                      : Text(
                          _isEditMode ? 'Uložiť zmeny' : 'Uložiť dodávateľa',
                          style: GoogleFonts.dmSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
