// Stock Pilot API – Coolify deploy trigger
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
const { Pool } = require('pg');
const { runMigrations } = require('./DBsync/runMigrations');
const { syncUser } = require('./DBsync/sync/userSync');
const { syncCustomers } = require('./DBsync/sync/customerSync');

const app = express();
const PORT = process.env.PORT || 3000;
const NODE_ENV = process.env.NODE_ENV || 'development';

// PostgreSQL – URL nastav v Coolify ako DATABASE_URL (postgresql://user:pass@host:5432/dbname)
const databaseUrl = process.env.DATABASE_URL;
let pool = databaseUrl ? new Pool({ connectionString: databaseUrl }) : null;
let poolReady = false;

if (pool) {
  pool.on('error', (err) => {
    console.error('[pool] Database pool error (server beží ďalej):', err.message);
  });
}

// Časová pečiatka zmien zákazníkov (web alebo sync) – Flutter periodicky kontroluje a zobrazí notifikáciu
let lastCustomersUpdatedAt = 0;

function getDbHostname() {
  if (!databaseUrl) return null;
  try {
    return new URL(databaseUrl).hostname;
  } catch {
    return null;
  }
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

// Povolené CORS origins (z env alebo default pre Stock Pilot)
const defaultOrigins = ['https://www.stockpilot.sk', 'https://stockpilot.sk'];
const envOrigins = process.env.ALLOWED_ORIGINS
  ? process.env.ALLOWED_ORIGINS.split(',').map((o) => o.trim())
  : defaultOrigins;
const allowedOrigins =
  NODE_ENV === 'development'
    ? [...envOrigins, 'http://localhost:5173', 'http://localhost:3000']
    : envOrigins;

// Middleware
app.use(helmet());
app.use(
  cors({
    origin: (origin, callback) => {
      if (!origin || allowedOrigins.includes(origin)) {
        callback(null, true);
      } else {
        callback(new Error('Not allowed by CORS'));
      }
    },
    credentials: true,
  })
);
app.use(express.json());
app.use(morgan('dev')); // prehľadné request logy v Coolify

// Rate limiting – ochrana proti brute-force (max 100 požiadaviek z IP za 15 min na /api/)
const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  message: { error: 'Príliš veľa požiadaviek, skús to neskôr.' },
});
app.use('/api/', apiLimiter);

// Uptime od štartu procesu (sekundy)
const startTime = Date.now();
const getUptimeSeconds = () => Math.floor((Date.now() - startTime) / 1000);

// --- Routes ---

app.get('/', (req, res) => {
  res.status(403).json({ error: 'Forbidden' });
});

app.get('/health', async (req, res) => {
  if (NODE_ENV === 'production') {
    return res.json({ status: 'up' });
  }
  let database = 'error';
  if (pool && poolReady) {
    try {
      await pool.query('SELECT NOW()');
      database = 'connected';
    } catch (err) {
      console.error('[health] DB check failed:', err.message);
    }
  } else if (!pool) {
    console.warn('[health] DATABASE_URL not set, skipping DB check');
  }
  res.json({
    status: 'ok',
    service: 'stock-pilot-api',
    uptimeSeconds: getUptimeSeconds(),
    uptimeFormatted: formatUptime(getUptimeSeconds()),
    database,
    internal_hostname: getDbHostname(),
  });
});

// --- API: Auth (rovnaká logika ako Flutter login_page – username + password z DB) ---
app.post('/api/auth/login', async (req, res) => {
  const { username, password } = req.body || {};
  if (!username || !password) {
    return res.status(401).json({
      success: false,
      error: 'Username a heslo sú povinné',
    });
  }
  if (!pool || !poolReady) {
    return res.status(503).json({
      success: false,
      error: 'Databáza nie je k dispozícii',
    });
  }
  try {
    const {
      rows: [user],
    } = await pool.query(
      'SELECT id, username, password, full_name, role, email, phone, department, avatar_url, join_date FROM users WHERE username = $1',
      [username.toString().trim()]
    );
    if (!user || user.password !== password) {
      console.warn('[auth] Failed login attempt for username:', username);
      return res.status(401).json({
        success: false,
        error: 'Nesprávny login alebo heslo',
      });
    }
    const token = `Bearer-${Buffer.from(String(user.id)).toString('base64')}-${Date.now()}`;
    console.log('[auth] Login OK:', user.username);
    res.status(200).json({
      success: true,
      token,
      user: {
        id: user.id,
        username: user.username,
        fullName: user.full_name || user.username,
        role: user.role || 'user',
        email: user.email || '',
      },
    });
  } catch (err) {
    console.error('[auth] Login error:', err.message);
    res.status(500).json({
      success: false,
      error: 'Chyba servera',
    });
  }
});

// --- Sync používateľa z Flutter (SQLite) do PostgreSQL – služba v DBsync/sync ---
app.post('/api/auth/sync-user', async (req, res) => {
  if (!pool || !poolReady) {
    return res.status(503).json({ success: false, error: 'Databáza nie je k dispozícii' });
  }
  const result = await syncUser(pool, req.body);
  if (!result.ok) {
    const status = result.error === 'username je povinný' ? 400 : 500;
    return res.status(status).json({ success: false, error: result.error || 'Chyba servera' });
  }
  console.log('[auth] Sync user OK:', req.body?.username);
  res.status(200).json({ success: true, message: 'Používateľ zosynchronizovaný' });
});

// --- API: Stocks (PostgreSQL) ---
app.get('/api/stocks', async (req, res) => {
  if (!pool || !poolReady) {
    console.error('[GET /api/stocks] Database not available');
    return res.status(503).json({ error: 'Database not configured or unavailable' });
  }
  try {
    const { rows } = await pool.query(
      'SELECT id, symbol, price, created_at FROM stocks ORDER BY created_at DESC'
    );
    console.log('[GET /api/stocks] returned', rows.length, 'rows');
    res.json(rows);
  } catch (err) {
    console.error('[GET /api/stocks]', err.message);
    res.status(500).json({ error: 'Database error' });
  }
});

app.post('/api/stocks', async (req, res) => {
  if (!pool || !poolReady) {
    console.error('[POST /api/stocks] Database not available');
    return res.status(503).json({ error: 'Database not configured or unavailable' });
  }
  const { symbol, price } = req.body || {};
  if (symbol == null || symbol.toString().trim() === '' || price == null) {
    console.warn('[POST /api/stocks] invalid body:', { symbol, price });
    return res.status(400).json({
      error: 'symbol (non-empty) and price (number) are required',
    });
  }
  const priceNum = Number(price);
  if (Number.isNaN(priceNum)) {
    return res.status(400).json({ error: 'price must be a number' });
  }
  try {
    const {
      rows: [row],
    } = await pool.query(
      'INSERT INTO stocks (symbol, price) VALUES ($1, $2) RETURNING id, symbol, price, created_at',
      [symbol.toString().trim(), priceNum]
    );
    console.log('[POST /api/stocks] created id=', row?.id, 'symbol=', row?.symbol);
    res.status(201).json(row);
  } catch (err) {
    console.error('[POST /api/stocks]', err.message);
    res.status(500).json({ error: 'Database error' });
  }
});

// --- Sync zákazníkov z Flutter do PostgreSQL (DBsync/sync) ---
app.post('/api/sync/customers', async (req, res) => {
  if (!pool || !poolReady) {
    return res.status(503).json({ success: false, error: 'Databáza nie je k dispozícii' });
  }
  const result = await syncCustomers(pool, req.body);
  if (!result.ok) {
    return res.status(500).json({ success: false, error: result.error || 'Chyba servera' });
  }
  lastCustomersUpdatedAt = Date.now();
  console.log('[sync] Customers OK:', result.count);
  res.status(200).json({ success: true, count: result.count });
});

// --- API: Zákazníci (zoznam a detail) ---
app.get('/api/customers', async (req, res) => {
  if (!pool || !poolReady) {
    return res.status(503).json({ error: 'Databáza nie je k dispozícii' });
  }
  try {
    const { rows } = await pool.query(
      `SELECT id, local_id, name, ico, email, address, city, postal_code, dic, ic_dph, default_vat_rate, is_active
       FROM customers ORDER BY name ASC`
    );
    res.json(rows);
  } catch (err) {
    console.error('[GET /api/customers]', err.message);
    res.status(500).json({ error: 'Chyba servera' });
  }
});

app.get('/api/customers/:id', async (req, res) => {
  if (!pool || !poolReady) {
    return res.status(503).json({ error: 'Databáza nie je k dispozícii' });
  }
  const id = parseInt(req.params.id, 10);
  if (Number.isNaN(id)) {
    return res.status(400).json({ error: 'Neplatné id' });
  }
  try {
    const { rows } = await pool.query(
      `SELECT id, local_id, name, ico, email, address, city, postal_code, dic, ic_dph, default_vat_rate, is_active
       FROM customers WHERE id = $1`,
      [id]
    );
    if (rows.length === 0) {
      return res.status(404).json({ error: 'Zákazník nebol nájdený' });
    }
    res.json(rows[0]);
  } catch (err) {
    console.error('[GET /api/customers/:id]', err.message);
    res.status(500).json({ error: 'Chyba servera' });
  }
});

app.put('/api/customers/:id', async (req, res) => {
  if (!pool || !poolReady) {
    return res.status(503).json({ error: 'Databáza nie je k dispozícii' });
  }
  const id = parseInt(req.params.id, 10);
  if (Number.isNaN(id)) {
    return res.status(400).json({ error: 'Neplatné id' });
  }
  const { name, ico, email, address, city, postal_code, dic, ic_dph, default_vat_rate, is_active } = req.body || {};
  const nameVal = name != null ? String(name).trim() : null;
  const icoVal = ico != null ? String(ico).trim() : null;
  if (!nameVal || nameVal === '' || !icoVal || icoVal === '') {
    return res.status(400).json({ error: 'Meno a IČO sú povinné' });
  }
  try {
    const { rowCount } = await pool.query(
      `UPDATE customers SET
        name = $1, ico = $2, email = $3, address = $4, city = $5, postal_code = $6,
        dic = $7, ic_dph = $8, default_vat_rate = $9, is_active = $10
       WHERE id = $11`,
      [
        nameVal,
        icoVal,
        email != null ? String(email).trim() || null : null,
        address != null ? String(address).trim() || null : null,
        city != null ? String(city).trim() || null : null,
        postal_code != null ? String(postal_code).trim() || null : null,
        dic != null ? String(dic).trim() || null : null,
        ic_dph != null ? String(ic_dph).trim() || null : null,
        default_vat_rate != null ? parseInt(default_vat_rate, 10) : 20,
        is_active !== undefined && is_active !== null ? (is_active ? 1 : 0) : 1,
        id,
      ]
    );
    if (rowCount === 0) {
      return res.status(404).json({ error: 'Zákazník nebol nájdený' });
    }
    const { rows } = await pool.query(
      'SELECT id, local_id, name, ico, email, address, city, postal_code, dic, ic_dph, default_vat_rate, is_active FROM customers WHERE id = $1',
      [id]
    );
    lastCustomersUpdatedAt = Date.now();
    res.json(rows[0]);
  } catch (err) {
    console.error('[PUT /api/customers/:id]', err.message);
    res.status(500).json({ error: 'Chyba servera' });
  }
});

// --- Kontrola zmien na webe (Flutter periodicky volá a zobrazí notifikáciu ak sa zmenilo) ---
app.get('/api/sync/check', (_req, res) => {
  res.json({ customers_updated_at: lastCustomersUpdatedAt });
});

// --- API: Dashboard štatistiky – čítanie z PostgreSQL (customers už sync, zvyšok 0 kým nie sú tabuľky) ---
app.get('/api/dashboard/stats', async (req, res) => {
  if (!pool || !poolReady) {
    return res.status(503).json({ error: 'Databáza nie je k dispozícii' });
  }
  try {
    let customers = 0;
    try {
      const r = await pool.query('SELECT COUNT(*)::int AS count FROM customers');
      customers = r.rows[0]?.count ?? 0;
    } catch (_) {}
    const stats = {
      products: 0,
      orders: 0,
      customers,
      revenue: 0,
      inboundCount: 0,
      outboundCount: 0,
      quotesCount: 0,
      recentInbound: [],
      recentOutbound: [],
    };
    res.json(stats);
  } catch (err) {
    console.error('[GET /api/dashboard/stats]', err.message);
    res.status(500).json({ error: 'Chyba servera' });
  }
});

// 404
app.use((req, res) => {
  res.status(404).json({ error: 'Not Found' });
});

// Error handler (CORS a iné chyby)
app.use((err, req, res, next) => {
  if (err.message === 'Not allowed by CORS') {
    return res.status(403).json({ error: 'Origin not allowed' });
  }
  console.error(err);
  res.status(500).json({ error: 'Internal Server Error' });
});

function formatUptime(seconds) {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = seconds % 60;
  const parts = [];
  if (h > 0) parts.push(`${h}h`);
  if (m > 0) parts.push(`${m}m`);
  parts.push(`${s}s`);
  return parts.join(' ');
}

async function start() {
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`API beží na http://0.0.0.0:${PORT}`);
    console.log(`CORS: ${allowedOrigins.join(', ')}`);
  });

  if (!pool) return;

  for (;;) {
    try {
      await pool.query('SELECT NOW()');
      const { run } = await runMigrations(pool);
      poolReady = true;
      if (run > 0) console.log('[start] Migrácie spustené:', run);
      break;
    } catch (err) {
      console.error('[start] DB / migrácie:', err.message);
      poolReady = false;
      console.error('[start] Retry za 5 s...');
      await sleep(5000);
    }
  }
}

start().catch((err) => {
  console.error('Startup error (server beží):', err);
});
