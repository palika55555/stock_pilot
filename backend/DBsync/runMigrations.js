const fs = require('fs');
const path = require('path');

const MIGRATIONS_DIR = path.join(__dirname, 'migrations');

/**
 * Spustí všetky migrácie z DBsync/migrations/ v poradí podľa názvu súboru.
 * Eviduje ich v tabuľke schema_migrations.
 * @param {import('pg').Pool} pool
 * @returns {Promise<{ run: number }>}
 */
async function runMigrations(pool) {
  if (!pool) return { run: 0 };
  const client = await pool.connect();
  let runCount = 0;
  try {
    let files = fs.readdirSync(MIGRATIONS_DIR).filter((f) => f.endsWith('.sql')).sort();
    for (const file of files) {
      const name = file;
      let existing = [];
      try {
        const r = await client.query('SELECT 1 FROM schema_migrations WHERE name = $1', [name]);
        existing = r.rows;
      } catch (err) {
        if (err.message?.includes('relation "schema_migrations" does not exist')) {
          const firstSql = fs.readFileSync(path.join(MIGRATIONS_DIR, files[0]), 'utf8');
          await client.query(firstSql);
          await client.query('INSERT INTO schema_migrations (name) VALUES ($1)', [files[0]]);
          runCount++;
          console.log('[migrations] Ran:', files[0]);
          continue;
        }
        throw err;
      }
      if (existing.length > 0) continue;

      const sql = fs.readFileSync(path.join(MIGRATIONS_DIR, file), 'utf8');
      await client.query(sql);
      await client.query('INSERT INTO schema_migrations (name) VALUES ($1)', [name]);
      runCount++;
      console.log('[migrations] Ran:', name);
    }
  } finally {
    client.release();
  }
  return { run: runCount };
}

module.exports = { runMigrations };
