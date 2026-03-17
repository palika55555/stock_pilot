/**
 * Sync skladov z Flutter (SQLite) do PostgreSQL – replace všetkých pre daného usera.
 * @param {import('pg').Pool} pool
 * @param {object} body - { warehouses: Array<{ id?, name, code?, warehouse_type?, address?, city?, postal_code?, is_active? }> }
 * @param {number} userId
 * @returns {Promise<{ ok: boolean, count?: number, error?: string }>}
 */
async function syncWarehouses(pool, body, userId) {
  if (!pool) return { ok: false, error: 'Databáza nie je k dispozícii' };
  if (!userId || userId < 1) return { ok: false, error: 'Chýba user_id (token)' };
  const list = Array.isArray(body?.warehouses) ? body.warehouses : [];
  const client = await pool.connect();
  try {
    await client.query('DELETE FROM warehouses WHERE user_id = $1', [userId]);
    let count = 0;
    for (const w of list) {
      const name = String(w.name ?? '').trim();
      if (!name) continue;
      const code = String(w.code ?? '').trim();
      const warehouseType = String(w.warehouse_type ?? 'Predaj').trim();
      const address = w.address != null ? String(w.address).trim() : null;
      const city = w.city != null ? String(w.city).trim() : null;
      const postalCode = w.postal_code != null ? String(w.postal_code).trim() : null;
      const isActive = w.is_active !== 0 && w.is_active !== false ? 1 : 0;
      await client.query(
        `INSERT INTO warehouses (user_id, name, code, warehouse_type, address, city, postal_code, is_active)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
        [userId, name, code, warehouseType, address, city, postalCode, isActive]
      );
      count++;
    }
    return { ok: true, count };
  } catch (err) {
    if (err.message?.includes('relation "warehouses" does not exist')) return { ok: true, count: 0 };
    console.error('[warehouseSync]', err.message);
    return { ok: false, error: err.message };
  } finally {
    client.release();
  }
}

module.exports = { syncWarehouses };
