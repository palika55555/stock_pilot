/**
 * Sync cenových ponúk (quotes + quote_items) z Flutter do PostgreSQL – upsert podľa local_id.
 * Odlišné od existujúcich REST /quotes endpointov – tento endpoint slúži na bulk sync.
 */
async function syncQuotesFull(pool, body, userId) {
  if (!pool) return { ok: false, error: 'Databáza nie je k dispozícii' };
  if (!userId || userId < 1) return { ok: false, error: 'Chýba user_id' };

  const quotes = Array.isArray(body?.quotes) ? body.quotes : [];
  const items = Array.isArray(body?.items) ? body.items : [];

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    for (const q of quotes) {
      const localId = q.local_id != null ? Number(q.local_id) : null;
      if (localId == null || Number.isNaN(localId)) continue;

      const existing = await client.query(
        'SELECT id FROM quotes WHERE user_id = $1 AND local_id = $2',
        [userId, localId]
      );

      const vals = [
        userId, localId,
        q.quote_number || null,
        q.customer_id != null ? Number(q.customer_id) : null,
        q.customer_name || null,
        q.created_at || null,
        q.valid_until || null,
        q.notes || null,
        q.prices_include_vat != null ? Number(q.prices_include_vat) : 0,
        q.default_vat_rate != null ? parseFloat(q.default_vat_rate) : 20,
        q.status || 'draft',
        q.delivery_cost != null ? parseFloat(q.delivery_cost) : 0,
        q.other_fees != null ? parseFloat(q.other_fees) : 0,
        q.payment_method || null,
        q.delivery_terms || null,
      ];

      if (existing.rows.length > 0) {
        await client.query(
          `UPDATE quotes SET
            quote_number=$3, customer_id=$4, customer_name=$5, issue_date=$6,
            valid_until=$7, notes=$8, prices_include_vat=$9, default_vat_rate=$10,
            status=$11, delivery_cost=$12, other_fees=$13
          WHERE user_id=$1 AND local_id=$2`,
          vals.slice(0, 13)
        );
      } else {
        await client.query(
          `INSERT INTO quotes (
            user_id, local_id, quote_number, customer_id, customer_name, issue_date,
            valid_until, notes, prices_include_vat, default_vat_rate, status, delivery_cost, other_fees
          ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)`,
          vals.slice(0, 13)
        );
      }
    }

    for (const item of items) {
      const localId = item.local_id != null ? Number(item.local_id) : null;
      if (localId == null || Number.isNaN(localId)) continue;

      // Nájdi backend ID pre quote
      const quoteRes = await client.query(
        'SELECT id FROM quotes WHERE user_id = $1 AND local_id = $2',
        [userId, item.quote_local_id != null ? Number(item.quote_local_id) : -1]
      );
      const quoteId = quoteRes.rows[0]?.id;
      if (!quoteId) continue;

      const existing = await client.query(
        'SELECT id FROM quote_items WHERE user_id = $1 AND local_id = $2',
        [userId, localId]
      );

      const vals = [
        quoteId, userId, localId,
        item.product_unique_id || null,
        item.item_type || 'Tovar',
        item.product_name || item.name || '',
        item.unit || 'ks',
        item.qty != null ? parseFloat(item.qty) : 1,
        item.unit_price != null ? parseFloat(item.unit_price) : 0,
        item.vat_percent != null ? parseFloat(item.vat_percent) : 20,
        item.discount_percent != null ? parseFloat(item.discount_percent) : 0,
        item.surcharge_percent != null ? parseFloat(item.surcharge_percent) : 0,
        item.description || null,
        item.sort_order != null ? Number(item.sort_order) : 0,
      ];

      if (existing.rows.length > 0) {
        await client.query(
          `UPDATE quote_items SET
            quote_id=$1, product_unique_id=$4, item_type=$5, name=$6, unit=$7,
            qty=$8, unit_price=$9, vat_percent=$10, discount_percent=$11,
            surcharge_percent=$12, description=$13, sort_order=$14
          WHERE user_id=$2 AND local_id=$3`,
          vals
        );
      } else {
        await client.query(
          `INSERT INTO quote_items (
            quote_id, user_id, local_id, product_unique_id, item_type, name, unit,
            qty, unit_price, vat_percent, discount_percent, surcharge_percent, description, sort_order
          ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14)`,
          vals
        );
      }
    }

    await client.query('COMMIT');
    return { ok: true, count: quotes.length };
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('[quoteSyncFull]', err.message);
    return { ok: false, error: err.message };
  } finally {
    client.release();
  }
}

async function fetchQuotesFull(pool, userId) {
  if (!pool || !userId) return null;
  const client = await pool.connect();
  try {
    const quotesRes = await client.query(
      'SELECT * FROM quotes WHERE user_id = $1 ORDER BY id',
      [userId]
    );
    const itemsRes = await client.query(
      'SELECT qi.*, q.local_id AS quote_local_id FROM quote_items qi JOIN quotes q ON q.id = qi.quote_id WHERE qi.user_id = $1 ORDER BY qi.id',
      [userId]
    );
    return { quotes: quotesRes.rows, items: itemsRes.rows };
  } catch (err) {
    console.error('[fetchQuotesFull]', err.message);
    return null;
  } finally {
    client.release();
  }
}

module.exports = { syncQuotesFull, fetchQuotesFull };
