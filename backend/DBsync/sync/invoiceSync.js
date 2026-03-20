/**
 * Sync faktúr (invoices + invoice_items) z Flutter do PostgreSQL – upsert podľa local_id.
 * Rovnaký vzor ako quoteSyncFull.js.
 */

async function syncInvoicesFull(pool, body, userId) {
  if (!pool) return { ok: false, error: 'Databáza nie je k dispozícii' };
  if (!userId || userId < 1) return { ok: false, error: 'Chýba user_id' };

  const invoices = Array.isArray(body?.invoices) ? body.invoices : [];
  const items    = Array.isArray(body?.items)    ? body.items    : [];

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    for (const inv of invoices) {
      const localId = inv.local_id != null ? Number(inv.local_id) : null;
      if (localId == null || Number.isNaN(localId)) continue;

      const existing = await client.query(
        'SELECT id FROM invoices WHERE user_id = $1 AND local_id = $2',
        [userId, localId]
      );

      const vals = [
        userId, localId,                                                                  // $1, $2
        inv.invoice_number   || null,                                                     // $3
        inv.invoice_type     || 'issuedInvoice',                                          // $4
        inv.issue_date       || null,                                                     // $5
        inv.tax_date         || null,                                                     // $6
        inv.due_date         || null,                                                     // $7
        inv.customer_id != null ? Number(inv.customer_id) : null,                        // $8
        inv.customer_name        || null,                                                 // $9
        inv.customer_address     || null,                                                 // $10
        inv.customer_city        || null,                                                 // $11
        inv.customer_postal_code || null,                                                 // $12
        inv.customer_ico         || null,                                                 // $13
        inv.customer_dic         || null,                                                 // $14
        inv.customer_ic_dph      || null,                                                 // $15
        inv.customer_country     || 'SK',                                                 // $16
        inv.quote_id   != null ? Number(inv.quote_id)   : null,                          // $17
        inv.quote_number   || null,                                                       // $18
        inv.project_id != null ? Number(inv.project_id) : null,                          // $19
        inv.project_name   || null,                                                       // $20
        inv.payment_method || 'transfer',                                                 // $21
        inv.variable_symbol  || null,                                                     // $22
        inv.constant_symbol  || '0308',                                                   // $23
        inv.specific_symbol  || null,                                                     // $24
        inv.total_without_vat != null ? parseFloat(inv.total_without_vat) : 0,           // $25
        inv.total_vat         != null ? parseFloat(inv.total_vat)         : 0,           // $26
        inv.total_with_vat    != null ? parseFloat(inv.total_with_vat)    : 0,           // $27
        inv.status            || 'draft',                                                 // $28
        inv.notes             || null,                                                    // $29
        inv.original_invoice_id     != null ? Number(inv.original_invoice_id) : null,   // $30
        inv.original_invoice_number || null,                                              // $31
        inv.is_vat_payer != null ? Number(inv.is_vat_payer) : 1,                        // $32
        inv.qr_string || null,                                                            // $33
      ];

      if (existing.rows.length > 0) {
        await client.query(
          `UPDATE invoices SET
            invoice_number=$3, invoice_type=$4, issue_date=$5, tax_date=$6, due_date=$7,
            customer_id=$8, customer_name=$9, customer_address=$10, customer_city=$11,
            customer_postal_code=$12, customer_ico=$13, customer_dic=$14, customer_ic_dph=$15,
            customer_country=$16, quote_id=$17, quote_number=$18, project_id=$19,
            project_name=$20, payment_method=$21, variable_symbol=$22, constant_symbol=$23,
            specific_symbol=$24, total_without_vat=$25, total_vat=$26, total_with_vat=$27,
            status=$28, notes=$29, original_invoice_id=$30, original_invoice_number=$31,
            is_vat_payer=$32, qr_string=$33, updated_at=NOW()
          WHERE user_id=$1 AND local_id=$2`,
          vals
        );
      } else {
        await client.query(
          `INSERT INTO invoices (
            user_id, local_id, invoice_number, invoice_type, issue_date, tax_date, due_date,
            customer_id, customer_name, customer_address, customer_city, customer_postal_code,
            customer_ico, customer_dic, customer_ic_dph, customer_country,
            quote_id, quote_number, project_id, project_name,
            payment_method, variable_symbol, constant_symbol, specific_symbol,
            total_without_vat, total_vat, total_with_vat,
            status, notes, original_invoice_id, original_invoice_number,
            is_vat_payer, qr_string
          ) VALUES (
            $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,
            $17,$18,$19,$20,$21,$22,$23,$24,$25,$26,$27,$28,$29,$30,$31,$32,$33
          )`,
          vals
        );
      }
    }

    // Sync položiek
    for (const item of items) {
      const localId = item.local_id != null ? Number(item.local_id) : null;
      if (localId == null || Number.isNaN(localId)) continue;

      // Nájdi backend ID pre faktúru
      const invRes = await client.query(
        'SELECT id FROM invoices WHERE user_id = $1 AND local_id = $2',
        [userId, item.invoice_local_id != null ? Number(item.invoice_local_id) : -1]
      );
      const invoiceId = invRes.rows[0]?.id;
      if (!invoiceId) continue;

      const existing = await client.query(
        'SELECT id FROM invoice_items WHERE user_id = $1 AND local_id = $2',
        [userId, localId]
      );

      const vals = [
        invoiceId, userId, localId,                                           // $1,$2,$3
        item.product_unique_id || null,                                       // $4
        item.item_type   || 'Tovar',                                          // $5
        item.name        || '',                                               // $6
        item.unit        || 'ks',                                             // $7
        item.qty         != null ? parseFloat(item.qty)         : 1,         // $8
        item.unit_price  != null ? parseFloat(item.unit_price)  : 0,         // $9
        item.vat_percent != null ? parseFloat(item.vat_percent) : 23,        // $10
        item.discount_percent != null ? parseFloat(item.discount_percent) : 0, // $11
        item.description || null,                                             // $12
        item.sort_order  != null ? Number(item.sort_order)       : 0,        // $13
      ];

      if (existing.rows.length > 0) {
        await client.query(
          `UPDATE invoice_items SET
            invoice_id=$1, product_unique_id=$4, item_type=$5, name=$6, unit=$7,
            qty=$8, unit_price=$9, vat_percent=$10, discount_percent=$11,
            description=$12, sort_order=$13
          WHERE user_id=$2 AND local_id=$3`,
          vals
        );
      } else {
        await client.query(
          `INSERT INTO invoice_items (
            invoice_id, user_id, local_id, product_unique_id, item_type, name, unit,
            qty, unit_price, vat_percent, discount_percent, description, sort_order
          ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)`,
          vals
        );
      }
    }

    await client.query('COMMIT');
    return { ok: true, count: invoices.length };
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('[invoiceSync]', err.message);
    return { ok: false, error: err.message };
  } finally {
    client.release();
  }
}

async function fetchInvoicesFull(pool, userId) {
  if (!pool || !userId) return null;
  const client = await pool.connect();
  try {
    const invRes = await client.query(
      'SELECT * FROM invoices WHERE user_id = $1 ORDER BY id',
      [userId]
    );
    const itemsRes = await client.query(
      `SELECT ii.*, i.local_id AS invoice_local_id
       FROM invoice_items ii
       JOIN invoices i ON i.id = ii.invoice_id
       WHERE ii.user_id = $1
       ORDER BY ii.id`,
      [userId]
    );
    return { invoices: invRes.rows, items: itemsRes.rows };
  } catch (err) {
    console.error('[fetchInvoicesFull]', err.message);
    return null;
  } finally {
    client.release();
  }
}

module.exports = { syncInvoicesFull, fetchInvoicesFull };
