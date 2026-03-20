-- Faktúry vydané – SK legislatíva (§71 Zák. č. 222/2004 Z.z. o DPH)
-- Typy: issuedInvoice | proformaInvoice | creditNote | debitNote
-- Stavy: draft | issued | sent | paid | overdue | cancelled

CREATE TABLE IF NOT EXISTS invoices (
  id                      SERIAL PRIMARY KEY,
  user_id                 INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  local_id                INTEGER,

  invoice_number          TEXT NOT NULL,
  invoice_type            TEXT NOT NULL DEFAULT 'issuedInvoice',

  -- Dátumy (povinné náležitosti §71 ods. 1 Zák. DPH)
  issue_date              TEXT NOT NULL,          -- dátum vystavenia
  tax_date                TEXT NOT NULL,          -- dátum zdaniteľného plnenia (DUZP)
  due_date                TEXT NOT NULL,          -- dátum splatnosti

  -- Odberateľ – denormalizované v čase vystavenia (musia zostať nemenne)
  customer_id             INTEGER,
  customer_name           TEXT,
  customer_address        TEXT,
  customer_city           TEXT,
  customer_postal_code    TEXT,
  customer_ico            TEXT,
  customer_dic            TEXT,
  customer_ic_dph         TEXT,
  customer_country        TEXT NOT NULL DEFAULT 'SK',

  -- Referencie
  quote_id                INTEGER,
  quote_number            TEXT,
  project_id              INTEGER,
  project_name            TEXT,

  -- Platobné údaje
  payment_method          TEXT NOT NULL DEFAULT 'transfer',  -- transfer | cash | card
  variable_symbol         TEXT,                              -- = invoice_number (číslo)
  constant_symbol         TEXT NOT NULL DEFAULT '0308',
  specific_symbol         TEXT,

  -- Vypočítané sumy (cache – nie sú autoritatívne, vždy prepočítané z položiek)
  total_without_vat       NUMERIC(12,2) NOT NULL DEFAULT 0,
  total_vat               NUMERIC(12,2) NOT NULL DEFAULT 0,
  total_with_vat          NUMERIC(12,2) NOT NULL DEFAULT 0,

  -- Stav faktúry
  status                  TEXT NOT NULL DEFAULT 'draft',

  notes                   TEXT,

  -- Dobropis / Ťarchopis – referencia na originálnu faktúru
  original_invoice_id     INTEGER,
  original_invoice_number TEXT,

  -- Snapshot: bol dodávateľ platiteľom DPH v čase vystavenia?
  is_vat_payer            INTEGER NOT NULL DEFAULT 1,

  -- Pay by Square QR string (Base32hex; generovaný backendom)
  qr_string               TEXT,

  created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE(user_id, local_id)
);

CREATE TABLE IF NOT EXISTS invoice_items (
  id                  SERIAL PRIMARY KEY,
  invoice_id          INTEGER NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
  user_id             INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  local_id            INTEGER,

  product_unique_id   TEXT,
  item_type           TEXT NOT NULL DEFAULT 'Tovar',   -- Tovar | Služba | Paleta | Doprava
  name                TEXT NOT NULL,
  unit                TEXT NOT NULL DEFAULT 'ks',
  qty                 NUMERIC(12,3) NOT NULL DEFAULT 1,
  unit_price          NUMERIC(12,4) NOT NULL DEFAULT 0,

  -- Sadzba DPH platná od 1.1.2025: 23 | 19 | 5 | 0
  vat_percent         NUMERIC(5,2) NOT NULL DEFAULT 23,
  discount_percent    NUMERIC(5,2) NOT NULL DEFAULT 0,
  description         TEXT,
  sort_order          INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_invoices_user_id     ON invoices(user_id);
CREATE INDEX IF NOT EXISTS idx_invoices_status      ON invoices(user_id, status);
CREATE INDEX IF NOT EXISTS idx_invoices_type        ON invoices(user_id, invoice_type);
CREATE INDEX IF NOT EXISTS idx_invoice_items_inv_id ON invoice_items(invoice_id);
