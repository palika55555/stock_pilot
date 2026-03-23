-- 2FA (TOTP) support for all users.
ALTER TABLE users ADD COLUMN IF NOT EXISTS twofa_enabled BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE users ADD COLUMN IF NOT EXISTS twofa_secret_enc TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS twofa_secret_iv TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS twofa_confirmed_at TIMESTAMP;
ALTER TABLE users ADD COLUMN IF NOT EXISTS twofa_backup_codes_hash JSONB;
ALTER TABLE users ADD COLUMN IF NOT EXISTS twofa_last_used_step BIGINT;
