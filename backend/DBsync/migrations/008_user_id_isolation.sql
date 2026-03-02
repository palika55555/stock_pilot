-- Per-user data isolation: add user_id to all data tables.
-- Token from login contains user id; backend will filter all queries by req.userId.

-- customers: one list per user
ALTER TABLE customers ADD COLUMN IF NOT EXISTS user_id INTEGER REFERENCES users(id) ON DELETE CASCADE;
UPDATE customers SET user_id = (SELECT id FROM users ORDER BY id ASC LIMIT 1) WHERE user_id IS NULL;
ALTER TABLE customers ALTER COLUMN user_id SET NOT NULL;
CREATE INDEX IF NOT EXISTS idx_customers_user_id ON customers(user_id);

-- products: one catalog per user (unique_id can repeat across users)
ALTER TABLE products ADD COLUMN IF NOT EXISTS user_id INTEGER REFERENCES users(id) ON DELETE CASCADE;
UPDATE products SET user_id = (SELECT id FROM users ORDER BY id ASC LIMIT 1) WHERE user_id IS NULL;
ALTER TABLE products ALTER COLUMN user_id SET NOT NULL;
CREATE INDEX IF NOT EXISTS idx_products_user_id ON products(user_id);

-- stocks
ALTER TABLE stocks ADD COLUMN IF NOT EXISTS user_id INTEGER REFERENCES users(id) ON DELETE CASCADE;
UPDATE stocks SET user_id = (SELECT id FROM users ORDER BY id ASC LIMIT 1) WHERE user_id IS NULL;
ALTER TABLE stocks ALTER COLUMN user_id SET NOT NULL;
CREATE INDEX IF NOT EXISTS idx_stocks_user_id ON stocks(user_id);

-- production_batches: one set per user; allow same local_id per user
ALTER TABLE production_batches ADD COLUMN IF NOT EXISTS user_id INTEGER REFERENCES users(id) ON DELETE CASCADE;
UPDATE production_batches SET user_id = (SELECT id FROM users ORDER BY id ASC LIMIT 1) WHERE user_id IS NULL;
DROP INDEX IF EXISTS idx_production_batches_local_id;
ALTER TABLE production_batches ALTER COLUMN user_id SET NOT NULL;
CREATE INDEX IF NOT EXISTS idx_production_batches_user_id ON production_batches(user_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_production_batches_user_local ON production_batches (user_id, local_id) WHERE local_id IS NOT NULL;

-- pallets: inherit via batch or set explicitly
ALTER TABLE pallets ADD COLUMN IF NOT EXISTS user_id INTEGER REFERENCES users(id) ON DELETE CASCADE;
UPDATE pallets SET user_id = (SELECT pb.user_id FROM production_batches pb WHERE pb.id = pallets.batch_id LIMIT 1) WHERE user_id IS NULL;
UPDATE pallets SET user_id = (SELECT id FROM users ORDER BY id ASC LIMIT 1) WHERE user_id IS NULL;
DROP INDEX IF EXISTS idx_pallets_local_id;
ALTER TABLE pallets ALTER COLUMN user_id SET NOT NULL;
CREATE INDEX IF NOT EXISTS idx_pallets_user_id ON pallets(user_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_pallets_user_local ON pallets (user_id, local_id) WHERE local_id IS NOT NULL;
