import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/warehouse.dart';
import '../../services/warehouse/warehouse_service.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';

class AddWarehouseModal extends StatefulWidget {
  final Warehouse? warehouse;

  const AddWarehouseModal({super.key, this.warehouse});

  @override
  State<AddWarehouseModal> createState() => _AddWarehouseModalState();
}

class _AddWarehouseModalState extends State<AddWarehouseModal> {
  final _formKey = GlobalKey<FormState>();
  final WarehouseService _warehouseService = WarehouseService();

  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _addressController;
  late final TextEditingController _cityController;
  late final TextEditingController _postalCodeController;

  bool _isSaving = false;
  bool _isActive = true;
  late String _warehouseType;

  bool get _isEditMode => widget.warehouse != null;

  @override
  void initState() {
    super.initState();
    final w = widget.warehouse;
    _nameController = TextEditingController(text: w?.name ?? '');
    _codeController = TextEditingController(text: w?.code ?? '');
    _addressController = TextEditingController(text: w?.address ?? '');
    _cityController = TextEditingController(text: w?.city ?? '');
    _postalCodeController = TextEditingController(text: w?.postalCode ?? '');
    _isActive = w?.isActive ?? true;
    _warehouseType = w?.warehouseType ?? WarehouseType.predaj;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  Future<void> _submitData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      Warehouse warehouseData;

      if (_isEditMode) {
        warehouseData = Warehouse(
          id: widget.warehouse?.id,
          name: _nameController.text.trim(),
          code: _codeController.text.trim(),
          warehouseType: _warehouseType,
          address: _addressController.text.trim().isEmpty
              ? null
              : _addressController.text.trim(),
          city: _cityController.text.trim().isEmpty
              ? null
              : _cityController.text.trim(),
          postalCode: _postalCodeController.text.trim().isEmpty
              ? null
              : _postalCodeController.text.trim(),
          isActive: _isActive,
        );
        await _warehouseService.updateWarehouse(warehouseData);
      } else {
        final newWarehouse = Warehouse(
          name: _nameController.text.trim(),
          code: _codeController.text.trim(),
          warehouseType: _warehouseType,
          address: _addressController.text.trim().isEmpty
              ? null
              : _addressController.text.trim(),
          city: _cityController.text.trim().isEmpty
              ? null
              : _cityController.text.trim(),
          postalCode: _postalCodeController.text.trim().isEmpty
              ? null
              : _postalCodeController.text.trim(),
          isActive: _isActive,
        );
        final id = await _warehouseService.createWarehouse(newWarehouse);
        warehouseData = newWarehouse.copyWith(id: id);
      }

      if (mounted) {
        Navigator.pop(context, warehouseData);
        _showSnackBar(
          _isEditMode
              ? AppLocalizations.of(context)!.warehouseUpdated
              : AppLocalizations.of(context)!.warehouseSaved,
          AppColors.success,
        );
      }
    } catch (e) {
      if (mounted) _showSnackBar('Chyba: $e', AppColors.danger);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.borderDefault,
                  borderRadius: BorderRadius.circular(10),
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
                      Icons.warehouse_rounded,
                      color: AppColors.accentGold,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _isEditMode ? l10n.editWarehouse : l10n.addNewWarehouse,
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

              // Názov skladu
              TextFormField(
                controller: _nameController,
                style: GoogleFonts.dmSans(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: l10n.warehouseName,
                  prefixIcon: const Icon(Icons.drive_file_rename_outline_rounded,
                      color: AppColors.accentGold, size: 20),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Zadajte názov skladu' : null,
              ),
              const SizedBox(height: 14),

              // Kód skladu
              TextFormField(
                controller: _codeController,
                readOnly: _isEditMode,
                style: GoogleFonts.dmSans(
                  color: _isEditMode
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  labelText: l10n.warehouseCode,
                  hintText: 'SKLAD-01',
                  prefixIcon: const Icon(Icons.fingerprint_rounded,
                      color: AppColors.accentGold, size: 20),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Zadajte kód skladu' : null,
              ),
              const SizedBox(height: 14),

              // Typ skladu
              DropdownButtonFormField<String>(
                value: _warehouseType,
                dropdownColor: AppColors.bgElevated,
                style: GoogleFonts.dmSans(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: l10n.warehouseType,
                  prefixIcon: const Icon(Icons.category_rounded,
                      color: AppColors.accentGold, size: 20),
                ),
                items: [
                  DropdownMenuItem(
                    value: WarehouseType.predaj,
                    child: Text(l10n.warehouseTypePredaj),
                  ),
                  DropdownMenuItem(
                    value: WarehouseType.vyroba,
                    child: Text(l10n.warehouseTypeVyroba),
                  ),
                  DropdownMenuItem(
                    value: WarehouseType.rezijnyMaterial,
                    child: Text(l10n.warehouseTypeRezijnyMaterial),
                  ),
                  DropdownMenuItem(
                    value: WarehouseType.sklad,
                    child: Text(l10n.warehouseTypeSklad),
                  ),
                ],
                onChanged: (v) =>
                    setState(() => _warehouseType = v ?? WarehouseType.predaj),
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
                        prefixIcon: Icon(Icons.local_post_office_outlined,
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
                    l10n.active,
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    _isActive
                        ? 'Zobrazuje sa v aplikácii'
                        : 'Sklad je dočasne skrytý',
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

              // Tlačidlo uložiť
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
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isEditMode
                                  ? Icons.check_circle_outline
                                  : Icons.add_circle_outline,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _isEditMode
                                  ? l10n.saveChanges
                                  : l10n.saveWarehouse,
                              style: GoogleFonts.dmSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
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
