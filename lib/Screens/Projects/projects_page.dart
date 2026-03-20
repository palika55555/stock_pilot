import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/project.dart';
import '../../services/Project/project_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/Projects/add_project_modal_widget.dart';

class ProjectsPage extends StatefulWidget {
  const ProjectsPage({super.key});

  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  final ProjectService _service = ProjectService();
  List<Project> _projects = [];
  List<Project> _filtered = [];
  bool _loading = true;
  String _search = '';
  ProjectStatus? _statusFilter; // null = všetky

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _service.getAllProjects();
    if (!mounted) return;
    setState(() {
      _projects = list;
      _loading = false;
      _applyFilter();
    });
  }

  void _applyFilter() {
    final q = _search.toLowerCase();
    _filtered = _projects.where((p) {
      final matchStatus = _statusFilter == null || p.status == _statusFilter;
      final matchSearch = q.isEmpty ||
          p.name.toLowerCase().contains(q) ||
          p.projectNumber.toLowerCase().contains(q) ||
          (p.customerName?.toLowerCase().contains(q) ?? false) ||
          (p.siteCity?.toLowerCase().contains(q) ?? false);
      return matchStatus && matchSearch;
    }).toList();
  }

  void _openModal({Project? project}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddProjectModal(
        project: project,
        onSaved: _load,
      ),
    );
  }

  Future<void> _delete(Project p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Zmazať zákazku'),
        content: Text('Naozaj zmazať zákazku "${p.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Zrušiť')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Zmazať', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _service.deleteProject(p.id!);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zákazky'),
        backgroundColor: AppColors.accentGold,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) => _ProjectCard(
                            project: _filtered[i],
                            onEdit: () => _openModal(project: _filtered[i]),
                            onDelete: () => _delete(_filtered[i]),
                          ),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openModal(),
        backgroundColor: AppColors.accentGold,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nová zákazka', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Hľadať zákazku...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              suffixIcon: _search.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() { _search = ''; _applyFilter(); }))
                  : null,
            ),
            onChanged: (v) => setState(() { _search = v; _applyFilter(); }),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(label: 'Všetky', selected: _statusFilter == null, onTap: () => setState(() { _statusFilter = null; _applyFilter(); })),
                const SizedBox(width: 6),
                _FilterChip(label: 'Aktívne', selected: _statusFilter == ProjectStatus.active, onTap: () => setState(() { _statusFilter = ProjectStatus.active; _applyFilter(); })),
                const SizedBox(width: 6),
                _FilterChip(label: 'Dokončené', selected: _statusFilter == ProjectStatus.completed, onTap: () => setState(() { _statusFilter = ProjectStatus.completed; _applyFilter(); })),
                const SizedBox(width: 6),
                _FilterChip(label: 'Zrušené', selected: _statusFilter == ProjectStatus.cancelled, onTap: () => setState(() { _statusFilter = ProjectStatus.cancelled; _applyFilter(); })),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.construction_rounded, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            _search.isNotEmpty || _statusFilter != null ? 'Žiadne zákazky nevyhovujú filtru' : 'Zatiaľ žiadne zákazky',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
          if (_search.isEmpty && _statusFilter == null) ...[
            const SizedBox(height: 8),
            Text('Kliknite na + pre vytvorenie novej zákazky', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentGold : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.accentGold : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.grey.shade700,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final Project project;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProjectCard({required this.project, required this.onEdit, required this.onDelete});

  Color _statusColor(ProjectStatus s) {
    switch (s) {
      case ProjectStatus.active:
        return Colors.green;
      case ProjectStatus.completed:
        return Colors.blue;
      case ProjectStatus.cancelled:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd.MM.yyyy');
    final hasDate = project.startDate != null || project.endDate != null;
    final hasBudget = project.budget != null;
    final currencyFmt = NumberFormat('#,##0.00', 'sk_SK');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.accentGold.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(project.projectNumber, style: TextStyle(fontSize: 11, color: AppColors.accentGold, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: _statusColor(project.status), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 4),
                  Text(project.status.label, style: TextStyle(fontSize: 12, color: _statusColor(project.status))),
                  const Spacer(),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') onEdit();
                      if (v == 'delete') onDelete();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Upraviť')])),
                      const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 18, color: Colors.red), SizedBox(width: 8), Text('Zmazať', style: TextStyle(color: Colors.red))])),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(project.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              if (project.customerName != null) ...[
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.person_outline, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(project.customerName!, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                ]),
              ],
              if (project.siteCity != null || project.siteAddress != null) ...[
                const SizedBox(height: 2),
                Row(children: [
                  Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Expanded(child: Text(
                    [if (project.siteAddress != null) project.siteAddress!, if (project.siteCity != null) project.siteCity!].join(', '),
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    overflow: TextOverflow.ellipsis,
                  )),
                ]),
              ],
              if (hasDate || hasBudget) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    if (hasDate)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.calendar_today_outlined, size: 13, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          [if (project.startDate != null) fmt.format(project.startDate!), if (project.endDate != null) fmt.format(project.endDate!)].join(' – '),
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ]),
                    if (hasBudget)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.euro_outlined, size: 13, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text('${currencyFmt.format(project.budget!)} €', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ]),
                  ],
                ),
              ],
              if (project.responsiblePerson != null) ...[
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.badge_outlined, size: 13, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(project.responsiblePerson!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
