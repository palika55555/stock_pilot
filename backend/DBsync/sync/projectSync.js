/**
 * Sync zákaziek z Flutter (SQLite) do PostgreSQL – upsert podľa local_id, izolované podľa user_id.
 * @param {import('pg').Pool} pool
 * @param {object} body - { projects: Array<{...}> }
 * @param {number} userId
 * @returns {Promise<{ ok: boolean, count?: number, error?: string }>}
 */
async function syncProjects(pool, body, userId) {
  if (!pool) return { ok: false, error: 'Databáza nie je k dispozícii' };
  if (!userId || userId < 1) return { ok: false, error: 'Chýba user_id (token)' };
  const list = Array.isArray(body?.projects) ? body.projects : [];
  const client = await pool.connect();
  try {
    await client.query('DELETE FROM projects WHERE user_id = $1', [userId]);
    let count = 0;
    for (const p of list) {
      const localId = p.id != null ? Number(p.id) : null;
      if (localId == null || Number.isNaN(localId)) continue;
      await client.query(
        `INSERT INTO projects
          (user_id, local_id, project_number, name, status, customer_id, customer_name,
           site_address, site_city, start_date, end_date, budget, responsible_person, notes, created_at)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15)`,
        [
          userId,
          localId,
          String(p.project_number ?? '').trim(),
          String(p.name ?? '').trim(),
          p.status ?? 'active',
          p.customer_id != null ? Number(p.customer_id) : null,
          p.customer_name != null ? String(p.customer_name).trim() : null,
          p.site_address != null ? String(p.site_address).trim() : null,
          p.site_city != null ? String(p.site_city).trim() : null,
          p.start_date != null ? String(p.start_date) : null,
          p.end_date != null ? String(p.end_date) : null,
          p.budget != null ? Number(p.budget) : null,
          p.responsible_person != null ? String(p.responsible_person).trim() : null,
          p.notes != null ? String(p.notes).trim() : null,
          p.created_at != null ? String(p.created_at) : null,
        ]
      );
      count++;
    }
    return { ok: true, count };
  } catch (err) {
    console.error('[projectSync]', err.message);
    return { ok: false, error: err.message };
  } finally {
    client.release();
  }
}

module.exports = { syncProjects };
