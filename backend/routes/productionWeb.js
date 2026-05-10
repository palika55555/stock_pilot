/**
 * Web-first výroba: dlažba (m²), úprava šarží, palety, predaj, výrobné príkazy (CRUD).
 */
const { pavingCalcFromM2 } = require('../utils/pavingCalc');

function dataUserId(req) {
  return req.dataUserId ?? req.userId;
}

function mapPavingRow(r) {
  return {
    id: r.id,
    name: r.name,
    length_mm: r.length_mm != null ? Number(r.length_mm) : null,
    width_mm: r.width_mm != null ? Number(r.width_mm) : null,
    thickness_mm: r.thickness_mm != null ? Number(r.thickness_mm) : null,
    pieces_per_layer: Number(r.pieces_per_layer),
    layers_per_pallet: Number(r.layers_per_pallet),
    created_at: r.created_at,
  };
}

function mapBatch(r) {
  const productionDate = r.production_date instanceof Date ? r.production_date.toISOString().slice(0, 10) : r.production_date;
  return {
    id: r.id,
    local_id: r.local_id != null ? Number(r.local_id) : null,
    production_date: productionDate,
    product_type: r.product_type,
    quantity_produced: Number(r.quantity_produced) || 0,
    notes: r.notes,
    created_at: r.created_at,
    cost_total: r.cost_total != null ? Number(r.cost_total) : null,
    revenue_total: r.revenue_total != null ? Number(r.revenue_total) : null,
    paving_stone_id: r.paving_stone_id != null ? Number(r.paving_stone_id) : null,
    requested_m2: r.requested_m2 != null ? Number(r.requested_m2) : null,
    actual_stored_m2: r.actual_stored_m2 != null ? Number(r.actual_stored_m2) : null,
  };
}

async function sumPalletPieces(pool, userId, batchId) {
  const { rows } = await pool.query(
    'SELECT COALESCE(SUM(quantity), 0)::bigint AS s FROM pallets WHERE user_id = $1 AND batch_id = $2',
    [userId, batchId]
  );
  return Number(rows[0].s) || 0;
}

async function palletCount(pool, userId, batchId) {
  const { rows } = await pool.query(
    'SELECT COUNT(*)::int AS c FROM pallets WHERE user_id = $1 AND batch_id = $2',
    [userId, batchId]
  );
  return rows[0]?.c ?? 0;
}

async function loadPavingStone(pool, userId, stoneId) {
  const { rows } = await pool.query('SELECT * FROM paving_stones WHERE user_id = $1 AND id = $2', [userId, stoneId]);
  return rows[0] || null;
}

async function nextNegativeLocalId(client, userId) {
  const { rows } = await client.query(
    'SELECT COALESCE(MIN(local_id), 0) - 1 AS n FROM production_orders WHERE user_id = $1 AND local_id < 0',
    [userId]
  );
  return rows[0]?.n ?? -1;
}

async function nextProductionOrderNumber(client, userId) {
  const year = new Date().getFullYear();
  const { rows } = await client.query(
    'SELECT order_number FROM production_orders WHERE user_id = $1 AND order_number LIKE $2 ORDER BY id DESC LIMIT 1',
    [userId, `VP-${year}-%`]
  );
  if (!rows.length) return `VP-${year}-0001`;
  const last = rows[0].order_number || '';
  const parts = last.split('-');
  if (parts.length < 3) return `VP-${year}-0001`;
  const num = parseInt(parts[2], 10) || 0;
  return `VP-${year}-${String(num + 1).padStart(4, '0')}`;
}

/** @param {import('express').Router} apiRouter */
function mountProductionWebRoutes(apiRouter, { pool, poolReady }) {
  apiRouter.get('/paving-stones', async (req, res) => {
    if (!pool || !poolReady) return res.status(503).json({ error: 'Databáza nie je k dispozícii' });
    try {
      const uid = dataUserId(req);
      const { rows } = await pool.query(
        'SELECT id, user_id, name, length_mm, width_mm, thickness_mm, pieces_per_layer, layers_per_pallet, created_at FROM paving_stones WHERE user_id = $1 ORDER BY name ASC',
        [uid]
      );
      res.json(rows.map(mapPavingRow));
    } catch (err) {
      console.error('[GET /paving-stones]', err.message);
      res.status(500).json({ error: 'Chyba servera' });
    }
  });

  apiRouter.post('/paving-stones', async (req, res) => {
    if (!pool || !poolReady) return res.status(503).json({ error: 'Databáza nie je k dispozícii' });
    const { name, length_mm, width_mm, thickness_mm, pieces_per_layer, layers_per_pallet } = req.body || {};
    const n = (name || '').toString().trim();
    if (!n) return res.status(400).json({ error: 'name je povinné' });
    const len = parseFloat(length_mm);
    const wid = parseFloat(width_mm);
    const th = parseFloat(thickness_mm);
    const ppl = parseInt(pieces_per_layer, 10);
    const lpp = parseInt(layers_per_pallet, 10);
    if (!len || !wid || !th || !ppl || !lpp) {
      return res.status(400).json({ error: 'Rozmery a počty vrstiev musia byť kladné' });
    }
    try {
      const uid = dataUserId(req);
      const { rows } = await pool.query(
        `INSERT INTO paving_stones (user_id, name, length_mm, width_mm, thickness_mm, pieces_per_layer, layers_per_pallet)
         VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING id, name, length_mm, width_mm, thickness_mm, pieces_per_layer, layers_per_pallet, created_at`,
        [uid, n, len, wid, th, ppl, lpp]
      );
      res.status(201).json(mapPavingRow(rows[0]));
    } catch (err) {
      console.error('[POST /paving-stones]', err.message);
      res.status(500).json({ error: 'Chyba servera' });
    }
  });

  apiRouter.put('/paving-stones/:id', async (req, res) => {
    if (!pool || !poolReady) return res.status(503).json({ error: 'Databáza nie je k dispozícii' });
    const id = parseInt(req.params.id, 10);
    if (Number.isNaN(id)) return res.status(400).json({ error: 'Neplatné id' });
    const { name, length_mm, width_mm, thickness_mm, pieces_per_layer, layers_per_pallet } = req.body || {};
    try {
      const uid = dataUserId(req);
      const existing = await pool.query('SELECT id FROM paving_stones WHERE user_id = $1 AND id = $2', [uid, id]);
      if (!existing.rows.length) return res.status(404).json({ error: 'Záznam nebol nájdený' });
      const n = name != null ? String(name).trim() : null;
      const len = length_mm != null ? parseFloat(length_mm) : null;
      const wid = width_mm != null ? parseFloat(width_mm) : null;
      const th = thickness_mm != null ? parseFloat(thickness_mm) : null;
      const ppl = pieces_per_layer != null ? parseInt(pieces_per_layer, 10) : null;
      const lpp = layers_per_pallet != null ? parseInt(layers_per_pallet, 10) : null;
      const { rows } = await pool.query(
        `UPDATE paving_stones SET
          name = COALESCE($3, name),
          length_mm = COALESCE($4, length_mm),
          width_mm = COALESCE($5, width_mm),
          thickness_mm = COALESCE($6, thickness_mm),
          pieces_per_layer = COALESCE($7, pieces_per_layer),
          layers_per_pallet = COALESCE($8, layers_per_pallet)
        WHERE user_id = $1 AND id = $2
        RETURNING id, name, length_mm, width_mm, thickness_mm, pieces_per_layer, layers_per_pallet, created_at`,
        [uid, id, n || null, len, wid, th, ppl, lpp]
      );
      res.json(mapPavingRow(rows[0]));
    } catch (err) {
      console.error('[PUT /paving-stones/:id]', err.message);
      res.status(500).json({ error: 'Chyba servera' });
    }
  });

  apiRouter.delete('/paving-stones/:id', async (req, res) => {
    if (!pool || !poolReady) return res.status(503).json({ error: 'Databáza nie je k dispozícii' });
    const id = parseInt(req.params.id, 10);
    if (Number.isNaN(id)) return res.status(400).json({ error: 'Neplatné id' });
    try {
      const uid = dataUserId(req);
      const used = await pool.query(
        'SELECT 1 FROM production_batches WHERE user_id = $1 AND paving_stone_id = $2 LIMIT 1',
        [uid, id]
      );
      if (used.rows.length) {
        return res.status(400).json({ error: 'Typ dlažby je použitý na šarži — najprv ho odpojte od šarží.' });
      }
      const r = await pool.query('DELETE FROM paving_stones WHERE user_id = $1 AND id = $2', [uid, id]);
      if (r.rowCount === 0) return res.status(404).json({ error: 'Záznam nebol nájdený' });
      res.json({ success: true });
    } catch (err) {
      console.error('[DELETE /paving-stones/:id]', err.message);
      res.status(500).json({ error: 'Chyba servera' });
    }
  });

  apiRouter.get('/production/summary', async (req, res) => {
    if (!pool || !poolReady) return res.status(503).json({ error: 'Databáza nie je k dispozícii' });
    const from = (req.query.from || new Date(Date.now() - 31 * 864e5).toISOString().slice(0, 10))
      .toString()
      .slice(0, 10);
    const to = (req.query.to || new Date().toISOString().slice(0, 10)).toString().slice(0, 10);
    try {
      const uid = dataUserId(req);
      const prod = await pool.query(
        `SELECT
           COALESCE(SUM(quantity_produced), 0)::bigint AS pieces,
           COALESCE(SUM(actual_stored_m2), 0)::numeric AS m2,
           COALESCE(SUM(cost_total), 0)::numeric AS cost,
           COALESCE(SUM(revenue_total), 0)::numeric AS revenue,
           COUNT(*)::int AS batches
         FROM production_batches WHERE user_id = $1 AND production_date >= $2 AND production_date <= $3`,
        [uid, from, to]
      );
      const pal = await pool.query(
        `SELECT p.status, COALESCE(SUM(p.quantity), 0)::bigint AS pieces, COUNT(*)::int AS pallets
         FROM pallets p
         INNER JOIN production_batches b ON b.id = p.batch_id AND b.user_id = $1
         WHERE b.production_date >= $2 AND b.production_date <= $3
         GROUP BY p.status
         ORDER BY p.status`,
        [uid, from, to]
      );
      const soldRows = await pool.query(
        `SELECT COALESCE(SUM(p.quantity), 0)::bigint AS pieces, COUNT(*)::int AS pallets
         FROM pallets p
         INNER JOIN production_batches b ON b.id = p.batch_id AND b.user_id = $1
         WHERE b.production_date >= $2 AND b.production_date <= $3
           AND (p.sold_at IS NOT NULL OR p.status IN ('Predané', 'Expedované'))`,
        [uid, from, to]
      );
      const byType = await pool.query(
        `SELECT
           b.product_type,
           COALESCE(SUM(b.quantity_produced), 0)::bigint AS produced_pieces,
           COALESCE(SUM(b.actual_stored_m2), 0)::numeric AS produced_m2,
           COALESCE(SUM(p.quantity) FILTER (WHERE p.sold_at IS NOT NULL OR p.status IN ('Predané','Expedované')), 0)::bigint AS sold_pieces,
           COALESCE(SUM(p.quantity) FILTER (WHERE p.status = 'Na sklade'), 0)::bigint AS in_stock_pieces,
           COALESCE(SUM(p.quantity) FILTER (WHERE p.status = 'U zákazníka'), 0)::bigint AS at_customer_pieces
         FROM production_batches b
         LEFT JOIN pallets p ON p.batch_id = b.id AND p.user_id = b.user_id
         WHERE b.user_id = $1 AND b.production_date >= $2 AND b.production_date <= $3
         GROUP BY b.product_type
         ORDER BY produced_pieces DESC`,
        [uid, from, to]
      );
      const daily = await pool.query(
        `SELECT to_char(production_date, 'YYYY-MM-DD') AS day,
                COALESCE(SUM(quantity_produced), 0)::bigint AS pieces,
                COALESCE(SUM(actual_stored_m2), 0)::numeric AS m2
         FROM production_batches
         WHERE user_id = $1 AND production_date >= $2 AND production_date <= $3
         GROUP BY production_date
         ORDER BY production_date ASC`,
        [uid, from, to]
      );
      const topCustomers = await pool.query(
        `SELECT c.id, c.name,
                COALESCE(SUM(p.quantity), 0)::bigint AS pieces,
                COUNT(p.id)::int AS pallets
         FROM pallets p
         INNER JOIN production_batches b ON b.id = p.batch_id AND b.user_id = $1
         INNER JOIN customers c ON c.id = p.customer_id AND c.user_id = $1
         WHERE b.production_date >= $2 AND b.production_date <= $3
           AND (p.sold_at IS NOT NULL OR p.status IN ('Predané','Expedované','U zákazníka'))
         GROUP BY c.id, c.name
         ORDER BY pieces DESC
         LIMIT 10`,
        [uid, from, to]
      );
      res.json({
        from,
        to,
        total_produced_pieces: Number(prod.rows[0]?.pieces) || 0,
        total_produced_m2: Number(prod.rows[0]?.m2) || 0,
        total_cost: Number(prod.rows[0]?.cost) || 0,
        total_revenue: Number(prod.rows[0]?.revenue) || 0,
        total_batches: Number(prod.rows[0]?.batches) || 0,
        pallets_by_status: (pal.rows || []).map((r) => ({
          status: r.status,
          pieces: Number(r.pieces) || 0,
          pallets: Number(r.pallets) || 0,
        })),
        sold_pieces: Number(soldRows.rows[0]?.pieces) || 0,
        sold_pallets: Number(soldRows.rows[0]?.pallets) || 0,
        by_product_type: (byType.rows || []).map((r) => ({
          product_type: r.product_type,
          produced_pieces: Number(r.produced_pieces) || 0,
          produced_m2: Number(r.produced_m2) || 0,
          sold_pieces: Number(r.sold_pieces) || 0,
          in_stock_pieces: Number(r.in_stock_pieces) || 0,
          at_customer_pieces: Number(r.at_customer_pieces) || 0,
        })),
        daily: (daily.rows || []).map((r) => ({
          day: r.day,
          pieces: Number(r.pieces) || 0,
          m2: Number(r.m2) || 0,
        })),
        top_customers: (topCustomers.rows || []).map((r) => ({
          id: r.id,
          name: r.name,
          pieces: Number(r.pieces) || 0,
          pallets: Number(r.pallets) || 0,
        })),
      });
    } catch (err) {
      console.error('[GET /production/summary]', err.message);
      res.status(500).json({ error: 'Chyba servera' });
    }
  });

  apiRouter.put('/batches/:id', async (req, res) => {
    if (!pool || !poolReady) return res.status(503).json({ error: 'Databáza nie je k dispozícii' });
    const batchId = parseInt(req.params.id, 10);
    if (Number.isNaN(batchId)) return res.status(400).json({ error: 'Neplatné id' });
    const {
      production_date,
      product_type,
      quantity_produced,
      notes,
      cost_total,
      revenue_total,
      recipe,
      paving_stone_id,
      requested_m2,
    } = req.body || {};

    const client = await pool.connect();
    try {
      const uid = dataUserId(req);
      await client.query('BEGIN');
      const cur = await client.query(
        `SELECT id, quantity_produced, product_type, paving_stone_id, requested_m2 FROM production_batches WHERE user_id = $1 AND id = $2 FOR UPDATE`,
        [uid, batchId]
      );
      if (!cur.rows.length) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'Šarža nebola nájdená' });
      }
      const hasPallets = (await palletCount(pool, uid, batchId)) > 0;
      let pavingId = paving_stone_id != null ? parseInt(paving_stone_id, 10) : null;
      if (Number.isNaN(pavingId)) pavingId = null;
      let reqM2 = requested_m2 != null ? parseFloat(requested_m2) : null;
      if (reqM2 != null && Number.isNaN(reqM2)) reqM2 = null;

      let qty = quantity_produced != null ? parseInt(quantity_produced, 10) : Number(cur.rows[0].quantity_produced) || 0;
      let actualM2 = null;
      let typeVal = (product_type || cur.rows[0].product_type || '').toString().trim();
      const dateVal = (production_date || '').toString().trim().slice(0, 10);
      if (!dateVal) {
        await client.query('ROLLBACK');
        return res.status(400).json({ error: 'production_date je povinné' });
      }

      if (pavingId) {
        const stone = await loadPavingStone(pool, uid, pavingId);
        if (!stone) {
          await client.query('ROLLBACK');
          return res.status(400).json({ error: 'Neplatná dlažba (paving_stone_id)' });
        }
        if (hasPallets && (reqM2 != null || pavingId !== Number(cur.rows[0].paving_stone_id))) {
          await client.query('ROLLBACK');
          return res.status(400).json({ error: 'Šarža má palety — zmena m² alebo typu dlažby nie je povolená.' });
        }
        if (!(reqM2 > 0)) {
          await client.query('ROLLBACK');
          return res.status(400).json({ error: 'Pre dlažbu zadajte requested_m2 > 0' });
        }
        const calc = pavingCalcFromM2(reqM2, stone);
        if (!calc) {
          await client.query('ROLLBACK');
          return res.status(400).json({ error: 'Nepodarilo sa vypočítať kusy z m²' });
        }
        qty = calc.totalPieces;
        actualM2 = calc.actualM2;
        typeVal = stone.name || typeVal;
      } else {
        pavingId = null;
        reqM2 = null;
        actualM2 = null;
        if (qty < 0) qty = 0;
      }

      const allocated = await sumPalletPieces(pool, uid, batchId);
      if (qty < allocated) {
        await client.query('ROLLBACK');
        return res.status(400).json({
          error: `Počet vyrobených (${qty}) nemôže byť menší než súčet na paletách (${allocated}).`,
        });
      }

      await client.query(
        `UPDATE production_batches SET
          production_date = $3, product_type = $4, quantity_produced = $5, notes = $6,
          cost_total = $7, revenue_total = $8,
          paving_stone_id = $9, requested_m2 = $10, actual_stored_m2 = $11
        WHERE user_id = $1 AND id = $2`,
        [
          uid,
          batchId,
          dateVal,
          typeVal || 'Výrobok',
          qty,
          notes != null ? String(notes).trim() || null : null,
          cost_total != null ? parseFloat(cost_total) : null,
          revenue_total != null ? parseFloat(revenue_total) : null,
          pavingId,
          reqM2,
          actualM2,
        ]
      );

      if (Array.isArray(recipe)) {
        await client.query('DELETE FROM production_batch_recipe WHERE batch_id = $1', [batchId]);
        for (const item of recipe) {
          const q = parseFloat(item.quantity) || 0;
          if (q <= 0) continue;
          const matName = (item.material_name || '').toString().trim() || 'Materiál';
          const unit = (item.unit || 'kg').toString().trim();
          await client.query(
            'INSERT INTO production_batch_recipe (batch_id, material_name, quantity, unit) VALUES ($1, $2, $3, $4)',
            [batchId, matName, q, unit]
          );
        }
      }

      await client.query('COMMIT');
      const { rows } = await pool.query(
        `SELECT id, local_id, production_date, product_type, quantity_produced, notes, created_at, cost_total, revenue_total,
          paving_stone_id, requested_m2, actual_stored_m2
         FROM production_batches WHERE user_id = $1 AND id = $2`,
        [uid, batchId]
      );
      res.json(mapBatch(rows[0]));
    } catch (err) {
      await client.query('ROLLBACK');
      console.error('[PUT /batches/:id]', err.message);
      res.status(500).json({ error: 'Chyba servera' });
    } finally {
      client.release();
    }
  });

  apiRouter.delete('/batches/:id', async (req, res) => {
    if (!pool || !poolReady) return res.status(503).json({ error: 'Databáza nie je k dispozícii' });
    const batchId = parseInt(req.params.id, 10);
    if (Number.isNaN(batchId)) return res.status(400).json({ error: 'Neplatné id' });
    const client = await pool.connect();
    try {
      const uid = dataUserId(req);
      await client.query('BEGIN');
      const cur = await client.query('SELECT id FROM production_batches WHERE user_id = $1 AND id = $2', [uid, batchId]);
      if (!cur.rows.length) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'Šarža nebola nájdená' });
      }
      await client.query('DELETE FROM pallets WHERE user_id = $1 AND batch_id = $2', [uid, batchId]);
      await client.query('DELETE FROM production_batch_recipe WHERE batch_id = $1', [batchId]);
      await client.query('DELETE FROM production_batches WHERE user_id = $1 AND id = $2', [uid, batchId]);
      await client.query('COMMIT');
      res.json({ success: true });
    } catch (err) {
      await client.query('ROLLBACK');
      console.error('[DELETE /batches/:id]', err.message);
      res.status(500).json({ error: 'Chyba servera' });
    } finally {
      client.release();
    }
  });

  apiRouter.get('/pallets', async (req, res) => {
    if (!pool || !poolReady) return res.status(503).json({ error: 'Databáza nie je k dispozícii' });
    const status = (req.query.status || '').toString().trim();
    const batchIdQ = req.query.batch_id != null ? parseInt(req.query.batch_id, 10) : null;
    try {
      const uid = dataUserId(req);
      let q = `SELECT p.id, p.batch_id, p.product_type, p.quantity, p.customer_id, p.status, p.created_at, p.sold_at, p.sale_note
        FROM pallets p WHERE p.user_id = $1`;
      const params = [uid];
      let i = 2;
      if (batchIdQ && !Number.isNaN(batchIdQ)) {
        q += ` AND p.batch_id = $${i}`;
        params.push(batchIdQ);
        i += 1;
      }
      if (status) {
        /* eslint-disable-next-line prefer-template */
        q += ` AND p.status = $${i}`;
        params.push(status);
      }
      q += ' ORDER BY p.id DESC LIMIT 500';
      const { rows } = await pool.query(q, params);
      res.json(
        rows.map((r) => ({
          id: r.id,
          batch_id: r.batch_id,
          product_type: r.product_type,
          quantity: Number(r.quantity),
          customer_id: r.customer_id,
          status: r.status || 'Na sklade',
          created_at: r.created_at,
          sold_at: r.sold_at,
          sale_note: r.sale_note,
        }))
      );
    } catch (err) {
      console.error('[GET /pallets]', err.message);
      res.status(500).json({ error: 'Chyba servera' });
    }
  });

  apiRouter.put('/pallets/:id', async (req, res) => {
    if (!pool || !poolReady) return res.status(503).json({ error: 'Databáza nie je k dispozícii' });
    const palletId = parseInt(req.params.id, 10);
    if (Number.isNaN(palletId)) return res.status(400).json({ error: 'Neplatné id' });
    const { quantity, status, customer_id, sale_note, sold_at, clear_customer } = req.body || {};
    const client = await pool.connect();
    try {
      const uid = dataUserId(req);
      await client.query('BEGIN');
      const prev = await client.query(
        'SELECT id, customer_id, status, quantity, sale_note, sold_at FROM pallets WHERE user_id = $1 AND id = $2 FOR UPDATE',
        [uid, palletId]
      );
      if (!prev.rows.length) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'Paleta nebola nájdená' });
      }
      const p0 = prev.rows[0];
      const oldCust = p0.customer_id != null ? Number(p0.customer_id) : null;
      const oldStat = (p0.status || '').toString();

      let newQty = quantity != null ? parseInt(quantity, 10) : Number(p0.quantity);
      if (Number.isNaN(newQty) || newQty < 0) newQty = Number(p0.quantity);
      let newStat = status != null ? String(status).trim() : oldStat;
      let newCust = customer_id !== undefined ? (customer_id === null || customer_id === '' ? null : parseInt(customer_id, 10)) : oldCust;
      if (clear_customer === true) newCust = null;
      if (newStat !== 'U zákazníka') newCust = null;
      const saleNoteVal =
        sale_note !== undefined ? (sale_note != null ? String(sale_note).trim() || null : null) : undefined;

      const batchRes = await client.query(
        'SELECT quantity_produced FROM production_batches WHERE user_id = $1 AND id = (SELECT batch_id FROM pallets WHERE user_id = $1 AND id = $2)',
        [uid, palletId]
      );
      const batchQty = Number(batchRes.rows[0]?.quantity_produced) || 0;
      const otherSum = await client.query(
        'SELECT COALESCE(SUM(quantity),0)::bigint AS s FROM pallets WHERE user_id = $1 AND batch_id = (SELECT batch_id FROM pallets WHERE id = $2 AND user_id = $1) AND id <> $2',
        [uid, palletId]
      );
      const others = Number(otherSum.rows[0].s) || 0;
      if (others + newQty > batchQty) {
        await client.query('ROLLBACK');
        return res.status(400).json({ error: `Súčet kusov na paletách (${others + newQty}) prevyšuje vyrobené (${batchQty}).` });
      }

      const decBalance = async (custId) => {
        await client.query(
          'UPDATE customers SET pallet_balance = GREATEST(0, COALESCE(pallet_balance,0) - 1) WHERE user_id = $1 AND id = $2',
          [uid, custId]
        );
      };
      const incBalance = async (custId) => {
        await client.query(
          'UPDATE customers SET pallet_balance = COALESCE(pallet_balance,0) + 1 WHERE user_id = $1 AND id = $2',
          [uid, custId]
        );
      };

      if (oldStat === 'U zákazníka' && oldCust && (newCust !== oldCust || newStat !== 'U zákazníka')) {
        await decBalance(oldCust);
      }
      if (newStat === 'U zákazníka' && newCust) {
        const custOk = await client.query('SELECT id FROM customers WHERE user_id = $1 AND id = $2', [uid, newCust]);
        if (!custOk.rows.length) {
          await client.query('ROLLBACK');
          return res.status(400).json({ error: 'Zákazník neexistuje' });
        }
        if (oldStat !== 'U zákazníka' || oldCust !== newCust) {
          await incBalance(newCust);
        }
      }

      let finalSaleNote = saleNoteVal !== undefined ? saleNoteVal : p0.sale_note;

      let finalSoldAt;
      if (sold_at !== undefined) finalSoldAt = sold_at ? new Date(sold_at) : null;
      else if (newStat === 'Predané' || newStat === 'Expedované') finalSoldAt = new Date();
      else if (['Predané', 'Expedované'].includes(oldStat) && !['Predané', 'Expedované'].includes(newStat)) finalSoldAt = null;
      else finalSoldAt = p0.sold_at;

      await client.query(
        `UPDATE pallets SET quantity = $3, status = $4, customer_id = $5, sale_note = $6, sold_at = $7
         WHERE user_id = $1 AND id = $2`,
        [uid, palletId, newQty, newStat, newCust, finalSaleNote, finalSoldAt]
      );

      const updated = await client.query('SELECT * FROM pallets WHERE user_id = $1 AND id = $2', [uid, palletId]);
      await client.query('COMMIT');
      const r = updated.rows[0];
      res.json({
        id: r.id,
        batch_id: r.batch_id,
        product_type: r.product_type,
        quantity: Number(r.quantity),
        customer_id: r.customer_id,
        status: r.status,
        created_at: r.created_at,
        sold_at: r.sold_at,
        sale_note: r.sale_note,
      });
    } catch (err) {
      await client.query('ROLLBACK');
      console.error('[PUT /pallets/:id]', err.message);
      res.status(500).json({ error: 'Chyba servera' });
    } finally {
      client.release();
    }
  });

  apiRouter.post('/pallets/bulk-sell', async (req, res) => {
    if (!pool || !poolReady) return res.status(503).json({ error: 'Databáza nie je k dispozícii' });
    const ids = Array.isArray(req.body?.ids) ? req.body.ids.map((n) => parseInt(n, 10)).filter((n) => !Number.isNaN(n)) : [];
    if (!ids.length) return res.status(400).json({ error: 'ids je povinné (pole id paliet)' });
    const customerId = req.body?.customer_id != null ? parseInt(req.body.customer_id, 10) : null;
    const saleNote = req.body?.sale_note != null ? String(req.body.sale_note).trim() || null : null;
    const soldAt = req.body?.sold_at ? new Date(req.body.sold_at) : new Date();
    const status = (req.body?.status || 'Predané').toString().trim();
    const client = await pool.connect();
    try {
      const uid = dataUserId(req);
      await client.query('BEGIN');
      if (customerId) {
        const ck = await client.query('SELECT id FROM customers WHERE user_id = $1 AND id = $2', [uid, customerId]);
        if (!ck.rows.length) {
          await client.query('ROLLBACK');
          return res.status(400).json({ error: 'Zákazník neexistuje' });
        }
      }
      const cur = await client.query(
        'SELECT id, customer_id, status FROM pallets WHERE user_id = $1 AND id = ANY($2::int[]) FOR UPDATE',
        [uid, ids]
      );
      if (!cur.rows.length) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'Žiadna z paliet sa nenašla' });
      }
      let releasedFromCustomer = 0;
      for (const row of cur.rows) {
        if (row.status === 'U zákazníka' && row.customer_id && row.customer_id !== customerId) {
          await client.query(
            'UPDATE customers SET pallet_balance = GREATEST(0, COALESCE(pallet_balance,0) - 1) WHERE user_id = $1 AND id = $2',
            [uid, row.customer_id]
          );
          releasedFromCustomer += 1;
        }
      }
      const isAtCustomer = status === 'U zákazníka';
      if (isAtCustomer && customerId) {
        for (const row of cur.rows) {
          if (row.status !== 'U zákazníka' || row.customer_id !== customerId) {
            await client.query(
              'UPDATE customers SET pallet_balance = COALESCE(pallet_balance,0) + 1 WHERE user_id = $1 AND id = $2',
              [uid, customerId]
            );
          }
        }
      }
      await client.query(
        `UPDATE pallets SET status = $3, customer_id = $4, sale_note = COALESCE($5, sale_note), sold_at = $6
         WHERE user_id = $1 AND id = ANY($2::int[])`,
        [uid, ids, status, isAtCustomer ? customerId : null, saleNote, ['Predané', 'Expedované'].includes(status) || isAtCustomer ? soldAt : null]
      );
      await client.query('COMMIT');
      res.json({ success: true, updated: cur.rows.length, released_from_customer: releasedFromCustomer });
    } catch (err) {
      await client.query('ROLLBACK');
      console.error('[POST /pallets/bulk-sell]', err.message);
      res.status(500).json({ error: 'Chyba servera' });
    } finally {
      client.release();
    }
  });

  apiRouter.get('/production/export.csv', async (req, res) => {
    if (!pool || !poolReady) return res.status(503).json({ error: 'Databáza nie je k dispozícii' });
    const from = (req.query.from || '2020-01-01').toString().slice(0, 10);
    const to = (req.query.to || new Date().toISOString().slice(0, 10)).toString().slice(0, 10);
    try {
      const uid = dataUserId(req);
      const { rows } = await pool.query(
        `SELECT b.production_date, b.product_type, b.quantity_produced, b.actual_stored_m2, b.cost_total, b.revenue_total,
                COALESCE(SUM(p.quantity), 0)::bigint AS pallet_pieces,
                COALESCE(SUM(p.quantity) FILTER (WHERE p.sold_at IS NOT NULL OR p.status IN ('Predané','Expedované')), 0)::bigint AS sold_pieces,
                COALESCE(SUM(p.quantity) FILTER (WHERE p.status = 'Na sklade'), 0)::bigint AS in_stock_pieces
           FROM production_batches b
           LEFT JOIN pallets p ON p.batch_id = b.id AND p.user_id = b.user_id
          WHERE b.user_id = $1 AND b.production_date >= $2 AND b.production_date <= $3
          GROUP BY b.id, b.production_date, b.product_type, b.quantity_produced, b.actual_stored_m2, b.cost_total, b.revenue_total
          ORDER BY b.production_date DESC`,
        [uid, from, to]
      );
      const escape = (v) => {
        if (v == null) return '';
        const s = String(v);
        return s.includes(';') || s.includes('"') || s.includes('\n') ? `"${s.replace(/"/g, '""')}"` : s;
      };
      const header = 'datum;typ;vyrobene_ks;vyrobene_m2;naklady_eur;vynos_eur;na_paletach_ks;predane_ks;na_sklade_ks';
      const lines = rows.map((r) => {
        const day = r.production_date instanceof Date ? r.production_date.toISOString().slice(0, 10) : r.production_date;
        return [
          day,
          r.product_type,
          Number(r.quantity_produced) || 0,
          r.actual_stored_m2 != null ? Number(r.actual_stored_m2).toFixed(2) : '',
          r.cost_total != null ? Number(r.cost_total).toFixed(2) : '',
          r.revenue_total != null ? Number(r.revenue_total).toFixed(2) : '',
          Number(r.pallet_pieces) || 0,
          Number(r.sold_pieces) || 0,
          Number(r.in_stock_pieces) || 0,
        ].map(escape).join(';');
      });
      const body = '\uFEFF' + [header, ...lines].join('\n');
      res.setHeader('Content-Type', 'text/csv; charset=utf-8');
      res.setHeader('Content-Disposition', `attachment; filename="vyroba-${from}-az-${to}.csv"`);
      res.send(body);
    } catch (err) {
      console.error('[GET /production/export.csv]', err.message);
      res.status(500).json({ error: 'Chyba servera' });
    }
  });

  apiRouter.delete('/pallets/:id', async (req, res) => {
    if (!pool || !poolReady) return res.status(503).json({ error: 'Databáza nie je k dispozícii' });
    const palletId = parseInt(req.params.id, 10);
    if (Number.isNaN(palletId)) return res.status(400).json({ error: 'Neplatné id' });
    const client = await pool.connect();
    try {
      const uid = dataUserId(req);
      await client.query('BEGIN');
      const prev = await client.query('SELECT customer_id, status FROM pallets WHERE user_id = $1 AND id = $2 FOR UPDATE', [uid, palletId]);
      if (!prev.rows.length) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'Paleta nebola nájdená' });
      }
      if (prev.rows[0].status === 'U zákazníka' && prev.rows[0].customer_id) {
        await client.query(
          'UPDATE customers SET pallet_balance = GREATEST(0, COALESCE(pallet_balance,0) - 1) WHERE user_id = $1 AND id = $2',
          [uid, prev.rows[0].customer_id]
        );
      }
      await client.query('DELETE FROM pallets WHERE user_id = $1 AND id = $2', [uid, palletId]);
      await client.query('COMMIT');
      res.json({ success: true });
    } catch (err) {
      await client.query('ROLLBACK');
      console.error('[DELETE /pallets/:id]', err.message);
      res.status(500).json({ error: 'Chyba servera' });
    } finally {
      client.release();
    }
  });

  apiRouter.get('/production-orders/:id', async (req, res) => {
    if (!pool || !poolReady) return res.status(503).json({ error: 'Databáza nie je k dispozícii' });
    const id = parseInt(req.params.id, 10);
    if (Number.isNaN(id)) return res.status(400).json({ error: 'Neplatné id' });
    try {
      const uid = dataUserId(req);
      const { rows } = await pool.query('SELECT * FROM production_orders WHERE user_id = $1 AND id = $2', [uid, id]);
      if (!rows.length) return res.status(404).json({ error: 'Príkaz nebol nájdený' });
      res.json(rows[0]);
    } catch (err) {
      console.error('[GET /production-orders/:id]', err.message);
      res.status(500).json({ error: 'Chyba servera' });
    }
  });

  apiRouter.post('/production-orders', async (req, res) => {
    if (!pool || !poolReady) return res.status(503).json({ error: 'Databáza nie je k dispozícii' });
    const {
      recipe_id,
      planned_quantity,
      production_date,
      notes,
      source_warehouse_id,
      destination_warehouse_id,
      requires_approval,
      order_number,
    } = req.body || {};
    const plan = parseFloat(planned_quantity);
    if (!recipe_id || !(plan > 0)) {
      return res.status(400).json({ error: 'recipe_id a planned_quantity sú povinné' });
    }
    const recId = parseInt(recipe_id, 10);
    const dateStr = (production_date || new Date().toISOString().slice(0, 10)).toString().trim().slice(0, 10);
    const client = await pool.connect();
    try {
      const uid = dataUserId(req);
      await client.query('BEGIN');
      const rec = await client.query(
        'SELECT id, local_id, name FROM recipes WHERE user_id = $1 AND id = $2',
        [uid, recId]
      );
      if (!rec.rows.length) {
        await client.query('ROLLBACK');
        return res.status(400).json({ error: 'Receptúra nebola nájdená' });
      }
      const localId = await nextNegativeLocalId(client, uid);
      const ordNum = (order_number && String(order_number).trim()) || (await nextProductionOrderNumber(client, uid));
      const nowIso = new Date().toISOString();
      const src = source_warehouse_id != null ? parseInt(source_warehouse_id, 10) : null;
      const dst = destination_warehouse_id != null ? parseInt(destination_warehouse_id, 10) : null;
      const reqAppr = requires_approval ? 1 : 0;
      const { rows } = await client.query(
        `INSERT INTO production_orders (
          user_id, local_id, order_number, recipe_local_id, recipe_name, planned_quantity, production_date,
          source_warehouse_id, destination_warehouse_id, notes, status, requires_approval,
          created_by_username, created_at
        ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,'draft',$11,$12,$13)
        RETURNING *`,
        [
          uid,
          localId,
          ordNum,
          rec.rows[0].local_id,
          rec.rows[0].name,
          plan,
          dateStr,
          Number.isNaN(src) ? null : src,
          Number.isNaN(dst) ? null : dst,
          notes != null ? String(notes).trim() || null : null,
          reqAppr,
          req.user?.username || req.user?.email || null,
          nowIso,
        ]
      );
      await client.query('COMMIT');
      res.status(201).json(rows[0]);
    } catch (err) {
      await client.query('ROLLBACK');
      console.error('[POST /production-orders]', err.message);
      res.status(500).json({ error: 'Chyba servera' });
    } finally {
      client.release();
    }
  });

  apiRouter.put('/production-orders/:id', async (req, res) => {
    if (!pool || !poolReady) return res.status(503).json({ error: 'Databáza nie je k dispozícii' });
    const id = parseInt(req.params.id, 10);
    if (Number.isNaN(id)) return res.status(400).json({ error: 'Neplatné id' });
    const body = req.body || {};
    const client = await pool.connect();
    try {
      const uid = dataUserId(req);
      await client.query('BEGIN');
      const ex = await client.query('SELECT * FROM production_orders WHERE user_id = $1 AND id = $2 FOR UPDATE', [uid, id]);
      if (!ex.rows.length) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'Príkaz nebol nájdený' });
      }
      const o = ex.rows[0];
      if (!['draft', 'pending', 'rejected', 'cancelled', 'approved', 'in_progress'].includes(o.status)) {
        await client.query('ROLLBACK');
        return res.status(400).json({ error: 'Dokončený príkaz nie je možné takto upravovať' });
      }

      let recipeLocalId = o.recipe_local_id;
      let recipeName = o.recipe_name;
      if (body.recipe_id != null) {
        const recId = parseInt(body.recipe_id, 10);
        const rec = await client.query('SELECT local_id, name FROM recipes WHERE user_id = $1 AND id = $2', [uid, recId]);
        if (!rec.rows.length) {
          await client.query('ROLLBACK');
          return res.status(400).json({ error: 'Receptúra nebola nájdená' });
        }
        recipeLocalId = rec.rows[0].local_id;
        recipeName = rec.rows[0].name;
      }

      const planned =
        body.planned_quantity != null ? parseFloat(body.planned_quantity) : parseFloat(o.planned_quantity);
      const prodDate =
        body.production_date != null ? String(body.production_date).slice(0, 10) : o.production_date;
      const notes = body.notes !== undefined ? (body.notes != null ? String(body.notes).trim() || null : null) : o.notes;
      const src =
        body.source_warehouse_id !== undefined
          ? parseInt(body.source_warehouse_id, 10)
          : o.source_warehouse_id;
      const dst =
        body.destination_warehouse_id !== undefined
          ? parseInt(body.destination_warehouse_id, 10)
          : o.destination_warehouse_id;

      const { rows } = await client.query(
        `UPDATE production_orders SET
          recipe_local_id = $3, recipe_name = $4, planned_quantity = $5, production_date = $6,
          source_warehouse_id = $7, destination_warehouse_id = $8, notes = $9, requires_approval = COALESCE($10, requires_approval)
        WHERE user_id = $1 AND id = $2 RETURNING *`,
        [
          uid,
          id,
          recipeLocalId,
          recipeName,
          planned,
          prodDate,
          Number.isNaN(src) ? null : src,
          Number.isNaN(dst) ? null : dst,
          notes,
          body.requires_approval != null ? (body.requires_approval ? 1 : 0) : null,
        ]
      );
      await client.query('COMMIT');
      res.json(rows[0]);
    } catch (err) {
      await client.query('ROLLBACK');
      console.error('[PUT /production-orders/:id]', err.message);
      res.status(500).json({ error: 'Chyba servera' });
    } finally {
      client.release();
    }
  });

  apiRouter.patch('/production-orders/:id/status', async (req, res) => {
    if (!pool || !poolReady) return res.status(503).json({ error: 'Databáza nie je k dispozícii' });
    const id = parseInt(req.params.id, 10);
    if (Number.isNaN(id)) return res.status(400).json({ error: 'Neplatné id' });
    const { status, rejection_reason, actual_quantity, create_batch } = req.body || {};
    const newStatus = (status || '').toString().trim();
    if (!newStatus) return res.status(400).json({ error: 'status je povinný' });
    const client = await pool.connect();
    try {
      const uid = dataUserId(req);
      await client.query('BEGIN');
      const ex = await client.query('SELECT * FROM production_orders WHERE user_id = $1 AND id = $2 FOR UPDATE', [uid, id]);
      if (!ex.rows.length) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'Príkaz nebol nájdený' });
      }
      const o = ex.rows[0];
      const nowIso = new Date().toISOString();
      const userLabel = req.user?.username || req.user?.email || null;

      const updates = { status: newStatus };
      if (newStatus === 'pending' && o.status === 'draft') {
        updates.submitted_at = nowIso;
      }
      if (newStatus === 'approved' && ['pending', 'draft'].includes(o.status)) {
        updates.approved_at = nowIso;
        updates.approver_username = userLabel;
      }
      if (newStatus === 'rejected') {
        updates.rejected_at = nowIso;
        updates.rejection_reason = rejection_reason != null ? String(rejection_reason).trim() : null;
      }
      if (newStatus === 'in_progress' && ['approved', 'draft'].includes(o.status)) {
        updates.started_at = nowIso;
      }
      if (newStatus === 'completed') {
        if (o.status !== 'in_progress' && o.status !== 'approved') {
          await client.query('ROLLBACK');
          return res.status(400).json({ error: 'Dokončiť sa dá len príkaz v stave schválený alebo prebieha výroba' });
        }
        const aq = actual_quantity != null ? parseFloat(actual_quantity) : parseFloat(o.planned_quantity);
        updates.completed_at = nowIso;
        updates.completed_by_username = userLabel;
        updates.actual_quantity = aq;
        updates.variance = parseFloat(o.planned_quantity) - aq;
        updates.status = 'completed';
      }
      if (newStatus === 'cancelled' && o.status === 'completed') {
        await client.query('ROLLBACK');
        return res.status(400).json({ error: 'Dokončený príkaz nie je možné zrušiť' });
      }

      const rejectionReasonOut =
        newStatus === 'rejected'
          ? (rejection_reason != null ? String(rejection_reason).trim() : null)
          : o.rejection_reason;

      const { rows } = await client.query(
        `UPDATE production_orders SET
          status = $3,
          submitted_at = COALESCE($4, submitted_at),
          approved_at = COALESCE($5, approved_at),
          approver_username = COALESCE($6, approver_username),
          rejection_reason = $7,
          rejected_at = COALESCE($8, rejected_at),
          started_at = COALESCE($9, started_at),
          completed_at = COALESCE($10, completed_at),
          completed_by_username = COALESCE($11, completed_by_username),
          actual_quantity = COALESCE($12, actual_quantity),
          variance = COALESCE($13, variance)
        WHERE user_id = $1 AND id = $2 RETURNING *`,
        [
          uid,
          id,
          updates.status,
          updates.submitted_at || null,
          updates.approved_at || null,
          updates.approver_username || null,
          rejectionReasonOut,
          updates.rejected_at || null,
          updates.started_at || null,
          updates.completed_at || null,
          updates.completed_by_username || null,
          updates.actual_quantity != null ? updates.actual_quantity : null,
          updates.variance != null ? updates.variance : null,
        ]
      );

      let createdBatch = null;
      if (newStatus === 'completed' && create_batch) {
        const aq = updates.actual_quantity != null ? Number(updates.actual_quantity) : Number(o.planned_quantity);
        if (aq > 0) {
          const recName = recipeName(rows[0]);
          const dateStr = (rows[0].production_date || new Date().toISOString().slice(0, 10)).toString().slice(0, 10);
          const batch = await client.query(
            `INSERT INTO production_batches (user_id, production_date, product_type, quantity_produced, notes, created_at)
             VALUES ($1, $2, $3, $4, $5, CURRENT_TIMESTAMP)
             RETURNING id, local_id, production_date, product_type, quantity_produced, notes, created_at`,
            [
              uid,
              dateStr,
              recName,
              Math.round(aq),
              `Auto z VP ${rows[0].order_number || rows[0].id}`,
            ]
          );
          createdBatch = mapBatch(batch.rows[0]);
          if (batch.rows[0].local_id != null) {
            await client.query(
              `UPDATE production_orders SET finished_goods_receipt_local_id = $3
               WHERE user_id = $1 AND id = $2`,
              [uid, id, batch.rows[0].local_id]
            );
          }
        }
      }

      await client.query('COMMIT');
      res.json({ ...rows[0], created_batch: createdBatch });
    } catch (err) {
      await client.query('ROLLBACK');
      console.error('[PATCH /production-orders/:id/status]', err.message);
      res.status(500).json({ error: 'Chyba servera' });
    } finally {
      client.release();
    }
  });

  function recipeName(row) {
    return row.recipe_name || `VP ${row.order_number || row.id}`;
  }

  apiRouter.delete('/production-orders/:id', async (req, res) => {
    if (!pool || !poolReady) return res.status(503).json({ error: 'Databáza nie je k dispozícii' });
    const id = parseInt(req.params.id, 10);
    if (Number.isNaN(id)) return res.status(400).json({ error: 'Neplatné id' });
    try {
      const uid = dataUserId(req);
      const ex = await pool.query('SELECT status FROM production_orders WHERE user_id = $1 AND id = $2', [uid, id]);
      if (!ex.rows.length) return res.status(404).json({ error: 'Príkaz nebol nájdený' });
      if (!['draft', 'cancelled', 'rejected'].includes(ex.rows[0].status)) {
        return res.status(400).json({ error: 'Zmazať sa dá len koncept / zrušený / zamietnutý príkaz' });
      }
      await pool.query('DELETE FROM production_orders WHERE user_id = $1 AND id = $2', [uid, id]);
      res.json({ success: true });
    } catch (err) {
      console.error('[DELETE /production-orders/:id]', err.message);
      res.status(500).json({ error: 'Chyba servera' });
    }
  });
}

module.exports = { mountProductionWebRoutes };
