import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../Database/database_service.dart';
import 'sync_event.dart';

/// Lokálna perzistentná fronta pre offline zmeny.
///
/// Tabuľka `offline_queue` v SQLite prežíva reštart apky.
/// Pri každej zmene entity volaj [enqueue].
/// SyncManager volá [pendingFor] + [markProcessed] / [markFailed].
class OfflineQueueService {
  static final OfflineQueueService instance = OfflineQueueService._();
  OfflineQueueService._();

  static const String _table = 'offline_queue';
  static const int _maxRetries = 5;

  // -----------------------------------------------------------------------
  // Inicializácia tabuľky (volaj pri štarte apky / otvorení DB)
  // -----------------------------------------------------------------------

  /// Vytvorí tabuľku offline_queue ak neexistuje. Volaj po otvorení databázy.
  Future<void> ensureTable() async {
    final db = await DatabaseService().database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_table (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type   TEXT    NOT NULL,
        entity_id     TEXT    NOT NULL,
        operation     TEXT    NOT NULL,
        field_changes TEXT    NOT NULL DEFAULT '{}',
        timestamp     TEXT    NOT NULL,
        device_id     TEXT    NOT NULL DEFAULT '',
        user_id       TEXT    NOT NULL,
        session_id    TEXT    NOT NULL DEFAULT '',
        client_version INTEGER NOT NULL DEFAULT 1,
        status        TEXT    NOT NULL DEFAULT 'pending',
        retry_count   INTEGER NOT NULL DEFAULT 0,
        last_error    TEXT,
        created_at    TEXT    NOT NULL
      )
    ''');
  }

  // -----------------------------------------------------------------------
  // Zápis do fronty
  // -----------------------------------------------------------------------

  /// Pridá zmenu do offline fronty. Idempotentné: ak rovnaký entityId + operation
  /// ešte nebol odoslaný, aktualizuje fieldChanges namiesto duplicitného záznamu.
  Future<void> enqueue(SyncEvent event) async {
    final db = await DatabaseService().database;

    // Ak existuje pending záznam pre rovnaký entitu + operáciu, zlúč fieldChanges
    final existing = await db.query(
      _table,
      where: 'entity_type = ? AND entity_id = ? AND operation = ? AND status = ? AND user_id = ?',
      whereArgs: [event.entityType, event.entityId, event.operation, 'pending', event.userId],
      orderBy: 'id DESC',
      limit: 1,
    );

    if (existing.isNotEmpty && event.operation == 'update') {
      // Zlúč fieldChanges – novšie hodnoty prepíšu staršie
      final oldChanges = _decodeJson(existing.first['field_changes'] as String?);
      final merged = {...oldChanges, ...event.fieldChanges};
      await db.update(
        _table,
        {
          'field_changes':  jsonEncode(merged),
          'timestamp':      event.timestamp,
          'client_version': event.clientVersion,
          'status':         'pending',
          'retry_count':    0,
          'last_error':     null,
        },
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    } else {
      await db.insert(_table, event.toSqliteRow());
    }
  }

  // -----------------------------------------------------------------------
  // Čítanie fronty
  // -----------------------------------------------------------------------

  /// Vráti všetky pending udalosti pre daného používateľa, zoradené podľa created_at.
  Future<List<QueueRow>> pendingFor(String userId) async {
    final db = await DatabaseService().database;
    final rows = await db.query(
      _table,
      where: 'user_id = ? AND status = ? AND retry_count < ?',
      whereArgs: [userId, 'pending', _maxRetries],
      orderBy: 'created_at ASC',
    );
    return rows.map(QueueRow.fromMap).toList();
  }

  /// Počet čakajúcich zmien (pre UI badge).
  Future<int> pendingCount(String userId) async {
    final db = await DatabaseService().database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM $_table WHERE user_id = ? AND status = ?',
      [userId, 'pending'],
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  // -----------------------------------------------------------------------
  // Aktualizácia stavu po odoslaní
  // -----------------------------------------------------------------------

  /// Označí záznamy ako odoslané (vymaže ich z fronty).
  Future<void> markProcessed(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await DatabaseService().database;
    final placeholders = ids.map((_) => '?').join(',');
    await db.delete(_table, where: 'id IN ($placeholders)', whereArgs: ids);
  }

  /// Označí záznamy ako failed – inkrementuje retry_count.
  Future<void> markFailed(List<int> ids, String error) async {
    if (ids.isEmpty) return;
    final db = await DatabaseService().database;
    for (final id in ids) {
      await db.rawUpdate(
        'UPDATE $_table SET retry_count = retry_count + 1, last_error = ?, status = ? WHERE id = ?',
        [error, 'pending', id],
      );
    }
  }

  /// Definitívne zahodí záznamy ktoré prekročili maxRetries.
  Future<void> purgeExpired() async {
    final db = await DatabaseService().database;
    await db.delete(
      _table,
      where: 'retry_count >= ?',
      whereArgs: [_maxRetries],
    );
  }

  /// Vymaže celú frontu pre daného používateľa (pri odhlásení).
  Future<void> clearFor(String userId) async {
    final db = await DatabaseService().database;
    await db.delete(_table, where: 'user_id = ?', whereArgs: [userId]);
  }

  // -----------------------------------------------------------------------
  // Privátne pomocné metódy
  // -----------------------------------------------------------------------

  Map<String, dynamic> _decodeJson(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }
}

/// Reprezentácia riadku z offline_queue (pridáva SQLite id).
class QueueRow {
  final int id;
  final SyncEvent event;
  final int retryCount;

  const QueueRow({required this.id, required this.event, required this.retryCount});

  factory QueueRow.fromMap(Map<String, dynamic> map) => QueueRow(
        id:         (map['id'] as num).toInt(),
        event:      SyncEvent.fromSqliteRow(map),
        retryCount: (map['retry_count'] as num?)?.toInt() ?? 0,
      );
}
