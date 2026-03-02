-- Flag: whether per-user data migration has been completed (for multi-user existing DBs).
-- If multiple users existed before 008, admin must reassign records via POST /admin/migrate-user-data.
CREATE TABLE IF NOT EXISTS app_settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

-- Set to 'true' only when all data has been assigned to users (single user: set true; multi: admin sets after migration).
INSERT INTO app_settings (key, value) VALUES ('data_isolation_migrated', 'false')
  ON CONFLICT (key) DO NOTHING;

-- If there is exactly one user, safe to mark as migrated (008 already assigned all to that user).
DO $$
DECLARE
  user_count int;
BEGIN
  SELECT COUNT(*) INTO user_count FROM users;
  IF user_count = 1 THEN
    UPDATE app_settings SET value = 'true' WHERE key = 'data_isolation_migrated';
  END IF;
END $$;
