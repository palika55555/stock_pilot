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
  conflict,   // Existujú nerozriešené konflikty
  error,      // Posledný sync zlyhal
}

/// SyncManager – centrálny orchestrátor synchronizácie.
///
/// Zodpovednosti:
///  1. Sledovanie online/offline stavu
///  2. Správa offline fronty (cez OfflineQueueService)
///  3. Auto-sync pri prihlásení a pri obnove konektivity
///  4. Push → Pull sekvencia s exponential backoff
///  5. Broadcast stavu pre UI (statusStream)
///
/// Použitie:
///   SyncManager.instance.initialize(userId, accessToken, deviceId);
///   // Pri zmene entity:
///   await SyncManager.instance.enqueueChange(event);
class SyncManager {
  static final SyncManager instance = SyncManager._();
  SyncManager._();

  static const String _kLastPullKey      = 'sync_last_pull_at';
  static const String _kDeviceIdKey      = 'sync_device_id';
  static const Duration _pullInterval    = Duration(minutes: 5);
  static const int _maxBackoffSeconds    = 300;

  String? _userId;
  String? _accessToken;
  String? _deviceId;

  bool _isOnline     = true;
  bool _isSyncing    = false;
  bool _initialized  = false;

  Timer?                                      _pullTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  final StreamController<SyncStatus>          _statusCtrl = StreamController.broadcast();

  // -----------------------------------------------------------------------
  // Public API
  // -----------------------------------------------------------------------

  Stream<SyncStatus> get statusStream => _statusCtrl.stream;

  String? get deviceId => _deviceId;

  /// Volaj po prihlásení. Inicializuje frontu, načíta deviceId, spustí sync.
  Future<void> initialize(String userId, String accessToken) async {
    _userId       = userId;
    _accessToken  = accessToken;
    _deviceId     = await _getOrCreateDeviceId();
    _initialized  = true;

    // Vytvor offline_queue tabuľku ak neexistuje
    await OfflineQueueService.instance.ensureTable();

    // Odpočúvaj konektivitu
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);

    // Spusti periodický pull
    _pullTimer?.cancel();
    _pullTimer = Timer.periodic(_pullInterval, (_) => _performSync());

    // Okamžitý sync
    await _performSync();
  }

  /// Volaj po odhlásení. Zastaví sync, vyčistí stav.
  Future<void> dispose(String userId) async {
    _pullTimer?.cancel();
    _connectivitySub?.cancel();
    _pullTimer       = null;
    _connectivitySub = null;
    _initialized     = false;
    _userId          = null;
    _accessToken     = null;

    await OfflineQueueService.instance.clearFor(userId);
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
      final uri = Uri.parse('$_apiBase/sync/conflicts');
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
    required String resolution, // 'server-wins' | 'client-wins' | 'manual'
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
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // -----------------------------------------------------------------------
  // Interná logika
  // -----------------------------------------------------------------------

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final isOnline = results.isNotEmpty && results.first != ConnectivityResult.none;
    final wasOffline = !_isOnline;
    _isOnline = isOnline;

    if (isOnline && wasOffline && _initialized) {
      _performSync();
    }
  }

  /// Hlavná sync sekvencia: push → pull
  Future<void> _performSync() async {
    if (_isSyncing || !_initialized) return;
    final userId = _userId;
    final token  = _accessToken ?? getBackendToken();
    if (userId == null || token == null) return;

    _isSyncing = true;
    _emitStatus(SyncStatus.syncing);

    try {
      // 1. Push offline fronty
      final pushOk = await _pushQueue(userId, token);

      // 2. Pull serverových zmien od posledného pullu
      await _pullChanges(userId, token);

      // 3. Skontroluj pending konflikty
      final pendingCount = await OfflineQueueService.instance.pendingCount(userId);
      if (pendingCount > 0) {
        _emitStatus(SyncStatus.pending);
      } else if (!pushOk) {
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

  /// Odošle všetky pending udalosti z fronty. Vracia true ak úspešné.
  Future<bool> _pushQueue(String userId, String token, {int attempt = 1}) async {
    final rows = await OfflineQueueService.instance.pendingFor(userId);
    if (rows.isEmpty) return true;

    final events    = rows.map((r) => r.event.toJson()).toList();
    final rowIds    = rows.map((r) => r.id).toList();

    try {
      final uri  = Uri.parse('$_apiBase/sync/push');
      final resp = await http.post(
        uri,
        headers: {..._headers(token), 'Content-Type': 'application/json'},
        body: jsonEncode({
          'deviceId': _deviceId,
          'events':   events,
        }),
      ).timeout(const Duration(seconds: 30));

      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;

        // Spracuj výsledky per-event
        final results  = List<Map<String, dynamic>>.from(body['results'] ?? []);
        final okIds    = <int>[];
        final failIds  = <int>[];

        for (int i = 0; i < rows.length; i++) {
          final result = i < results.length ? results[i] : null;
          final status = result?['status'] as String? ?? 'error';

          if (status == 'ok' || status == 'conflict') {
            // 'conflict' – bolo zaznamenané na serveri (manual = čaká, ostatné = vyriešené)
            okIds.add(rows[i].id);
          } else {
            failIds.add(rows[i].id);
          }
        }

        await OfflineQueueService.instance.markProcessed(okIds);
        if (failIds.isNotEmpty) {
          await OfflineQueueService.instance.markFailed(failIds, 'server returned error');
        }

        // Ak existujú manuálne konflikty, notifikuj UI
        final manualConflicts = (body['conflicts'] as List? ?? []);
        if (manualConflicts.isNotEmpty) {
          _emitStatus(SyncStatus.conflict);
        }

        return true;
      } else if (resp.statusCode == 401) {
        // Token expiroval – sync zastavíme, volajúci sa musí znova prihlásiť
        return false;
      } else {
        throw Exception('HTTP ${resp.statusCode}');
      }
    } catch (e) {
      if (attempt >= 5) {
        await OfflineQueueService.instance.markFailed(rowIds, e.toString());
        return false;
      }
      // Exponential backoff: 2^attempt sekundy, max 300 s
      final delay = Duration(seconds: min(pow(2, attempt).toInt(), _maxBackoffSeconds));
      await Future.delayed(delay);
      return _pushQueue(userId, token, attempt: attempt + 1);
    }
  }

  /// Stiahne zmeny zo servera od posledného pullu a aplikuje ich lokálne.
  Future<void> _pullChanges(String userId, String token) async {
    final since = await _getLastPullTime();

    try {
      final uri = Uri.parse(
        '$_apiBase/sync/pull?since=${Uri.encodeComponent(since)}&deviceId=${Uri.encodeComponent(_deviceId ?? '')}',
      );
      final resp = await http.get(uri, headers: _headers(token))
          .timeout(const Duration(seconds: 30));

      if (resp.statusCode != 200) return;

      final body   = jsonDecode(resp.body) as Map<String, dynamic>;
      final events = List<Map<String, dynamic>>.from(body['events'] ?? []);

      for (final ev in events) {
        await _applyPulledEvent(ev);
      }

      // Ulož čas posledného úspešného pullu
      await _saveLastPullTime(body['serverTime'] as String? ?? DateTime.now().toIso8601String());
    } catch (_) {
      // Offline alebo server error – fronta bude odoslaná pri ďalšom pokuse
    }
  }

  /// Aplikuje príchodzí event zo servera do lokálnej SQLite DB.
  ///
  /// Táto metóda je zámerné jednoduchá – pri 'delete' nastaví deleted_at,
  /// pri 'create'/'update' aktualizuje záznamy v príslušnej tabuľke.
  /// Komplexnejšie merge logika je na zodpovednosti konkrétnych DB metód.
  Future<void> _applyPulledEvent(Map<String, dynamic> ev) async {
    final entityType  = ev['entity_type'] as String?;
    final entityId    = ev['entity_id'] as String?;
    final operation   = ev['operation'] as String?;
    final rawChanges  = ev['field_changes'];

    if (entityType == null || entityId == null || operation == null) return;

    Map<String, dynamic> changes = {};
    if (rawChanges is Map) {
      changes = Map<String, dynamic>.from(rawChanges);
    }

    final db = await DatabaseService().database;

    // Soft delete
    if (operation == 'delete') {
      final tableMap = _localTableFor(entityType);
      if (tableMap != null) {
        try {
          await db.update(
            tableMap.table,
            {'deleted_at': DateTime.now().toIso8601String()},
            where: '${tableMap.idField} = ?',
            whereArgs: [entityId],
          );
        } catch (_) {}
      }
      return;
    }

    // Update / create – aplikuj len polia ktoré existujú v lokálnej tabuľke
    if (changes.isEmpty) return;
    final tableMap = _localTableFor(entityType);
    if (tableMap == null) return;

    try {
      // Pokús sa o UPDATE; ak nič neaktualizuje, preskočíme (INSERT cez existujúce sync endpointy)
      final protected = {'id', 'user_id', 'created_at'};
      final safeChanges = {
        for (final k in changes.keys)
          if (!protected.contains(k)) k: changes[k]
      };
      if (safeChanges.isEmpty) return;

      await db.update(
        tableMap.table,
        safeChanges,
        where: '${tableMap.idField} = ? AND user_id = ?',
        whereArgs: [entityId, _userId],
      );
    } catch (_) {}
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
    final rng = Random.secure();
    final bytes = List.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    return [
      bytes.sublist(0, 4).map(hex).join(),
      bytes.sublist(4, 6).map(hex).join(),
      bytes.sublist(6, 8).map(hex).join(),
      bytes.sublist(8, 10).map(hex).join(),
      bytes.sublist(10, 16).map(hex).join(),
    ].join('-');
  }

  _LocalTable? _localTableFor(String entityType) {
    const map = <String, _LocalTable>{
      'product':          _LocalTable('products',          'unique_id'),
      'customer':         _LocalTable('customers',         'id'),
      'warehouse':        _LocalTable('warehouses',        'id'),
      'supplier':         _LocalTable('suppliers',         'id'),
      'inbound_receipt':  _LocalTable('inbound_receipts',  'id'),
      'stock_out':        _LocalTable('stock_outs',        'id'),
      'recipe':           _LocalTable('recipes',           'id'),
      'production_order': _LocalTable('production_orders', 'id'),
      'production_batch': _LocalTable('production_batches','id'),
      'quote':            _LocalTable('quotes',            'id'),
      'transport':        _LocalTable('transports',        'id'),
      'pallet':           _LocalTable('pallets',           'id'),
      'company':          _LocalTable('company',           'id'),
    };
    return map[entityType];
  }
}

class _LocalTable {
  final String table;
  final String idField;
  const _LocalTable(this.table, this.idField);
}
