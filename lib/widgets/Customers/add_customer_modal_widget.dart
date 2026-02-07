import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/customer.dart';
import '../../services/customer/customer_service.dart';
import '../../services/External/finstat_service.dart';

class AddCustomerModal extends StatefulWidget {
  final Customer? customer;

  const AddCustomerModal({super.key, this.customer});

  @override
  State<AddCustomerModal> createState() => _AddCustomerModalState();
}

class _AddCustomerModalState extends State<AddCustomerModal> {
  final _formKey = GlobalKey<FormState>();
  final FinstatService _finstatService = FinstatService();
  final CustomerService _customerService = CustomerService();

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

  bool get _isEditMode => widget.customer != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode && widget.customer != null) {
      final cust = widget.customer!;
      _nameController.text = cust.name;
      _icoController.text = cust.ico;
      _emailController.text = cust.email ?? '';
      _addressController.text = cust.address ?? '';
      _cityController.text = cust.city ?? '';
      _postalCodeController.text = cust.postalCode ?? '';
      _dicController.text = cust.dic ?? '';
      _icDphController.text = cust.icDph ?? '';
      _vatController.text = cust.defaultVatRate.toString();
      _isActive = cust.isActive;
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Zadajte najprv IČO')));
      return;
    }
    if (ico.length != 8 || !RegExp(r'^\d+$').hasMatch(ico)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('IČO musí obsahovať presne 8 číslic')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _submitData() async {
    if (!_formKey.currentState!.validate()) return;

    final vat = int.tryParse(_vatController.text.trim()) ?? 20;
    final vatClamped = vat.clamp(0, 27);

    setState(() => _isSaving = true);
    try {
      if (_isEditMode && widget.customer != null) {
        final updated = widget.customer!.copyWith(
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
        await _customerService.updateCustomer(updated);
        if (mounted) {
          Navigator.pop(context, updated);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Zákazník bol upravený'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        final newCustomer = Customer(
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
        final id = await _customerService.createCustomer(newCustomer);
        if (mounted) {
          final created = newCustomer.copyWith(id: id);
          Navigator.pop(context, created);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Zákazník bol pridaný'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isEditMode
                        ? 'Upraviť zákazníka'
                        : 'Pridať nového zákazníka',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _icoController,
                readOnly: _isEditMode,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.search,
                onFieldSubmitted: (_) => _fetchFinstatData(),
                decoration: InputDecoration(
                  labelText: 'IČO',
                  hintText: _isEditMode
                      ? null
                      : 'Zadajte IČO a kliknite na lupu',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.numbers),
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
                                  ),
                                ),
                              )
                            : IconButton(
                                icon: const Icon(
                                  Icons.search,
                                  color: Colors.blue,
                                ),
                                onPressed: _fetchFinstatData,
                                tooltip: 'Načítať dáta z Finstatu',
                              )),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Zadajte IČO' : null,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Názov firmy',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Zadajte názov' : null,
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _vatController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'DPH % (pre cenové ponuky)',
                        hintText: '20',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.percent),
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
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'E-mail',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Adresa',
                  hintText: 'Ulica a číslo',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _cityController,
                      decoration: const InputDecoration(
                        labelText: 'Mesto',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_city),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _postalCodeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'PSČ',
                        hintText: '067 45',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.markunread_mailbox),
                      ),
                      maxLength: 6,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d\s]')),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              SwitchListTile(
                title: const Text('Aktívny'),
                subtitle: Text(
                  _isActive
                      ? 'Zobrazený pri výbere pri cenových ponukách'
                      : 'Skrytý – nepoužíva sa pri nových cenových ponukách',
                ),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _dicController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'DIČ',
                        hintText: 'Daňové ID',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.receipt),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _icDphController,
                      decoration: const InputDecoration(
                        labelText: 'IČ DPH',
                        hintText: 'SK...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.account_box),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submitData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
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
                      : Text(_isEditMode ? 'Uložiť zmeny' : 'Uložiť zákazníka'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
