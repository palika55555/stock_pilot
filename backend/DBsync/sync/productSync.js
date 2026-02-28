/**
 * Sync produktov z Flutter (SQLite) do PostgreSQL – replace všetkých (podľa unique_id + warehouse_id).
 * @param {import('pg').Pool} pool
 * @param {object} body - { products: Array<{ uniqueId, name, plu, ean?, unit?, warehouseId?, qty? }> }
 * @returns {Promise<{ ok: boolean, count?: number, error?: string }>}
 */
async function syncProducts(pool, body) {
  if (!pool) return { ok: false, error: 'Databáza nie je k dispozícii' };
  const list = Array.isArray(body?.products) ? body.products : [];
  const client = await pool.connect();
  try {
    await client.query('DELETE FROM products');
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
      await client.query(
        `INSERT INTO products (unique_id, warehouse_id, name, plu, ean, unit, qty)
         VALUES ($1, $2, $3, $4, $5, $6, $7)`,
        [uniqueId, Number.isNaN(warehouseId) ? null : warehouseId, name, plu, ean, unit, qty]
      );
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
