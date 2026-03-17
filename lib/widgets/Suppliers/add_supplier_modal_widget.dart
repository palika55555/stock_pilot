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

  bool _isLoading = false;
  bool _isSaving = false;
  bool _isActive = true;

  bool get _isEditMode => widget.supplier != null;

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
  }

  @override
  void dispose() {
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

  Future<void> _fetchFinstatData() async {
    final ico = _icoController.text.trim();
    if (ico.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zadajte najprv IČO')),
      );
      return;
    }
    if (ico.length != 8 || !RegExp(r'^\d+$').hasMatch(ico)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('IČO musí obsahovať presne 8 číslic')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supplier = await _finstatService.fetchSupplierData(ico);
      if (supplier != null) {
        setState(() {
          _nameController.text = supplier.name;
          _emailController.text = supplier.email ?? '';
          _addressController.text = supplier.address ?? '';
          _cityController.text = supplier.city ?? '';
          _postalCodeController.text = supplier.postalCode ?? '';
          _dicController.text = supplier.dic ?? '';
          _icDphController.text = supplier.icDph ?? '';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba pri načítaní dát: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
              : _icDphController.text.trim(),
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
              : _icDphController.text.trim(),
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

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
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
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.borderDefault,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              // Header
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.accentGoldSubtle,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.local_shipping_rounded,
                      color: AppColors.accentGold,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      _isEditMode
                          ? 'Upraviť dodávateľa'
                          : 'Pridať nového dodávateľa',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.bgElevated,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.borderDefault),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textSecondary,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // IČO + Finstat lookup
              TextFormField(
                controller: _icoController,
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
                  hintText: _isEditMode ? null : 'Zadajte IČO a kliknite na lupu',
                  prefixIcon: const Icon(Icons.numbers,
                      color: AppColors.textSecondary, size: 20),
                  suffixIcon: _isEditMode
                      ? null
                      : (_isLoading
                          ? const Padding(
                              padding: EdgeInsets.all(10.0),
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
                              icon: const Icon(Icons.search,
                                  color: AppColors.accentGold),
                              onPressed: _fetchFinstatData,
                              tooltip: 'Načítať dáta z Finstatu',
                            )),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Zadajte IČO' : null,
              ),
              const SizedBox(height: 14),

              // Názov firmy
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

              // DPH + Email
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _vatController,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.dmSans(color: AppColors.textPrimary),
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
                      style: GoogleFonts.dmSans(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'E-mail',
                        prefixIcon: Icon(Icons.email_outlined,
                            color: AppColors.textSecondary, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Adresa
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

              // Mesto + PSČ
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _cityController,
                      style: GoogleFonts.dmSans(color: AppColors.textPrimary),
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
                      style: GoogleFonts.dmSans(color: AppColors.textPrimary),
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
              const SizedBox(height: 14),

              // DIČ + IČ DPH
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _dicController,
                      style: GoogleFonts.dmSans(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'DIČ',
                        hintText: 'Daňové ID',
                        prefixIcon: Icon(Icons.receipt_outlined,
                            color: AppColors.textSecondary, size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _icDphController,
                      style: GoogleFonts.dmSans(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'IČ DPH',
                        hintText: 'SK...',
                        prefixIcon: Icon(Icons.account_box_outlined,
                            color: AppColors.textSecondary, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Aktívny switch
              Container(
                decoration: BoxDecoration(
                  color: AppColors.bgElevated,
                  borderRadius: BorderRadius.circular(12),
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
              const SizedBox(height: 28),

              // Uložiť
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
