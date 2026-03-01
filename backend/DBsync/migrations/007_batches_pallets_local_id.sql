-- Flutter (aplikácia) posiela šarže s lokálnym id; backend ich ukladá a mapuje podľa local_id.
ALTER TABLE production_batches ADD COLUMN IF NOT EXISTS local_id INTEGER;
CREATE UNIQUE INDEX IF NOT EXISTS idx_production_batches_local_id ON production_batches (local_id) WHERE local_id IS NOT NULL;

ALTER TABLE pallets ADD COLUMN IF NOT EXISTS local_id INTEGER;
CREATE UNIQUE INDEX IF NOT EXISTS idx_pallets_local_id ON pallets (local_id) WHERE local_id IS NOT NULL;
