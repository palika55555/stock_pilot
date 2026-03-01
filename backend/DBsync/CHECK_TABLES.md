# Kontrola tabuliek PostgreSQL (web backend) – Debian / Linux

## Potrebné tabuľky pre web

| Tabuľka              | Migrácia              | Popis                    |
|----------------------|------------------------|--------------------------|
| `schema_migrations`  | 001_schema_migrations.sql | Evidencia spustených migrácií |
| `users`              | 002_users.sql         | Používatelia (login)     |
| `stocks`             | 003_stocks.sql        | (voliteľné)              |
| `customers`          | 004_customers.sql     | Zákazníci                |
| `products`           | 005_products.sql      | Produkty (EAN, skenovanie)|

---

## 1. Kontrola cez API (bez prihlásenia)

Po spustení backendu (Coolify / Docker) otvor v prehliadači alebo cez `curl`:

```bash
curl -s https://TVOJ-BACKEND/health/db-tables
```

Príklad odpovede ak je všetko OK:

```json
{
  "database": "connected",
  "tables": ["customers", "products", "schema_migrations", "stocks", "users"],
  "migrations": [
    {"name": "001_schema_migrations.sql", "run_at": "..."},
    {"name": "002_users.sql", "run_at": "..."},
    ...
  ],
  "expected": ["schema_migrations", "users", "customers", "products", "stocks"],
  "missing": null,
  "ok": true
}
```

Ak niečo chýba, v odpovedi bude `"missing": ["products"]` a `"ok": false`.

---

## 2. Kontrola priamo v PostgreSQL (psql) – Debian

### Pripojenie k databáze

Použiť connection string z Coolify (premenná `DATABASE_URL`) alebo lokálne:

```bash
# Ak máš DATABASE_URL v tvare postgresql://user:password@host:5432/dbname
psql "postgresql://USER:HESLO@localhost:5432/NAZOV_DB"

# Alebo jednotlivo
psql -h localhost -p 5432 -U postgres -d NAZOV_DATABAZE
```

### Zoznam všetkých tabuliek v schéme public

```sql
SELECT tablename
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;
```

Očakávaný výstup obsahuje aspoň: `customers`, `products`, `schema_migrations`, `users` (a voliteľne `stocks`).

### Ktoré migrácie už boli spustené

```sql
SELECT name, run_at FROM schema_migrations ORDER BY name;
```

Mali by byť: `001_schema_migrations.sql`, `002_users.sql`, `003_stocks.sql`, `004_customers.sql`, `005_products.sql`.

### Rýchla kontrola existencie kľúčových tabuliek

```sql
SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'schema_migrations') AS schema_migrations,
       EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users')       AS users,
       EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'customers')  AS customers,
       EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'products')    AS products;
```

Všetky stĺpce by mali byť `t`.

---

## 3. Ak tabuľky chýbajú

Migrácie spúšťa backend pri štarte (v `server.js` → `runMigrations(pool)`). Ak nie sú tabuľky:

1. **Skontroluj `DATABASE_URL`** v Coolify – musí byť nastavená a platná.
2. **Reštartuj backend** – pri štarte sa znova pokúsi pripojiť a spustiť migrácie.
3. **Pozri logy** – v Coolify logoch hľadaj `[migrations] Ran:` alebo chyby pri `pool.query`.

Ak potrebuješ spustiť migrácie ručne (napr. iný užívateľ DB):

```bash
cd /cesta/k/backend
node -e "
const { Pool } = require('pg');
const { runMigrations } = require('./DBsync/runMigrations');
const pool = new Pool({ connectionString: process.env.DATABASE_URL });
runMigrations(pool).then(r => { console.log('Ran', r.run, 'migrations'); process.exit(0); }).catch(e => { console.error(e); process.exit(1); });
"
```

(Spusti v prostredí, kde je nastavená premenná `DATABASE_URL`.)
