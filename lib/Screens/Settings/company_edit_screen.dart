import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/company.dart';
import '../../services/company/company_service.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/common/standard_text_field.dart';

class CompanyEditScreen extends StatefulWidget {
  const CompanyEditScreen({super.key});

  @override
  State<CompanyEditScreen> createState() => _CompanyEditScreenState();
}

class _CompanyEditScreenState extends State<CompanyEditScreen> {
  final CompanyService _companyService = CompanyService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _postalCodeController = TextEditingController();
  final TextEditingController _countryController = TextEditingController(text: 'Slovensko');
  final TextEditingController _icoController = TextEditingController();
  final TextEditingController _icDphController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _webController = TextEditingController();
  final TextEditingController _ibanController = TextEditingController();
  final TextEditingController _swiftController = TextEditingController();
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _registerInfoController = TextEditingController();

  String? _logoPath;
  bool _vatPayer = true;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadCompany();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    _countryController.dispose();
    _icoController.dispose();
    _icDphController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _webController.dispose();
    _ibanController.dispose();
    _swiftController.dispose();
    _bankNameController.dispose();
    _accountController.dispose();
    _registerInfoController.dispose();
    super.dispose();
  }

  Future<void> _loadCompany() async {
    setState(() => _loading = true);
    final company = await _companyService.getCompany();
    if (mounted && company != null) {
      _nameController.text = company.name;
      _addressController.text = company.address ?? '';
      _cityController.text = company.city ?? '';
      _postalCodeController.text = company.postalCode ?? '';
      _countryController.text = company.country ?? 'Slovensko';
      _icoController.text = company.ico ?? '';
      _icDphController.text = company.icDph ?? '';
      _vatPayer = company.vatPayer;
      _phoneController.text = company.phone ?? '';
      _emailController.text = company.email ?? '';
      _webController.text = company.web ?? '';
      _ibanController.text = company.iban ?? '';
      _swiftController.text = company.swift ?? '';
      _bankNameController.text = company.bankName ?? '';
      _accountController.text = company.account ?? '';
      _registerInfoController.text = company.registerInfo ?? '';
      _logoPath = company.logoPath;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty || result.files.single.path == null) return;
    
    final pickedPath = result.files.single.path!;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final ext = result.files.single.extension;
      final destPath = '${dir.path}/company_logo.${ext ?? 'png'}';
      
      await File(pickedPath).copy(destPath);
      if (mounted) setState(() => _logoPath = destPath);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba pri ukladaní loga: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _removeLogo() {
    setState(() => _logoPath = null);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    
    final company = Company(
      id: 1,
      name: _nameController.text.trim(),
      address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      city: _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
      postalCode: _postalCodeController.text.trim().isEmpty ? null : _postalCodeController.text.trim(),
      country: _countryController.text.trim().isEmpty ? null : _countryController.text.trim(),
      ico: _icoController.text.trim().isEmpty ? null : _icoController.text.trim(),
      icDph: _icDphController.text.trim().isEmpty ? null : _icDphController.text.trim(),
      vatPayer: _vatPayer,
      phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      web: _webController.text.trim().isEmpty ? null : _webController.text.trim(),
      iban: _ibanController.text.trim().isEmpty ? null : _ibanController.text.trim(),
      swift: _swiftController.text.trim().isEmpty ? null : _swiftController.text.trim(),
      bankName: _bankNameController.text.trim().isEmpty ? null : _bankNameController.text.trim(),
      account: _accountController.text.trim().isEmpty ? null : _accountController.text.trim(),
      registerInfo: _registerInfoController.text.trim().isEmpty ? null : _registerInfoController.text.trim(),
      logoPath: _logoPath,
    );

    await _companyService.saveCompany(company);
    
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.saveChanges), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    }
  }

  Widget _sectionCard({required String title, required IconData icon, required List<Widget> children}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16), 
        side: BorderSide(color: Colors.grey.shade200),
      ),
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.1), 
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.teal, size: 22),
                ),
                const SizedBox(width: 12),
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _input(String label, TextEditingController controller, {int maxLines = 1, TextInputType? keyboardType, String? Function(String?)? validator, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: StandardTextField(
        controller: controller,
        labelText: label,
        icon: icon,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(l10n.ourCompany),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!_loading)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving 
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                    : const Icon(Icons.save, size: 20, color: Colors.white),
                label: Text(l10n.saveChanges, style: const TextStyle(color: Colors.white)),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _sectionCard(
                    title: 'Logo firmy',
                    icon: Icons.image_outlined,
                    children: [
                      const Text('Logo sa zobrazí na tlačených dokladoch', style: TextStyle(fontSize: 13, color: Colors.grey)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          if (_logoPath != null && File(_logoPath!).existsSync())
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(File(_logoPath!), width: 100, height: 100, fit: BoxFit.contain),
                            )
                          else
                            Container(
                              width: 100, height: 100,
                              decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
                              child: Icon(Icons.business, size: 40, color: Colors.grey.shade400),
                            ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                FilledButton.tonalIcon(
                                  onPressed: _pickLogo,
                                  icon: const Icon(Icons.add_photo_alternate),
                                  label: Text(_logoPath != null ? 'Zmeniť logo' : 'Pridať logo'),
                                ),
                                if (_logoPath != null)
                                  TextButton.icon(
                                    onPressed: _removeLogo,
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    label: const Text('Odstrániť', style: TextStyle(color: Colors.red)),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  _sectionCard(
                    title: 'Základné údaje',
                    icon: Icons.business_center_outlined,
                    children: [
                      _input('Názov firmy *', _nameController, validator: (v) => v?.isEmpty ?? true ? 'Povinný údaj' : null),
                      _input('Adresa', _addressController),
                      Row(
                        children: [
                          Expanded(flex: 2, child: _input('Mesto', _cityController)),
                          const SizedBox(width: 12),
                          Expanded(child: _input('PSČ', _postalCodeController)),
                        ],
                      ),
                      _input('Krajina', _countryController),
                      _input('Registračné údaje', _registerInfoController, maxLines: 2),
                      Row(
                        children: [
                          Expanded(child: _input('IČO', _icoController)),
                          const SizedBox(width: 12),
                          Expanded(child: _input('IČ DPH', _icDphController)),
                        ],
                      ),
                      SwitchListTile(
                        title: Text(l10n.vatPayer),
                        value: _vatPayer,
                        onChanged: (v) => setState(() => _vatPayer = v),
                        activeColor: Colors.teal,
                      ),
                    ],
                  ),
                  _sectionCard(
                    title: 'Kontakt a Banka',
                    icon: Icons.contact_phone_outlined,
                    children: [
                      _input('E-mail', _emailController, keyboardType: TextInputType.emailAddress),
                      _input('Telefón', _phoneController),
                      _input('IBAN', _ibanController),
                      _input('SWIFT', _swiftController),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}