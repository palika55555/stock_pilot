-- Paletová bilancia pre zákazníkov (expedícia)
ALTER TABLE customers ADD COLUMN IF NOT EXISTS pallet_balance INTEGER NOT NULL DEFAULT 0;

-- Šarže výroby
CREATE TABLE IF NOT EXISTS production_batches (
  id SERIAL PRIMARY KEY,
  production_date DATE NOT NULL,
  product_type TEXT NOT NULL,
  quantity_produced INTEGER NOT NULL DEFAULT 0,
  notes TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  cost_total NUMERIC(12,2),
  revenue_total NUMERIC(12,2)
);

-- Receptúra šarže
CREATE TABLE IF NOT EXISTS production_batch_recipe (
  id SERIAL PRIMARY KEY,
  batch_id INTEGER NOT NULL REFERENCES production_batches(id) ON DELETE CASCADE,
  material_name TEXT NOT NULL,
  quantity NUMERIC(12,2) NOT NULL,
  unit TEXT NOT NULL DEFAULT 'kg'
);

-- Palety (výstup z výroby, expedícia)
CREATE TABLE IF NOT EXISTS pallets (
  id SERIAL PRIMARY KEY,
  batch_id INTEGER NOT NULL REFERENCES production_batches(id),
  product_type TEXT NOT NULL,
  quantity INTEGER NOT NULL,
  customer_id INTEGER REFERENCES customers(id),
  status TEXT NOT NULL DEFAULT 'Na sklade',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_production_batches_date ON production_batches(production_date);
CREATE INDEX IF NOT EXISTS idx_production_batch_recipe_batch ON production_batch_recipe(batch_id);
CREATE INDEX IF NOT EXISTS idx_pallets_batch ON pallets(batch_id);
CREATE INDEX IF NOT EXISTS idx_pallets_customer ON pallets(customer_id);
