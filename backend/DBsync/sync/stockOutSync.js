/**
 * Sync výdajiek z Flutter (SQLite) do PostgreSQL – upsert podľa local_id.
 * @param {import('pg').Pool} pool
 * @param {object} body - { stock_outs, items, movements }
 * @param {number} userId
 */
async function syncStockOuts(pool, body, userId) {
  if (!pool) return { ok: false, error: 'Databáza nie je k dispozícii' };
  if (!userId || userId < 1) return { ok: false, error: 'Chýba user_id' };

  const outs = Array.isArray(body?.stock_outs) ? body.stock_outs : [];
  const items = Array.isArray(body?.items) ? body.items : [];
  const movements = Array.isArray(body?.movements) ? body.movements : [];

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    for (const s of outs) {
      const localId = s.local_id != null ? Number(s.local_id) : null;
      if (localId == null || Number.isNaN(localId)) continue;

      const existing = await client.query(
        'SELECT id FROM stock_outs WHERE user_id = $1 AND local_id = $2',
        [userId, localId]
      );

      const vals = [
        userId, localId,
        s.document_number || null,
        s.created_at || null,
        s.recipient_name || null,
        s.notes || null,
        s.username || null,
        s.status || 'rozpracovany',
        s.warehouse_id != null ? Number(s.warehouse_id) : null,
        s.je_vysporiadana != null ? Number(s.je_vysporiadana) : 0,
        s.vat_rate != null ? parseFloat(s.vat_rate) : null,
        s.issue_type || null,
        s.write_off_reason || null,
        s.linked_receipt_local_id != null ? Number(s.linked_receipt_local_id) : null,
        s.customer_id != null ? Number(s.customer_id) : null,
        s.recipient_ico || null,
        s.recipient_dic || null,
        s.recipient_address || null,
        s.submitted_at || null,
        s.approved_at || null,
        s.approver_username || null,
        s.approver_note || null,
        s.rejected_at || null,
        s.rejection_reason || null,
      ];

      if (existing.rows.length > 0) {
        await client.query(
          `UPDATE stock_outs SET
            document_number=$3, created_at=$4, recipient_name=$5, notes=$6, username=$7,
            status=$8, warehouse_id=$9, je_vysporiadana=$10, vat_rate=$11, issue_type=$12,
            write_off_reason=$13, linked_receipt_local_id=$14, customer_id=$15,
            recipient_ico=$16, recipient_dic=$17, recipient_address=$18,
            submitted_at=$19, approved_at=$20, approver_username=$21, approver_note=$22,
            rejected_at=$23, rejection_reason=$24
          WHERE user_id=$1 AND local_id=$2`,
          vals
        );
      } else {
        await client.query(
          `INSERT INTO stock_outs (
            user_id, local_id, document_number, created_at, recipient_name, notes, username,
            status, warehouse_id, je_vysporiadana, vat_rate, issue_type, write_off_reason,
            linked_receipt_local_id, customer_id, recipient_ico, recipient_dic, recipient_address,
            submitted_at, approved_at, approver_username, approver_note, rejected_at, rejection_reason
          ) VALUES (
            $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21,$22,$23,$24
          )`,
          vals
        );
      }
    }

    for (const item of items) {
      const localId = item.local_id != null ? Number(item.local_id) : null;
      if (localId == null || Number.isNaN(localId)) continue;
      const existing = await client.query(
        'SELECT id FROM stock_out_items WHERE user_id = $1 AND local_id = $2',
        [userId, localId]
      );
      const vals = [
        userId, localId,
        item.stock_out_local_id != null ? Number(item.stock_out_local_id) : null,
        item.product_unique_id || null,
        item.product_name || null,
        item.plu || null,
        item.qty != null ? parseFloat(item.qty) : null,
        item.unit || null,
        item.unit_price != null ? parseFloat(item.unit_price) : null,
        item.batch_number || null,
        item.expiry_date || null,
      ];
      if (existing.rows.length > 0) {
        await client.query(
          `UPDATE stock_out_items SET
            stock_out_local_id=$3, product_unique_id=$4, product_name=$5, plu=$6,
            qty=$7, unit=$8, unit_price=$9, batch_number=$10, expiry_date=$11
          WHERE user_id=$1 AND local_id=$2`,
          vals
        );
      } else {
        await client.query(
          `INSERT INTO stock_out_items (
            user_id, local_id, stock_out_local_id, product_unique_id, product_name, plu,
            qty, unit, unit_price, batch_number, expiry_date
          ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)`,
          vals
        );
      }
    }

    for (const mv of movements) {
      const localId = mv.local_id != null ? Number(mv.local_id) : null;
      if (localId == null || Number.isNaN(localId)) continue;
      const existing = await client.query(
        'SELECT id FROM stock_movements WHERE user_id = $1 AND local_id = $2',
        [userId, localId]
      );
      const vals = [
        userId, localId,
        mv.stock_out_local_id != null ? Number(mv.stock_out_local_id) : null,
        mv.document_number || null,
        mv.created_at || null,
        mv.product_unique_id || null,
        mv.product_name || null,
        mv.plu || null,
        mv.qty != null ? parseFloat(mv.qty) : null,
        mv.unit || null,
        mv.direction || null,
      ];
      if (existing.rows.length > 0) {
        await client.query(
          `UPDATE stock_movements SET
            stock_out_local_id=$3, document_number=$4, created_at=$5, product_unique_id=$6,
            product_name=$7, plu=$8, qty=$9, unit=$10, direction=$11
          WHERE user_id=$1 AND local_id=$2`,
          vals
        );
      } else {
        await client.query(
          `INSERT INTO stock_movements (
            user_id, local_id, stock_out_local_id, document_number, created_at,
            product_unique_id, product_name, plu, qty, unit, direction
          ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)`,
          vals
        );
      }
    }

    await client.query('COMMIT');
    return { ok: true, count: outs.length };
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('[stockOutSync]', err.message);
    return { ok: false, error: err.message };
  } finally {
    client.release();
  }
}

async function fetchStockOuts(pool, userId) {
  if (!pool || !userId) return null;
  const client = await pool.connect();
  try {
    const outsRes = await client.query(
      'SELECT * FROM stock_outs WHERE user_id = $1 ORDER BY id',
      [userId]
    );
    const itemsRes = await client.query(
      'SELECT * FROM stock_out_items WHERE user_id = $1 ORDER BY id',
      [userId]
    );
    const movementsRes = await client.query(
      'SELECT * FROM stock_movements WHERE user_id = $1 ORDER BY id',
      [userId]
    );
    return {
      stock_outs: outsRes.rows,
      items: itemsRes.rows,
      movements: movementsRes.rows,
    };
  } catch (err) {
    console.error('[fetchStockOuts]', err.message);
    return null;
  } finally {
    client.release();
  }
}

module.exports = { syncStockOuts, fetchStockOuts };
