/**
 * Sync dodávateľov z Flutter (SQLite) do PostgreSQL – replace všetkých pre daného usera.
 * @param {import('pg').Pool} pool
 * @param {object} body - { suppliers: Array<{ id?, name, ico?, email?, address?, city?, postal_code?, dic?, ic_dph?, default_vat_rate?, is_active? }> }
 * @param {number} userId
 * @returns {Promise<{ ok: boolean, count?: number, error?: string }>}
 */
async function syncSuppliers(pool, body, userId) {
  if (!pool) return { ok: false, error: 'Databáza nie je k dispozícii' };
  if (!userId || userId < 1) return { ok: false, error: 'Chýba user_id (token)' };
  const list = Array.isArray(body?.suppliers) ? body.suppliers : [];
  const client = await pool.connect();
  try {
    await client.query('DELETE FROM suppliers WHERE user_id = $1', [userId]);
    let count = 0;
    for (const s of list) {
      const name = String(s.name ?? '').trim();
      const ico = String(s.ico ?? '').trim();
      if (!name) continue;
      const email = s.email != null ? String(s.email).trim() : null;
      const address = s.address != null ? String(s.address).trim() : null;
      const city = s.city != null ? String(s.city).trim() : null;
      const postalCode = s.postal_code != null ? String(s.postal_code).trim() : null;
      const dic = s.dic != null ? String(s.dic).trim() : null;
      const icDph = s.ic_dph != null ? String(s.ic_dph).trim() : null;
      const defaultVatRate = s.default_vat_rate != null ? Number(s.default_vat_rate) : 20;
      const isActive = s.is_active !== 0 && s.is_active !== false ? 1 : 0;
      await client.query(
        `INSERT INTO suppliers (user_id, name, ico, email, address, city, postal_code, dic, ic_dph, default_vat_rate, is_active)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)`,
        [userId, name, ico, email, address, city, postalCode, dic, icDph, defaultVatRate, isActive]
      );
      count++;
    }
    return { ok: true, count };
  } catch (err) {
    if (err.message?.includes('relation "suppliers" does not exist')) return { ok: true, count: 0 };
    console.error('[supplierSync]', err.message);
    return { ok: false, error: err.message };
  } finally {
    client.release();
  }
}

module.exports = { syncSuppliers };
