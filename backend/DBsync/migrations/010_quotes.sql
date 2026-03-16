-- Cenové ponuky (quotes) syncované z Flutter aplikácie
CREATE TABLE IF NOT EXISTS quotes (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  local_id INTEGER,
  quote_number TEXT NOT NULL,
  customer_id INTEGER,
  customer_name TEXT,
  customer_ico TEXT,
  customer_address TEXT,
  issue_date TEXT,
  valid_until TEXT,
  status TEXT NOT NULL DEFAULT 'draft',
  notes TEXT,
  delivery_cost NUMERIC(12,2) NOT NULL DEFAULT 0,
  other_fees NUMERIC(12,2) NOT NULL DEFAULT 0,
  prices_include_vat INTEGER NOT NULL DEFAULT 0,
  total_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, local_id)
);

CREATE TABLE IF NOT EXISTS quote_items (
  id SERIAL PRIMARY KEY,
  quote_id INTEGER NOT NULL REFERENCES quotes(id) ON DELETE CASCADE,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  product_unique_id TEXT,
  item_type TEXT NOT NULL DEFAULT 'Tovar',
  name TEXT NOT NULL,
  unit TEXT NOT NULL DEFAULT 'ks',
  qty NUMERIC(12,3) NOT NULL DEFAULT 1,
  unit_price NUMERIC(12,4) NOT NULL DEFAULT 0,
  vat_percent NUMERIC(5,2) NOT NULL DEFAULT 20,
  discount_percent NUMERIC(5,2) NOT NULL DEFAULT 0,
  surcharge_percent NUMERIC(5,2) NOT NULL DEFAULT 0,
  description TEXT,
  sort_order INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_quotes_user_id ON quotes(user_id);
CREATE INDEX IF NOT EXISTS idx_quotes_status ON quotes(user_id, status);
CREATE INDEX IF NOT EXISTS idx_quote_items_quote_id ON quote_items(quote_id);
