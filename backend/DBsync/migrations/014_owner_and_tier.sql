-- Hierarchia používateľov: DB_OWNER > admin (tenant) > user (sub-user)
-- owner_id: NULL pre db_owner a standalone adminov; admin's id pre sub-userov
ALTER TABLE users ADD COLUMN IF NOT EXISTS owner_id INTEGER REFERENCES users(id) ON DELETE SET NULL;

-- Tier pre adminov (určuje koľko sub-userov môžu mať)
-- free=0, basic=2, pro=5, enterprise=neobmedzene
ALTER TABLE users ADD COLUMN IF NOT EXISTS tier TEXT NOT NULL DEFAULT 'free';

-- Existujúci admini dostanú tier 'free' (default)
-- DB_OWNER musí byť nastavený manuálne:
-- UPDATE users SET role = 'db_owner', tier = 'enterprise', web_access = true WHERE username = 'TvojLogin';
