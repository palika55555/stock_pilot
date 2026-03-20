-- Migration 023: Pricing rules for Extended Pricing (Rozšírená cenotvorba)
-- 1:N relationship: products → pricing_rules

CREATE TABLE IF NOT EXISTS pricing_rules (
  id               SERIAL PRIMARY KEY,
  product_unique_id TEXT NOT NULL,
  user_id          INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  label            TEXT,
  price            NUMERIC(12,4) NOT NULL CHECK (price >= 0),
  quantity_from    NUMERIC(12,3) NOT NULL DEFAULT 1 CHECK (quantity_from >= 0),
  quantity_to      NUMERIC(12,3) CHECK (quantity_to IS NULL OR quantity_to >= quantity_from),
  customer_group   TEXT,
  valid_from       TIMESTAMPTZ,
  valid_to         TIMESTAMPTZ,
  created_at       TIMESTAMPTZ DEFAULT NOW(),
  updated_at       TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pricing_rules_product
  ON pricing_rules(product_unique_id, user_id);

CREATE INDEX IF NOT EXISTS idx_pricing_rules_customer_group
  ON pricing_rules(customer_group);
