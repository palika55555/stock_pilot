-- Migrácia 021: Generický sync systém s offline frontou, event logom a riešením konfliktov
-- =====================================================================================

-- 1. Pridaj version + deleted_at + updated_at na všetky entity tabuľky (bezpečne IF NOT EXISTS)
ALTER TABLE products           ADD COLUMN IF NOT EXISTS version    INTEGER     NOT NULL DEFAULT 1;
ALTER TABLE products           ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE products           ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

ALTER TABLE customers          ADD COLUMN IF NOT EXISTS version    INTEGER     NOT NULL DEFAULT 1;
ALTER TABLE customers          ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE customers          ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

ALTER TABLE warehouses         ADD COLUMN IF NOT EXISTS version    INTEGER     NOT NULL DEFAULT 1;
ALTER TABLE warehouses         ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE warehouses         ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

ALTER TABLE suppliers          ADD COLUMN IF NOT EXISTS version    INTEGER     NOT NULL DEFAULT 1;
ALTER TABLE suppliers          ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE suppliers          ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

ALTER TABLE inbound_receipts   ADD COLUMN IF NOT EXISTS version    INTEGER     NOT NULL DEFAULT 1;
ALTER TABLE inbound_receipts   ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE inbound_receipts   ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

ALTER TABLE stock_outs         ADD COLUMN IF NOT EXISTS version    INTEGER     NOT NULL DEFAULT 1;
ALTER TABLE stock_outs         ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE stock_outs         ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

ALTER TABLE recipes            ADD COLUMN IF NOT EXISTS version    INTEGER     NOT NULL DEFAULT 1;
ALTER TABLE recipes            ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE recipes            ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

ALTER TABLE production_orders  ADD COLUMN IF NOT EXISTS version    INTEGER     NOT NULL DEFAULT 1;
ALTER TABLE production_orders  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE production_orders  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

ALTER TABLE production_batches ADD COLUMN IF NOT EXISTS version    INTEGER     NOT NULL DEFAULT 1;
ALTER TABLE production_batches ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE production_batches ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

ALTER TABLE quotes             ADD COLUMN IF NOT EXISTS version    INTEGER     NOT NULL DEFAULT 1;
ALTER TABLE quotes             ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE quotes             ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

ALTER TABLE transports         ADD COLUMN IF NOT EXISTS version    INTEGER     NOT NULL DEFAULT 1;
ALTER TABLE transports         ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE transports         ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

ALTER TABLE pallets            ADD COLUMN IF NOT EXISTS version    INTEGER     NOT NULL DEFAULT 1;
ALTER TABLE pallets            ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE pallets            ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

ALTER TABLE company            ADD COLUMN IF NOT EXISTS version    INTEGER     NOT NULL DEFAULT 1;
ALTER TABLE company            ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE company            ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- 2. sync_events: append-only log všetkých zmien (nikdy sa nemazú)
CREATE TABLE IF NOT EXISTS sync_events (
  id               BIGSERIAL    PRIMARY KEY,
  entity_type      VARCHAR(100) NOT NULL,
  entity_id        VARCHAR(255) NOT NULL,
  operation        VARCHAR(20)  NOT NULL CHECK (operation IN ('create', 'update', 'delete')),
  field_changes    JSONB        NOT NULL DEFAULT '{}',
  client_timestamp TIMESTAMPTZ  NOT NULL,
  server_timestamp TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  device_id        VARCHAR(255),
  user_id          INTEGER      REFERENCES users(id) ON DELETE SET NULL,
  session_id       VARCHAR(255),
  client_version   INTEGER      NOT NULL DEFAULT 1,
  server_version   INTEGER      NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS sync_events_user_id_idx    ON sync_events(user_id);
CREATE INDEX IF NOT EXISTS sync_events_entity_idx     ON sync_events(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS sync_events_server_ts_idx  ON sync_events(server_timestamp);
CREATE INDEX IF NOT EXISTS sync_events_device_id_idx  ON sync_events(device_id);

-- 3. sync_conflicts: evidencia rozriešených aj nerozriešených konfliktov
CREATE TABLE IF NOT EXISTS sync_conflicts (
  id               BIGSERIAL    PRIMARY KEY,
  entity_type      VARCHAR(100) NOT NULL,
  entity_id        VARCHAR(255) NOT NULL,
  conflict_fields  JSONB        NOT NULL DEFAULT '[]',
  client_change    JSONB        NOT NULL DEFAULT '{}',
  server_change    JSONB        NOT NULL DEFAULT '{}',
  client_version   INTEGER      NOT NULL,
  server_version   INTEGER      NOT NULL,
  client_timestamp TIMESTAMPTZ  NOT NULL,
  server_timestamp TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  strategy_applied VARCHAR(50),
  resolution       VARCHAR(50)  NOT NULL DEFAULT 'pending'
                   CHECK (resolution IN ('pending','server-wins','client-wins','newer-wins','field-merge','manual')),
  resolved_at      TIMESTAMPTZ,
  resolved_by      INTEGER      REFERENCES users(id) ON DELETE SET NULL,
  resolved_data    JSONB,
  user_id          INTEGER      REFERENCES users(id) ON DELETE SET NULL,
  device_id        VARCHAR(255),
  created_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS sync_conflicts_user_id_idx    ON sync_conflicts(user_id);
CREATE INDEX IF NOT EXISTS sync_conflicts_resolution_idx ON sync_conflicts(resolution);
CREATE INDEX IF NOT EXISTS sync_conflicts_entity_idx     ON sync_conflicts(entity_type, entity_id);
