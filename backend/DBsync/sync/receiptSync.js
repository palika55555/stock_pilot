/**
 * Sync prijemiek z Flutter (SQLite) do PostgreSQL – upsert podľa local_id.
 * @param {import('pg').Pool} pool
 * @param {object} body - { receipts, items, costs }
 * @param {number} userId
 */
async function syncReceipts(pool, body, userId) {
  if (!pool) return { ok: false, error: 'Databáza nie je k dispozícii' };
  if (!userId || userId < 1) return { ok: false, error: 'Chýba user_id' };

  const receipts = Array.isArray(body?.receipts) ? body.receipts : [];
  const items = Array.isArray(body?.items) ? body.items : [];
  const costs = Array.isArray(body?.costs) ? body.costs : [];

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    for (const r of receipts) {
      const localId = r.local_id != null ? Number(r.local_id) : null;
      if (localId == null || Number.isNaN(localId)) continue;

      const existing = await client.query(
        'SELECT id, status, stock_applied FROM inbound_receipts WHERE user_id = $1 AND local_id = $2',
        [userId, localId]
      );
      const existed = existing.rows.length > 0;
      const oldStatus = existed ? existing.rows[0].status : null;
      const oldApplied = existed ? Number(existing.rows[0].stock_applied) || 0 : 0;

      const vals = [
        userId, localId,
        (r.receipt_number || '').toString().trim(),
        r.created_at || null,
        r.supplier_name || null,
        r.notes || null,
        r.username || null,
        r.prices_include_vat != null ? Number(r.prices_include_vat) : 0,
        r.vat_applies_to_all != null ? Number(r.vat_applies_to_all) : 0,
        r.vat_rate != null ? parseFloat(r.vat_rate) : null,
        r.status || 'rozpracovany',
        r.invoice_number || null,
        r.warehouse_id != null ? Number(r.warehouse_id) : null,
        r.source_warehouse_id != null ? Number(r.source_warehouse_id) : null,
        r.movement_type_code || 'STANDARD',
        r.je_vysporiadana != null ? Number(r.je_vysporiadana) : 0,
        r.linked_stock_out_local_id != null ? Number(r.linked_stock_out_local_id) : null,
        r.cost_distribution_method || null,
        r.submitted_at || null,
        r.approved_at || null,
        r.approver_username || null,
        r.approver_note || null,
        r.rejected_at || null,
        r.rejection_reason || null,
        r.reversed_at || null,
        r.reversed_by_username || null,
        r.reverse_reason || null,
        r.stock_applied != null ? Number(r.stock_applied) : 0,
        r.supplier_id != null ? Number(r.supplier_id) : null,
        r.supplier_ico || null,
        r.supplier_dic || null,
        r.supplier_address || null,
        r.delivery_note_number || null,
        r.po_number || null,
      ];

      if (existed) {
        await client.query(
          `UPDATE inbound_receipts SET
            receipt_number=$3, created_at=$4, supplier_name=$5, notes=$6, username=$7,
            prices_include_vat=$8, vat_applies_to_all=$9, vat_rate=$10, status=$11,
            invoice_number=$12, warehouse_id=$13, source_warehouse_id=$14, movement_type_code=$15,
            je_vysporiadana=$16, linked_stock_out_local_id=$17, cost_distribution_method=$18,
            submitted_at=$19, approved_at=$20, approver_username=$21, approver_note=$22,
            rejected_at=$23, rejection_reason=$24, reversed_at=$25, reversed_by_username=$26,
            reverse_reason=$27, stock_applied=$28, supplier_id=$29, supplier_ico=$30,
            supplier_dic=$31, supplier_address=$32, delivery_note_number=$33, po_number=$34
          WHERE user_id=$1 AND local_id=$2`,
          vals
        );
      } else {
        await client.query(
          `INSERT INTO inbound_receipts (
            user_id, local_id, receipt_number, created_at, supplier_name, notes, username,
            prices_include_vat, vat_applies_to_all, vat_rate, status, invoice_number,
            warehouse_id, source_warehouse_id, movement_type_code, je_vysporiadana,
            linked_stock_out_local_id, cost_distribution_method, submitted_at, approved_at,
            approver_username, approver_note, rejected_at, rejection_reason, reversed_at,
            reversed_by_username, reverse_reason, stock_applied, supplier_id, supplier_ico,
            supplier_dic, supplier_address, delivery_note_number, po_number
          ) VALUES (
            $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,
            $21,$22,$23,$24,$25,$26,$27,$28,$29,$30,$31,$32,$33,$34
          )`,
          vals
        );
      }

      // Activity log: vytvorenie/úprava + špeciálne "aplikovanie skladu"
      try {
        const newStatus = vals[10];
        const newApplied = Number(vals[27]) || 0; // stock_applied
        const changes = {};
        if (!existed) {
          changes.receipt_number = vals[2];
          changes.status = newStatus;
          changes.stock_applied = newApplied;
          changes.supplier_name = vals[4];
        } else {
          if (oldStatus !== newStatus) changes.status = newStatus;
          if (oldApplied !== newApplied) changes.stock_applied = newApplied;
        }
        if (Object.keys(changes).length > 0) {
          await client.query(
            `INSERT INTO sync_events
             (entity_type, entity_id, operation, field_changes, client_timestamp,
              device_id, user_id, session_id, client_version, server_version)
             VALUES ($1,$2,$3,$4,NOW(),$5,$6,$7,$8,$9)`,
            [
              'inbound_receipt',
              String(localId),
              existed ? 'update' : 'create',
              JSON.stringify(changes),
              'flutter',
              userId,
              null,
              1,
              1,
            ]
          );
        }
      } catch (_) {}
    }

    for (const item of items) {
      const localId = item.local_id != null ? Number(item.local_id) : null;
      if (localId == null || Number.isNaN(localId)) continue;
      const existing = await client.query(
        'SELECT id FROM inbound_receipt_items WHERE user_id = $1 AND local_id = $2',
        [userId, localId]
      );
      const vals = [
        userId, localId,
        item.receipt_local_id != null ? Number(item.receipt_local_id) : null,
        item.product_unique_id || null,
        item.product_name || null,
        item.plu || null,
        item.qty != null ? parseFloat(item.qty) : null,
        item.unit || null,
        item.unit_price != null ? parseFloat(item.unit_price) : null,
        item.vat_percent != null ? parseFloat(item.vat_percent) : null,
        item.allocated_cost != null ? parseFloat(item.allocated_cost) : null,
        item.total_price != null ? parseFloat(item.total_price) : null,
        item.batch_number || null,
        item.expiry_date || null,
      ];
      if (existing.rows.length > 0) {
        await client.query(
          `UPDATE inbound_receipt_items SET
            receipt_local_id=$3, product_unique_id=$4, product_name=$5, plu=$6,
            qty=$7, unit=$8, unit_price=$9, vat_percent=$10, allocated_cost=$11,
            total_price=$12, batch_number=$13, expiry_date=$14
          WHERE user_id=$1 AND local_id=$2`,
          vals
        );
      } else {
        await client.query(
          `INSERT INTO inbound_receipt_items (
            user_id, local_id, receipt_local_id, product_unique_id, product_name, plu,
            qty, unit, unit_price, vat_percent, allocated_cost, total_price, batch_number, expiry_date
          ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14)`,
          vals
        );
      }
    }

    for (const cost of costs) {
      const localId = cost.local_id != null ? Number(cost.local_id) : null;
      if (localId == null || Number.isNaN(localId)) continue;
      const existing = await client.query(
        'SELECT id FROM receipt_acquisition_costs WHERE user_id = $1 AND local_id = $2',
        [userId, localId]
      );
      const vals = [
        userId, localId,
        cost.receipt_local_id != null ? Number(cost.receipt_local_id) : null,
        cost.cost_type || null,
        cost.description || null,
        cost.amount_without_vat != null ? parseFloat(cost.amount_without_vat) : null,
        cost.vat_percent != null ? parseFloat(cost.vat_percent) : null,
        cost.amount_with_vat != null ? parseFloat(cost.amount_with_vat) : null,
        cost.cost_supplier_name || null,
        cost.document_number || null,
        cost.sort_order != null ? Number(cost.sort_order) : 0,
      ];
      if (existing.rows.length > 0) {
        await client.query(
          `UPDATE receipt_acquisition_costs SET
            receipt_local_id=$3, cost_type=$4, description=$5, amount_without_vat=$6,
            vat_percent=$7, amount_with_vat=$8, cost_supplier_name=$9,
            document_number=$10, sort_order=$11
          WHERE user_id=$1 AND local_id=$2`,
          vals
        );
      } else {
        await client.query(
          `INSERT INTO receipt_acquisition_costs (
            user_id, local_id, receipt_local_id, cost_type, description,
            amount_without_vat, vat_percent, amount_with_vat, cost_supplier_name,
            document_number, sort_order
          ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)`,
          vals
        );
      }
    }

    await client.query('COMMIT');
    return { ok: true, count: receipts.length };
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('[receiptSync]', err.message);
    return { ok: false, error: err.message };
  } finally {
    client.release();
  }
}

/**
 * Vráti všetky prijemky používateľa vrátane položiek a nákladov.
 */
async function fetchReceipts(pool, userId) {
  if (!pool || !userId) return null;
  const client = await pool.connect();
  try {
    const receiptsRes = await client.query(
      'SELECT * FROM inbound_receipts WHERE user_id = $1 ORDER BY id',
      [userId]
    );
    const itemsRes = await client.query(
      'SELECT * FROM inbound_receipt_items WHERE user_id = $1 ORDER BY id',
      [userId]
    );
    const costsRes = await client.query(
      'SELECT * FROM receipt_acquisition_costs WHERE user_id = $1 ORDER BY id',
      [userId]
    );
    return {
      receipts: receiptsRes.rows,
      items: itemsRes.rows,
      costs: costsRes.rows,
    };
  } catch (err) {
    console.error('[fetchReceipts]', err.message);
    return null;
  } finally {
    client.release();
  }
}

module.exports = { syncReceipts, fetchReceipts };
