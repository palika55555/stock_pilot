/**
 * Sync firemných údajov z Flutter do PostgreSQL – jeden záznam na používateľa.
 */
async function syncCompany(pool, body, userId) {
  if (!pool) return { ok: false, error: 'Databáza nie je k dispozícii' };
  if (!userId || userId < 1) return { ok: false, error: 'Chýba user_id' };

  const c = body?.company;
  if (!c) return { ok: false, error: 'Chýbajú dáta firmy' };

  const client = await pool.connect();
  try {
    const existing = await client.query(
      'SELECT id FROM company WHERE user_id = $1',
      [userId]
    );

    const vals = [
      userId,
      c.name || null,
      c.address || null,
      c.city || null,
      c.postal_code || null,
      c.country || null,
      c.ico || null,
      c.dic || null,
      c.ic_dph || null,
      c.vat_payer != null ? Number(c.vat_payer) : 0,
      c.phone || null,
      c.email || null,
      c.web || null,
      c.iban || null,
      c.swift || null,
      c.bank_name || null,
      c.account || null,
      c.register_info || null,
    ];

    if (existing.rows.length > 0) {
      await client.query(
        `UPDATE company SET
          name=$2, address=$3, city=$4, postal_code=$5, country=$6,
          ico=$7, dic=$8, ic_dph=$9, vat_payer=$10, phone=$11, email=$12,
          web=$13, iban=$14, swift=$15, bank_name=$16, account=$17, register_info=$18
        WHERE user_id=$1`,
        vals
      );
    } else {
      await client.query(
        `INSERT INTO company (
          user_id, name, address, city, postal_code, country,
          ico, dic, ic_dph, vat_payer, phone, email, web, iban, swift, bank_name, account, register_info
        ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18)`,
        vals
      );
    }

    return { ok: true };
  } catch (err) {
    console.error('[companySync]', err.message);
    return { ok: false, error: err.message };
  } finally {
    client.release();
  }
}

async function fetchCompany(pool, userId) {
  if (!pool || !userId) return null;
  const client = await pool.connect();
  try {
    const res = await client.query(
      'SELECT * FROM company WHERE user_id = $1',
      [userId]
    );
    return res.rows[0] || null;
  } catch (err) {
    console.error('[fetchCompany]', err.message);
    return null;
  } finally {
    client.release();
  }
}

module.exports = { syncCompany, fetchCompany };
