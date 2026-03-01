/**
 * Sync šarží a paliet z Flutter (SQLite) do PostgreSQL – upsert podľa local_id.
 * @param {import('pg').Pool} pool
 * @param {object} body - { batches: Array<{ id, production_date, product_type, quantity_produced, notes, created_at, cost_total, revenue_total, recipe?: Array<{ material_name, quantity, unit }> }>, pallets?: Array<{ id, batch_id, product_type, quantity, customer_id, status }> }
 * @returns {Promise<{ ok: boolean, count?: number, error?: string }>}
 */
async function syncBatches(pool, body) {
  if (!pool) return { ok: false, error: 'Databáza nie je k dispozícii' };
  const batches = Array.isArray(body?.batches) ? body.batches : [];
  const pallets = Array.isArray(body?.pallets) ? body.pallets : [];
  const client = await pool.connect();
  try {
    const batchIdMap = {}; // Flutter batch id -> backend batch id

    for (const b of batches) {
      const localId = b.id != null ? Number(b.id) : null;
      if (localId == null || Number.isNaN(localId)) continue;
      const productionDate = (b.production_date || '').toString().trim().slice(0, 10);
      const productType = (b.product_type || '').toString().trim() || 'Výrobok';
      const quantityProduced = parseInt(b.quantity_produced, 10) || 0;
      const notes = b.notes != null ? String(b.notes).trim() || null : null;
      const createdAt = b.created_at || null;
      const costTotal = b.cost_total != null ? parseFloat(b.cost_total) : null;
      const revenueTotal = b.revenue_total != null ? parseFloat(b.revenue_total) : null;

      let backendBatchId;
      const existing = await client.query(
        'SELECT id FROM production_batches WHERE local_id = $1',
        [localId]
      );
      if (existing.rows.length > 0) {
        backendBatchId = existing.rows[0].id;
        await client.query(
          `UPDATE production_batches SET production_date = $1, product_type = $2, quantity_produced = $3, notes = $4, created_at = $5::timestamp, cost_total = $6, revenue_total = $7 WHERE id = $8`,
          [productionDate, productType, quantityProduced, notes, createdAt, costTotal, revenueTotal, backendBatchId]
        );
      } else {
        const ins = await client.query(
          `INSERT INTO production_batches (local_id, production_date, product_type, quantity_produced, notes, created_at, cost_total, revenue_total)
           VALUES ($1, $2, $3, $4, $5, $6::timestamp, $7, $8) RETURNING id`,
          [localId, productionDate, productType, quantityProduced, notes, createdAt, costTotal, revenueTotal]
        );
        backendBatchId = ins.rows[0]?.id;
      }
      if (backendBatchId) batchIdMap[localId] = backendBatchId;

      const recipe = Array.isArray(b.recipe) ? b.recipe : [];
      await client.query('DELETE FROM production_batch_recipe WHERE batch_id = $1', [backendBatchId]);
      for (const r of recipe) {
        const qty = parseFloat(r.quantity) || 0;
        if (qty <= 0) continue;
        const matName = (r.material_name || '').toString().trim() || 'Materiál';
        const unit = (r.unit || 'kg').toString().trim();
        await client.query(
          'INSERT INTO production_batch_recipe (batch_id, material_name, quantity, unit) VALUES ($1, $2, $3, $4)',
          [backendBatchId, matName, qty, unit]
        );
      }
    }

    for (const p of pallets) {
      const localId = p.id != null ? Number(p.id) : null;
      if (localId == null || Number.isNaN(localId)) continue;
      const flutterBatchId = parseInt(p.batch_id, 10);
      const backendBatchId = batchIdMap[flutterBatchId];
      if (backendBatchId == null) continue;
      const productType = (p.product_type || '').toString().trim() || 'Výrobok';
      const quantity = parseInt(p.quantity, 10) || 0;
      const status = (p.status || 'Na sklade').toString().trim();
      let backendCustomerId = null;
      if (p.customer_id != null) {
        const cust = await client.query('SELECT id FROM customers WHERE local_id = $1', [Number(p.customer_id)]);
        if (cust.rows[0]) backendCustomerId = cust.rows[0].id;
      }
      const existingPallet = await client.query('SELECT id FROM pallets WHERE local_id = $1', [localId]);
      if (existingPallet.rows.length > 0) {
        await client.query(
          `UPDATE pallets SET batch_id = $1, product_type = $2, quantity = $3, customer_id = $4, status = $5 WHERE local_id = $6`,
          [backendBatchId, productType, quantity, backendCustomerId, status, localId]
        );
      } else {
        await client.query(
          `INSERT INTO pallets (local_id, batch_id, product_type, quantity, customer_id, status)
           VALUES ($1, $2, $3, $4, $5, $6)`,
          [localId, backendBatchId, productType, quantity, backendCustomerId, status]
        );
      }
    }

    return { ok: true, count: batches.length };
  } catch (err) {
    console.error('[batchSync]', err.message);
    return { ok: false, error: err.message };
  } finally {
    client.release();
  }
}

module.exports = { syncBatches };
