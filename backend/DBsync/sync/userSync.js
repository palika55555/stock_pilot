/**
 * Sync používateľa z Flutter (SQLite) do PostgreSQL – upsert podľa username.
 * Ak je poskytnutý ownerId a role je 'user', nastaví sa owner_id (sub-user admina) – potom sa kolega zobrazí v "Moji kolegovia" na webe.
 * @param {import('pg').Pool} pool
 * @param {object} body - { username, password?, full_name?, role?, email?, phone?, department?, avatar_url? }
 * @param {number|null} [ownerId] - ID admina (PostgreSQL), ak sync volá prihlásený admin a pridáva kolegu (role=user)
 * @returns {Promise<{ ok: boolean, error?: string }>}
 */
async function syncUser(pool, body, ownerId = null) {
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
  const setOwner = ownerId != null && Number.isInteger(Number(ownerId)) && r === 'user';
  try {
    // web_access sa NIKDY neaktualizuje cez sync z PC appky – admin ho nastavuje manuálne na webe.
    // owner_id: nastavíme len keď Flutter volá sync s admin tokenom a synced user má role=user (kolega).
    if (setOwner) {
      await pool.query(
        `INSERT INTO users (username, password, full_name, role, email, phone, department, avatar_url, web_access, owner_id)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, false, $9)
         ON CONFLICT (username) DO UPDATE SET
           password = EXCLUDED.password,
           full_name = EXCLUDED.full_name,
           role = EXCLUDED.role,
           email = EXCLUDED.email,
           phone = EXCLUDED.phone,
           department = EXCLUDED.department,
           avatar_url = EXCLUDED.avatar_url,
           owner_id = EXCLUDED.owner_id`,
        [u, p, fn, r, e, ph, d, av, ownerId]
      );
    } else {
      await pool.query(
        `INSERT INTO users (username, password, full_name, role, email, phone, department, avatar_url, web_access)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, false)
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
    }
    return { ok: true };
  } catch (err) {
    console.error('[userSync]', err.message);
    return { ok: false, error: err.message };
  }
}

module.exports = { syncUser };
