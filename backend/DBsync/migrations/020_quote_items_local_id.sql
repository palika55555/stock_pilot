-- Pridanie local_id do quote_items pre sync z Flutter
ALTER TABLE quote_items ADD COLUMN IF NOT EXISTS local_id INTEGER;
CREATE UNIQUE INDEX IF NOT EXISTS uq_quote_items_user_local ON quote_items(user_id, local_id)
  WHERE local_id IS NOT NULL;

-- Chýbajúce stĺpce v quotes (default_vat_rate, payment_method, delivery_terms)
ALTER TABLE quotes ADD COLUMN IF NOT EXISTS default_vat_rate INTEGER NOT NULL DEFAULT 20;
ALTER TABLE quotes ADD COLUMN IF NOT EXISTS payment_method TEXT;
ALTER TABLE quotes ADD COLUMN IF NOT EXISTS delivery_terms TEXT;
