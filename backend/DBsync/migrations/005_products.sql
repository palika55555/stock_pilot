-- Produkty syncované z Flutteru pre web (skenovanie podľa EAN/PLU).
-- Jeden produkt môže mať viac riadkov (rôzne skladoviská).
CREATE TABLE IF NOT EXISTS products (
  id SERIAL PRIMARY KEY,
  unique_id TEXT NOT NULL,
  warehouse_id INTEGER,
  name TEXT NOT NULL,
  plu TEXT NOT NULL,
  ean TEXT,
  unit TEXT NOT NULL DEFAULT 'ks',
  qty INTEGER NOT NULL DEFAULT 0,
  UNIQUE(unique_id, warehouse_id)
);

CREATE INDEX IF NOT EXISTS idx_products_ean ON products(ean) WHERE ean IS NOT NULL AND ean != '';
CREATE INDEX IF NOT EXISTS idx_products_plu ON products(plu);
CREATE INDEX IF NOT EXISTS idx_products_unique_id ON products(unique_id);
