const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const { Pool } = require('pg');

const app = express();
const PORT = process.env.PORT || 3000;
const NODE_ENV = process.env.NODE_ENV || 'development';

// PostgreSQL pool (DATABASE_URL napr. postgresql://user:pass@host:5432/dbname)
const pool = process.env.DATABASE_URL
  ? new Pool({ connectionString: process.env.DATABASE_URL })
  : null;

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

// Uptime od štartu procesu (sekundy)
const startTime = Date.now();
const getUptimeSeconds = () => Math.floor((Date.now() - startTime) / 1000);

// --- Routes ---

app.get('/', (req, res) => {
  res.json({
    message: 'Stock Pilot API',
    version: '1.0.0',
  });
});

app.get('/health', async (req, res) => {
  let database = 'error';
  if (pool) {
    try {
      await pool.query('SELECT NOW()');
      database = 'connected';
    } catch (err) {
      console.error('[health] DB check failed:', err.message);
    }
  } else {
    console.warn('[health] DATABASE_URL not set, skipping DB check');
  }
  res.json({
    status: 'ok',
    service: 'stock-pilot-api',
    uptimeSeconds: getUptimeSeconds(),
    uptimeFormatted: formatUptime(getUptimeSeconds()),
    database,
  });
});

// --- API: Auth (stub pre test frontendu) ---
app.post('/api/auth/login', (req, res) => {
  const { email, password } = req.body || {};
  if (!email || !password) {
    return res.status(401).json({
      success: false,
      error: 'E-mail a heslo sú povinné',
    });
  }
  // Stub: akceptuje ľubovoľný pár (skutočná validácia neskôr cez DB)
  res.status(200).json({
    success: true,
    token: `stub-${Buffer.from(email).toString('base64')}-${Date.now()}`,
    user: { email: email.trim() },
  });
});

// --- API: Stocks (PostgreSQL) ---
app.get('/api/stocks', async (req, res) => {
  if (!pool) {
    console.error('[GET /api/stocks] DATABASE_URL not set');
    return res.status(503).json({ error: 'Database not configured' });
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
  if (!pool) {
    console.error('[POST /api/stocks] DATABASE_URL not set');
    return res.status(503).json({ error: 'Database not configured' });
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

async function initDatabase() {
  if (!pool) {
    console.warn('[init] DATABASE_URL not set, skipping table creation');
    return;
  }
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS stocks (
        id SERIAL PRIMARY KEY,
        symbol TEXT NOT NULL,
        price NUMERIC NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
    console.log('[init] Table stocks ready');
  } catch (err) {
    console.error('[init] Failed to create table stocks:', err.message);
    throw err;
  }
}

async function start() {
  await initDatabase();
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`API beží na http://0.0.0.0:${PORT}`);
    console.log(`CORS: ${allowedOrigins.join(', ')}`);
  });
}

start().catch((err) => {
  console.error('Startup failed:', err);
  process.exit(1);
});
