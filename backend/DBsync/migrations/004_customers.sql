CREATE TABLE IF NOT EXISTS customers (
  id SERIAL PRIMARY KEY,
  local_id INTEGER UNIQUE NOT NULL,
  name TEXT NOT NULL,
  ico TEXT NOT NULL,
  email TEXT,
  address TEXT,
  city TEXT,
  postal_code TEXT,
  dic TEXT,
  ic_dph TEXT,
  default_vat_rate INTEGER NOT NULL DEFAULT 20,
  is_active INTEGER NOT NULL DEFAULT 1
);
