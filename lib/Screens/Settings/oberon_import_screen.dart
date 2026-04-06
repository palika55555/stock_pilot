import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/oberon_product_import.dart';
import '../../services/migration/oberon_import_service.dart';
import '../../services/migration/oberon_import_spec.dart';
import '../../services/Database/database_service.dart';
import '../../services/product_cache.dart';
import '../../theme/app_theme.dart';

const _kPrefsSelectedTable = 'oberon_import_selected_table';
const _kPrefsLastDbPath = 'oberon_import_last_db_path';

/// Migrácia skladových kariet z Oberon – tabuľku vyberiete v aplikácii, mapovanie stĺpcov v config.
class OberonImportScreen extends StatefulWidget {
  const OberonImportScreen({super.key});

  @override
  State<OberonImportScreen> createState() => _OberonImportScreenState();
}

class _OberonImportScreenState extends State<OberonImportScreen> {
  final _service = OberonImportService(DatabaseService());
  String? _pickedPath;
  String? _pathWarning;
  String? _pathAccessHint;
  bool _busy = false;
  String? _lastResult;
  /// Tabuľka zvolená v aplikácii (má prioritu pred `tableName` v `oberon_product_import.dart`).
  String? _selectedTableName;

  @override
  void initState() {
    super.initState();
    _loadSavedTable();
  }

  Future<void> _loadSavedTable() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _selectedTableName = prefs.getString(_kPrefsSelectedTable);
    });
  }

  Future<void> _onDbPathChanged(String newPath) async {
    final prefs = await SharedPreferences.getInstance();
    final prev = prefs.getString(_kPrefsLastDbPath);
    if (prev != newPath) {
      await prefs.remove(_kPrefsSelectedTable);
      await prefs.setString(_kPrefsLastDbPath, newPath);
      if (mounted) {
        setState(() => _selectedTableName = null);
      }
    } else {
      await prefs.setString(_kPrefsLastDbPath, newPath);
    }
  }

  Future<void> _pickFile() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      dialogTitle: 'Vyberte databázu (.db / .sqlite alebo .mdb na Windows)',
    );
    if (r == null || r.files.isEmpty) return;
    final p = r.files.single.path;
    if (p == null) return;
    await _onDbPathChanged(p);
    setState(() {
      _pickedPath = p;
      _lastResult = null;
      _pathWarning = OberonImportService.sqlitePathRejectionMessage(p);
      _pathAccessHint = OberonImportService.accessEngineHint(p);
    });
  }

  /// Názov tabuľky: výber v aplikácii, inak hodnota z `oberon_product_import.dart`.
  String get _effectiveTableName {
    final s = _selectedTableName?.trim();
    if (s != null && s.isNotEmpty) return s;
    return oberonProductImportSpec.tableName.trim();
  }

  OberonProductImportSpec _effectiveSpec() {
    final base = oberonProductImportSpec;
    final t = _selectedTableName?.trim();
    if (t != null && t.isNotEmpty) {
      return base.copyWith(tableName: t);
    }
    return base;
  }

  bool get _configured {
    final spec = oberonProductImportSpec;
    return _effectiveTableName.isNotEmpty && spec.columnMap.isNotEmpty;
  }

  Future<void> _showTablePicker() async {
    final p = _pickedPath;
    if (p == null || p.isEmpty) {
      _toast('Najprv vyberte súbor databázy.');
      return;
    }
    setState(() => _busy = true);
    List<String> tables;
    try {
      tables = await _service.listTables(p);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _showImportError(e);
      }
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    if (tables.isEmpty) {
      _toast('V súbore sa nenašli žiadne tabuľky.');
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Vyberte tabuľku s tovarom'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: tables.length,
              itemBuilder: (_, i) {
                final name = tables[i];
                final selected = _selectedTableName == name;
                return ListTile(
                  title: Text(name),
                  selected: selected,
                  trailing: selected ? Icon(Icons.check_circle, color: AppColors.accentGold) : null,
                  onTap: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString(_kPrefsSelectedTable, name);
                    if (!mounted) return;
                    setState(() => _selectedTableName = name);
                    if (ctx.mounted) Navigator.pop(ctx);
                    _toast('Tabuľka: $name');
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Zavrieť'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _clearTableSelection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrefsSelectedTable);
    if (mounted) setState(() => _selectedTableName = null);
    _toast('Výber tabuľky zrušený.');
  }

  Future<void> _listColumns() async {
    final p = _pickedPath;
    final t = _effectiveTableName;
    if (p == null || p.isEmpty) {
      _toast('Najprv vyberte súbor databázy.');
      return;
    }
    if (t.isEmpty) {
      _toast('Najprv vyberte tabuľku (tlačidlo „Vybrať tabuľku“).');
      return;
    }
    setState(() => _busy = true);
    try {
      final cols = await _service.listColumns(p, t);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Stĺpce tabuľky „$t“'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: cols.length,
              itemBuilder: (_, i) => SelectableText(cols[i]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Zavrieť')),
          ],
        ),
      );
    } catch (e) {
      _showImportError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final p = _pickedPath;
    if (p == null || p.isEmpty) {
      _toast('Vyberte súbor databázy Oberon.');
      return;
    }
    setState(() {
      _busy = true;
      _lastResult = null;
    });
    try {
      final res = await _service.importProducts(p, spec: _effectiveSpec());
      await ProductCache.instance.load();
      if (!mounted) return;
      final buf = StringBuffer()
        ..writeln('Importované: ${res.imported}, preskočené: ${res.skipped}, chyby: ${res.errors}');
      for (final m in res.messages) {
        buf.writeln(m);
      }
      setState(() => _lastResult = buf.toString());
      if (res.errors == 0 && res.imported > 0) {
        _toast('Import dokončený.');
      } else if (res.imported == 0 && res.errors > 0) {
        _toast('Import zlyhal – pozrite súhrn.');
      }
    } catch (e) {
      _showImportError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showImportError(Object e) {
    if (e is FormatException) {
      _toast(e.message);
      return;
    }
    final s = e.toString();
    if (s.contains('code 26') || s.contains('not a database')) {
      _toast(
        'Súbor nie je rozpoznaný ako SQLite. Skontrolujte, či ide o platný .db, alebo na Windows o .mdb s nainštalovaným Access Database Engine.',
      );
      return;
    }
    _toast('Chyba: $e');
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final spec = oberonProductImportSpec;
    final tableLabel = _effectiveTableName.isEmpty ? '—' : _effectiveTableName;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Import z Oberon'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            '1) Vyberte súbor databázy. 2) Tlačidlo „Vybrať tabuľku“ – kliknite na riadok s tabuľkou tovaru. '
            '3) Mapovanie stĺpcov (name, plu, …) zostáva v lib/config/oberon_product_import.dart. '
            '4) „Stĺpce nastavenej tabuľky“ zobrazí názvy stĺpcov pre doplnenie columnMap.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                _configured ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                color: _configured ? AppColors.success : Colors.orange,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _configured
                      ? 'Tabuľka: „$tableLabel“, mapovaní stĺpcov: ${spec.columnMap.length}.'
                      : 'Chýba tabuľka alebo columnMap v konfigurácii.',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _busy ? null : _pickFile,
            icon: const Icon(Icons.folder_open),
            label: Text(_pickedPath == null ? 'Vybrať súbor Oberon DB' : 'Zmeniť súbor'),
          ),
          if (_pickedPath != null) ...[
            const SizedBox(height: 8),
            SelectableText(_pickedPath!, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
          if (_pathWarning != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _pathWarning!,
                      style: const TextStyle(color: Colors.orange, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_pathAccessHint != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.info.withValues(alpha: 0.45)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline, color: AppColors.info, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _pathAccessHint!,
                      style: TextStyle(color: AppColors.textPrimary, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: (_busy || _pathWarning != null || _pickedPath == null) ? null : _showTablePicker,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accentGold.withValues(alpha: 0.25),
                  foregroundColor: AppColors.accentGold,
                ),
                icon: const Icon(Icons.touch_app_rounded),
                label: const Text('Vybrať tabuľku'),
              ),
              if (_selectedTableName != null)
                TextButton(
                  onPressed: _busy ? null : _clearTableSelection,
                  child: const Text('Zrušiť výber tabuľky'),
                ),
              OutlinedButton.icon(
                onPressed: (_busy || _pathWarning != null) ? null : _listColumns,
                icon: const Icon(Icons.view_column_outlined),
                label: const Text('Stĺpce nastavenej tabuľky'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: (_busy || !_configured || _pathWarning != null) ? null : _import,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentGold,
              foregroundColor: AppColors.bgPrimary,
            ),
            icon: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload),
            label: const Text('Importovať produkty'),
          ),
          if (_lastResult != null) ...[
            const SizedBox(height: 24),
            Text('Výsledok', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            SelectableText(_lastResult!, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}
