/**
 * Sync zákazníkov z Flutter (SQLite) do PostgreSQL – upsert podľa local_id (Flutter id), izolované podľa user_id.
 * @param {import('pg').Pool} pool
 * @param {object} body - { customers: Array<{ id, name, ico, ... }> }
 * @param {number} userId - ID prihláseného používateľa (z tokenu)
 * @returns {Promise<{ ok: boolean, count?: number, error?: string }>}
 */
async function syncCustomers(pool, body, userId) {
  if (!pool) return { ok: false, error: 'Databáza nie je k dispozícii' };
  if (!userId || userId < 1) return { ok: false, error: 'Chýba user_id (token)' };
  const list = Array.isArray(body?.customers) ? body.customers : [];
  const client = await pool.connect();
  try {
    await client.query('DELETE FROM customers WHERE user_id = $1', [userId]);
    let count = 0;
    for (const c of list) {
      const localId = c.id != null ? Number(c.id) : null;
      if (localId == null || Number.isNaN(localId)) continue;
      const name = String(c.name ?? '').trim();
      const ico = String(c.ico ?? '').trim();
      const email = c.email != null ? String(c.email).trim() : null;
      const address = c.address != null ? String(c.address).trim() : null;
      const city = c.city != null ? String(c.city).trim() : null;
      const postalCode = c.postal_code != null ? String(c.postal_code).trim() : null;
      const dic = c.dic != null ? String(c.dic).trim() : null;
      const icDph = c.ic_dph != null ? String(c.ic_dph).trim() : null;
      const defaultVatRate = c.default_vat_rate != null ? Number(c.default_vat_rate) : 20;
      const isActive = c.is_active !== 0 && c.is_active !== false ? 1 : 0;
      await client.query(
        `INSERT INTO customers (user_id, local_id, name, ico, email, address, city, postal_code, dic, ic_dph, default_vat_rate, is_active)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)`,
        [userId, localId, name, ico, email, address, city, postalCode, dic, icDph, defaultVatRate, isActive]
      );
      count++;
    }
    return { ok: true, count };
  } catch (err) {
    console.error('[customerSync]', err.message);
    return { ok: false, error: err.message };
  } finally {
    client.release();
  }
}

module.exports = { syncCustomers };
