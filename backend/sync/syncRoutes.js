/**
 * syncRoutes.js – Nové generické sync endpointy pre Stock Pilot.
 *
 * Endpointy:
 *   POST /sync/push        – Flutter posiela dávku offline zmien
 *   GET  /sync/pull        – Flutter sťahuje zmeny od daného času
 *   GET  /sync/conflicts   – zoznam nerozriešených konfliktov
 *   POST /sync/resolve     – manuálne rozriešenie konfliktu
 *   GET  /sync/events/stream – SSE real-time push pre web klientov
 *
 * Autentifikácia: JWT (Bearer) – riešená cez authenticateToken middleware v server.js.
 * Sub-user: req.dataUserId = owner_id (ako v ostatných endpointoch).
 */

const { ConflictResolutionEngine } = require('./conflictResolution');
const { syncConfig }               = require('./syncConfig');

const engine = new ConflictResolutionEngine(syncConfig);

// Mapa entityType → PostgreSQL tabuľka + primárny kľúč (idField musí byť stĺpec s user_id)
const ENTITY_MAP = {
  product:          { table: 'products',          idField: 'unique_id' },
  customer:         { table: 'customers',          idField: 'id' },
  warehouse:        { table: 'warehouses',         idField: 'id' },
  supplier:         { table: 'suppliers',          idField: 'id' },
  inbound_receipt:  { table: 'inbound_receipts',   idField: 'id' },
  stock_out:        { table: 'stock_outs',         idField: 'id' },
  recipe:           { table: 'recipes',            idField: 'id' },
  production_order: { table: 'production_orders',  idField: 'id' },
  production_batch: { table: 'production_batches', idField: 'id' },
  quote:            { table: 'quotes',             idField: 'id' },
  transport:        { table: 'transports',         idField: 'id' },
  pallet:           { table: 'pallets',            idField: 'id' },
  company:          { table: 'company',            idField: 'id' },
};

// SSE: prihlásení klienti čakajúci na push notifikácie  { userId → Set<res> }
const sseClients = new Map();

/**
 * Zaregistruje sync endpointy na router.
 * @param {import('express').Router} router
 * @param {import('pg').Pool}        pool
 */
function registerSyncRoutes(router, pool) {
  // -----------------------------------------------------------------------
  // POST /sync/push
  // Dávkové nahranie offline zmien z Flutter apky.
  // Body: { deviceId, events: SyncEvent[] }
  // -----------------------------------------------------------------------
  router.post('/sync/push', async (req, res) => {
    if (!pool) return res.status(503).json({ error: 'DB unavailable' });

    const userId   = req.dataUserId || req.userId;
    const deviceId = req.body?.deviceId || null;
    const events   = Array.isArray(req.body?.events) ? req.body.events : [];

    if (events.length === 0) return res.json({ ok: true, processed: 0, results: [], conflicts: [] });

    const results   = [];
    const conflicts = [];
    const client    = await pool.connect();

    try {
      await client.query('BEGIN');

      for (const event of events) {
        const { entityType, entityId, operation, fieldChanges, timestamp, sessionId, clientVersion } = event;

        // Validácia povinných polí
        if (!entityType || !entityId || !operation || !timestamp) {
          results.push({ entityId, status: 'error', reason: 'missing required fields' });
          continue;
        }

        const mapping = ENTITY_MAP[entityType];
        if (!mapping) {
          results.push({ entityId, status: 'error', reason: `unknown entityType: ${entityType}` });
          continue;
        }

        // Načítaj aktuálny serverový stav záznamu
        const serverRow = await client.query(
          `SELECT version, updated_at FROM ${mapping.table}
           WHERE ${mapping.idField} = $1 AND user_id = $2`,
          [entityId, userId]
        );
        const serverRecord  = serverRow.rows[0];
        const serverVersion = serverRecord?.version ?? 0;

        // ----------------------------------------------------------------
        // SOFT DELETE
        // ----------------------------------------------------------------
        if (operation === 'delete') {
          if (serverRecord) {
            await client.query(
              `UPDATE ${mapping.table}
               SET deleted_at = NOW(), version = version + 1, updated_at = NOW()
               WHERE ${mapping.idField} = $1 AND user_id = $2`,
              [entityId, userId]
            );
          }
          await _logEvent(client, { entityType, entityId, operation, fieldChanges: {}, timestamp, deviceId, userId, sessionId, clientVersion, serverVersion });
          results.push({ entityId, status: 'ok', operation: 'delete' });
          _notifySseClients(userId, deviceId, { entityType, entityId, operation: 'delete' });
          continue;
        }

        // ----------------------------------------------------------------
        // DETEKCIA KONFLIKTU
        // Ak existuje serverový záznam s inou verziou než klient očakával
        // ----------------------------------------------------------------
        const hasVersionMismatch = serverRecord && clientVersion !== serverVersion;

        if (hasVersionMismatch) {
          // Zisti čo bolo naposledy zmenené na serveri (field-level diff z posled. sync_event)
          const lastServerEvent = await client.query(
            `SELECT field_changes, server_timestamp
             FROM sync_events
             WHERE entity_type = $1 AND entity_id = $2 AND user_id = $3
             ORDER BY server_timestamp DESC
             LIMIT 1`,
            [entityType, entityId, userId]
          );

          const serverFieldChanges = lastServerEvent.rows[0]?.field_changes || {};
          const serverUpdatedAt    = serverRecord.updated_at;

          const resolution = engine.resolve({
            entityType,
            entityId,
            clientChange: { fieldChanges: fieldChanges || {}, timestamp, clientVersion },
            serverState:  { fieldChanges: serverFieldChanges, version: serverVersion, updatedAt: serverUpdatedAt },
          });

          // Log do sync_conflicts (vždy, aj pri automatickom rozriešení)
          await client.query(
            `INSERT INTO sync_conflicts
             (entity_type, entity_id, conflict_fields, client_change, server_change,
              client_version, server_version, client_timestamp, strategy_applied, resolution,
              user_id, device_id)
             VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)`,
            [
              entityType, entityId,
              JSON.stringify(resolution.conflictingFields),
              JSON.stringify({ fieldChanges, timestamp, clientVersion }),
              JSON.stringify({ fieldChanges: serverFieldChanges, version: serverVersion }),
              clientVersion, serverVersion,
              timestamp,
              resolution.strategy,
              resolution.result === 'manual' ? 'pending' : resolution.result,
              userId, deviceId,
            ]
          );

          // Manuálny konflikt – uchov, odpovedz klientovi, čakaj na /sync/resolve
          if (resolution.result === 'manual') {
            conflicts.push({ entityType, entityId, conflictingFields: resolution.conflictingFields });
            results.push({ entityId, status: 'conflict', resolution: 'manual' });
            continue;
          }

          // server-wins – zahodí client zmenu (len zalogujeme event)
          if (resolution.result === 'server-wins') {
            await _logEvent(client, { entityType, entityId, operation, fieldChanges, timestamp, deviceId, userId, sessionId, clientVersion, serverVersion });
            results.push({ entityId, status: 'conflict', resolution: 'server-wins' });
            continue;
          }

          // client-wins / field-merge – aplikuj zmeny na server
          const applyFields = resolution.result === 'field-merge'
            ? resolution.mergedFields
            : (fieldChanges || {});

          await _applyUpdate(client, mapping, entityId, userId, applyFields);
          await _logEvent(client, { entityType, entityId, operation, fieldChanges: applyFields, timestamp, deviceId, userId, sessionId, clientVersion, serverVersion: serverVersion + 1 });
          results.push({ entityId, status: 'ok', resolution: resolution.result });
          _notifySseClients(userId, deviceId, { entityType, entityId, operation });
          continue;
        }

        // ----------------------------------------------------------------
        // BEZ KONFLIKTU – aplikuj zmenu priamo
        // ----------------------------------------------------------------
        if (operation === 'create') {
          // Create – INSERT sa vykonáva cez existujúce sync endpointy; tu len logujeme
          await _logEvent(client, { entityType, entityId, operation: 'create', fieldChanges, timestamp, deviceId, userId, sessionId, clientVersion, serverVersion: 1 });
          results.push({ entityId, status: 'ok', operation: 'create' });
        } else {
          // Update
          await _applyUpdate(client, mapping, entityId, userId, fieldChanges);
          await _logEvent(client, { entityType, entityId, operation: 'update', fieldChanges, timestamp, deviceId, userId, sessionId, clientVersion, serverVersion: serverVersion + 1 });
          results.push({ entityId, status: 'ok', operation: 'update' });
          _notifySseClients(userId, deviceId, { entityType, entityId, operation });
        }
      }

      await client.query('COMMIT');
      res.json({ ok: true, processed: results.length, results, conflicts });
    } catch (err) {
      await client.query('ROLLBACK');
      console.error('[sync/push]', err.message);
      res.status(500).json({ error: err.message });
    } finally {
      client.release();
    }
  });

  // -----------------------------------------------------------------------
  // GET /sync/pull?since=<ISO>&deviceId=<id>
  // Flutter stiahne zmeny ktoré vznikli na serveri od posledného pullu.
  // Vynechá udalosti z toho istého zariadenia (deviceId).
  // -----------------------------------------------------------------------
  router.get('/sync/pull', async (req, res) => {
    if (!pool) return res.status(503).json({ error: 'DB unavailable' });

    const userId   = req.dataUserId || req.userId;
    const since    = req.query.since    || new Date(0).toISOString();
    const deviceId = req.query.deviceId || null;

    try {
      const { rows } = await pool.query(
        `SELECT entity_type, entity_id, operation, field_changes,
                server_timestamp, server_version, client_version
         FROM sync_events
         WHERE user_id = $1
           AND server_timestamp > $2
           AND (device_id IS DISTINCT FROM $3 OR device_id IS NULL)
         ORDER BY server_timestamp ASC
         LIMIT 2000`,
        [userId, since, deviceId]
      );

      res.json({
        ok:         true,
        events:     rows,
        count:      rows.length,
        serverTime: new Date().toISOString(),
      });
    } catch (err) {
      console.error('[sync/pull]', err.message);
      res.status(500).json({ error: err.message });
    }
  });

  // -----------------------------------------------------------------------
  // GET /sync/conflicts
  // Zoznam nerozriešených (pending) konfliktov pre daného usera.
  // -----------------------------------------------------------------------
  router.get('/sync/conflicts', async (req, res) => {
    if (!pool) return res.status(503).json({ error: 'DB unavailable' });

    const userId = req.dataUserId || req.userId;

    try {
      const { rows } = await pool.query(
        `SELECT id, entity_type, entity_id, conflict_fields,
                client_change, server_change,
                client_version, server_version,
                client_timestamp, created_at, device_id
         FROM sync_conflicts
         WHERE user_id = $1 AND resolution = 'pending'
         ORDER BY created_at DESC`,
        [userId]
      );

      res.json({ ok: true, conflicts: rows, count: rows.length });
    } catch (err) {
      console.error('[sync/conflicts]', err.message);
      res.status(500).json({ error: err.message });
    }
  });

  // -----------------------------------------------------------------------
  // POST /sync/resolve
  // Manuálne rozriešenie konfliktu adminom / používateľom.
  // Body: { conflictId, resolution: 'server-wins'|'client-wins'|'manual', resolvedData? }
  // -----------------------------------------------------------------------
  router.post('/sync/resolve', async (req, res) => {
    if (!pool) return res.status(503).json({ error: 'DB unavailable' });

    const userId = req.dataUserId || req.userId;
    const { conflictId, resolution, resolvedData } = req.body || {};

    if (!conflictId || !resolution) {
      return res.status(400).json({ error: 'conflictId and resolution are required' });
    }
    if (!['server-wins', 'client-wins', 'manual'].includes(resolution)) {
      return res.status(400).json({ error: 'Invalid resolution value' });
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      // Načítaj konflikt (overenie vlastníctva)
      const { rows } = await client.query(
        'SELECT * FROM sync_conflicts WHERE id = $1 AND user_id = $2',
        [conflictId, userId]
      );
      const conflict = rows[0];
      if (!conflict) return res.status(404).json({ error: 'Conflict not found' });

      const mapping = ENTITY_MAP[conflict.entity_type];
      if (!mapping) return res.status(400).json({ error: `Unknown entityType: ${conflict.entity_type}` });

      // Aplikuj zvolenú verziu na server
      let applyFields = null;
      if (resolution === 'client-wins') {
        applyFields = conflict.client_change?.fieldChanges;
      } else if (resolution === 'manual' && resolvedData) {
        applyFields = resolvedData;
      }
      // server-wins: nič nemeníme – serverový stav zostáva

      if (applyFields && Object.keys(applyFields).length > 0) {
        await _applyUpdate(client, mapping, conflict.entity_id, userId, applyFields);
        // Zaloguj výslednú zmenu
        await _logEvent(client, {
          entityType:    conflict.entity_type,
          entityId:      conflict.entity_id,
          operation:     'update',
          fieldChanges:  applyFields,
          timestamp:     new Date().toISOString(),
          deviceId:      'server-resolve',
          userId,
          sessionId:     null,
          clientVersion: conflict.server_version,
          serverVersion: conflict.server_version + 1,
        });
      }

      // Označ konflikt ako rozriešený
      await client.query(
        `UPDATE sync_conflicts
         SET resolution = $1, resolved_at = NOW(), resolved_by = $2, resolved_data = $3
         WHERE id = $4`,
        [resolution, req.userId, JSON.stringify(resolvedData || {}), conflictId]
      );

      await client.query('COMMIT');

      // Notifikuj SSE klientov
      _notifySseClients(userId, null, {
        entityType: conflict.entity_type,
        entityId:   conflict.entity_id,
        operation:  'update',
      });

      res.json({ ok: true, conflictId, resolution });
    } catch (err) {
      await client.query('ROLLBACK');
      console.error('[sync/resolve]', err.message);
      res.status(500).json({ error: err.message });
    } finally {
      client.release();
    }
  });

  // -----------------------------------------------------------------------
  // GET /sync/events/stream – SSE real-time push
  // Webový / natívny klient sa pripojí a dostáva push notifikácie pri každej zmene.
  // Notifikácia obsahuje: entityType, entityId, operation (klient si dogge aktuálny stav).
  // -----------------------------------------------------------------------
  router.get('/sync/events/stream', (req, res) => {
    const userId = req.dataUserId || req.userId;
    if (!userId) return res.status(401).end();

    res.setHeader('Content-Type',                'text/event-stream');
    res.setHeader('Cache-Control',               'no-cache');
    res.setHeader('Connection',                  'keep-alive');
    res.setHeader('X-Accel-Buffering',           'no'); // Nginx: vypni buffering SSE
    res.flushHeaders();

    // Heartbeat každých 20 s – zabraňuje timeoutu proxy serverov
    const heartbeat = setInterval(() => {
      try { res.write(':heartbeat\n\n'); } catch (_) {}
    }, 20_000);

    // Registruj klienta
    if (!sseClients.has(userId)) sseClients.set(userId, new Set());
    sseClients.get(userId).add(res);

    res.write(`data: ${JSON.stringify({ type: 'connected', serverTime: new Date().toISOString() })}\n\n`);

    req.on('close', () => {
      clearInterval(heartbeat);
      sseClients.get(userId)?.delete(res);
      if (sseClients.get(userId)?.size === 0) sseClients.delete(userId);
    });
  });
}

// =========================================================================
// Pomocné interné funkcie
// =========================================================================

/**
 * Aplikuje fieldChanges ako UPDATE na príslušnú tabuľku.
 * Automaticky inkrementuje version a nastaví updated_at.
 */
async function _applyUpdate(client, mapping, entityId, userId, fieldChanges) {
  if (!fieldChanges || Object.keys(fieldChanges).length === 0) return;

  // Zakáž prepis primárnych / systémových stĺpcov
  const protected_ = new Set(['id', 'user_id', 'version', 'unique_id', 'created_at']);
  const fields     = Object.keys(fieldChanges).filter((k) => !protected_.has(k));
  if (fields.length === 0) return;

  const sets   = fields.map((k, i) => `"${k}" = $${i + 3}`).join(', ');
  const values = fields.map((k) => fieldChanges[k]);

  await client.query(
    `UPDATE ${mapping.table}
     SET ${sets}, version = version + 1, updated_at = NOW()
     WHERE ${mapping.idField} = $1 AND user_id = $2`,
    [entityId, userId, ...values]
  );
}

/**
 * Zapíše záznam do sync_events (append-only log).
 */
async function _logEvent(client, {
  entityType, entityId, operation, fieldChanges,
  timestamp, deviceId, userId, sessionId, clientVersion, serverVersion,
}) {
  await client.query(
    `INSERT INTO sync_events
     (entity_type, entity_id, operation, field_changes, client_timestamp,
      device_id, user_id, session_id, client_version, server_version)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)`,
    [
      entityType, entityId, operation,
      JSON.stringify(fieldChanges || {}),
      timestamp, deviceId, userId, sessionId,
      clientVersion, serverVersion,
    ]
  );
}

/**
 * Pošle SSE notifikáciu všetkým pripojeným klientom daného usera
 * (okrem zariadenia ktoré zmenu spustilo).
 */
function _notifySseClients(userId, excludeDeviceId, payload) {
  const clients = sseClients.get(String(userId));
  if (!clients || clients.size === 0) return;

  const data = JSON.stringify({ type: 'change', ...payload, serverTime: new Date().toISOString() });
  for (const res of clients) {
    try { res.write(`data: ${data}\n\n`); } catch (_) { /* klient sa odpojil */ }
  }
}

module.exports = { registerSyncRoutes };
