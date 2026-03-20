import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/customer.dart';
import '../../models/project.dart';
import '../../services/Project/project_service.dart';
import '../../services/Database/database_service.dart';
import '../../theme/app_theme.dart';

class AddProjectModal extends StatefulWidget {
  final Project? project; // null = nový projekt
  final VoidCallback onSaved;

  const AddProjectModal({super.key, this.project, required this.onSaved});

  @override
  State<AddProjectModal> createState() => _AddProjectModalState();
}

class _AddProjectModalState extends State<AddProjectModal> {
  final _formKey = GlobalKey<FormState>();
  final ProjectService _service = ProjectService();
  final DatabaseService _db = DatabaseService();

  final _nameController = TextEditingController();
  final _siteAddressController = TextEditingController();
  final _siteCityController = TextEditingController();
  final _budgetController = TextEditingController();
  final _responsiblePersonController = TextEditingController();
  final _notesController = TextEditingController();

  ProjectStatus _status = ProjectStatus.active;
  Customer? _selectedCustomer;
  List<Customer> _customers = [];
  DateTime? _startDate;
  DateTime? _endDate;
  bool _saving = false;

  bool get _isEdit => widget.project != null;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
    if (_isEdit) {
      final p = widget.project!;
      _nameController.text = p.name;
      _siteAddressController.text = p.siteAddress ?? '';
      _siteCityController.text = p.siteCity ?? '';
      _budgetController.text = p.budget != null ? p.budget!.toStringAsFixed(2) : '';
      _responsiblePersonController.text = p.responsiblePerson ?? '';
      _notesController.text = p.notes ?? '';
      _status = p.status;
      _startDate = p.startDate;
      _endDate = p.endDate;
    }
  }

  Future<void> _loadCustomers() async {
    final list = await _db.getActiveCustomers();
    if (!mounted) return;
    setState(() {
      _customers = list;
      if (_isEdit && widget.project!.customerId != null) {
        _selectedCustomer = list.where((c) => c.id == widget.project!.customerId).firstOrNull;
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _siteAddressController.dispose();
    _siteCityController.dispose();
    _budgetController.dispose();
    _responsiblePersonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isStart) async {
    final initial = (isStart ? _startDate : _endDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final budget = _budgetController.text.trim().isEmpty ? null : double.tryParse(_budgetController.text.trim().replaceAll(',', '.'));
      final project = Project(
        id: widget.project?.id,
        projectNumber: widget.project?.projectNumber ?? '',
        name: _nameController.text.trim(),
        status: _status,
        customerId: _selectedCustomer?.id,
        customerName: _selectedCustomer?.name,
        siteAddress: _siteAddressController.text.trim().isEmpty ? null : _siteAddressController.text.trim(),
        siteCity: _siteCityController.text.trim().isEmpty ? null : _siteCityController.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        budget: budget,
        responsiblePerson: _responsiblePersonController.text.trim().isEmpty ? null : _responsiblePersonController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        createdAt: widget.project?.createdAt ?? DateTime.now(),
      );

      if (_isEdit) {
        await _service.updateProject(project);
      } else {
        await _service.createProject(project);
      }
      if (mounted) Navigator.of(context).pop();
      widget.onSaved();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd.MM.yyyy');
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Text(
                    _isEdit ? 'Upraviť zákazku' : 'Nová zákazka',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Zrušiť')),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  children: [
                    // Název
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Názov zákazky *', border: OutlineInputBorder()),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Povinné pole' : null,
                    ),
                    const SizedBox(height: 16),

                    // Stav
                    DropdownButtonFormField<ProjectStatus>(
                      value: _status,
                      decoration: const InputDecoration(labelText: 'Stav', border: OutlineInputBorder()),
                      items: ProjectStatus.values.map((s) => DropdownMenuItem(value: s, child: Text(s.label))).toList(),
                      onChanged: (v) => setState(() => _status = v ?? ProjectStatus.active),
                    ),
                    const SizedBox(height: 16),

                    // Zákazník
                    DropdownButtonFormField<Customer>(
                      value: _selectedCustomer,
                      decoration: const InputDecoration(labelText: 'Zákazník', border: OutlineInputBorder()),
                      hint: const Text('Vyberte zákazníka'),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<Customer>(value: null, child: Text('— Bez zákazníka —')),
                        ..._customers.map((c) => DropdownMenuItem(value: c, child: Text(c.name))),
                      ],
                      onChanged: (v) => setState(() => _selectedCustomer = v),
                    ),
                    const SizedBox(height: 16),

                    // Adresa stavby
                    TextFormField(
                      controller: _siteAddressController,
                      decoration: const InputDecoration(labelText: 'Adresa stavby', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _siteCityController,
                      decoration: const InputDecoration(labelText: 'Mesto stavby', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),

                    // Dátumy
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _pickDate(true),
                            child: InputDecorator(
                              decoration: const InputDecoration(labelText: 'Dátum od', border: OutlineInputBorder()),
                              child: Text(_startDate != null ? fmt.format(_startDate!) : '—'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () => _pickDate(false),
                            child: InputDecorator(
                              decoration: const InputDecoration(labelText: 'Dátum do', border: OutlineInputBorder()),
                              child: Text(_endDate != null ? fmt.format(_endDate!) : '—'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Rozpočet
                    TextFormField(
                      controller: _budgetController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Rozpočet (€)', border: OutlineInputBorder(), suffixText: '€'),
                    ),
                    const SizedBox(height: 12),

                    // Zodpovedná osoba
                    TextFormField(
                      controller: _responsiblePersonController,
                      decoration: const InputDecoration(labelText: 'Zodpovedná osoba', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),

                    // Poznámky
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Poznámky', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentGold),
                        child: _saving
                            ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                            : Text(_isEdit ? 'Uložiť zmeny' : 'Vytvoriť zákazku',
                                style: const TextStyle(color: Colors.white, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
