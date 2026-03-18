-- Migrácia 019: Transporty a firemné údaje

CREATE TABLE IF NOT EXISTS transports (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id),
  local_id INTEGER NOT NULL,
  origin TEXT,
  destination TEXT,
  distance NUMERIC(10,2),
  is_round_trip INTEGER DEFAULT 0,
  price_per_km NUMERIC(10,4),
  fuel_consumption NUMERIC(10,4),
  fuel_price NUMERIC(10,4),
  base_cost NUMERIC(12,4),
  fuel_cost NUMERIC(12,4),
  total_cost NUMERIC(12,4),
  created_at TEXT,
  notes TEXT,
  UNIQUE(user_id, local_id)
);

CREATE TABLE IF NOT EXISTS company (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id),
  name TEXT,
  address TEXT,
  city TEXT,
  postal_code TEXT,
  country TEXT,
  ico TEXT,
  dic TEXT,
  ic_dph TEXT,
  vat_payer INTEGER DEFAULT 0,
  phone TEXT,
  email TEXT,
  web TEXT,
  iban TEXT,
  swift TEXT,
  bank_name TEXT,
  account TEXT,
  register_info TEXT,
  UNIQUE(user_id)
);
