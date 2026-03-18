/**
 * Sync transportov z Flutter do PostgreSQL.
 */
async function syncTransports(pool, body, userId) {
  if (!pool) return { ok: false, error: 'Databáza nie je k dispozícii' };
  if (!userId || userId < 1) return { ok: false, error: 'Chýba user_id' };

  const transports = Array.isArray(body?.transports) ? body.transports : [];
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    for (const t of transports) {
      const localId = t.local_id != null ? Number(t.local_id) : null;
      if (localId == null || Number.isNaN(localId)) continue;

      const existing = await client.query(
        'SELECT id FROM transports WHERE user_id = $1 AND local_id = $2',
        [userId, localId]
      );

      const vals = [
        userId, localId,
        t.origin || null,
        t.destination || null,
        t.distance != null ? parseFloat(t.distance) : null,
        t.is_round_trip != null ? Number(t.is_round_trip) : 0,
        t.price_per_km != null ? parseFloat(t.price_per_km) : null,
        t.fuel_consumption != null ? parseFloat(t.fuel_consumption) : null,
        t.fuel_price != null ? parseFloat(t.fuel_price) : null,
        t.base_cost != null ? parseFloat(t.base_cost) : null,
        t.fuel_cost != null ? parseFloat(t.fuel_cost) : null,
        t.total_cost != null ? parseFloat(t.total_cost) : null,
        t.created_at || null,
        t.notes || null,
      ];

      if (existing.rows.length > 0) {
        await client.query(
          `UPDATE transports SET
            origin=$3, destination=$4, distance=$5, is_round_trip=$6,
            price_per_km=$7, fuel_consumption=$8, fuel_price=$9,
            base_cost=$10, fuel_cost=$11, total_cost=$12, created_at=$13, notes=$14
          WHERE user_id=$1 AND local_id=$2`,
          vals
        );
      } else {
        await client.query(
          `INSERT INTO transports (
            user_id, local_id, origin, destination, distance, is_round_trip,
            price_per_km, fuel_consumption, fuel_price, base_cost, fuel_cost,
            total_cost, created_at, notes
          ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14)`,
          vals
        );
      }
    }

    await client.query('COMMIT');
    return { ok: true, count: transports.length };
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('[transportSync]', err.message);
    return { ok: false, error: err.message };
  } finally {
    client.release();
  }
}

async function fetchTransports(pool, userId) {
  if (!pool || !userId) return null;
  const client = await pool.connect();
  try {
    const res = await client.query(
      'SELECT * FROM transports WHERE user_id = $1 ORDER BY id',
      [userId]
    );
    return { transports: res.rows };
  } catch (err) {
    console.error('[fetchTransports]', err.message);
    return null;
  } finally {
    client.release();
  }
}

module.exports = { syncTransports, fetchTransports };
