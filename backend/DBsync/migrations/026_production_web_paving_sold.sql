-- Zamková dlažba (m²), rozšírenie šarží a evidencia predaja paliet (web-first)

CREATE TABLE IF NOT EXISTS paving_stones (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  length_mm NUMERIC(14,3) NOT NULL,
  width_mm NUMERIC(14,3) NOT NULL,
  thickness_mm NUMERIC(14,3) NOT NULL,
  pieces_per_layer INTEGER NOT NULL CHECK (pieces_per_layer > 0),
  layers_per_pallet INTEGER NOT NULL CHECK (layers_per_pallet > 0),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_paving_stones_user ON paving_stones(user_id);

ALTER TABLE production_batches
  ADD COLUMN IF NOT EXISTS paving_stone_id INTEGER REFERENCES paving_stones(id) ON DELETE SET NULL;
ALTER TABLE production_batches
  ADD COLUMN IF NOT EXISTS requested_m2 NUMERIC(14,4);
ALTER TABLE production_batches
  ADD COLUMN IF NOT EXISTS actual_stored_m2 NUMERIC(14,4);

CREATE INDEX IF NOT EXISTS idx_production_batches_paving ON production_batches(paving_stone_id);

ALTER TABLE pallets
  ADD COLUMN IF NOT EXISTS sold_at TIMESTAMP;
ALTER TABLE pallets
  ADD COLUMN IF NOT EXISTS sale_note TEXT;
