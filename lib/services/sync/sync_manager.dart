import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../api_sync_service.dart';
import '../Database/database_service.dart';
import 'sync_event.dart';
import 'offline_queue_service.dart';

/// Stav synchronizácie – pre UI badge / indikátor
enum SyncStatus {
  idle,       // Nič neprebieha
  syncing,    // Prebieha sync
  pending,    // Čakajúce zmeny v offline fronte
  conflict,   // Existujú nerozriešené manuálne konflikty
  error,      // Posledný sync zlyhal
}

/// SyncManager – centrálny orchestrátor synchronizácie.
///
/// ## Sekvencia push → pull (bezpečná pre paralelné zmeny)
///
/// 1. **Push** – offline fronta sa odošle na server s conflict detection.
///    Server porovná clientVersion vs serverVersion:
///    - žiadny prekryv polí → field-merge (obe zmeny sa zlúčia)
///    - prekryv → stratégia (server-wins / client-wins / newer-wins / manual)
///
/// 2. **Chránené polia** – pred pullom sa zozbierajú všetky (entityType:entityId:field)
///    z offline fronty ktoré ešte čakajú. Tieto polia pull PRESKOČÍ.
///    Dôvod: user ich explicitne zmenil → nesmú byť prepísané serverovými hodnotami
///    kým ich server nespracuje alebo používateľ nevyrieši konflikt.
///
/// 3. **Pull** – server pošle zmeny od iných zariadení (web, iná apka).
///    Chránené polia sa preskočia; ostatné sa aplikujú na lokálnu SQLite.
///    Po úspešnom pulle sa obnoví timestamp pre ďalší inkrementálny pull.
///
/// 4. **Manual konflikty** – ak server vráti `resolution: manual`, SyncStatus → conflict.
///    Používateľ rieši cez ConflictListScreen. Po rozriešení server emituje sync_event
///    → pri ďalšom pulle príde finálna hodnota do lokálnej DB.
class SyncManager {
  static final SyncManager instance = SyncManager._();
  SyncManager._();

  static const String _kLastPullKey   = 'sync_last_pull_at';
  static const String _kDeviceIdKey   = 'sync_device_id';
  static const Duration _pullInterval = Duration(minutes: 5);
  static const int _maxBackoffSeconds = 300;

  String? _userId;
  String? _accessToken;
  String? _deviceId;

  bool _isOnline    = true;
  bool _isSyncing   = false;
  bool _initialized = false;

  Timer?                                       _pullTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  final StreamController<SyncStatus> _statusCtrl      = StreamController.broadcast();
  final StreamController<void>       _dataChangedCtrl = StreamController.broadcast();

  // -----------------------------------------------------------------------
  // Public API
  // -----------------------------------------------------------------------

  /// Stream stavu synchronizácie pre UI badge.
  Stream<SyncStatus> get statusStream => _statusCtrl.stream;

  /// Stream: emituje po každom úspešnom pulle – UI môže obnoviť dáta.
  Stream<void> get dataRefreshed => _dataChangedCtrl.stream;

  String? get deviceId => _deviceId;

  /// Volaj po prihlásení. Inicializuje frontu, načíta deviceId, spustí sync.
  Future<void> initialize(String userId, String accessToken) async {
    _userId      = userId;
    _accessToken = accessToken;
    _deviceId    = await _getOrCreateDeviceId();
    _initialized = true;

    await OfflineQueueService.instance.ensureTable();

    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);

    _pullTimer?.cancel();
    _pullTimer = Timer.periodic(_pullInterval, (_) => _performSync());

    // Okamžitý sync po prihlásení
    await _performSync();
  }

  /// Zastaví timery a listenery (volaj z dispose() widgetu – synchrónne).
  /// Offline fronta zostáva zachovaná – zmeny sa odošlú po ďalšom prihlásení.
  void stop() {
    _pullTimer?.cancel();
    _connectivitySub?.cancel();
    _pullTimer       = null;
    _connectivitySub = null;
    _initialized     = false;
  }

  /// Volaj pri odhlásení. Zastaví sync, offline frontu ZACHOVÁ.
  /// Čakajúce zmeny sa odošlú automaticky po ďalšom prihlásení + internete.
  void disposeForLogout() {
    stop();
    _userId      = null;
    _accessToken = null;
  }

  /// Pridá zmenu do offline fronty (volaj vždy pri zmene entity).
  /// Ak je online, okamžite spustí sync.
  Future<void> enqueueChange(SyncEvent event) async {
    await OfflineQueueService.instance.enqueue(event);
    _emitStatus(SyncStatus.pending);
    if (_isOnline && _initialized) {
      await _performSync();
    }
  }

  /// Stiahne zoznam manuálnych konfliktov zo servera.
  Future<List<Map<String, dynamic>>> fetchConflicts() async {
    final token = _accessToken ?? getBackendToken();
    if (token == null) return [];
    try {
      final uri  = Uri.parse('$_apiBase/sync/conflicts');
      final resp = await http.get(uri, headers: _headers(token))
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(body['conflicts'] ?? []);
      }
    } catch (_) {}
    return [];
  }

  /// Odošle rozhodnutie o manuálnom konflikte na server.
  Future<bool> resolveConflict({
    required int conflictId,
    required String resolution,
    Map<String, dynamic>? resolvedData,
  }) async {
    final token = _accessToken ?? getBackendToken();
    if (token == null) return false;
    try {
      final uri  = Uri.parse('$_apiBase/sync/resolve');
      final resp = await http.post(
        uri,
        headers: {..._headers(token), 'Content-Type': 'application/json'},
        body: jsonEncode({
          'conflictId':   conflictId,
          'resolution':   resolution,
          'resolvedData': resolvedData,
        }),
      ).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        // Po rozriešení okamžite pull aby sa finálna hodnota prejavila lokálne
        final userId = _userId;
        final tok    = _accessToken ?? getBackendToken();
        if (userId != null && tok != null) {
          await _pullChanges(userId, tok, protectedFields: {});
        }
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // -----------------------------------------------------------------------
  // Interná logika
  // -----------------------------------------------------------------------

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final isOnline  = results.isNotEmpty && results.first != ConnectivityResult.none;
    final wasOffline = !_isOnline;
    _isOnline = isOnline;
    if (isOnline && wasOffline && _initialized) {
      _performSync();
    }
  }

  /// Hlavná sync sekvencia: push → chránené polia → pull
  Future<void> _performSync() async {
    if (_isSyncing || !_initialized) return;
    final userId = _userId;
    final token  = _accessToken ?? getBackendToken();
    if (userId == null || token == null) return;

    _isSyncing = true;
    _emitStatus(SyncStatus.syncing);

    try {
      // ── Krok 1: Zozbieraj polia čakajúce v offline fronte ────────────
      // Tieto polia pull nesmie prepísať – user ich explicitne zmenil.
      final protectedFields = await _collectPendingFields(userId);

      // ── Krok 2: Push offline fronty na server ─────────────────────────
      final pushResult = await _pushQueue(userId, token);

      // ── Krok 3: Pull zmien zo servera (s ochranou pending polí) ───────
      // Ak push zlyhal sieťovo, skúsime pull nabudúce. Ak bol OK (aj s
      // konfliktmi), pull ideme – konflikty sú na serveri uložené bezpečne.
      if (pushResult != _PushOutcome.networkError) {
        await _pullChanges(userId, token, protectedFields: protectedFields);
      }

      // ── Krok 4: Výsledný stav pre UI badge ────────────────────────────
      final pendingCount = await OfflineQueueService.instance.pendingCount(userId);
      if (pushResult == _PushOutcome.hasManualConflicts) {
        _emitStatus(SyncStatus.conflict);
      } else if (pendingCount > 0) {
        _emitStatus(SyncStatus.pending);
      } else if (pushResult == _PushOutcome.networkError) {
        _emitStatus(SyncStatus.error);
      } else {
        _emitStatus(SyncStatus.idle);
      }
    } catch (_) {
      _emitStatus(SyncStatus.error);
    } finally {
      _isSyncing = false;
    }
  }

  /// Zozbiera kľúče `"entityType:entityId:fieldName"` zo všetkých pending
  /// položiek v offline fronte. Pull ich bude ignorovať.
  Future<Set<String>> _collectPendingFields(String userId) async {
    final rows   = await OfflineQueueService.instance.pendingFor(userId);
    final result = <String>{};
    for (final row in rows) {
      for (final field in row.event.fieldChanges.keys) {
        result.add('${row.event.entityType}:${row.event.entityId}:$field');
      }
    }
    return result;
  }

  /// Odošle všetky pending udalosti z fronty.
  Future<_PushOutcome> _pushQueue(String userId, String token, {int attempt = 1}) async {
    final rows = await OfflineQueueService.instance.pendingFor(userId);
    if (rows.isEmpty) return _PushOutcome.ok;

    final events = rows.map((r) => r.event.toJson()).toList();
    final rowIds = rows.map((r) => r.id).toList();

    try {
      final uri  = Uri.parse('$_apiBase/sync/push');
      final resp = await http.post(
        uri,
        headers: {..._headers(token), 'Content-Type': 'application/json'},
        body: jsonEncode({'deviceId': _deviceId, 'events': events}),
      ).timeout(const Duration(seconds: 30));

      if (resp.statusCode == 200) {
        final body    = jsonDecode(resp.body) as Map<String, dynamic>;
        final results = List<Map<String, dynamic>>.from(body['results'] ?? []);

        final okIds   = <int>[];
        final failIds = <int>[];
        bool  hasManual = false;

        for (int i = 0; i < rows.length; i++) {
          final r          = i < results.length ? results[i] : null;
          final status     = r?['status']     as String? ?? 'error';
          final resolution = r?['resolution'] as String?;

          if (status == 'ok') {
            okIds.add(rows[i].id);
          } else if (status == 'conflict') {
            // Konflikt bol zaznamenaný na serveri – z fronty ho odstraníme
            // (server ho spravuje v sync_conflicts, nie my).
            okIds.add(rows[i].id);
            if (resolution == 'manual') hasManual = true;
          } else {
            failIds.add(rows[i].id);
          }
        }

        await OfflineQueueService.instance.markProcessed(okIds);
        if (failIds.isNotEmpty) {
          await OfflineQueueService.instance.markFailed(failIds, 'server returned error');
        }

        return hasManual ? _PushOutcome.hasManualConflicts : _PushOutcome.ok;

      } else if (resp.statusCode == 401) {
        return _PushOutcome.networkError; // token expiroval
      } else {
        throw Exception('HTTP ${resp.statusCode}');
      }
    } catch (e) {
      if (attempt >= 5) {
        await OfflineQueueService.instance.markFailed(rowIds, e.toString());
        return _PushOutcome.networkError;
      }
      final delay = Duration(seconds: min(pow(2, attempt).toInt(), _maxBackoffSeconds));
      await Future.delayed(delay);
      return _pushQueue(userId, token, attempt: attempt + 1);
    }
  }

  /// Stiahne zmeny zo servera (od iných zariadení) a aplikuje ich lokálne.
  ///
  /// [protectedFields] – sada `"entityType:entityId:field"` ktoré sa NESMÚ
  /// prepísať, lebo user ich zmenil v offline fronte a ešte čakajú.
  Future<void> _pullChanges(
    String userId,
    String token, {
    required Set<String> protectedFields,
  }) async {
    final since = await _getLastPullTime();

    try {
      final uri = Uri.parse(
        '$_apiBase/sync/pull'
        '?since=${Uri.encodeComponent(since)}'
        '&deviceId=${Uri.encodeComponent(_deviceId ?? '')}',
      );
      final resp = await http.get(uri, headers: _headers(token))
          .timeout(const Duration(seconds: 30));

      if (resp.statusCode != 200) return;

      final body   = jsonDecode(resp.body) as Map<String, dynamic>;
      final events = List<Map<String, dynamic>>.from(body['events'] ?? []);

      bool anyApplied = false;
      for (final ev in events) {
        final applied = await _applyPulledEvent(ev, protectedFields);
        if (applied) anyApplied = true;
      }

      await _saveLastPullTime(
        body['serverTime'] as String? ?? DateTime.now().toIso8601String(),
      );

      // Notifikuj UI nech obnoví dáta (bez spustenia AutoPush loop)
      if (anyApplied && !_dataChangedCtrl.isClosed) {
        _dataChangedCtrl.add(null);
      }
    } catch (_) {
      // Offline alebo server error – pull sa zopakuje pri ďalšom _performSync
    }
  }

  /// Aplikuje jeden pulled event z servera do lokálnej SQLite.
  ///
  /// Vracia `true` ak aspoň jedno pole bolo skutočne zapísané.
  ///
  /// **Logika ochrany:**
  /// - Ak je pole v [protectedFields] (`entityType:entityId:fieldName`),
  ///   preskočí sa – user ho zmenil offline a čaká na vyriešenie.
  /// - Ostatné polia sa aplikujú normálne (field-merge bez konfliktu).
  Future<bool> _applyPulledEvent(
    Map<String, dynamic> ev,
    Set<String> protectedFields,
  ) async {
    final entityType = ev['entity_type'] as String?;
    final entityId   = ev['entity_id']   as String?;
    final operation  = ev['operation']   as String?;
    final rawChanges = ev['field_changes'];

    if (entityType == null || entityId == null || operation == null) return false;

    Map<String, dynamic> changes = {};
    if (rawChanges is Map) {
      changes = Map<String, dynamic>.from(rawChanges);
    }

    final db       = await DatabaseService().database;
    final tableMap = _localTableFor(entityType);
    if (tableMap == null) return false;

    // ── Soft delete ───────────────────────────────────────────────────────
    if (operation == 'delete') {
      // Delete nepodlieha ochrane polí – ak server hovorí mazať, mažeme.
      try {
        await db.update(
          tableMap.table,
          {'deleted_at': DateTime.now().toIso8601String()},
          where: '${tableMap.idField} = ? AND user_id = ?',
          whereArgs: [entityId, _userId],
        );
        return true;
      } catch (_) {
        return false;
      }
    }

    if (changes.isEmpty) return false;

    // ── Filter chránených a systémových polí ─────────────────────────────
    const systemFields = {'id', 'user_id', 'created_at'};

    final safeChanges = <String, dynamic>{};
    for (final entry in changes.entries) {
      final key = entry.key;

      // Systémové polia nikdy nezapisujeme
      if (systemFields.contains(key)) continue;

      // Pole čaká v offline fronte → preskočíme, user má prednosť
      if (protectedFields.contains('$entityType:$entityId:$key')) continue;

      safeChanges[key] = entry.value;
    }

    if (safeChanges.isEmpty) return false;

    // ── Zapíš do lokálnej SQLite ──────────────────────────────────────────
    try {
      final affected = await db.update(
        tableMap.table,
        safeChanges,
        where: '${tableMap.idField} = ? AND user_id = ?',
        whereArgs: [entityId, _userId],
      );
      return affected > 0;
    } catch (_) {
      return false;
    }
  }

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  String get _apiBase => '$kBackendApiBase$kApiPrefix';

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Accept':        'application/json',
      };

  void _emitStatus(SyncStatus s) {
    if (!_statusCtrl.isClosed) _statusCtrl.add(s);
  }

  Future<String> _getLastPullTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_kLastPullKey:$_userId') ?? DateTime(2020).toIso8601String();
  }

  Future<void> _saveLastPullTime(String iso) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_kLastPullKey:$_userId', iso);
  }

  Future<String> _getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_kDeviceIdKey);
    if (id == null || id.isEmpty) {
      id = _generateUuid();
      await prefs.setString(_kDeviceIdKey, id);
    }
    return id;
  }

  String _generateUuid() {
    final rng   = Random.secure();
    final bytes = List.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    return [
      bytes.sublist(0,  4).map(hex).join(),
      bytes.sublist(4,  6).map(hex).join(),
      bytes.sublist(6,  8).map(hex).join(),
      bytes.sublist(8,  10).map(hex).join(),
      bytes.sublist(10, 16).map(hex).join(),
    ].join('-');
  }

  _LocalTable? _localTableFor(String entityType) {
    const map = <String, _LocalTable>{
      'product':          _LocalTable('products',           'unique_id'),
      'customer':         _LocalTable('customers',          'id'),
      'warehouse':        _LocalTable('warehouses',         'id'),
      'supplier':         _LocalTable('suppliers',          'id'),
      'inbound_receipt':  _LocalTable('inbound_receipts',   'id'),
      'stock_out':        _LocalTable('stock_outs',         'id'),
      'recipe':           _LocalTable('recipes',            'id'),
      'production_order': _LocalTable('production_orders',  'id'),
      'production_batch': _LocalTable('production_batches', 'id'),
      'quote':            _LocalTable('quotes',             'id'),
      'transport':        _LocalTable('transports',         'id'),
      'pallet':           _LocalTable('pallets',            'id'),
      'company':          _LocalTable('company',            'id'),
    };
    return map[entityType];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Interné typy
// ─────────────────────────────────────────────────────────────────────────────

enum _PushOutcome { ok, hasManualConflicts, networkError }

class _LocalTable {
  final String table;
  final String idField;
  const _LocalTable(this.table, this.idField);
}
