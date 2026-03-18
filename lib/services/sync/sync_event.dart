import 'dart:convert';

/// Reprezentuje jednu zmenu (create / update / delete) na ľubovoľnom entitnom type.
/// Ukladá sa do lokálnej offline fronty (SQLite) a posiela na server cez POST /sync/push.
class SyncEvent {
  /// Typ entity napr. 'product', 'customer', 'inbound_receipt' – zodpovedá konfigurácii v syncConfig
  final String entityType;

  /// Jedinečné ID záznamu (unique_id pre produkty, id pre ostatné)
  final String entityId;

  /// 'create' | 'update' | 'delete'
  final String operation;

  /// Iba zmenené polia (nie celý záznam). Pri delete je prázdny objekt.
  final Map<String, dynamic> fieldChanges;

  /// ISO 8601 timestamp vzniku zmeny na zariadení
  final String timestamp;

  /// Identifikátor zariadenia (UUID, trvalý po inštalácii)
  final String deviceId;

  /// ID prihláseného používateľa
  final String userId;

  /// Session ID (UUID aktuálnej session – z JWT alebo UUID vygenerovaný pri prihlásení)
  final String sessionId;

  /// Verzia záznamu z ktorej zmena vychádza (optimistic locking)
  final int clientVersion;

  const SyncEvent({
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.fieldChanges,
    required this.timestamp,
    required this.deviceId,
    required this.userId,
    required this.sessionId,
    required this.clientVersion,
  });

  /// Serializácia pre HTTP body (POST /sync/push)
  Map<String, dynamic> toJson() => {
        'entityType':    entityType,
        'entityId':      entityId,
        'operation':     operation,
        'fieldChanges':  fieldChanges,
        'timestamp':     timestamp,
        'deviceId':      deviceId,
        'userId':        userId,
        'sessionId':     sessionId,
        'clientVersion': clientVersion,
      };

  /// Serializácia pre SQLite offline_queue
  Map<String, dynamic> toSqliteRow() => {
        'entity_type':    entityType,
        'entity_id':      entityId,
        'operation':      operation,
        'field_changes':  jsonEncode(fieldChanges),
        'timestamp':      timestamp,
        'device_id':      deviceId,
        'user_id':        userId,
        'session_id':     sessionId,
        'client_version': clientVersion,
        'status':         'pending',
        'retry_count':    0,
        'created_at':     DateTime.now().toIso8601String(),
      };

  /// Deserializácia zo SQLite riadku
  factory SyncEvent.fromSqliteRow(Map<String, dynamic> row) {
    final raw = row['field_changes'];
    Map<String, dynamic> changes = {};
    if (raw is String && raw.isNotEmpty) {
      try {
        changes = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {}
    }
    return SyncEvent(
      entityType:    row['entity_type'] as String,
      entityId:      row['entity_id'] as String,
      operation:     row['operation'] as String,
      fieldChanges:  changes,
      timestamp:     row['timestamp'] as String,
      deviceId:      row['device_id'] as String? ?? '',
      userId:        row['user_id'] as String,
      sessionId:     row['session_id'] as String? ?? '',
      clientVersion: (row['client_version'] as num?)?.toInt() ?? 1,
    );
  }

  @override
  String toString() => 'SyncEvent($operation $entityType#$entityId v$clientVersion)';
}

/// Výsledok push operácie pre jeden event
class SyncEventResult {
  final String entityId;
  final String status;       // 'ok' | 'conflict' | 'error'
  final String? resolution;  // 'server-wins' | 'client-wins' | 'field-merge' | 'manual'
  final String? reason;

  const SyncEventResult({
    required this.entityId,
    required this.status,
    this.resolution,
    this.reason,
  });

  factory SyncEventResult.fromJson(Map<String, dynamic> json) => SyncEventResult(
        entityId:   json['entityId'] as String? ?? '',
        status:     json['status'] as String? ?? 'error',
        resolution: json['resolution'] as String?,
        reason:     json['reason'] as String?,
      );
}
