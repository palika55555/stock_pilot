import 'dart:ui';

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
  ProjectStatus? _statusFilter;

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
        backgroundColor: AppColors.bgCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Zmazať zákazku', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Naozaj zmazať zákazku "${p.name}"?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Zrušiť', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Zmazať', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _service.deleteProject(p.id!);
      _load();
    }
  }

  Color _statusAccent(ProjectStatus s) {
    switch (s) {
      case ProjectStatus.active:
        return AppColors.success;
      case ProjectStatus.completed:
        return AppColors.info;
      case ProjectStatus.cancelled:
        return AppColors.danger;
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 960;
    final horizontalPad = isWide ? 28.0 : 20.0;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.bgPrimary,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.bgCard.withValues(alpha: 0.9),
                border: const Border(
                  bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
                ),
              ),
              child: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: false,
                leading: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.bgInput,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderSubtle, width: 1),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                title: const Text(
                  'Zákazky',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accentGold),
            )
          : RefreshIndicator(
              color: AppColors.accentGold,
              backgroundColor: AppColors.bgCard,
              onRefresh: _load,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).top + 56)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(horizontalPad, 0, horizontalPad, 8),
                      child: _buildIntroCard(),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(horizontalPad, 0, horizontalPad, 16),
                      child: _buildFiltersPanel(),
                    ),
                  ),
                  if (_projects.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(isSearchEmpty: false),
                    )
                  else if (_filtered.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(isSearchEmpty: true),
                    )
                  else if (isWide)
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(horizontalPad, 0, horizontalPad, 100),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 14,
                          childAspectRatio: 1.45,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildProjectCard(_filtered[index]),
                          childCount: _filtered.length,
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(horizontalPad, 0, horizontalPad, 100),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildProjectCard(_filtered[index]),
                          ),
                          childCount: _filtered.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: FloatingActionButton.extended(
          onPressed: () => _openModal(),
          backgroundColor: AppColors.accentGold,
          foregroundColor: AppColors.bgPrimary,
          elevation: 6,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Nová zákazka', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Widget _buildIntroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.bgElevated,
            AppColors.bgCard.withValues(alpha: 0.92),
          ],
        ),
        border: Border.all(color: AppColors.borderSubtle, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.accentGoldSubtle,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.accentGold.withValues(alpha: 0.35),
              ),
            ),
            child: const Icon(
              Icons.construction_rounded,
              color: AppColors.accentGold,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'STAVBY A PROJEKTY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Čísla zákaziek, zákazníci, miesta realizácie a rozpočty na jednom mieste.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    color: AppColors.textSecondary.withValues(alpha: 0.95),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersPanel() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderSubtle, width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'VYHĽADÁVANIE',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                onChanged: (v) => setState(() {
                  _search = v;
                  _applyFilter();
                }),
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                cursorColor: AppColors.accentGold,
                decoration: InputDecoration(
                  hintText: 'Číslo, názov, zákazník alebo mesto…',
                  hintStyle: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.85)),
                  prefixIcon: Icon(Icons.search_rounded, color: AppColors.accentGold.withValues(alpha: 0.9)),
                  suffixIcon: _search.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded, color: AppColors.textMuted),
                          onPressed: () => setState(() {
                            _search = '';
                            _applyFilter();
                          }),
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.bgInput,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.borderDefault),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.borderSubtle),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.accentGold.withValues(alpha: 0.6)),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'STAV',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _statusChip(
                    label: 'Všetky',
                    selected: _statusFilter == null,
                    accent: AppColors.textSecondary,
                    onTap: () => setState(() {
                      _statusFilter = null;
                      _applyFilter();
                    }),
                  ),
                  _statusChip(
                    label: 'Aktívne',
                    selected: _statusFilter == ProjectStatus.active,
                    accent: AppColors.success,
                    onTap: () => setState(() {
                      _statusFilter = ProjectStatus.active;
                      _applyFilter();
                    }),
                  ),
                  _statusChip(
                    label: 'Dokončené',
                    selected: _statusFilter == ProjectStatus.completed,
                    accent: AppColors.info,
                    onTap: () => setState(() {
                      _statusFilter = ProjectStatus.completed;
                      _applyFilter();
                    }),
                  ),
                  _statusChip(
                    label: 'Zrušené',
                    selected: _statusFilter == ProjectStatus.cancelled,
                    accent: AppColors.danger,
                    onTap: () => setState(() {
                      _statusFilter = ProjectStatus.cancelled;
                      _applyFilter();
                    }),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChip({
    required String label,
    required bool selected,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? accent.withValues(alpha: 0.65) : AppColors.borderSubtle,
              width: selected ? 1.5 : 1,
            ),
            color: selected ? accent.withValues(alpha: 0.18) : AppColors.bgInput.withValues(alpha: 0.85),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(Icons.check_rounded, size: 16, color: accent),
                ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({required bool isSearchEmpty}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.accentGoldSubtle,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Icon(
              isSearchEmpty ? Icons.search_off_rounded : Icons.construction_rounded,
              size: 48,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isSearchEmpty
                ? 'Žiadna zákazka nevyhovuje filtru'
                : 'Zatiaľ žiadne zákazky',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isSearchEmpty
                ? 'Upravte vyhľadávanie alebo stav.'
                : 'Kliknite na „Nová zákazka“ a vytvorte prvú položku.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectCard(Project project) {
    final fmt = DateFormat('dd.MM.yyyy');
    final hasDate = project.startDate != null || project.endDate != null;
    final hasBudget = project.budget != null;
    final currencyFmt = NumberFormat('#,##0.00', 'sk_SK');
    final accent = _statusAccent(project.status);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openModal(project: project),
        borderRadius: BorderRadius.circular(20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderSubtle, width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          accent,
                          accent.withValues(alpha: 0.55),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.accentGold.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: AppColors.accentGold.withValues(alpha: 0.28),
                                        ),
                                      ),
                                      child: Text(
                                        project.projectNumber,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.accentGold,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      project.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                        height: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                margin: const EdgeInsets.only(left: 6),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: accent.withValues(alpha: 0.35)),
                                ),
                                child: Text(
                                  project.status.label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: accent,
                                  ),
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: Icon(Icons.more_vert_rounded, color: AppColors.textMuted.withValues(alpha: 0.9)),
                                color: AppColors.bgElevated,
                                onSelected: (v) {
                                  if (v == 'edit') _openModal(project: project);
                                  if (v == 'delete') _delete(project);
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
                                        SizedBox(width: 8),
                                        Text('Upraviť', style: TextStyle(color: AppColors.textPrimary)),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                                        SizedBox(width: 8),
                                        Text('Zmazať', style: TextStyle(color: AppColors.danger)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (project.customerName != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.person_outline, size: 14, color: AppColors.textMuted),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    project.customerName!,
                                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (project.siteCity != null || project.siteAddress != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.location_on_outlined, size: 14, color: AppColors.textMuted),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    [if (project.siteAddress != null) project.siteAddress!, if (project.siteCity != null) project.siteCity!]
                                        .join(', '),
                                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (hasDate || hasBudget) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 12,
                              runSpacing: 6,
                              children: [
                                if (hasDate)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.calendar_today_outlined, size: 13, color: AppColors.textMuted),
                                      const SizedBox(width: 4),
                                      Text(
                                        [
                                          if (project.startDate != null) fmt.format(project.startDate!),
                                          if (project.endDate != null) fmt.format(project.endDate!),
                                        ].join(' – '),
                                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                      ),
                                    ],
                                  ),
                                if (hasBudget)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.euro_outlined, size: 13, color: AppColors.textMuted),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${currencyFmt.format(project.budget!)} €',
                                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ],
                          if (project.responsiblePerson != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.badge_outlined, size: 13, color: AppColors.textMuted),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    project.responsiblePerson!,
                                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
