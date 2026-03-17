-- Platnosť tiera (prístupu) na určité obdobie. NULL = neobmedzené.
ALTER TABLE users ADD COLUMN IF NOT EXISTS tier_valid_until DATE DEFAULT NULL;
