-- Tabuľka pre evidovanie spustených migrácií (žiadna závislosť na iných tabuľkách).
CREATE TABLE IF NOT EXISTS schema_migrations (
  id SERIAL PRIMARY KEY,
  name TEXT UNIQUE NOT NULL,
  run_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
