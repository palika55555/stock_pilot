-- Migrácia 017: Výdajky (stock_outs), ich položky a pohyby

CREATE TABLE IF NOT EXISTS stock_outs (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id),
  local_id INTEGER NOT NULL,
  document_number TEXT,
  created_at TEXT,
  recipient_name TEXT,
  notes TEXT,
  username TEXT,
  status TEXT DEFAULT 'rozpracovany',
  warehouse_id INTEGER,
  je_vysporiadana INTEGER DEFAULT 0,
  vat_rate NUMERIC(5,2),
  issue_type TEXT,
  write_off_reason TEXT,
  linked_receipt_local_id INTEGER,
  customer_id INTEGER,
  recipient_ico TEXT,
  recipient_dic TEXT,
  recipient_address TEXT,
  submitted_at TEXT,
  approved_at TEXT,
  approver_username TEXT,
  approver_note TEXT,
  rejected_at TEXT,
  rejection_reason TEXT,
  UNIQUE(user_id, local_id)
);

CREATE TABLE IF NOT EXISTS stock_out_items (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id),
  local_id INTEGER NOT NULL,
  stock_out_local_id INTEGER NOT NULL,
  product_unique_id TEXT,
  product_name TEXT,
  plu TEXT,
  qty NUMERIC(12,3),
  unit TEXT,
  unit_price NUMERIC(12,4),
  batch_number TEXT,
  expiry_date TEXT,
  UNIQUE(user_id, local_id)
);

CREATE TABLE IF NOT EXISTS stock_movements (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id),
  local_id INTEGER NOT NULL,
  stock_out_local_id INTEGER,
  document_number TEXT,
  created_at TEXT,
  product_unique_id TEXT,
  product_name TEXT,
  plu TEXT,
  qty NUMERIC(12,3),
  unit TEXT,
  direction TEXT,
  UNIQUE(user_id, local_id)
);
