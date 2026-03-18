/**
 * Sync produktov z Flutter (SQLite) do PostgreSQL – replace všetkých pre daného usera (podľa unique_id + warehouse_id).
 * @param {import('pg').Pool} pool
 * @param {object} body - { products: Array<{ uniqueId, name, plu, ean?, unit?, warehouseId?, qty? }> }
 * @param {number} userId - ID prihláseného používateľa (z tokenu)
 * @returns {Promise<{ ok: boolean, count?: number, error?: string }>}
 */
async function syncProducts(pool, body, userId) {
  if (!pool) return { ok: false, error: 'Databáza nie je k dispozícii' };
  if (!userId || userId < 1) return { ok: false, error: 'Chýba user_id (token)' };
  const list = Array.isArray(body?.products) ? body.products : [];
  const client = await pool.connect();
  try {
    // Pred replace si načítaj existujúce produkty pre diff (kvôli activity feedu)
    const beforeRes = await client.query(
      'SELECT unique_id, warehouse_id, name, plu, ean, unit, qty, version FROM products WHERE user_id = $1',
      [userId]
    );
    const beforeMap = new Map();
    for (const r of beforeRes.rows || []) {
      const key = `${r.unique_id}::${r.warehouse_id ?? ''}`;
      beforeMap.set(key, r);
    }

    await client.query('DELETE FROM products WHERE user_id = $1', [userId]);
    let count = 0;
    for (const p of list) {
      const uniqueId = p.uniqueId != null ? String(p.uniqueId).trim() : null;
      if (!uniqueId) continue;
      const name = String(p.name ?? '').trim();
      const plu = String(p.plu ?? '').trim();
      const ean = p.ean != null ? String(p.ean).trim() || null : null;
      const unit = String(p.unit ?? 'ks').trim();
      const warehouseId = p.warehouseId != null ? parseInt(p.warehouseId, 10) : null;
      const qty = p.qty != null ? parseInt(p.qty, 10) : 0;
      if (Number.isNaN(qty)) continue;
      const wh = Number.isNaN(warehouseId) ? null : warehouseId;
      const key = `${uniqueId}::${wh ?? ''}`;
      const old = beforeMap.get(key);
      const oldVersion = old?.version ?? 1;

      await client.query(
        `INSERT INTO products (user_id, unique_id, warehouse_id, name, plu, ean, unit, qty, version, updated_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, NOW())`,
        [userId, uniqueId, wh, name, plu, ean, unit, qty, oldVersion + 1]
      );

      // Activity log: create/update + relevant field changes
      try {
        const changes = {};
        const op = old ? 'update' : 'create';
        if (!old) {
          changes.name = name;
          changes.plu = plu;
          changes.ean = ean;
          changes.unit = unit;
          changes.qty = qty;
          changes.warehouse_id = wh;
        } else {
          if (old.name !== name) changes.name = name;
          if (old.plu !== plu) changes.plu = plu;
          if ((old.ean ?? null) !== (ean ?? null)) changes.ean = ean;
          if (old.unit !== unit) changes.unit = unit;
          if (Number(old.qty) !== qty) changes.qty = qty;
        }
        if (Object.keys(changes).length > 0) {
          await client.query(
            `INSERT INTO sync_events
             (entity_type, entity_id, operation, field_changes, client_timestamp,
              device_id, user_id, session_id, client_version, server_version)
             VALUES ($1,$2,$3,$4,NOW(),$5,$6,$7,$8,$9)`,
            [
              'product',
              uniqueId,
              op,
              JSON.stringify(changes),
              'flutter-bulk',
              userId,
              null,
              oldVersion,
              oldVersion + 1,
            ]
          );
        }
      } catch (_) {}

      count++;
    }
    return { ok: true, count };
  } catch (err) {
    console.error('[productSync]', err.message);
    return { ok: false, error: err.message };
  } finally {
    client.release();
  }
}

module.exports = { syncProducts };
