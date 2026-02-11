import 'package:flutter/material.dart';
import '../../models/warehouse.dart';
import '../../services/warehouse/warehouse_service.dart';
import '../../l10n/app_localizations.dart';

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
          Colors.green,
        );
      }
    } catch (e) {
      if (mounted) _showSnackBar('Chyba: $e', Colors.red);
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

  InputDecoration _buildInputDecoration(
    String label,
    IconData icon, {
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: const Color(0xFF6366F1), size: 22),
      filled: true,
      fillColor: Colors.grey[50],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[200]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, bottomInset + 24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Držiak pre BottomSheet
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFF6366F1).withOpacity(0.1),
                    child: const Icon(
                      Icons.warehouse_rounded,
                      color: Color(0xFF6366F1),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _isEditMode ? l10n.editWarehouse : l10n.addNewWarehouse,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey[100],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _nameController,
                decoration: _buildInputDecoration(
                  l10n.warehouseName,
                  Icons.drive_file_rename_outline_rounded,
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Zadajte názov skladu' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _codeController,
                readOnly: _isEditMode,
                decoration: _buildInputDecoration(
                  l10n.warehouseCode,
                  Icons.fingerprint_rounded,
                  hint: 'SKLAD-01',
                ),
                style: _isEditMode ? TextStyle(color: Colors.grey[600]) : null,
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Zadajte kód skladu' : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _warehouseType,
                decoration: _buildInputDecoration(
                  l10n.warehouseType,
                  Icons.category_rounded,
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
                onChanged: (v) => setState(() => _warehouseType = v ?? WarehouseType.predaj),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _addressController,
                decoration: _buildInputDecoration(
                  'Adresa',
                  Icons.location_on_outlined,
                  hint: 'Ulica a číslo',
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _cityController,
                      decoration: _buildInputDecoration(
                        'Mesto',
                        Icons.location_city_rounded,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _postalCodeController,
                      keyboardType: TextInputType.number,
                      decoration: _buildInputDecoration(
                        'PSČ',
                        Icons.local_post_office_outlined,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: SwitchListTile(
                  title: Text(
                    l10n.active,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Text(
                    _isActive
                        ? 'Zobrazuje sa v aplikácii'
                        : 'Sklad je dočasne skrytý',
                  ),
                  value: _isActive,
                  activeColor: const Color(0xFF6366F1),
                  onChanged: (v) => setState(() => _isActive = v),
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submitData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isEditMode
                                  ? Icons.check_circle_outline
                                  : Icons.add_circle_outline,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _isEditMode
                                  ? l10n.saveChanges
                                  : l10n.saveWarehouse,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
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
