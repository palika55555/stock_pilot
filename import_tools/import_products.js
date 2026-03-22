/**
 * import_products.js
 * Importuje produkty z pohoda_products.json (Pohoda MDB export)
 * priamo do Stock Pilot SQLite databázy.
 *
 * Použitie:
 *   1. npm install
 *   2. Uprav USER_ID nižšie (alebo spustiť s: node import_products.js --user-id=1)
 *   3. node import_products.js
 *      --dry-run     → iba zobrazí čo by importovalo, nič nezapíše
 *      --clear       → vymaže existujúce produkty pre daného usera pred importom
 */

'use strict';

const Database = require('better-sqlite3');
const fs = require('fs');
const path = require('path');

// ─── KONFIGURÁCIA ────────────────────────────────────────────────────────────

// ID prihláseného používateľa v Stock Pilot (TEXT v SQLite).
// Spusti app, prihlás sa, a potom sa pozri do DB: SELECT user_id FROM products LIMIT 1
// alebo spusti: node import_products.js --check-user
let USER_ID = null; // nastaví sa z --user-id=X alebo z DB

const DB_PATH = path.resolve(
  __dirname,
  '../.dart_tool/sqflite_common_ffi/databases/account_1/stock_pilot.db'
);
const JSON_PATH = path.resolve(__dirname, 'pohoda_products.json');

// ─── ARGUMENTY ───────────────────────────────────────────────────────────────

const args = process.argv.slice(2);
const DRY_RUN = args.includes('--dry-run');
const CLEAR = args.includes('--clear');
const CHECK_USER = args.includes('--check-user');

const userIdArg = args.find(a => a.startsWith('--user-id='));
if (userIdArg) USER_ID = userIdArg.split('=')[1];

// ─── POMOCNÉ FUNKCIE ─────────────────────────────────────────────────────────

/** Pohoda decimal: "1,29" → 1.29, "0" → 0, null → 0 */
function parseDecimal(val) {
  if (val === null || val === undefined || val === '') return 0;
  if (typeof val === 'number') return val;
  const str = String(val).trim().replace(',', '.');
  const n = parseFloat(str);
  return isNaN(n) ? 0 : n;
}

/** Pohoda integer: null → 0 */
function parseInteger(val) {
  if (val === null || val === undefined || val === '') return 0;
  if (typeof val === 'number') return Math.round(val);
  const n = parseInt(String(val).trim(), 10);
  return isNaN(n) ? 0 : n;
}

/** EAN kód: "|5907451356425|" → "5907451356425", null → null */
function parseEan(val) {
  if (!val) return null;
  const str = String(val).trim();
  // Strip leading/trailing pipes
  const stripped = str.replace(/^\|+/, '').replace(/\|+$/, '').trim();
  if (!stripped || stripped.length < 8) return null;
  // Ak obsahuje ešte pipe, vezmi prvý kód
  const firstCode = stripped.split('|')[0].trim();
  return firstCode || null;
}

/** Kategória z Umiestnenie path: "\HUDCOVCE\Hudcovce\Tovar na predaj\" → "Tovar na predaj" */
function parseCategory(umiestnenie) {
  if (!umiestnenie) return null;
  const parts = String(umiestnenie)
    .split('\\')
    .map(p => p.trim())
    .filter(p => p.length > 0);
  // Posledná neprázdna časť je kategória
  return parts.length > 0 ? parts[parts.length - 1] : null;
}

/** VAT sadzba: 23 → 23, "23" → 23, null → 23 */
function parseVat(val) {
  if (val === null || val === undefined) return 23;
  const n = parseInteger(val);
  // Pohoda používa: 23, 19, 10, 5, 0
  // Stock Pilot používa integer percento
  return n;
}

/** Boolean z Pohoda (0/-1/true/false) → 0/1 */
function parseBool(val, defaultVal = 1) {
  if (val === null || val === undefined) return defaultVal;
  if (val === true || val === -1 || val === 1) return 1;
  if (val === false || val === 0) return 0;
  const s = String(val).toLowerCase().trim();
  if (s === 'true' || s === '-1' || s === '1') return 1;
  return 0;
}

// ─── MAPOVANIE Pohoda → Stock Pilot ──────────────────────────────────────────

/**
 * Skonvertuje jeden riadok SkladoveKarty00001 na Stock Pilot product objekt.
 */
function mapProduct(row, userId) {
  // unique_id: IDNum ako string (napr. "10001")
  const uniqueId = row['IDNum'] != null ? String(row['IDNum']).trim() : null;
  if (!uniqueId || uniqueId === '0') return null;

  const name = String(row['Nazov'] || '').trim();
  if (!name) return null; // preskočíme produkty bez názvu

  // Cena s DPH (CenaPredajSDPH1)
  const priceWithVat = parseDecimal(row['CenaPredajSDPH1']);
  // Cena bez DPH (CenaPredajna1)
  const priceWithoutVat = parseDecimal(row['CenaPredajna1']);
  // VAT sadzba
  const vat = parseVat(row['SadzbaDPH']);

  // Purchase price (obstarávacia cena)
  const purchasePrice = parseDecimal(row['CenaObstar']);
  const lastPurchasePrice = parseDecimal(row['CenaLastNakupna']);

  // Kupná cena bez DPH (prepočítame ak nemáme)
  const purchaseVat = vat; // rovnaká sadzba
  const purchasePriceWithoutVat = purchaseVat > 0
    ? Math.round((purchasePrice / (1 + purchaseVat / 100)) * 10000) / 10000
    : purchasePrice;
  const lastPurchasePriceWithoutVat = purchaseVat > 0
    ? Math.round((lastPurchasePrice / (1 + purchaseVat / 100)) * 10000) / 10000
    : lastPurchasePrice;

  // EAN kód
  const ean = parseEan(row['EAN']);

  // Množstvo na sklade
  const qty = parseDecimal(row['MnozstvoZostatok']);

  // Minimálne množstvo
  const minQty = parseInteger(row['MnozstvoMin']);

  // Merná jednotka
  const unit = String(row['MJ'] || 'ks').trim() || 'ks';

  // PLU / kód
  const plu = String(row['Cislo'] || row['IDNum'] || '').trim();

  // Kategória a umiestnenie (non-nullable String v Flutter – nesmie byť null)
  const umiestnenie = row['Umiestnenie'] ? String(row['Umiestnenie']).trim() : '';
  const category = parseCategory(umiestnenie) || String(row['Skupina'] || '').trim() || '';
  const location = umiestnenie;

  // Stock group (Skupina = číslo skupiny v Pohoda)
  const stockGroup = row['Skupina'] != null ? String(row['Skupina']).trim() : null;

  // Show in price list
  const showInPriceList = parseBool(row['CennikUvadzat'], 1);

  // Allow at cash register
  const allowAtCashRegister = parseBool(row['PokladnaUmoznitPracovat'], 1);

  // Zľava
  const discount = parseInteger(row['Rabat1']);

  return {
    unique_id: uniqueId,
    name,
    plu,
    category,
    qty,
    unit,
    price: priceWithVat,
    without_vat: priceWithoutVat,
    vat,
    discount,
    last_purchase_price: lastPurchasePrice,
    last_purchase_price_without_vat: lastPurchasePriceWithoutVat,
    last_purchase_date: '',
    currency: 'EUR',
    location: location || '',
    purchase_price: purchasePrice,
    purchase_price_without_vat: purchasePriceWithoutVat,
    purchase_vat: purchaseVat,
    recycling_fee: 0.0,
    product_type: 'Sklad',
    supplier_name: null,
    kind_id: null,
    warehouse_id: null,
    min_quantity: minQty,
    allow_at_cash_register: allowAtCashRegister,
    show_in_price_list: showInPriceList,
    is_active: 1,
    temporarily_unavailable: 0,
    stock_group: stockGroup,
    card_type: 'jednoduchá',
    has_extended_pricing: 0,
    iba_cele_mnozstva: 0,
    ean,
    user_id: userId,
  };
}

// ─── HLAVNÝ KÓD ──────────────────────────────────────────────────────────────

function main() {
  console.log('=== Stock Pilot – Pohoda Import ===\n');

  // Otvori DB
  if (!fs.existsSync(DB_PATH)) {
    console.error('❌ SQLite DB nenájdená:', DB_PATH);
    console.error('   Uisti sa, že máš Stock Pilot aspoň raz otvorenú a prihlásenú.');
    process.exit(1);
  }
  console.log('📂 DB:', DB_PATH);

  const db = new Database(DB_PATH);

  // Zisti user_id ak nie je zadané
  if (!USER_ID) {
    const row = db.prepare("SELECT user_id FROM products WHERE user_id IS NOT NULL LIMIT 1").get();
    if (row) {
      USER_ID = row.user_id;
      console.log(`ℹ️  Auto-detekovaný user_id: "${USER_ID}"`);
    } else {
      // Skúsime z iných tabuliek
      const tables = ['customers', 'warehouses', 'quotes'];
      for (const t of tables) {
        try {
          const r = db.prepare(`SELECT user_id FROM ${t} WHERE user_id IS NOT NULL LIMIT 1`).get();
          if (r && r.user_id) { USER_ID = r.user_id; break; }
        } catch {}
      }
      if (!USER_ID) {
        console.error('❌ Nepodarilo sa auto-detekovať user_id.');
        console.error('   Spusti app, prihlás sa, a potom spusti:');
        console.error('   node import_products.js --user-id=<tvoj_user_id>');
        db.close();
        process.exit(1);
      }
      console.log(`ℹ️  Auto-detekovaný user_id (z inej tabuľky): "${USER_ID}"`);
    }
  }

  // --check-user: iba zobraz user_id a skonči
  if (CHECK_USER) {
    console.log(`\n✅ Aktuálny user_id v DB: "${USER_ID}"`);
    const count = db.prepare("SELECT COUNT(*) as c FROM products WHERE user_id = ?").get(USER_ID);
    console.log(`   Produktov pre tohto usera: ${count.c}`);
    db.close();
    return;
  }

  console.log(`👤 Importujem pre user_id: "${USER_ID}"`);
  console.log('');

  // Prečítaj JSON
  if (!fs.existsSync(JSON_PATH)) {
    console.error('❌ JSON súbor nenájdený:', JSON_PATH);
    console.error('   Najprv spusti: powershell -ExecutionPolicy Bypass -File export_pohoda.ps1');
    db.close();
    process.exit(1);
  }

  // Strip UTF-8 BOM ak ho PowerShell pridalo
  let jsonText = fs.readFileSync(JSON_PATH, 'utf8');
  if (jsonText.charCodeAt(0) === 0xFEFF) jsonText = jsonText.slice(1);
  const rawData = JSON.parse(jsonText);
  console.log(`📄 Načítaných zo JSON: ${rawData.length} riadkov`);

  // Mapuj produkty
  const products = [];
  let skipped = 0;
  for (const row of rawData) {
    const p = mapProduct(row, USER_ID);
    if (p) {
      products.push(p);
    } else {
      skipped++;
    }
  }

  console.log(`✅ Platných produktov: ${products.length}`);
  if (skipped > 0) console.log(`⚠️  Preskočených (bez IDNum/Nazov): ${skipped}`);
  console.log('');

  if (DRY_RUN) {
    console.log('--- DRY RUN (nič sa nezapíše) ---');
    const sample = products.slice(0, 5);
    for (const p of sample) {
      console.log(`  [${p.unique_id}] ${p.name} | ${p.unit} | ${p.price}€ s DPH | ks: ${p.qty} | EAN: ${p.ean || '-'}`);
    }
    if (products.length > 5) console.log(`  ... a ďalších ${products.length - 5} produktov`);
    return;
  }

  // Skontroluj, či stĺpec user_id existuje v products
  const tableInfo = db.prepare("PRAGMA table_info(products)").all();
  const hasUserId = tableInfo.some(c => c.name === 'user_id');
  if (!hasUserId) {
    console.log('⚙️  Pridávam stĺpec user_id do products...');
    db.prepare("ALTER TABLE products ADD COLUMN user_id TEXT").run();
  }

  // --clear: vymaž existujúce produkty pre tohto usera
  if (CLEAR) {
    const deleted = db.prepare("DELETE FROM products WHERE user_id = ?").run(USER_ID);
    console.log(`🗑️  Vymazaných existujúcich produktov: ${deleted.changes}`);
  }

  // Načítaj existujúce unique_id pre tohto usera (kvôli UPSERT logike)
  const existing = new Set(
    db.prepare("SELECT unique_id FROM products WHERE user_id = ?").all(USER_ID).map(r => r.unique_id)
  );
  console.log(`📊 Existujúcich produktov v DB pre usera: ${existing.size}`);

  // Stĺpce tabuľky (dynamické – závisí od verzie schémy)
  const allCols = tableInfo.map(c => c.name);
  const productKeys = Object.keys(products[0]).filter(k => allCols.includes(k));
  console.log(`🔧 Mapované stĺpce: ${productKeys.join(', ')}`);
  console.log('');

  // INSERT OR REPLACE
  const placeholders = productKeys.map(() => '?').join(', ');
  const insertSql = `INSERT OR REPLACE INTO products (${productKeys.join(', ')}) VALUES (${placeholders})`;
  const stmt = db.prepare(insertSql);

  let inserted = 0;
  let updated = 0;
  let errors = 0;

  const runAll = db.transaction(() => {
    for (const p of products) {
      try {
        const values = productKeys.map(k => p[k] !== undefined ? p[k] : null);
        stmt.run(values);
        if (existing.has(p.unique_id)) {
          updated++;
        } else {
          inserted++;
        }
      } catch (err) {
        console.error(`  ❌ Chyba pri [${p.unique_id}] ${p.name}: ${err.message}`);
        errors++;
      }
    }
  });

  console.log('💾 Zapisujem do SQLite...');
  runAll();

  console.log('');
  console.log('=== Výsledok ===');
  console.log(`✅ Nové produkty:      ${inserted}`);
  console.log(`🔄 Aktualizované:     ${updated}`);
  if (errors > 0) console.log(`❌ Chyby:             ${errors}`);
  console.log(`📦 Celkovo spracované: ${inserted + updated}`);
  console.log('');
  console.log('Hotovo! Otvor Stock Pilot a synchronizuj (tlačidlo Sync).');

  db.close();
}

main();
