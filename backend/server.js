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
const { syncWarehouses } = require('./DBsync/sync/warehouseSync');
const { syncSuppliers } = require('./DBsync/sync/supplierSync');
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
  : ['https://app.stockpilot.sk'];
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

// Pre sub-userov: req.dataUserId = owner_id (admin), aby API vracalo dáta nadriadeného. Inak req.dataUserId = req.userId.
apiRouter.use(async (req, res, next) => {
  if (!req.userId || !pool || !poolReady) {
    req.dataUserId = req.userId;
    return next();
  }
  try {
    const { rows } = await pool.query('SELECT owner_id FROM users WHERE id = $1', [req.userId]);
    const ownerId = rows[0]?.owner_id;
    req.dataUserId = ownerId != null ? ownerId : req.userId;
  } catch (_) {
    req.dataUserId = req.userId;
  }
  next();
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
    let ownerInfo = null;
    const {
      rows: [user],
    } = await pool.query(
      'SELECT id, username, password, full_name, role, email, phone, department, avatar_url, join_date, COALESCE(is_blocked, false) AS is_blocked, COALESCE(web_access, false) AS web_access, owner_id, tier_valid_until FROM users WHERE username = $1',
      [username.toString().trim()]
    );
    if (!user || user.password !== password) {
      console.warn('[auth] Failed login attempt for username:', username);
      return res.status(401).json({
        success: false,
        error: 'Nesprávny login alebo heslo',
      });
    }
    if (user.is_blocked) {
      console.warn('[auth] Blocked user tried to login:', username);
      return res.status(403).json({
        success: false,
        error: 'Účet je zablokovaný. Kontaktujte administrátora.',
      });
    }
    // db_owner má vždy prístup
    if (user.role !== 'db_owner') {
      // Sub-user (kolega) nemusí mať web_access – potrebuje token na sync v apke (dáta nadriadeného).
      // Admin a standalone user potrebujú web_access na prihlásenie na web.
      if (!user.owner_id && !user.web_access) {
        console.warn('[auth] User without web_access tried to login:', username);
        return res.status(403).json({
          success: false,
          error: 'Prístup na web nie je povolený. Kontaktujte administrátora.',
        });
      }
      // Admin: platnosť tiera – ak je tier_valid_until v minulosti, prístup zamietnutý
      if (user.role === 'admin' && user.tier_valid_until) {
        const today = new Date().toISOString().slice(0, 10);
        if (user.tier_valid_until < today) {
          console.warn('[auth] Admin login blocked – tier expired:', username);
          return res.status(403).json({
            success: false,
            error: 'Platnosť vášho plánu vypršala. Kontaktujte administrátora.',
          });
        }
      }
      // Sub-user: skontroluj web_access a tier_valid_until jeho admina (owner)
      if (user.owner_id) {
        const { rows: [owner] } = await pool.query(
          'SELECT id, username, full_name, web_access, tier_valid_until FROM users WHERE id = $1',
          [user.owner_id]
        );
        if (!owner || !owner.web_access) {
          console.warn('[auth] Sub-user login blocked – owner has no web_access:', username);
          return res.status(403).json({
            success: false,
            error: 'Prístup na web nie je povolený. Kontaktujte administrátora.',
          });
        }
        if (owner.tier_valid_until) {
          const today = new Date().toISOString().slice(0, 10);
          if (owner.tier_valid_until < today) {
            console.warn('[auth] Sub-user login blocked – owner tier expired:', username);
            return res.status(403).json({
              success: false,
              error: 'Platnosť plánu vášho administrátora vypršala. Kontaktujte ho.',
            });
          }
        }
        // Informácie o nadriadenom – použijeme v odpovedi /auth/login pre zobrazenie v apke.
        ownerInfo = {
          id: owner.id,
          username: owner.username,
          fullName: owner.full_name || owner.username,
        };
      }
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
        ownerId: ownerInfo ? ownerInfo.id : null,
        ownerUsername: ownerInfo ? ownerInfo.username : null,
        ownerFullName: ownerInfo ? ownerInfo.fullName : null,
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
// Ak Flutter pošle Authorization (admin token) a synced user má role=user, nastaví sa owner_id → zobrazí sa v "Moji kolegovia".
apiRouter.post('/auth/sync-user', async (req, res) => {
  if (!pool || !poolReady) {
    return res.status(503).json({ success: false, error: 'Databáza nie je k dispozícii' });
  }
  let ownerId = null;
  const authHeader = req.headers['authorization'];
  if (authHeader && typeof authHeader === 'string' && authHeader.trim().startsWith('Bearer ')) {
    const token = authHeader.trim().slice(7).trim();
    const decoded = verifyAccessToken(token);
    if (decoded && decoded.userId && (decoded.role === 'admin' || decoded.role === 'db_owner')) {
      ownerId = decoded.userId;
    }
  }
  const result = await syncUser(pool, req.body, ownerId);
  if (!result.ok) {
    const status = result.error === 'username je povinný' ? 400 : 500;
    return res.status(status).json({ success: false, error: result.error || 'Chyba servera' });
  }
  console.log('[auth] Sync user OK:', req.body?.username, ownerId ? `(owner_id=${ownerId})` : '');
  res.status(200).json({ success: true, message: 'Používateľ zosynchronizovaný' });
});

// --- API: Stocks (PostgreSQL) – per user ---
apiRouter.get('/stocks', async (req, res) => {
  if (!pool || !poolReady) {
    console.error('[GET /api/stocks] Database not available');
    return res.status(503).json({ error: 'Database not configured or unavailable' });
  }
  try {
    const dataUserId = req.dataUserId ?? req.userId;
    const { rows } = await pool.query(
      'SELECT id, symbol, price, created_at FROM stocks WHERE user_id = $1 ORDER BY created_at DESC',
      [dataUserId]
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
    const dataUserId = req.dataUserId ?? req.userId;
    const {
      rows: [row],
    } = await pool.query(
      'INSERT INTO stocks (user_id, symbol, price) VALUES ($1, $2, $3) RETURNING id, symbol, price, created_at',
      [dataUserId, symbol.toString().trim(), priceNum]
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
  const result = await syncProducts(pool, req.body, req.dataUserId ?? req.userId);
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
  const result = await syncCustomers(pool, req.body, req.dataUserId ?? req.userId);
  if (!result.ok) {
    return res.status(500).json({ success: false, error: result.error || 'Chyba servera' });
  }
  lastCustomersUpdatedAt = Date.now();
  lastSyncAt = Date.now();
  console.log('[sync] Customers OK:', result.count);
  res.status(200).json({ success: true, count: result.count });
});

// --- Sync skladov z Flutter do PostgreSQL – per user ---
apiRouter.post('/sync/warehouses', async (req, res) => {
  if (!pool || !poolReady) {
    return res.status(503).json({ success: false, error: 'Databáza nie je k dispozícii' });
  }
  const result = await syncWarehouses(pool, req.body, req.dataUserId ?? req.userId);
  if (!result.ok) {
    return res.status(500).json({ success: false, error: result.error || 'Chyba servera' });
  }
  lastSyncAt = Date.now();
  res.status(200).json({ success: true, count: result.count ?? 0 });
});

// --- Sync dodávateľov z Flutter do PostgreSQL – per user ---
apiRouter.post('/sync/suppliers', async (req, res) => {
  if (!pool || !poolReady) {
    return res.status(503).json({ success: false, error: 'Databáza nie je k dispozícii' });
  }
  const result = await syncSuppliers(pool, req.body, req.dataUserId ?? req.userId);
  if (!result.ok) {
    return res.status(500).json({ success: false, error: result.error || 'Chyba servera' });
  }
  lastSyncAt = Date.now();
  res.status(200).json({ success: true, count: result.count ?? 0 });
});

// --- Sync šarží a paliet z Flutter do PostgreSQL – per user ---
apiRouter.post('/sync/batches', async (req, res) => {
  if (!pool || !poolReady) {
    return res.status(503).json({ success: false, error: 'Databáza nie je k dispozícii' });
  }
  const userId = req.dataUserId ?? req.userId;
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
    const dataUserId = req.dataUserId ?? req.userId;
    const { rows } = await pool.query(
      `SELECT id, local_id, name, ico, email, address, city, postal_code, dic, ic_dph, default_vat_rate, is_active
       FROM customers WHERE user_id = $1 ORDER BY name ASC`,
      [dataUserId]
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
    const dataUserId = req.dataUserId ?? req.userId;
    const { rows } = await pool.query(
      `SELECT id, local_id, name, ico, email, address, city, postal_code, dic, ic_dph, default_vat_rate, is_active
       FROM customers WHERE user_id = $1 AND id = $2`,
      [dataUserId, id]
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
        req.dataUserId ?? req.userId,
        id,
      ]
    );
    if (rowCount === 0) {
      return res.status(404).json({ error: 'Zákazník nebol nájdený' });
    }
    const dataUserId = req.dataUserId ?? req.userId;
    const { rows } = await pool.query(
      'SELECT id, local_id, name, ico, email, address, city, postal_code, dic, ic_dph, default_vat_rate, is_active FROM customers WHERE user_id = $1 AND id = $2',
      [dataUserId, id]
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
    const dataUserId = req.dataUserId ?? req.userId;
    const { rows } = await pool.query(
      `SELECT unique_id, name, plu, ean, unit, SUM(qty)::int AS qty
       FROM products
       WHERE user_id = $1 AND ((ean IS NOT NULL AND ean = $2) OR plu = $2)
       GROUP BY unique_id, name, plu, ean, unit
       LIMIT 1`,
      [dataUserId, code]
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
    const dataUserId = req.dataUserId ?? req.userId;
    let query = `SELECT unique_id, name, plu, ean, unit, SUM(qty)::int AS qty
      FROM products WHERE user_id = $1 GROUP BY unique_id, name, plu, ean, unit`;
    const params = [dataUserId];
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
    const dataUserId = req.dataUserId ?? req.userId;
    const { rows } = await pool.query(
      `SELECT unique_id, name, plu, ean, unit, SUM(qty)::int AS qty
       FROM products WHERE user_id = $1 AND unique_id = $2
       GROUP BY unique_id, name, plu, ean, unit`,
      [dataUserId, uniqueId]
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
    const dataUserId = req.dataUserId ?? req.userId;
    const { rowCount } = await pool.query(
      'UPDATE products SET ean = $1 WHERE user_id = $2 AND unique_id = $3',
      [eanVal, dataUserId, uniqueId]
    );
    if (rowCount === 0) {
      return res.status(404).json({ error: 'Produkt nenájdený' });
    }
    const { rows } = await pool.query(
      'SELECT unique_id, name, plu, ean, unit, SUM(qty)::int AS qty FROM products WHERE user_id = $1 AND unique_id = $2 GROUP BY unique_id, name, plu, ean, unit',
      [dataUserId, uniqueId]
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
    const dataUserId = req.dataUserId ?? req.userId;
    const batchRows = await pool.query(
      `SELECT id, local_id, production_date, product_type, quantity_produced, notes, created_at, cost_total, revenue_total
       FROM production_batches WHERE user_id = $1 AND production_date >= $2 AND production_date <= $3 ORDER BY production_date DESC, created_at DESC`,
      [dataUserId, from, to]
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
    const dataUserId = req.dataUserId ?? req.userId;
    let query = 'SELECT id, local_id, production_date, product_type, quantity_produced, notes, created_at, cost_total, revenue_total FROM production_batches WHERE user_id = $1';
    const params = [dataUserId];
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
    const dataUserId = req.dataUserId ?? req.userId;
    const { rows } = await pool.query(
      `INSERT INTO production_batches (user_id, production_date, product_type, quantity_produced, notes, cost_total, revenue_total)
       VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id, production_date, product_type, quantity_produced, notes, created_at, cost_total, revenue_total`,
      [
        dataUserId,
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
    const dataUserId = req.dataUserId ?? req.userId;
    const { rows } = await pool.query(
      'SELECT id, production_date, product_type, quantity_produced, notes, created_at, cost_total, revenue_total FROM production_batches WHERE user_id = $1 AND local_id = $2',
      [dataUserId, localId]
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
    const dataUserId = req.dataUserId ?? req.userId;
    const { rows } = await pool.query(
      'SELECT id, production_date, product_type, quantity_produced, notes, created_at, cost_total, revenue_total FROM production_batches WHERE user_id = $1 AND id = $2',
      [dataUserId, id]
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
    const dataUserId = req.dataUserId ?? req.userId;
    const { rows } = await pool.query(
      'SELECT r.id, r.batch_id, r.material_name, r.quantity, r.unit FROM production_batch_recipe r INNER JOIN production_batches b ON b.id = r.batch_id WHERE b.user_id = $1 AND r.batch_id = $2 ORDER BY r.id ASC',
      [dataUserId, id]
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
    const dataUserId = req.dataUserId ?? req.userId;
    const { rows } = await pool.query(
      'SELECT id, batch_id, product_type, quantity, customer_id, status, created_at FROM pallets WHERE user_id = $1 AND batch_id = $2 ORDER BY id ASC',
      [dataUserId, id]
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
    const dataUserId = req.dataUserId ?? req.userId;
    const batchRes = await pool.query(
      'SELECT id, product_type, quantity_produced FROM production_batches WHERE user_id = $1 AND id = $2',
      [dataUserId, batchId]
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
        [dataUserId, batchId, batch.product_type, qty]
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
    const dataUserId = req.dataUserId ?? req.userId;
    const { rows } = await pool.query(
      'SELECT id, batch_id, product_type, quantity, customer_id, status, created_at FROM pallets WHERE user_id = $1 AND local_id = $2',
      [dataUserId, localId]
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
    const dataUserId = req.dataUserId ?? req.userId;
    const { rows } = await pool.query(
      'SELECT id, batch_id, product_type, quantity, customer_id, status, created_at FROM pallets WHERE user_id = $1 AND id = $2',
      [dataUserId, id]
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
    const dataUserId = req.dataUserId ?? req.userId;
    const palletRes = await pool.query('SELECT id, status FROM pallets WHERE user_id = $1 AND id = $2', [dataUserId, palletId]);
    if (palletRes.rows.length === 0) return res.status(404).json({ error: 'Paleta nebola nájdená' });
    if (palletRes.rows[0].status === 'U zákazníka') {
      return res.status(400).json({ error: 'Paleta je už priradená zákazníkovi' });
    }
    const custRes = await pool.query('SELECT id, pallet_balance FROM customers WHERE user_id = $1 AND id = $2', [dataUserId, customerId]);
    if (custRes.rows.length === 0) return res.status(404).json({ error: 'Zákazník nebol nájdený' });
    await pool.query("UPDATE pallets SET customer_id = $1, status = 'U zákazníka' WHERE user_id = $2 AND id = $3", [customerId, dataUserId, palletId]);
    const newBalance = (Number(custRes.rows[0].pallet_balance) || 0) + 1;
    await pool.query('UPDATE customers SET pallet_balance = $1 WHERE user_id = $2 AND id = $3', [newBalance, dataUserId, customerId]);
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
    const dataUserId = req.dataUserId ?? req.userId;
    let customers = 0;
    let products = 0;
    let lowStockCount = 0;
    try {
      const r = await pool.query('SELECT COUNT(*)::int AS count FROM customers WHERE user_id = $1', [dataUserId]);
      customers = r.rows[0]?.count ?? 0;
    } catch (_) {}
    try {
      const r = await pool.query('SELECT COUNT(DISTINCT unique_id)::int AS count FROM products WHERE user_id = $1', [dataUserId]);
      products = r.rows[0]?.count ?? 0;
    } catch (_) {}
    try {
      const r = await pool.query(
        `SELECT COUNT(*)::int AS count FROM (
          SELECT unique_id FROM products WHERE user_id = $1 GROUP BY unique_id HAVING SUM(qty) < 5
        ) AS low`,
        [dataUserId]
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

// --- API: Sklady (warehouses) – per user ---
apiRouter.get('/warehouses', async (req, res) => {
  if (!pool || !poolReady) return res.status(503).json({ error: 'Databáza nie je k dispozícii' });
  try {
    const dataUserId = req.dataUserId ?? req.userId;
    const { rows } = await pool.query(
      `SELECT id, name, code, warehouse_type, address, city, postal_code, is_active
       FROM warehouses WHERE user_id = $1 ORDER BY name`,
      [dataUserId]
    );
    res.json(rows.map((r) => ({
      id: r.id,
      name: r.name,
      code: r.code || '',
      warehouse_type: r.warehouse_type || 'Predaj',
      address: r.address,
      city: r.city,
      postal_code: r.postal_code,
      is_active: (r.is_active ?? 1) !== 0,
    })));
  } catch (err) {
    if (err.message?.includes('relation "warehouses" does not exist')) return res.json([]);
    console.error('[GET /api/warehouses]', err.message);
    res.status(500).json({ error: 'Chyba servera' });
  }
});

// --- API: Dodávatelia (suppliers) – per user ---
apiRouter.get('/suppliers', async (req, res) => {
  if (!pool || !poolReady) return res.status(503).json({ error: 'Databáza nie je k dispozícii' });
  try {
    const dataUserId = req.dataUserId ?? req.userId;
    const { rows } = await pool.query(
      `SELECT id, name, ico, email, address, city, postal_code, dic, ic_dph, default_vat_rate, is_active
       FROM suppliers WHERE user_id = $1 ORDER BY name`,
      [dataUserId]
    );
    res.json(rows.map((r) => ({
      id: r.id,
      name: r.name,
      ico: r.ico || '',
      email: r.email,
      address: r.address,
      city: r.city,
      postal_code: r.postal_code,
      dic: r.dic,
      ic_dph: r.ic_dph,
      default_vat_rate: r.default_vat_rate ?? 20,
      is_active: (r.is_active ?? 1) !== 0,
    })));
  } catch (err) {
    if (err.message?.includes('relation "suppliers" does not exist')) return res.json([]);
    console.error('[GET /api/suppliers]', err.message);
    res.status(500).json({ error: 'Chyba servera' });
  }
});

// --- Admin: správa používateľov ---
const TIER_LIMITS = { free: 0, basic: 2, pro: 5, enterprise: -1 };

const requireAdmin = (req, res, next) => {
  if (req.userRole !== 'admin' && req.userRole !== 'db_owner') {
    return res.status(403).json({ error: 'Len administrátor.' });
  }
  next();
};

const requireDbOwner = (req, res, next) => {
  if (req.userRole !== 'db_owner') {
    return res.status(403).json({ error: 'Len DB_OWNER.' });
  }
  next();
};

// DB_OWNER: štatistiky – počet používateľov, tieri, registrácie, platnosti
apiRouter.get('/admin/stats', requireDbOwner, async (req, res) => {
  if (!pool || !poolReady) return res.status(503).json({ error: 'Databáza nie je k dispozícii' });
  try {
    const today = new Date().toISOString().slice(0, 10);
    const { rows: totalRows } = await pool.query(
      `SELECT
         (SELECT COUNT(*)::int FROM users WHERE role = 'admin') AS admins_count,
         (SELECT COUNT(*)::int FROM users WHERE role = 'user' AND owner_id IS NOT NULL) AS sub_users_count,
         (SELECT COUNT(*)::int FROM users WHERE role IN ('admin','user')) AS total_users_count`
    );
    const { rows: byTier } = await pool.query(
      `SELECT COALESCE(tier, 'free') AS tier, COUNT(*)::int AS cnt
       FROM users WHERE role = 'admin' GROUP BY tier`
    );
    const tierCounts = { free: 0, basic: 0, pro: 0, enterprise: 0 };
    byTier.forEach((r) => { tierCounts[r.tier] = r.cnt; });

    const { rows: adminsList } = await pool.query(
      `SELECT u.id, u.username, u.full_name, COALESCE(u.tier, 'free') AS tier,
              u.join_date, u.tier_valid_until, COALESCE(u.web_access, false) AS web_access,
              COUNT(s.id)::int AS sub_user_count
       FROM users u
       LEFT JOIN users s ON s.owner_id = u.id
       WHERE u.role = 'admin'
       GROUP BY u.id ORDER BY u.join_date DESC`
    );
    const admins = adminsList.map((a) => ({
      id: a.id,
      username: a.username,
      full_name: a.full_name,
      tier: a.tier,
      join_date: a.join_date,
      tier_valid_until: a.tier_valid_until ? a.tier_valid_until.toISOString?.()?.slice(0, 10) : null,
      web_access: !!a.web_access,
      sub_user_count: a.sub_user_count,
      is_expired: a.tier_valid_until ? a.tier_valid_until < today : false,
    }));

    const expiredCount = admins.filter((a) => a.is_expired).length;
    const activeCount = admins.length - expiredCount;

    res.json({
      admins_count: totalRows[0]?.admins_count ?? 0,
      sub_users_count: totalRows[0]?.sub_users_count ?? 0,
      total_users_count: totalRows[0]?.total_users_count ?? 0,
      by_tier: tierCounts,
      admins_active: activeCount,
      admins_expired: expiredCount,
      admins,
    });
  } catch (err) {
    console.error('[GET /admin/stats]', err.message);
    res.status(500).json({ error: 'Chyba servera' });
  }
});

apiRouter.get('/admin/users', requireAdmin, async (req, res) => {
  if (!pool || !poolReady) return res.status(503).json({ error: 'Databáza nie je k dispozícii' });
  try {
    if (req.userRole === 'db_owner') {
      // DB_OWNER vidí všetkých adminov + ich počet sub-userov + platnosť tiera
      const { rows } = await pool.query(
        `SELECT u.id, u.username, u.full_name, u.email,
                COALESCE(u.is_blocked, false) AS is_blocked,
                COALESCE(u.web_access, false) AS web_access,
                COALESCE(u.tier, 'free') AS tier,
                u.join_date, u.tier_valid_until,
                COUNT(s.id) AS sub_user_count
         FROM users u
         LEFT JOIN users s ON s.owner_id = u.id
         WHERE u.role = 'admin'
         GROUP BY u.id ORDER BY u.id ASC`
      );
      return res.json(rows.map((r) => ({
        id: r.id, username: r.username, full_name: r.full_name, email: r.email,
        is_blocked: !!r.is_blocked, web_access: !!r.web_access,
        tier: r.tier, sub_user_count: parseInt(r.sub_user_count, 10),
        join_date: r.join_date,
        tier_valid_until: r.tier_valid_until ? r.tier_valid_until.toISOString?.()?.slice(0, 10) : null,
      })));
    } else {
      // Admin vidí iba svojich sub-userov
      const { rows } = await pool.query(
        `SELECT id, username, full_name, email,
                COALESCE(is_blocked, false) AS is_blocked,
                COALESCE(web_access, false) AS web_access,
                join_date
         FROM users WHERE owner_id = $1 ORDER BY id ASC`,
        [req.userId]
      );
      // Vráť aj info o tieri admina
      const { rows: [me] } = await pool.query(
        'SELECT COALESCE(tier, $1) AS tier, COALESCE(web_access, false) AS web_access FROM users WHERE id = $2',
        ['free', req.userId]
      );
      return res.json({
        tier: me?.tier || 'free',
        web_access: !!me?.web_access,
        tier_limit: TIER_LIMITS[me?.tier || 'free'],
        sub_users: rows.map((r) => ({
          id: r.id, username: r.username, full_name: r.full_name, email: r.email,
          is_blocked: !!r.is_blocked, web_access: !!r.web_access, join_date: r.join_date,
        })),
      });
    }
  } catch (err) {
    console.error('[GET /admin/users]', err.message);
    res.status(500).json({ error: 'Chyba servera' });
  }
});

apiRouter.patch('/admin/users/:id/block', requireAdmin, async (req, res) => {
  if (!pool || !poolReady) return res.status(503).json({ error: 'Databáza nie je k dispozícii' });
  const id = parseInt(req.params.id, 10);
  if (Number.isNaN(id)) return res.status(400).json({ error: 'Neplatné id' });
  const { block } = req.body || {};
  const setBlocked = block === true || block === 'true';
  try {
    const { rowCount } = await pool.query(
      'UPDATE users SET is_blocked = $1 WHERE id = $2',
      [setBlocked, id]
    );
    if (rowCount === 0) return res.status(404).json({ error: 'Používateľ nenájdený' });
    console.log('[admin] User', id, setBlocked ? 'blocked' : 'unblocked');
    res.json({ success: true, is_blocked: setBlocked });
  } catch (err) {
    console.error('[PATCH /admin/users/:id/block]', err.message);
    res.status(500).json({ error: 'Chyba servera' });
  }
});

apiRouter.patch('/admin/users/:id/web-access', requireAdmin, async (req, res) => {
  if (!pool || !poolReady) return res.status(503).json({ error: 'Databáza nie je k dispozícii' });
  const id = parseInt(req.params.id, 10);
  if (Number.isNaN(id)) return res.status(400).json({ error: 'Neplatné id' });
  const { allow } = req.body || {};
  const setAccess = allow === true || allow === 'true';
  try {
    if (req.userRole === 'db_owner') {
      // DB_OWNER môže meniť web_access iba adminom
      const { rowCount } = await pool.query(
        "UPDATE users SET web_access = $1 WHERE id = $2 AND role = 'admin'",
        [setAccess, id]
      );
      if (rowCount === 0) return res.status(404).json({ error: 'Admin nenájdený' });
    } else {
      // Admin môže meniť web_access iba svojim sub-userom
      const { rowCount } = await pool.query(
        'UPDATE users SET web_access = $1 WHERE id = $2 AND owner_id = $3',
        [setAccess, id, req.userId]
      );
      if (rowCount === 0) return res.status(404).json({ error: 'Sub-user nenájdený' });
    }
    console.log('[admin] User', id, setAccess ? 'web_access granted' : 'web_access revoked');
    res.json({ success: true, web_access: setAccess });
  } catch (err) {
    console.error('[PATCH /admin/users/:id/web-access]', err.message);
    res.status(500).json({ error: 'Chyba servera' });
  }
});

// DB_OWNER: nastavenie tiera a platnosti pre admina
apiRouter.patch('/admin/users/:id/tier', requireDbOwner, async (req, res) => {
  if (!pool || !poolReady) return res.status(503).json({ error: 'Databáza nie je k dispozícii' });
  const id = parseInt(req.params.id, 10);
  if (Number.isNaN(id)) return res.status(400).json({ error: 'Neplatné id' });
  const { tier, valid_until } = req.body || {};
  if (tier !== undefined && !TIER_LIMITS.hasOwnProperty(tier)) {
    return res.status(400).json({ error: 'Neplatný tier. Platné hodnoty: free, basic, pro, enterprise' });
  }
  try {
    let rowCount;
    if (tier !== undefined && valid_until !== undefined) {
      const validDate = valid_until === null || valid_until === '' ? null : String(valid_until).slice(0, 10);
      rowCount = (await pool.query(
        "UPDATE users SET tier = $1, tier_valid_until = $2 WHERE id = $3 AND role = 'admin'",
        [tier, validDate, id]
      )).rowCount;
    } else if (valid_until !== undefined) {
      const validDate = valid_until === null || valid_until === '' ? null : String(valid_until).slice(0, 10);
      rowCount = (await pool.query(
        "UPDATE users SET tier_valid_until = $1 WHERE id = $2 AND role = 'admin'",
        [validDate, id]
      )).rowCount;
    } else if (tier !== undefined) {
      rowCount = (await pool.query(
        "UPDATE users SET tier = $1 WHERE id = $2 AND role = 'admin'",
        [tier, id]
      )).rowCount;
    } else {
      return res.status(400).json({ error: 'Zadajte tier alebo valid_until (alebo oboje).' });
    }
    if (rowCount === 0) return res.status(404).json({ error: 'Admin nenájdený' });
    console.log('[db_owner] Tier/valid_until updated for user', id);
    res.json({ success: true, tier: tier !== undefined ? tier : undefined, valid_until: valid_until === null || valid_until === '' ? null : valid_until });
  } catch (err) {
    console.error('[PATCH /admin/users/:id/tier]', err.message);
    res.status(500).json({ error: 'Chyba servera' });
  }
});

// Admin: pridanie sub-usera (s kontrolou tiera)
apiRouter.post('/admin/subusers', requireAdmin, async (req, res) => {
  if (!pool || !poolReady) return res.status(503).json({ error: 'Databáza nie je k dispozícii' });
  if (req.userRole !== 'admin') return res.status(403).json({ error: 'Len admin môže pridávať sub-userov.' });
  const { username, password, full_name, email } = req.body || {};
  if (!username || !password) return res.status(400).json({ error: 'username a password sú povinné' });
  try {
    // Skontroluj tier admina a platnosť – ak tier vypršal, efektívne free (0)
    const today = new Date().toISOString().slice(0, 10);
    const { rows: [me] } = await pool.query(
      'SELECT COALESCE(tier, $1) AS tier, tier_valid_until FROM users WHERE id = $2',
      ['free', req.userId]
    );
    const tierExpired = me?.tier_valid_until && me.tier_valid_until < today;
    const limit = tierExpired ? 0 : TIER_LIMITS[me?.tier || 'free'];
    if (limit === 0) {
      return res.status(403).json({ error: 'Váš plán (free) neumožňuje pridávať sub-userov. Kontaktujte administrátora pre upgrade.' });
    }
    if (limit > 0) {
      const { rows: [cnt] } = await pool.query(
        'SELECT COUNT(*) AS c FROM users WHERE owner_id = $1', [req.userId]
      );
      if (parseInt(cnt.c, 10) >= limit) {
        return res.status(403).json({ error: `Dosiahli ste limit ${limit} sub-userov pre váš plán (${me.tier}). Kontaktujte administrátora pre upgrade.` });
      }
    }
    // Vytvor sub-usera
    const { rows: [newUser] } = await pool.query(
      `INSERT INTO users (username, password, full_name, email, role, owner_id, web_access, tier)
       VALUES ($1, $2, $3, $4, 'user', $5, false, 'free')
       RETURNING id, username, full_name, email`,
      [username.trim(), password, (full_name || username).trim(), (email || '').trim(), req.userId]
    );
    console.log('[admin] Sub-user created:', newUser.username, 'by admin', req.userId);
    res.status(201).json({ success: true, user: newUser });
  } catch (err) {
    if (err.code === '23505') return res.status(409).json({ error: 'Používateľské meno už existuje.' });
    console.error('[POST /admin/subusers]', err.message);
    res.status(500).json({ error: 'Chyba servera' });
  }
});

apiRouter.delete('/admin/users/:id', requireAdmin, async (req, res) => {
  if (!pool || !poolReady) return res.status(503).json({ error: 'Databáza nie je k dispozícii' });
  const id = parseInt(req.params.id, 10);
  if (Number.isNaN(id)) return res.status(400).json({ error: 'Neplatné id' });
  if (id === req.userId) return res.status(400).json({ error: 'Nemôžete vymazať vlastný účet.' });
  try {
    let rowCount;
    if (req.userRole === 'db_owner') {
      // DB_OWNER môže mazať adminov (nie db_ownerov)
      ({ rowCount } = await pool.query("DELETE FROM users WHERE id = $1 AND role = 'admin'", [id]));
    } else {
      // Admin môže mazať iba svojich sub-userov
      ({ rowCount } = await pool.query('DELETE FROM users WHERE id = $1 AND owner_id = $2', [id, req.userId]));
    }
    if (rowCount === 0) return res.status(404).json({ error: 'Používateľ nenájdený' });
    console.log('[admin] User deleted:', id);
    res.json({ success: true });
  } catch (err) {
    console.error('[DELETE /admin/users/:id]', err.message);
    res.status(500).json({ error: 'Chyba servera' });
  }
});

apiRouter.post('/admin/users/:id/delete-data', requireAdmin, async (req, res) => {
  if (!pool || !poolReady) return res.status(503).json({ error: 'Databáza nie je k dispozícii' });
  const id = parseInt(req.params.id, 10);
  if (Number.isNaN(id)) return res.status(400).json({ error: 'Neplatné id' });
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('DELETE FROM quote_items WHERE quote_id IN (SELECT id FROM quotes WHERE user_id = $1)', [id]);
    await client.query('DELETE FROM quotes WHERE user_id = $1', [id]);
    await client.query('DELETE FROM pallets WHERE user_id = $1', [id]);
    await client.query('DELETE FROM production_batch_recipe WHERE batch_id IN (SELECT id FROM production_batches WHERE user_id = $1)', [id]);
    await client.query('DELETE FROM production_batches WHERE user_id = $1', [id]);
    await client.query('DELETE FROM products WHERE user_id = $1', [id]);
    await client.query('DELETE FROM stocks WHERE user_id = $1', [id]);
    await client.query('DELETE FROM customers WHERE user_id = $1', [id]);
    await client.query('COMMIT');
    console.log('[admin] User data deleted for user:', id);
    res.json({ success: true, message: 'Dáta používateľa boli vymazané.' });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('[POST /admin/users/:id/delete-data]', err.message);
    res.status(500).json({ error: 'Chyba servera' });
  } finally {
    client.release();
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

// --- API: Cenové ponuky (Quotes) ---

apiRouter.get('/quotes', async (req, res) => {
  if (!pool || !poolReady) return res.status(503).json({ error: 'Databáza nie je k dispozícii' });
  const { status, search } = req.query;
  try {
    const dataUserId = req.dataUserId ?? req.userId;
    let where = 'WHERE q.user_id = $1';
    const params = [dataUserId];
    if (status) { params.push(status); where += ` AND q.status = $${params.length}`; }
    if (search) { params.push(`%${search}%`); where += ` AND (q.quote_number ILIKE $${params.length} OR q.customer_name ILIKE $${params.length})`; }
    const { rows } = await pool.query(
      `SELECT q.id, q.local_id, q.quote_number, q.customer_id, q.customer_name, q.customer_ico,
              q.issue_date, q.valid_until, q.status, q.notes, q.delivery_cost, q.other_fees,
              q.prices_include_vat, q.total_amount, q.created_at, q.updated_at
       FROM quotes q ${where} ORDER BY q.created_at DESC`,
      params
    );
    res.json(rows);
  } catch (err) {
    console.error('[GET /api/quotes]', err.message);
    res.status(500).json({ error: 'Chyba servera' });
  }
});

apiRouter.get('/quotes/:id', async (req, res) => {
  if (!pool || !poolReady) return res.status(503).json({ error: 'Databáza nie je k dispozícii' });
  const id = parseInt(req.params.id, 10);
  if (isNaN(id)) return res.status(400).json({ error: 'Neplatné id' });
  try {
    const dataUserId = req.dataUserId ?? req.userId;
    const { rows: qRows } = await pool.query(
      'SELECT * FROM quotes WHERE id = $1 AND user_id = $2', [id, dataUserId]
    );
    if (qRows.length === 0) return res.status(404).json({ error: 'Ponuka nenájdená' });
    const { rows: items } = await pool.query(
      'SELECT * FROM quote_items WHERE quote_id = $1 ORDER BY sort_order, id', [id]
    );
    res.json({ ...qRows[0], items });
  } catch (err) {
    console.error('[GET /api/quotes/:id]', err.message);
    res.status(500).json({ error: 'Chyba servera' });
  }
});

apiRouter.post('/quotes', async (req, res) => {
  if (!pool || !poolReady) return res.status(503).json({ error: 'Databáza nie je k dispozícii' });
  const {
    local_id, quote_number, customer_id, customer_name, customer_ico, customer_address,
    issue_date, valid_until, status = 'draft', notes, delivery_cost = 0, other_fees = 0,
    prices_include_vat = 0, total_amount = 0, items = []
  } = req.body || {};
  if (!quote_number) return res.status(400).json({ error: 'quote_number je povinný' });
  const client = await pool.connect();
  try {
    const dataUserId = req.dataUserId ?? req.userId;
    await client.query('BEGIN');
    const { rows } = await client.query(
      `INSERT INTO quotes (user_id, local_id, quote_number, customer_id, customer_name, customer_ico,
        customer_address, issue_date, valid_until, status, notes, delivery_cost, other_fees,
        prices_include_vat, total_amount)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15)
       ON CONFLICT (user_id, local_id) DO UPDATE SET
         quote_number=EXCLUDED.quote_number, customer_id=EXCLUDED.customer_id,
         customer_name=EXCLUDED.customer_name, customer_ico=EXCLUDED.customer_ico,
         customer_address=EXCLUDED.customer_address, issue_date=EXCLUDED.issue_date,
         valid_until=EXCLUDED.valid_until, status=EXCLUDED.status, notes=EXCLUDED.notes,
         delivery_cost=EXCLUDED.delivery_cost, other_fees=EXCLUDED.other_fees,
         prices_include_vat=EXCLUDED.prices_include_vat, total_amount=EXCLUDED.total_amount,
         updated_at=NOW()
       RETURNING *`,
      [dataUserId, local_id || null, quote_number, customer_id || null, customer_name || null,
       customer_ico || null, customer_address || null, issue_date || null, valid_until || null,
       status, notes || null, delivery_cost, other_fees, prices_include_vat, total_amount]
    );
    const quote = rows[0];
    if (items.length > 0) {
      await client.query('DELETE FROM quote_items WHERE quote_id = $1', [quote.id]);
      for (let i = 0; i < items.length; i++) {
        const it = items[i];
        await client.query(
          `INSERT INTO quote_items (quote_id, user_id, product_unique_id, item_type, name, unit,
            qty, unit_price, vat_percent, discount_percent, surcharge_percent, description, sort_order)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)`,
          [quote.id, dataUserId, it.product_unique_id || null, it.item_type || 'Tovar',
           it.name, it.unit || 'ks', it.qty || 1, it.unit_price || 0,
           it.vat_percent ?? 20, it.discount_percent ?? 0, it.surcharge_percent ?? 0,
           it.description || null, i]
        );
      }
    }
    await client.query('COMMIT');
    const { rows: fullItems } = await pool.query('SELECT * FROM quote_items WHERE quote_id = $1 ORDER BY sort_order, id', [quote.id]);
    res.status(201).json({ ...quote, items: fullItems });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('[POST /api/quotes]', err.message);
    res.status(500).json({ error: 'Chyba servera' });
  } finally {
    client.release();
  }
});

apiRouter.put('/quotes/:id', async (req, res) => {
  if (!pool || !poolReady) return res.status(503).json({ error: 'Databáza nie je k dispozícii' });
  const id = parseInt(req.params.id, 10);
  if (isNaN(id)) return res.status(400).json({ error: 'Neplatné id' });
  const {
    quote_number, customer_id, customer_name, customer_ico, customer_address,
    issue_date, valid_until, status, notes, delivery_cost, other_fees,
    prices_include_vat, total_amount, items
  } = req.body || {};
  const client = await pool.connect();
  try {
    const dataUserId = req.dataUserId ?? req.userId;
    await client.query('BEGIN');
    const { rows } = await client.query(
      `UPDATE quotes SET
         quote_number = COALESCE($3, quote_number),
         customer_id = $4, customer_name = $5, customer_ico = $6, customer_address = $7,
         issue_date = $8, valid_until = $9,
         status = COALESCE($10, status),
         notes = $11,
         delivery_cost = COALESCE($12, delivery_cost),
         other_fees = COALESCE($13, other_fees),
         prices_include_vat = COALESCE($14, prices_include_vat),
         total_amount = COALESCE($15, total_amount),
         updated_at = NOW()
       WHERE id = $1 AND user_id = $2 RETURNING *`,
      [id, dataUserId, quote_number, customer_id || null, customer_name || null,
       customer_ico || null, customer_address || null, issue_date || null,
       valid_until || null, status, notes || null, delivery_cost, other_fees,
       prices_include_vat, total_amount]
    );
    if (rows.length === 0) { await client.query('ROLLBACK'); return res.status(404).json({ error: 'Ponuka nenájdená' }); }
    if (Array.isArray(items)) {
      await client.query('DELETE FROM quote_items WHERE quote_id = $1', [id]);
      for (let i = 0; i < items.length; i++) {
        const it = items[i];
        await client.query(
          `INSERT INTO quote_items (quote_id, user_id, product_unique_id, item_type, name, unit,
            qty, unit_price, vat_percent, discount_percent, surcharge_percent, description, sort_order)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)`,
          [id, dataUserId, it.product_unique_id || null, it.item_type || 'Tovar',
           it.name, it.unit || 'ks', it.qty || 1, it.unit_price || 0,
           it.vat_percent ?? 20, it.discount_percent ?? 0, it.surcharge_percent ?? 0,
           it.description || null, i]
        );
      }
    }
    await client.query('COMMIT');
    const { rows: fullItems } = await pool.query('SELECT * FROM quote_items WHERE quote_id = $1 ORDER BY sort_order, id', [id]);
    res.json({ ...rows[0], items: fullItems });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('[PUT /api/quotes/:id]', err.message);
    res.status(500).json({ error: 'Chyba servera' });
  } finally {
    client.release();
  }
});

apiRouter.delete('/quotes/:id', async (req, res) => {
  if (!pool || !poolReady) return res.status(503).json({ error: 'Databáza nie je k dispozícii' });
  const id = parseInt(req.params.id, 10);
  if (isNaN(id)) return res.status(400).json({ error: 'Neplatné id' });
  try {
    const dataUserId = req.dataUserId ?? req.userId;
    const { rowCount } = await pool.query('DELETE FROM quotes WHERE id = $1 AND user_id = $2', [id, dataUserId]);
    if (rowCount === 0) return res.status(404).json({ error: 'Ponuka nenájdená' });
    res.json({ success: true });
  } catch (err) {
    console.error('[DELETE /api/quotes/:id]', err.message);
    res.status(500).json({ error: 'Chyba servera' });
  }
});

// --- API: Vytvorenie produktu ---

apiRouter.post('/products', async (req, res) => {
  if (!pool || !poolReady) return res.status(503).json({ error: 'Databáza nie je k dispozícii' });
  const { unique_id, name, plu, ean, unit = 'ks', qty = 0, warehouse_id = null } = req.body || {};
  if (!unique_id || !name || !plu) return res.status(400).json({ error: 'unique_id, name a plu sú povinné' });
  try {
    const dataUserId = req.dataUserId ?? req.userId;
    const { rows } = await pool.query(
      `INSERT INTO products (unique_id, warehouse_id, name, plu, ean, unit, qty, user_id)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       ON CONFLICT (unique_id, warehouse_id) DO UPDATE SET
         name = EXCLUDED.name, plu = EXCLUDED.plu, ean = EXCLUDED.ean, unit = EXCLUDED.unit
       RETURNING unique_id, name, plu, ean, unit, qty`,
      [unique_id, warehouse_id, name, plu, ean || null, unit, qty, dataUserId]
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    console.error('[POST /api/products]', err.message);
    res.status(500).json({ error: 'Chyba servera' });
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
