// Stock Pilot API – Coolify deploy (v1.0.2)
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
const { Pool } = require('pg');
const { runMigrations } = require('./DBsync/runMigrations');
const { syncUser } = require('./DBsync/sync/userSync');
const { syncCustomers } = require('./DBsync/sync/customerSync');
const { syncProducts } = require('./DBsync/sync/productSync');
const { signTokens, verifyAccessToken, verifyRefreshToken } = require('./auth/jwt');
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
// Posledná úspešná synchronizácia (akákoľvek sync) – pre dashboard a notifikácie
let lastSyncAt = 0;

// Po migrácii 009: true ak sú dáta priradené používateľom; false ak treba manuálnu migráciu (viac používateľov)
let dataIsolationMigrated = true;

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
const defaultOrigins = [
  'https://www.app.stockpilot.sk',
  'https://app.stockpilot.sk',
];

// Vždy zahrni default origins; ALLOWED_ORIGINS len pridá ďalšie (nikdy nenahradí www.stockpilot.sk).
const extraOrigins = process.env.ALLOWED_ORIGINS
  ? process.env.ALLOWED_ORIGINS.split(',').map((o) => o.trim()).filter(Boolean)
  : ['https://stock-pilot-web.vercel.app'];
const envOrigins = [...defaultOrigins, ...extraOrigins];

// Dôležité: Uisti sa, že NODE_ENV je v Coolify nastavené na 'production'
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

// Tajný path prefix pre API – bez znalosti tejto cesty sa nikto nedostane k endpointom (obfuskovácia).
// Na Coolify nastav API_PATH_PREFIX (napr. vlastný náhodný reťazec). Musí byť rovnaký vo Flutter/React.
const API_PATH_PREFIX = process.env.API_PATH_PREFIX || 'sp-9f2a4e1b';

// Rate limiting – ochrana proti brute-force (max 100 požiadaviek z IP za 15 min na /api/)
const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  message: { error: 'Príliš veľa požiadaviek, skús to neskôr.' },
});
app.use('/api/', apiLimiter);

// Middleware: verify JWT (Bearer <accessToken>) and set req.userId, req.userEmail, req.userRole
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  if (!authHeader || typeof authHeader !== 'string') {
    return res.status(401).json({ error: 'Prístup zamietnutý. Vyžaduje sa prihlásenie.' });
  }
  const trimmed = authHeader.trim();
  // Accept "Bearer <jwt>"
  if (trimmed.startsWith('Bearer ')) {
    const token = trimmed.slice(7).trim();
    const decoded = verifyAccessToken(token);
    if (decoded) {
      req.userId = decoded.userId;
      req.userEmail = decoded.email;
      req.userRole = decoded.role;
      return next();
    }
  }
  return res.status(401).json({ error: 'Neplatný alebo expirovaný token.' });
};

// API router – všetky endpointy sú pod /api/:API_PATH_PREFIX/ (napr. /api/sp-9f2a4e1b/auth/login)
const apiRouter = express.Router();

// Preflight (OPTIONS) neposiela Authorization – musí prejsť, aby prehliadač potom poslal skutočný request
apiRouter.options('*', (req, res) => res.sendStatus(204));

// Všetko okrem /auth/login, /auth/refresh, /auth/sync-user vyžaduje JWT
apiRouter.use((req, res, next) => {
  if (req.method === 'OPTIONS') return next();
  if (req.path === '/auth/login' || req.path === '/auth/refresh' || req.path === '/auth/sync-user') return next();
  if (req.path.startsWith('/auth')) return next();
  authenticateToken(req, res, next);
});

// Header pre klienta: X-Data-Isolation-Warning: true ak treba manuálnu migráciu
apiRouter.use((req, res, next) => {
  res.setHeader('X-Data-Isolation-Warning', dataIsolationMigrated ? 'false' : 'true');
  next();
});

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

// Kontrola tabuliek v PostgreSQL (pre web) – bez auth, vracia zoznam tabuliek a spustených migrácií
app.get('/health/db-tables', async (req, res) => {
  if (!pool || !poolReady) {
    return res.status(503).json({
      error: 'Databáza nie je nakonfigurovaná alebo nie je pripojená',
      tables: [],
      migrations: [],
    });
  }
  try {
    const tablesRes = await pool.query(
      `SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename`
    );
    const tables = (tablesRes.rows || []).map((r) => r.tablename);
    let migrations = [];
    try {
      const migRes = await pool.query('SELECT name, run_at FROM schema_migrations ORDER BY name');
      migrations = (migRes.rows || []).map((r) => ({ name: r.name, run_at: r.run_at }));
    } catch (_) {
      // schema_migrations ešte neexistuje
    }
    const expected = ['schema_migrations', 'users', 'customers', 'products', 'stocks'];
    const missing = expected.filter((t) => !tables.includes(t));
    res.json({
      database: 'connected',
      tables,
      migrations,
      expected,
      missing: missing.length ? missing : null,
      ok: missing.length === 0,
    });
  } catch (err) {
    console.error('[health/db-tables]', err.message);
    res.status(500).json({
      error: err.message,
      tables: [],
      migrations: [],
    });
  }
});

// --- API: Auth – JWT (access 24h, refresh 30d; rememberMe => access 7d) ---
apiRouter.post('/auth/login', async (req, res) => {
  const { username, password, rememberMe } = req.body || {};
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
    const tokens = signTokens(
      { userId: user.id, email: user.email || '', role: user.role || 'user' },
      !!rememberMe
    );
    console.log('[auth] Login OK:', user.username);
    res.status(200).json({
      success: true,
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      expiresIn: tokens.accessExpiresIn,
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

// --- Refresh access token using refresh token (body: { refreshToken }) ---
apiRouter.post('/auth/refresh', async (req, res) => {
  const { refreshToken } = req.body || {};
  if (!refreshToken) {
    return res.status(401).json({ success: false, error: 'Chýba refresh token.' });
  }
  const decoded = verifyRefreshToken(refreshToken);
  if (!decoded) {
    return res.status(401).json({ success: false, error: 'Neplatný alebo expirovaný refresh token.' });
  }
  if (!pool || !poolReady) {
    return res.status(503).json({ success: false, error: 'Databáza nie je k dispozícii' });
  }
  try {
    const { rows } = await pool.query(
      'SELECT id, email, role FROM users WHERE id = $1',
      [decoded.userId]
    );
    if (rows.length === 0) {
      return res.status(401).json({ success: false, error: 'Používateľ neexistuje.' });
    }
    const u = rows[0];
    const tokens = signTokens(
      { userId: u.id, email: u.email || '', role: u.role || 'user' },
      false
    );
    res.status(200).json({
      success: true,
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      expiresIn: tokens.accessExpiresIn,
    });
  } catch (err) {
    console.error('[auth] Refresh error:', err.message);
    res.status(500).json({ success: false, error: 'Chyba servera' });
  }
});

// --- Sync používateľa z Flutter (SQLite) do PostgreSQL – služba v DBsync/sync ---
apiRouter.post('/auth/sync-user', async (req, res) => {
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

// --- API: Stocks (PostgreSQL) – per user ---
apiRouter.get('/stocks', async (req, res) => {
  if (!pool || !poolReady) {
    console.error('[GET /api/stocks] Database not available');
    return res.status(503).json({ error: 'Database not configured or unavailable' });
  }
  try {
    const { rows } = await pool.query(
      'SELECT id, symbol, price, created_at FROM stocks WHERE user_id = $1 ORDER BY created_at DESC',
      [req.userId]
    );
    console.log('[GET /api/stocks] returned', rows.length, 'rows');
    res.json(rows);
  } catch (err) {
    console.error('[GET /api/stocks]', err.message);
    res.status(500).json({ error: 'Database error' });
  }
});

apiRouter.post('/stocks', async (req, res) => {
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
      'INSERT INTO stocks (user_id, symbol, price) VALUES ($1, $2, $3) RETURNING id, symbol, price, created_at',
      [req.userId, symbol.toString().trim(), priceNum]
    );
    console.log('[POST /api/stocks] created id=', row?.id, 'symbol=', row?.symbol);
    res.status(201).json(row);
  } catch (err) {
    console.error('[POST /api/stocks]', err.message);
    res.status(500).json({ error: 'Database error' });
  }
});

// --- Sync produktov z Flutter do PostgreSQL (DBsync/sync) – per user ---
apiRouter.post('/sync/products', async (req, res) => {
  const received = Array.isArray(req.body?.products) ? req.body.products.length : 0;
  console.log('[sync] Products request received:', received, 'items');
  if (!pool || !poolReady) {
    return res.status(503).json({ success: false, error: 'Databáza nie je k dispozícii' });
  }
  const result = await syncProducts(pool, req.body, req.userId);
  if (!result.ok) {
    console.error('[sync] Products failed:', result.error);
    return res.status(500).json({ success: false, error: result.error || 'Chyba servera' });
  }
  lastSyncAt = Date.now();
  console.log('[sync] Products OK, saved:', result.count);
  res.status(200).json({ success: true, count: result.count });
});

// --- Sync zákazníkov z Flutter do PostgreSQL (DBsync/sync) – per user ---
apiRouter.post('/sync/customers', async (req, res) => {
  if (!pool || !poolReady) {
    return res.status(503).json({ success: false, error: 'Databáza nie je k dispozícii' });
  }
  const result = await syncCustomers(pool, req.body, req.userId);
  if (!result.ok) {
    return res.status(500).json({ success: false, error: result.error || 'Chyba servera' });
  }
  lastCustomersUpdatedAt = Date.now();
  lastSyncAt = Date.now();
  console.log('[sync] Customers OK:', result.count);
  res.status(200).json({ success: true, count: result.count });
});

// --- Sync šarží a paliet z Flutter do PostgreSQL – per user ---
apiRouter.post('/sync/batches', async (req, res) => {
  if (!pool || !poolReady) {
    return res.status(503).json({ success: false, error: 'Databáza nie je k dispozícii' });
  }
  const userId = req.userId;
  const batches = Array.isArray(req.body?.batches) ? req.body.batches : [];
  const pallets = Array.isArray(req.body?.pallets) ? req.body.pallets : [];
  const client = await pool.connect();
  const batchIdMap = {};
  try {
    for (const b of batches) {
      const localId = b.id != null ? Number(b.id) : null;
      if (localId == null || Number.isNaN(localId)) continue;
      const productionDate = (b.production_date || '').toString().trim().slice(0, 10);
      const productType = (b.product_type || '').toString().trim() || 'Výrobok';
      const quantityProduced = parseInt(b.quantity_produced, 10) || 0;
      const notes = b.notes != null ? String(b.notes).trim() || null : null;
      const createdAt = b.created_at || null;
      const costTotal = b.cost_total != null ? parseFloat(b.cost_total) : null;
      const revenueTotal = b.revenue_total != null ? parseFloat(b.revenue_total) : null;
      const existing = await client.query('SELECT id FROM production_batches WHERE user_id = $1 AND local_id = $2', [userId, localId]);
      let backendBatchId;
      if (existing.rows.length > 0) {
        backendBatchId = existing.rows[0].id;
        await client.query(
          `UPDATE production_batches SET production_date = $1, product_type = $2, quantity_produced = $3, notes = $4, created_at = $5::timestamp, cost_total = $6, revenue_total = $7 WHERE id = $8`,
          [productionDate, productType, quantityProduced, notes, createdAt, costTotal, revenueTotal, backendBatchId]
        );
      } else {
        const ins = await client.query(
          `INSERT INTO production_batches (user_id, local_id, production_date, product_type, quantity_produced, notes, created_at, cost_total, revenue_total) VALUES ($1, $2, $3, $4, $5, $6, $7::timestamp, $8, $9) RETURNING id`,
          [userId, localId, productionDate, productType, quantityProduced, notes, createdAt, costTotal, revenueTotal]
        );
        backendBatchId = ins.rows[0]?.id;
      }
      if (backendBatchId) batchIdMap[localId] = backendBatchId;
      const recipe = Array.isArray(b.recipe) ? b.recipe : [];
      await client.query('DELETE FROM production_batch_recipe WHERE batch_id = $1', [backendBatchId]);
      for (const r of recipe) {
        const qty = parseFloat(r.quantity) || 0;
        if (qty <= 0) continue;
        const matName = (r.material_name || '').toString().trim() || 'Materiál';
        const unit = (r.unit || 'kg').toString().trim();
        await client.query(
          'INSERT INTO production_batch_recipe (batch_id, material_name, quantity, unit) VALUES ($1, $2, $3, $4)',
          [backendBatchId, matName, qty, unit]
        );
      }
    }
    for (const p of pallets) {
      const localId = p.id != null ? Number(p.id) : null;
      if (localId == null || Number.isNaN(localId)) continue;
      const flutterBatchId = parseInt(p.batch_id, 10);
      const backendBatchId = batchIdMap[flutterBatchId];
      if (backendBatchId == null) continue;
      const productType = (p.product_type || '').toString().trim() || 'Výrobok';
      const quantity = parseInt(p.quantity, 10) || 0;
      const status = (p.status || 'Na sklade').toString().trim();
      let backendCustomerId = null;
      if (p.customer_id != null) {
        const cust = await client.query('SELECT id FROM customers WHERE user_id = $1 AND local_id = $2', [userId, Number(p.customer_id)]);
        if (cust.rows[0]) backendCustomerId = cust.rows[0].id;
      }
      const existingPallet = await client.query('SELECT id FROM pallets WHERE user_id = $1 AND local_id = $2', [userId, localId]);
      if (existingPallet.rows.length > 0) {
        await client.query(
          `UPDATE pallets SET batch_id = $1, product_type = $2, quantity = $3, customer_id = $4, status = $5 WHERE user_id = $6 AND local_id = $7`,
          [backendBatchId, productType, quantity, backendCustomerId, status, userId, localId]
        );
      } else {
        await client.query(
          `INSERT INTO pallets (user_id, local_id, batch_id, product_type, quantity, customer_id, status) VALUES ($1, $2, $3, $4, $5, $6, $7)`,
          [userId, localId, backendBatchId, productType, quantity, backendCustomerId, status]
        );
      }
    }
    lastSyncAt = Date.now();
    console.log('[sync] Batches OK:', batches.length);
    res.status(200).json({ success: true, count: batches.length });
  } catch (err) {
    console.error('[sync/batches]', err.message);
    res.status(500).json({ success: false, error: err.message });
  } finally {
    client.release();
  }
});

// --- API: Zákazníci (zoznam a detail) – per user ---
apiRouter.get('/customers', async (req, res) => {
  if (!pool || !poolReady) {
    return res.status(503).json({ error: 'Databáza nie je k dispozícii' });
  }
  try {
    const { rows } = await pool.query(
      `SELECT id, local_id, name, ico, email, address, city, postal_code, dic, ic_dph, default_vat_rate, is_active
       FROM customers WHERE user_id = $1 ORDER BY name ASC`,
      [req.userId]
    );
    res.json(rows);
  } catch (err) {
    console.error('[GET /api/customers]', err.message);
    res.status(500).json({ error: 'Chyba servera' });
  }
});

apiRouter.get('/customers/:id', async (req, res) => {
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
       FROM customers WHERE user_id = $1 AND id = $2`,
      [req.userId, id]
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

apiRouter.put('/customers/:id', async (req, res) => {
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
       WHERE user_id = $11 AND id = $12`,
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
        req.userId,
        id,
      ]
    );
    if (rowCount === 0) {
      return res.status(404).json({ error: 'Zákazník nebol nájdený' });
    }
    const { rows } = await pool.query(
      'SELECT id, local_id, name, ico, email, address, city, postal_code, dic, ic_dph, default_vat_rate, is_active FROM customers WHERE user_id = $1 AND id = $2',
      [req.userId, id]
    );
    lastCustomersUpdatedAt = Date.now();
    res.json(rows[0]);
  } catch (err) {
    console.error('[PUT /api/customers/:id]', err.message);
    res.status(500).json({ error: 'Chyba servera' });
  }
});

// --- Kontrola zmien na webe (Flutter periodicky volá a zobrazí notifikáciu ak sa zmenilo) ---
apiRouter.get('/sync/check', (_req, res) => {
  res.json({
    customers_updated_at: lastCustomersUpdatedAt,
    last_sync_at: lastSyncAt,
  });
});

// --- API: Produkty (pre webové skenovanie a priradenie EAN) – per user ---
apiRouter.get('/products/by-barcode', async (req, res) => {
  if (!pool || !poolReady) {
    return res.status(503).json({ error: 'Databáza nie je k dispozícii' });
  }
  const code = (req.query.code ?? '').toString().trim();
  if (!code) {
    return res.status(400).json({ error: 'Parameter code je povinný' });
  }
  try {
    const { rows } = await pool.query(
      `SELECT unique_id, name, plu, ean, unit, SUM(qty)::int AS qty
       FROM products
       WHERE user_id = $1 AND ((ean IS NOT NULL AND ean = $2) OR plu = $2)
       GROUP BY unique_id, name, plu, ean, unit
       LIMIT 1`,
      [req.userId, code]
    );
    if (rows.length === 0) {
      return res.status(404).json({ error: 'Produkt nenájdený', code });
    }
    res.json(rows[0]);
  } catch (err) {
    console.error('[GET /api/products/by-barcode]', err.message);
    res.status(500).json({ error: 'Chyba servera' });
  }
});

apiRouter.get('/products', async (req, res) => {
  if (!pool || !poolReady) {
    return res.status(503).json({ error: 'Databáza nie je k dispozícii' });
  }
  const search = (req.query.search ?? '').toString().trim().toLowerCase();
  try {
    let query = `SELECT unique_id, name, plu, ean, unit, SUM(qty)::int AS qty
      FROM products WHERE user_id = $1 GROUP BY unique_id, name, plu, ean, unit`;
    const params = [req.userId];
    if (search) {
      params.push(`%${search}%`);
      query = `SELECT * FROM (${query}) AS agg
        WHERE LOWER(name) LIKE $2 OR plu LIKE $2 OR (ean IS NOT NULL AND LOWER(ean) LIKE $2)`;
    }
    query += ' ORDER BY name ASC LIMIT 200';
    const { rows } = await pool.query(query, params);
    res.json(rows);
  } catch (err) {
    console.error('[GET /api/products]', err.message);
    res.status(500).json({ error: 'Chyba servera' });
  }
});

apiRouter.get('/products/:uniqueId', async (req, res) => {
  if (!pool || !poolReady) {
    return res.status(503).json({ error: 'Databáza nie je k dispozícii' });
  }
  const uniqueId = (req.params.uniqueId ?? '').toString().trim();
  if (!uniqueId) {
    return res.status(400).json({ error: 'uniqueId je povinný' });
  }
  try {
    const { rows } = await pool.query(
      `SELECT unique_id, name, plu, ean, unit, SUM(qty)::int AS qty
       FROM products WHERE user_id = $1 AND unique_id = $2
       GROUP BY unique_id, name, plu, ean, unit`,
      [req.userId, uniqueId]
    );
    if (rows.length === 0) {
      return res.status(404).json({ error: 'Produkt nenájdený' });
    }
    res.json(rows[0]);
  } catch (err) {
    console.error('[GET /api/products/:uniqueId]', err.message);
    res.status(500).json({ error: 'Chyba servera' });
  }
});

apiRouter.patch('/products/:uniqueId', async (req, res) => {
  if (!pool || !poolReady) {
    return res.status(503).json({ error: 'Databáza nie je k dispozícii' });
  }
  const uniqueId = (req.params.uniqueId ?? '').toString().trim();
  if (!uniqueId) {
    return res.status(400).json({ error: 'uniqueId je povinný' });
  }
  const { ean } = req.body || {};
  const eanVal = ean != null ? String(ean).trim() || null : null;
  try {
    const { rowCount } = await pool.query(
      'UPDATE products SET ean = $1 WHERE user_id = $2 AND unique_id = $3',
      [eanVal, req.userId, uniqueId]
    );
    if (rowCount === 0) {
      return res.status(404).json({ error: 'Produkt nenájdený' });
    }
    const { rows } = await pool.query(
      'SELECT unique_id, name, plu, ean, unit, SUM(qty)::int AS qty FROM products WHERE user_id = $1 AND unique_id = $2 GROUP BY unique_id, name, plu, ean, unit',
      [req.userId, uniqueId]
    );
    res.json(rows[0] || { unique_id: uniqueId, ean: eanVal });
  } catch (err) {
    console.error('[PATCH /api/products/:uniqueId]', err.message);
    res.status(500).json({ error: 'Chyba servera' });
  }
});

// --- API: Výroba – šarže a palety – per user ---
apiRouter.get('/batches/sync', async (req, res) => {
  if (!pool || !poolReady) return res.status(503).json({ error: 'Databáza nie je k dispozícii' });
  const from = (req.query.from || '2020-01-01').toString().trim();
  const to = (req.query.to || '2099-12-31').toString().trim();
  try {
    const batchRows = await pool.query(
      `SELECT id, local_id, production_date, product_type, quantity_produced, notes, created_at, cost_total, revenue_total
       FROM production_batches WHERE user_id = $1 AND production_date >= $2 AND production_date <= $3 ORDER BY production_date DESC, created_at DESC`,
      [req.userId, from, to]
    );
    const batches = [];
    for (const b of batchRows.rows) {
      const batchId = b.id;
      const [recipeRes, palletRes] = await Promise.all([
        pool.query('SELECT id, batch_id, material_name, quantity, unit FROM production_batch_recipe WHERE batch_id = $1 ORDER BY id', [batchId]),
        pool.query('SELECT id, batch_id, product_type, quantity, customer_id, status, created_at FROM pallets WHERE batch_id = $1 ORDER BY id', [batchId]),
      ]);
      const productionDate = b.production_date instanceof Date ? b.production_date.toISOString().slice(0, 10) : b.production_date;
      batches.push({
        id: batchId,
        local_id: b.local_id != null ? Number(b.local_id) : null,
        production_date: productionDate,
        product_type: b.product_type,
        quantity_produced: Number(b.quantity_produced) || 0,
        notes: b.notes,
        created_at: b.created_at,
        cost_total: b.cost_total != null ? Number(b.cost_total) : null,
        revenue_total: b.revenue_total != null ? Number(b.revenue_total) : null,
        recipe: (recipeRes.rows || []).map((r) => ({ id: r.id, batch_id: r.batch_id, material_name: r.material_name, quantity: Number(r.quantity), unit: r.unit || 'kg' })),
        pallets: (palletRes.rows || []).map((p) => ({
          id: p.id,
          batch_id: p.batch_id,
          product_type: p.product_type,
          quantity: Number(p.quantity),
          customer_id: p.customer_id,
          status: p.status || 'Na sklade',
          created_at: p.created_at,
        })),
      });
    }
    res.json({ batches });
  } catch (err) {
    console.error('[GET /api/batches/sync]', err.message);
    res.status(500).json({ error: 'Chyba servera' });
  }
});

apiRouter.get('/batches', async (req, res) => {
  if (!pool || !poolReady) return res.status(503).json({ error: 'Databáza nie je k dispozícii' });
  const date = (req.query.date || '').toString().trim();
  const from = (req.query.from || '').toString().trim();
  const to = (req.query.to || '').toString().trim();
  const limit = Math.min(parseInt(req.query.limit, 10) || 0, 200);
  try {
    let query = 'SELECT id, local_id, production_date, product_type, quantity_produced, notes, created_at, cost_total, revenue_total FROM production_batches WHERE user_id = $1';
    const params = [req.userId];
    if (date) {
      query += ' AND production_date = $2';
      params.push(date);
    } else if (from && to) {
      query += ' AND production_date >= $2 AND production_date <= $3';
      params.push(from, to);
    }
    query += ' ORDER BY production_date DESC, created_at DESC';
    if (limit > 0) query += ` LIMIT ${limit}`;
    const { rows } = await pool.query(query, params);
    res.json(rows.map((r) => ({
      id: r.id,
      local_id: r.local_id != null ? Number(r.local_id) : null,
      production_date: r.production_date instanceof Date ? r.production_date.toISOString().slice(0, 10) : r.production_date,
      product_type: r.product_type,
      quantity_produced: Number(r.quantity_produced) || 0,
      notes: r.notes,
      created_at: r.created_at,
      cost_total: r.cost_total != null ? Number(r.cost_total) : null,
      revenue_total: r.revenue_total != null ? Number(r.revenue_total) : null,
    })));
  } catch (err) {
    console.error('[GET /api/batches]', err.message);
    res.status(500).json({ error: 'Chyba servera' });
  }
});

apiRouter.post('/batches', async (req, res) => {
  if (!pool || !poolReady) return res.status(503).json({ error: 'Databáza nie je k dispozícii' });
  const { production_date, product_type, quantity_produced, notes, cost_total, revenue_total, recipe } = req.body || {};
  const dateVal = (production_date || '').toString().trim();
  const typeVal = (product_type || '').toString().trim();
  if (!dateVal || !typeVal) {
    return res.status(400).json({ error: 'production_date a product_type sú povinné' });
  }
  const qty = parseInt(quantity_produced, 10) || 0;
  try {
    const { rows } = await pool.query(
      `INSERT INTO production_batches (user_id, production_date, product_type, quantity_produced, notes, cost_total, revenue_total)
       VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id, production_date, product_type, quantity_produced, notes, created_at, cost_total, revenue_total`,
      [
        req.userId,
        dateVal,
        typeVal,
        qty,
        notes != null ? String(notes).trim() || null : null,
        cost_total != null ? parseFloat(cost_total) : null,
        revenue_total != null ? parseFloat(revenue_total) : null,
      ]
    );
    const batch = rows[0];
    const batchId = batch.id;
    const recipeList = Array.isArray(recipe) ? recipe : [];
    for (const item of recipeList) {
      const q = parseFloat(item.quantity) || 0;
      if (q <= 0) continue;
      const matName = (item.material_name || '').toString().trim() || 'Materiál';
      const unit = (item.unit || 'kg').toString().trim();
      await pool.query(
        'INSERT INTO production_batch_recipe (batch_id, material_name, quantity, unit) VALUES ($1, $2, $3, $4)',
        [batchId, matName, q, unit]
      );
    }
    res.status(201).json({
      id: batchId,
      production_date: batch.production_date instanceof Date ? batch.production_date.toISOString().slice(0, 10) : batch.production_date,
      product_type: batch.product_type,
      quantity_produced: Number(batch.quantity_produced) || 0,
      notes: batch.notes,
      created_at: batch.created_at,
      cost_total: batch.cost_total != null ? Number(batch.cost_total) : null,
      revenue_total: batch.revenue_total != null ? Number(batch.revenue_total) : null,
    });
  } catch (err) {
    console.error('[POST /api/batches]', err.message);
    res.status(500).json({ error: 'Chyba servera' });
  }
});

apiRouter.get('/batches/by-local/:localId', async (req, res) => {
  if (!pool || !poolReady) return res.status(503).json({ error: 'Databáza nie je k dispozícii' });
  const localId = parseInt(req.params.localId, 10);
  if (Number.isNaN(localId)) return res.status(400).json({ error: 'Neplatné localId' });
  try {
    const { rows } = await pool.query(
      'SELECT id, production_date, product_type, quantity_produced, notes, created_at, cost_total, revenue_total FROM production_batches WHERE user_id = $1 AND local_id = $2',
      [req.userId, localId]
    );
    if (rows.length === 0) return res.status(404).json({ error: 'Šarža nebola nájdená' });
    const r = rows[0];
    res.json({
      id: r.id,
      production_date: r.production_date instanceof Date ? r.production_date.toISOString().slice(0, 10) : r.production_date,
      product_type: r.product_type,
      quantity_produced: Number(r.quantity_produced) || 0,
      notes: r.notes,
      created_at: r.created_at,
      cost_total: r.cost_total != null ? Number(r.cost_total) : null,
      revenue_total: r.revenue_total != null ? Number(r.revenue_total) : null,
    });
  } catch (err) {
    console.error('[GET /api/batches/by-local/:localId]', err.message);
    res.status(500).json({ error: 'Chyba servera' });
  }
});

apiRouter.get('/batches/:id', async (req, res) => {
  if (!pool || !poolReady) return res.status(503).json({ error: 'Databáza nie je k dispozícii' });
  const id = parseInt(req.params.id, 10);
  if (Number.isNaN(id)) return res.status(400).json({ error: 'Neplatné id' });
  try {
    const { rows } = await pool.query(
      'SELECT id, production_date, product_type, quantity_produced, notes, created_at, cost_total, revenue_total FROM production_batches WHERE user_id = $1 AND id = $2',
      [req.userId, id]
    );
    if (rows.length === 0) return res.status(404).json({ error: 'Šarža nebola nájdená' });
    const r = rows[0];
    res.json({
      id: r.id,
      production_date: r.production_date instanceof Date ? r.production_date.toISOString().slice(0, 10) : r.production_date,
      product_type: r.product_type,
      quantity_produced: Number(r.quantity_produced) || 0,
      notes: r.notes,
      created_at: r.created_at,
      cost_total: r.cost_total != null ? Number(r.cost_total) : null,
      revenue_total: r.revenue_total != null ? Number(r.revenue_total) : null,
    });
  } catch (err) {
    console.error('[GET /api/batches/:id]', err.message);
    res.status(500).json({ error: 'Chyba servera' });
  }
});

apiRouter.get('/batches/:id/recipe', async (req, res) => {
  if (!pool || !poolReady) return res.status(503).json({ error: 'Databáza nie je k dispozícii' });
  const id = parseInt(req.params.id, 10);
  if (Number.isNaN(id)) return res.status(400).json({ error: 'Neplatné id' });
  try {
    const { rows } = await pool.query(
      'SELECT r.id, r.batch_id, r.material_name, r.quantity, r.unit FROM production_batch_recipe r INNER JOIN production_batches b ON b.id = r.batch_id WHERE b.user_id = $1 AND r.batch_id = $2 ORDER BY r.id ASC',
      [req.userId, id]
    );
    res.json(rows.map((r) => ({ id: r.id, batch_id: r.batch_id, material_name: r.material_name, quantity: Number(r.quantity), unit: r.unit || 'kg' })));
  } catch (err) {
    console.error('[GET /api/batches/:id/recipe]', err.message);
    res.status(500).json({ error: 'Chyba servera' });
  }
});

apiRouter.get('/batches/:id/pallets', async (req, res) => {
  if (!pool || !poolReady) return res.status(503).json({ error: 'Databáza nie je k dispozícii' });
  const id = parseInt(req.params.id, 10);
  if (Number.isNaN(id)) return res.status(400).json({ error: 'Neplatné id' });
  try {
    const { rows } = await pool.query(
      'SELECT id, batch_id, product_type, quantity, customer_id, status, created_at FROM pallets WHERE user_id = $1 AND batch_id = $2 ORDER BY id ASC',
      [req.userId, id]
    );
    res.json(
      rows.map((r) => ({
        id: r.id,
        batch_id: r.batch_id,
        product_type: r.product_type,
        quantity: Number(r.quantity),
        customer_id: r.customer_id,
        status: r.status || 'Na sklade',
        created_at: r.created_at,
      }))
    );
  } catch (err) {
    console.error('[GET /api/batches/:id/pallets]', err.message);
    res.status(500).json({ error: 'Chyba servera' });
  }
});

apiRouter.post('/batches/:id/pallets', async (req, res) => {
  if (!pool || !poolReady) return res.status(503).json({ error: 'Databáza nie je k dispozícii' });
  const batchId = parseInt(req.params.id, 10);
  if (Number.isNaN(batchId)) return res.status(400).json({ error: 'Neplatné id šarže' });
  const { pieces_per_pallet: qtyPerPallet, count: palletCount } = req.body || {};
  const qty = parseInt(qtyPerPallet, 10) || 0;
  const count = parseInt(palletCount, 10) || 0;
  if (qty <= 0 || count <= 0) {
    return res.status(400).json({ error: 'pieces_per_pallet a count musia byť kladné čísla' });
  }
  try {
    const batchRes = await pool.query(
      'SELECT id, product_type, quantity_produced FROM production_batches WHERE user_id = $1 AND id = $2',
      [req.userId, batchId]
    );
    if (batchRes.rows.length === 0) return res.status(404).json({ error: 'Šarža nebola nájdená' });
    const batch = batchRes.rows[0];
    const total = qty * count;
    if (total > Number(batch.quantity_produced)) {
      return res.status(400).json({ error: `Celkom ${total} kusov prevyšuje počet vyrobených (${batch.quantity_produced}).` });
    }
    const created = [];
    for (let i = 0; i < count; i++) {
      const { rows } = await pool.query(
        `INSERT INTO pallets (user_id, batch_id, product_type, quantity, status) VALUES ($1, $2, $3, $4, 'Na sklade') RETURNING id, batch_id, product_type, quantity, status, created_at`,
        [req.userId, batchId, batch.product_type, qty]
      );
      if (rows[0]) created.push(rows[0]);
    }
    res.status(201).json(
      created.map((r) => ({
        id: r.id,
        batch_id: r.batch_id,
        product_type: r.product_type,
        quantity: Number(r.quantity),
        customer_id: null,
        status: r.status || 'Na sklade',
        created_at: r.created_at,
      }))
    );
  } catch (err) {
    console.error('[POST /api/batches/:id/pallets]', err.message);
    res.status(500).json({ error: 'Chyba servera' });
  }
});

apiRouter.get('/pallets/by-local/:localId', async (req, res) => {
  if (!pool || !poolReady) return res.status(503).json({ error: 'Databáza nie je k dispozícii' });
  const localId = parseInt(req.params.localId, 10);
  if (Number.isNaN(localId)) return res.status(400).json({ error: 'Neplatné localId' });
  try {
    const { rows } = await pool.query(
      'SELECT id, batch_id, product_type, quantity, customer_id, status, created_at FROM pallets WHERE user_id = $1 AND local_id = $2',
      [req.userId, localId]
    );
    if (rows.length === 0) return res.status(404).json({ error: 'Paleta nebola nájdená' });
    const r = rows[0];
    res.json({
      id: r.id,
      batch_id: r.batch_id,
      product_type: r.product_type,
      quantity: Number(r.quantity),
      customer_id: r.customer_id,
      status: r.status || 'Na sklade',
      created_at: r.created_at,
    });
  } catch (err) {
    console.error('[GET /api/pallets/by-local/:localId]', err.message);
    res.status(500).json({ error: 'Chyba servera' });
  }
});

apiRouter.get('/pallets/:id', async (req, res) => {
  if (!pool || !poolReady) return res.status(503).json({ error: 'Databáza nie je k dispozícii' });
  const id = parseInt(req.params.id, 10);
  if (Number.isNaN(id)) return res.status(400).json({ error: 'Neplatné id' });
  try {
    const { rows } = await pool.query(
      'SELECT id, batch_id, product_type, quantity, customer_id, status, created_at FROM pallets WHERE user_id = $1 AND id = $2',
      [req.userId, id]
    );
    if (rows.length === 0) return res.status(404).json({ error: 'Paleta nebola nájdená' });
    const r = rows[0];
    res.json({
      id: r.id,
      batch_id: r.batch_id,
      product_type: r.product_type,
      quantity: Number(r.quantity),
      customer_id: r.customer_id,
      status: r.status || 'Na sklade',
      created_at: r.created_at,
    });
  } catch (err) {
    console.error('[GET /api/pallets/:id]', err.message);
    res.status(500).json({ error: 'Chyba servera' });
  }
});

apiRouter.put('/pallets/:id/assign', async (req, res) => {
  if (!pool || !poolReady) return res.status(503).json({ error: 'Databáza nie je k dispozícii' });
  const palletId = parseInt(req.params.id, 10);
  const customerId = parseInt(req.body?.customer_id, 10);
  if (Number.isNaN(palletId) || Number.isNaN(customerId)) {
    return res.status(400).json({ error: 'customer_id je povinný' });
  }
  try {
    const palletRes = await pool.query('SELECT id, status FROM pallets WHERE user_id = $1 AND id = $2', [req.userId, palletId]);
    if (palletRes.rows.length === 0) return res.status(404).json({ error: 'Paleta nebola nájdená' });
    if (palletRes.rows[0].status === 'U zákazníka') {
      return res.status(400).json({ error: 'Paleta je už priradená zákazníkovi' });
    }
    const custRes = await pool.query('SELECT id, pallet_balance FROM customers WHERE user_id = $1 AND id = $2', [req.userId, customerId]);
    if (custRes.rows.length === 0) return res.status(404).json({ error: 'Zákazník nebol nájdený' });
    await pool.query("UPDATE pallets SET customer_id = $1, status = 'U zákazníka' WHERE user_id = $2 AND id = $3", [customerId, req.userId, palletId]);
    const newBalance = (Number(custRes.rows[0].pallet_balance) || 0) + 1;
    await pool.query('UPDATE customers SET pallet_balance = $1 WHERE user_id = $2 AND id = $3', [newBalance, req.userId, customerId]);
    res.json({ success: true, message: 'Paleta priradená zákazníkovi' });
  } catch (err) {
    console.error('[PUT /api/pallets/:id/assign]', err.message);
    res.status(500).json({ error: 'Chyba servera' });
  }
});

// --- API: Dashboard štatistiky – per user ---
apiRouter.get('/dashboard/stats', async (req, res) => {
  if (!pool || !poolReady) {
    return res.status(503).json({ error: 'Databáza nie je k dispozícii' });
  }
  try {
    let customers = 0;
    let products = 0;
    let lowStockCount = 0;
    try {
      const r = await pool.query('SELECT COUNT(*)::int AS count FROM customers WHERE user_id = $1', [req.userId]);
      customers = r.rows[0]?.count ?? 0;
    } catch (_) {}
    try {
      const r = await pool.query('SELECT COUNT(DISTINCT unique_id)::int AS count FROM products WHERE user_id = $1', [req.userId]);
      products = r.rows[0]?.count ?? 0;
    } catch (_) {}
    try {
      const r = await pool.query(
        `SELECT COUNT(*)::int AS count FROM (
          SELECT unique_id FROM products WHERE user_id = $1 GROUP BY unique_id HAVING SUM(qty) < 5
        ) AS low`,
        [req.userId]
      );
      lowStockCount = r.rows[0]?.count ?? 0;
    } catch (_) {}
    const stats = {
      products_count: products,
      products: products,
      customers_count: customers,
      customers: customers,
      total_sales: 0,
      revenue: 0,
      low_stock_count: lowStockCount,
      products_trend_week: 0,
      customers_trend_week: 0,
      sales_trend_week: 0,
      last_sync_at: lastSyncAt,
      orders: 0,
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

// --- Admin: manuálne priradenie záznamov používateľovi (ak bolo viac používateľov pred migráciou) ---
apiRouter.post('/admin/migrate-user-data', async (req, res) => {
  if (req.userRole !== 'admin') {
    return res.status(403).json({ error: 'Len administrátor.' });
  }
  const { recordType, recordIds, targetUserId, markComplete } = req.body || {};
  if (!recordType || !Array.isArray(recordIds) || recordIds.length === 0 || !targetUserId) {
    return res.status(400).json({ error: 'recordType, recordIds (pole), targetUserId sú povinné' });
  }
  const doMarkComplete = markComplete === true;
  const targetId = parseInt(targetUserId, 10);
  if (Number.isNaN(targetId) || targetId < 1) {
    return res.status(400).json({ error: 'Neplatné targetUserId' });
  }
  const tables = { customers: 'customers', products: 'products', production_batches: 'production_batches', pallets: 'pallets', stocks: 'stocks' };
  const table = tables[recordType];
  if (!table) {
    return res.status(400).json({ error: 'recordType musí byť: customers, products, production_batches, pallets, stocks' });
  }
  try {
    const ids = recordIds.map((id) => parseInt(id, 10)).filter((id) => !Number.isNaN(id) && id > 0);
    if (ids.length === 0) return res.status(400).json({ error: 'Žiadne platné recordIds' });
    const placeholders = ids.map((_, i) => `$${i + 2}`).join(',');
    const q = `UPDATE ${table} SET user_id = $1 WHERE id IN (${placeholders})`;
    await pool.query(q, [targetId, ...ids]);
    if (doMarkComplete) {
      await pool.query("UPDATE app_settings SET value = 'true' WHERE key = 'data_isolation_migrated'");
      dataIsolationMigrated = true;
      console.log('[admin] data_isolation_migrated set to true');
    }
    res.json({ success: true, updated: ids.length });
  } catch (err) {
    console.error('[admin/migrate-user-data]', err.message);
    res.status(500).json({ error: err.message });
  }
});

// Montovanie API routera pod tajný prefix – bez znalosti cesty /api/:prefix/ sa nikto nedostane k dátam
app.use(`/api/${API_PATH_PREFIX}`, apiRouter);

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
      try {
        const r = await pool.query("SELECT value FROM app_settings WHERE key = 'data_isolation_migrated'");
        dataIsolationMigrated = r.rows[0]?.value === 'true';
        if (!dataIsolationMigrated) console.warn('[start] data_isolation_migrated = false – manuálna migrácia môže byť potrebná');
      } catch (_) {
        dataIsolationMigrated = true;
      }
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
