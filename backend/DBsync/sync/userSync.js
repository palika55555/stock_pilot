/**
 * Sync používateľa z Flutter (SQLite) do PostgreSQL – upsert podľa username.
 * @param {import('pg').Pool} pool
 * @param {object} body - { username, password?, full_name?, role?, email?, phone?, department?, avatar_url? }
 * @returns {Promise<{ ok: boolean, error?: string }>}
 */
async function syncUser(pool, body) {
  if (!pool) return { ok: false, error: 'Databáza nie je k dispozícii' };
  const {
    username,
    password,
    full_name,
    role,
    email,
    phone,
    department,
    avatar_url,
  } = body || {};
  if (!username || String(username).trim() === '') {
    return { ok: false, error: 'username je povinný' };
  }
  const u = String(username).trim();
  const p = password != null ? String(password) : '';
  const fn = full_name != null ? String(full_name).trim() : u;
  const r = role != null ? String(role).trim() : 'user';
  const e = email != null ? String(email).trim() : '';
  const ph = phone != null ? String(phone).trim() : '';
  const d = department != null ? String(department).trim() : '';
  const av = avatar_url != null ? String(avatar_url).trim() : '';
  try {
    await pool.query(
      `INSERT INTO users (username, password, full_name, role, email, phone, department, avatar_url)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       ON CONFLICT (username) DO UPDATE SET
         password = EXCLUDED.password,
         full_name = EXCLUDED.full_name,
         role = EXCLUDED.role,
         email = EXCLUDED.email,
         phone = EXCLUDED.phone,
         department = EXCLUDED.department,
         avatar_url = EXCLUDED.avatar_url`,
      [u, p, fn, r, e, ph, d, av]
    );
    return { ok: true };
  } catch (err) {
    console.error('[userSync]', err.message);
    return { ok: false, error: err.message };
  }
}

module.exports = { syncUser };
