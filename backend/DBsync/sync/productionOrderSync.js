/**
 * Sync výrobných príkazov z Flutter do PostgreSQL.
 */
async function syncProductionOrders(pool, body, userId) {
  if (!pool) return { ok: false, error: 'Databáza nie je k dispozícii' };
  if (!userId || userId < 1) return { ok: false, error: 'Chýba user_id' };

  const orders = Array.isArray(body?.production_orders) ? body.production_orders : [];
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    for (const o of orders) {
      const localId = o.local_id != null ? Number(o.local_id) : null;
      if (localId == null || Number.isNaN(localId)) continue;

      const existing = await client.query(
        'SELECT id FROM production_orders WHERE user_id = $1 AND local_id = $2',
        [userId, localId]
      );

      const vals = [
        userId, localId,
        o.order_number || null,
        o.recipe_local_id != null ? Number(o.recipe_local_id) : null,
        o.recipe_name || null,
        o.planned_quantity != null ? parseFloat(o.planned_quantity) : null,
        o.production_date || null,
        o.source_warehouse_id != null ? Number(o.source_warehouse_id) : null,
        o.destination_warehouse_id != null ? Number(o.destination_warehouse_id) : null,
        o.notes || null,
        o.status || 'draft',
        o.requires_approval != null ? Number(o.requires_approval) : 0,
        o.created_by_username || null,
        o.created_at || null,
        o.submitted_at || null,
        o.approver_username || null,
        o.approved_at || null,
        o.rejection_reason || null,
        o.rejected_at || null,
        o.started_at || null,
        o.completed_at || null,
        o.completed_by_username || null,
        o.actual_quantity != null ? parseFloat(o.actual_quantity) : null,
        o.variance != null ? parseFloat(o.variance) : null,
        o.material_cost != null ? parseFloat(o.material_cost) : null,
        o.labor_cost != null ? parseFloat(o.labor_cost) : null,
        o.energy_cost != null ? parseFloat(o.energy_cost) : null,
        o.overhead_cost != null ? parseFloat(o.overhead_cost) : null,
        o.other_cost != null ? parseFloat(o.other_cost) : null,
        o.total_cost != null ? parseFloat(o.total_cost) : null,
        o.cost_per_unit != null ? parseFloat(o.cost_per_unit) : null,
        o.raw_materials_stock_out_local_id != null ? Number(o.raw_materials_stock_out_local_id) : null,
        o.finished_goods_receipt_local_id != null ? Number(o.finished_goods_receipt_local_id) : null,
      ];

      if (existing.rows.length > 0) {
        await client.query(
          `UPDATE production_orders SET
            order_number=$3, recipe_local_id=$4, recipe_name=$5, planned_quantity=$6,
            production_date=$7, source_warehouse_id=$8, destination_warehouse_id=$9,
            notes=$10, status=$11, requires_approval=$12, created_by_username=$13,
            created_at=$14, submitted_at=$15, approver_username=$16, approved_at=$17,
            rejection_reason=$18, rejected_at=$19, started_at=$20, completed_at=$21,
            completed_by_username=$22, actual_quantity=$23, variance=$24,
            material_cost=$25, labor_cost=$26, energy_cost=$27, overhead_cost=$28,
            other_cost=$29, total_cost=$30, cost_per_unit=$31,
            raw_materials_stock_out_local_id=$32, finished_goods_receipt_local_id=$33
          WHERE user_id=$1 AND local_id=$2`,
          vals
        );
      } else {
        await client.query(
          `INSERT INTO production_orders (
            user_id, local_id, order_number, recipe_local_id, recipe_name, planned_quantity,
            production_date, source_warehouse_id, destination_warehouse_id, notes, status,
            requires_approval, created_by_username, created_at, submitted_at, approver_username,
            approved_at, rejection_reason, rejected_at, started_at, completed_at,
            completed_by_username, actual_quantity, variance, material_cost, labor_cost,
            energy_cost, overhead_cost, other_cost, total_cost, cost_per_unit,
            raw_materials_stock_out_local_id, finished_goods_receipt_local_id
          ) VALUES (
            $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,
            $21,$22,$23,$24,$25,$26,$27,$28,$29,$30,$31,$32,$33
          )`,
          vals
        );
      }
    }

    await client.query('COMMIT');
    return { ok: true, count: orders.length };
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('[productionOrderSync]', err.message);
    return { ok: false, error: err.message };
  } finally {
    client.release();
  }
}

async function fetchProductionOrders(pool, userId) {
  if (!pool || !userId) return null;
  const client = await pool.connect();
  try {
    const res = await client.query(
      'SELECT * FROM production_orders WHERE user_id = $1 ORDER BY id',
      [userId]
    );
    return { production_orders: res.rows };
  } catch (err) {
    console.error('[fetchProductionOrders]', err.message);
    return null;
  } finally {
    client.release();
  }
}

module.exports = { syncProductionOrders, fetchProductionOrders };
