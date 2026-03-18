import 'package:flutter/material.dart';
import '../../services/sync/sync_config.dart';
import '../../services/sync/sync_manager.dart';
import 'sync_status_badge.dart';

/// Widget pre zobrazenie a manuálne rozriešenie sync konfliktu.
///
/// Zobrazuje:
///  - Typ entity a ID záznamu
///  - Konfliktnné polia s hodnotami (client vs server)
///  - Tlačidlá: "Ponechaj serverovú", "Použi moju", "Zadaj ručne"
///  - Po rozhodnutí volá SyncManager.instance.resolveConflict(...)
///
/// Použitie:
///   showConflictDialog(context, conflict: conflictMap);
///   // alebo ako stránka pre viac konfliktov:
///   Navigator.push(context, MaterialPageRoute(builder: (_) => ConflictListScreen()));

class ConflictResolutionWidget extends StatefulWidget {
  final Map<String, dynamic> conflict;
  final VoidCallback? onResolved;

  const ConflictResolutionWidget({
    super.key,
    required this.conflict,
    this.onResolved,
  });

  @override
  State<ConflictResolutionWidget> createState() => _ConflictResolutionWidgetState();
}

class _ConflictResolutionWidgetState extends State<ConflictResolutionWidget> {
  bool _loading = false;
  String? _error;

  // Manuálne hodnoty (per-field editovateľné)
  late Map<String, TextEditingController> _manualControllers;
  bool _showManual = false;

  @override
  void initState() {
    super.initState();
    _manualControllers = {};
    _initManualFields();
  }

  void _initManualFields() {
    final conflictFields = _conflictFields;
    final serverData = _serverFieldChanges;
    for (final field in conflictFields) {
      _manualControllers[field] = TextEditingController(
        text: '${serverData[field] ?? ''}',
      );
    }
  }

  @override
  void dispose() {
    for (final c in _manualControllers.values) c.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _clientChange => (widget.conflict['client_change'] as Map?)?.cast<String, dynamic>() ?? {};
  Map<String, dynamic> get _serverChange => (widget.conflict['server_change'] as Map?)?.cast<String, dynamic>() ?? {};
  Map<String, dynamic> get _clientFieldChanges => (_clientChange['fieldChanges'] as Map?)?.cast<String, dynamic>() ?? {};
  Map<String, dynamic> get _serverFieldChanges => (_serverChange['fieldChanges'] as Map?)?.cast<String, dynamic>() ?? {};

  List<String> get _conflictFields {
    final raw = widget.conflict['conflict_fields'];
    if (raw is List) return raw.cast<String>();
    return [];
  }

  String get _entityType => widget.conflict['entity_type'] as String? ?? '';
  String get _entityId   => widget.conflict['entity_id'] as String? ?? '';
  int get _conflictId    => (widget.conflict['id'] as num?)?.toInt() ?? 0;

  Future<void> _resolve(String resolution, {Map<String, dynamic>? resolvedData}) async {
    setState(() { _loading = true; _error = null; });
    final ok = await SyncManager.instance.resolveConflict(
      conflictId:   _conflictId,
      resolution:   resolution,
      resolvedData: resolvedData,
    );
    setState(() { _loading = false; });
    if (ok) {
      widget.onResolved?.call();
      if (mounted) Navigator.of(context).pop(true);
    } else {
      setState(() { _error = 'Chyba pri ukladaní. Skúste znova.'; });
    }
  }

  Future<void> _resolveManual() async {
    final resolvedData = <String, dynamic>{};
    for (final field in _conflictFields) {
      resolvedData[field] = _manualControllers[field]?.text ?? '';
    }
    await _resolve('manual', resolvedData: resolvedData);
  }

  @override
  Widget build(BuildContext context) {
    final entityLabel = SyncConfig.entityLabel(_entityType);
    final conflictFields = _conflictFields;
    final clientData = _clientFieldChanges;
    final serverData = _serverFieldChanges;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Konflikt synchronizácie'),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(entityLabel),
                  const SizedBox(height: 16),
                  _buildStrategyInfo(),
                  const SizedBox(height: 16),
                  if (_error != null) _buildError(),
                  ...conflictFields.map((field) => _buildFieldRow(field, clientData, serverData)),
                  const SizedBox(height: 24),
                  if (_showManual) _buildManualSection(conflictFields),
                  _buildActions(conflictFields),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader(String entityLabel) {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$entityLabel bol zmenený offline aj na webe',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ID: $_entityId',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStrategyInfo() {
    final strategy = SyncConfig.strategyFor(_entityType);
    return Row(
      children: [
        Icon(Icons.info_outline, size: 16, color: Colors.blue.shade600),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Nastavená stratégia: ${strategy.label}',
            style: TextStyle(color: Colors.blue.shade700, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Text(_error!, style: TextStyle(color: Colors.red.shade700)),
      ),
    );
  }

  Widget _buildFieldRow(String field, Map<String, dynamic> client, Map<String, dynamic> server) {
    final clientVal = '${client[field] ?? '—'}';
    final serverVal = '${server[field] ?? '—'}';
    final fieldStrategy = SyncConfig.strategyFor(_entityType, field: field);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    field,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const Spacer(),
                  if (fieldStrategy == ConflictStrategy.manual)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'manual',
                        style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _valueBox('Vaša zmena (offline)', clientVal, Colors.blue.shade50, Colors.blue.shade700)),
                  const SizedBox(width: 8),
                  Expanded(child: _valueBox('Web / server', serverVal, Colors.green.shade50, Colors.green.shade700)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _valueBox(String label, String value, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 14, color: fg, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildManualSection(List<String> fields) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Zadaj hodnoty ručne:', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...fields.map((field) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                controller: _manualControllers[field],
                decoration: InputDecoration(
                  labelText: field,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            )),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildActions(List<String> conflictFields) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: () => _resolve('server-wins'),
          icon: const Icon(Icons.cloud_done_outlined),
          label: const Text('Použi serverovú verziu'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade600,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed: () => _resolve('client-wins'),
          icon: const Icon(Icons.phone_android),
          label: const Text('Použi moju offline zmenu'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade600,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: conflictFields.isEmpty
              ? null
              : () => setState(() => _showManual = !_showManual),
          icon: const Icon(Icons.edit_note),
          label: Text(_showManual ? 'Skryť manuálne zadanie' : 'Zadaj hodnoty ručne'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        if (_showManual) ...[
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _resolveManual,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Uložiť manuálne hodnoty'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ],
    );
  }
}

// =========================================================================
// ConflictListScreen – zoznam všetkých čakajúcich konfliktov
// =========================================================================

/// Obrazovka so zoznamom všetkých nerozriešených konfliktov.
/// Dostupná napríklad z admin menu alebo zo SyncStatusBadge.
class ConflictListScreen extends StatefulWidget {
  const ConflictListScreen({super.key});

  @override
  State<ConflictListScreen> createState() => _ConflictListScreenState();
}

class _ConflictListScreenState extends State<ConflictListScreen> {
  List<Map<String, dynamic>> _conflicts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await SyncManager.instance.fetchConflicts();
    if (mounted) {
      setState(() {
        _conflicts = result;
        _loading   = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Konflikty synchronizácie'),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _conflicts.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                      SizedBox(height: 12),
                      Text('Žiadne konflikty', style: TextStyle(fontSize: 18)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _conflicts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) => _buildConflictCard(ctx, _conflicts[i]),
                ),
    );
  }

  Widget _buildConflictCard(BuildContext context, Map<String, dynamic> conflict) {
    final entityType    = conflict['entity_type'] as String? ?? '';
    final entityId      = conflict['entity_id'] as String? ?? '';
    final conflFields   = (conflict['conflict_fields'] as List? ?? []).cast<String>();
    final createdAt     = conflict['created_at'] as String? ?? '';

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.orange.shade100,
          child: Icon(Icons.sync_problem, color: Colors.orange.shade700),
        ),
        title: Text(
          '${SyncConfig.entityLabel(entityType)}: $entityId',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Konfliktné polia: ${conflFields.join(', ')}'),
            Text(createdAt.isNotEmpty ? createdAt.substring(0, 16).replaceAll('T', ' ') : ''),
          ],
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ConflictResolutionWidget(
                conflict:   conflict,
                onResolved: _load,
              ),
            ),
          );
        },
      ),
    );
  }
}

// =========================================================================
// Pomocná funkcia pre otvorenie konfliktu ako dialog
// =========================================================================

/// Zobrazí conflict resolution ako dialog. Vráti true ak bol konflikt rozriešený.
Future<bool> showConflictDialog(
  BuildContext context, {
  required Map<String, dynamic> conflict,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.8,
        child: ConflictResolutionWidget(conflict: conflict),
      ),
    ),
  );
  return result == true;
}
