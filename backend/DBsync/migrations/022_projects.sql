-- Migration 022: Projects (Zákazky)
CREATE TABLE IF NOT EXISTS projects (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  local_id INTEGER,
  project_number TEXT NOT NULL,
  name TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'active',
  customer_id INTEGER,
  customer_name TEXT,
  site_address TEXT,
  site_city TEXT,
  start_date TEXT,
  end_date TEXT,
  budget NUMERIC(14,2),
  responsible_person TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, local_id)
);

ALTER TABLE quotes ADD COLUMN IF NOT EXISTS project_id INTEGER REFERENCES projects(id) ON DELETE SET NULL;
ALTER TABLE quotes ADD COLUMN IF NOT EXISTS project_name TEXT;
