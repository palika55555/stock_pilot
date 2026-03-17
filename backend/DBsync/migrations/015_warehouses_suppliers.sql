-- Sklady a dodávatelia pre web (per user).

CREATE TABLE IF NOT EXISTS warehouses (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  code TEXT NOT NULL DEFAULT '',
  warehouse_type TEXT NOT NULL DEFAULT 'Predaj',
  address TEXT,
  city TEXT,
  postal_code TEXT,
  is_active INTEGER NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_warehouses_user_id ON warehouses(user_id);

CREATE TABLE IF NOT EXISTS suppliers (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  ico TEXT NOT NULL DEFAULT '',
  email TEXT,
  address TEXT,
  city TEXT,
  postal_code TEXT,
  dic TEXT,
  ic_dph TEXT,
  default_vat_rate INTEGER NOT NULL DEFAULT 20,
  is_active INTEGER NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_suppliers_user_id ON suppliers(user_id);
