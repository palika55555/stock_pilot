# Mesačné uzávierky v StockPilot – návod

## Čo to je

**Mesačná uzávierka** označí kalendárny mesiac (napr. `2025-03`) ako *uzavretý*. Pre tento mesiac aplikácia **nepovolí** vytváranie ani úpravy vybraných dokladov a skladových operácií, kým mesiac znova neotvoríte (iba **administrátor**).

Údaje o uzávierkach sú v lokálnej databáze v tabuľke `monthly_closures` a platia **pre celú databázu** (nie per používateľ).

## Report a tlač

1. **Reporty** (hlavná ponuka aplikácie, kde sú ostatné reporty) → **Mesačné uzávierky**.
2. Obrazovka zobrazí rovnaké údaje ako PDF: obdobie (mesiac), dátum uzavretia, kto uzavrel, poznámka.
3. V hornom paneli:
   - **Tlač / náhľad PDF** – systémový dialóg tlače alebo náhľad (podľa platformy),
   - **Zdieľať PDF** – uloženie/odoslanie súboru, názov typu `mesacne_uzavierky_YYYYMMDD.pdf`.

V PDF je aj názov firmy z **Nastavenia → Naša firma** (ak je vyplnený).

## Kontroly pred uzavretím

Pri kliknutí na **Uzavrieť mesiac** aplikácia najprv spustí **kontrolu** (len dáta aktuálneho používateľa v DB):

**Blokuje uzavretie**, ak v danom kalendárnom mesiaci existujú napr.:

- príjemky v stave *rozpracovaná*, *vykázaná* alebo *čaká na schválenie*;
- výdajky *rozpracovaná* alebo *vykázaná* (nie schválené);
- faktúry v *koncepte*, ak pripadá do mesiaca **dátum vystavenia** alebo **DUZP**;
- výrobné príkazy, ktoré **nie sú** dokončené ani zrušené a majú **dátum výroby** v tom mesiaci.

**Neblokuje**, ale zobrazí **varovanie** (môžete uzavrieť aj tak):

- schválené výdajky **bez vysporiadania** (bez väzby na faktúru);
- cenové ponuky v **koncepte** vytvorené v tom mesiaci;
- **zamietnuté** príjemky v tom mesiaci (odporúčanie na kontrolu).

## Kde to nastavíte

1. **Nastavenia** → sekcia **Dáta a úložisko** → **Mesačné uzávierky**.
2. Zoznam ukáže všetky uzavreté mesiace (dátum uzavretia, kto, poznámka).
3. **Uzavrieť mesiac** (plávajúce tlačidlo): výber mesiaca z posledných 72 mesiacov, voliteľná poznámka. Rovnaký mesiac dvakrát uzavrieť nejde.
4. **Znovu otvoriť** (ikona zámku pri riadku): len **admin** – mesiac sa zruší z uzavretých a doklady v ňom pôjde znova meniť.

Bežný používateľ vidí zoznam a vysvetlenie; uzatvárať a otvárať môže len admin.

## Podľa akého dátumu sa kontroluje mesiac

| Oblast | Ktoré dátumy |
|--------|----------------|
| **Príjemky** | dátum vytvorenia dokladu (`createdAt` na príjemke) |
| **Výdajky** | dátum dokladu (`createdAt`) |
| **Presuny medzi skladmi** | dátum záznamu presunu |
| **Inventúra / úprava zásob** | aktuálny dátum v okamihu uloženia |
| **Výrobné príkazy** | dátum výroby (`productionDate`); pri **dokončení výroby** sa kontroluje aj **aktuálny dátum** (vznikajú nové doklady „dnes“) |
| **Faktúry** | **dátum vystavenia** aj **dátum zdaniteľného plnenia (DUZP)** – ak je aspoň jeden z nich v uzavretom mesiaci, operácia sa zablokuje |
| **Cenové ponuky** | dátum vytvorenia ponuky (`createdAt`); úpravy **položiek** ponuky tiež kontrolujú mesiac tejto hlavičky |

Ak teda uzavriete marec, nepridáte ani neupravíte faktúru, ktorej dátum vystavenia alebo DUZP spadá do marca (a rovnako ostatné typy podľa tabuľky).

## Čo používateľ uvidí pri chybe

Služby pri pokuse o zakázanú zmenu vyhodia `MonthClosedException` so správou v slovenčine, napr. že dané obdobie je uzavreté. V UI sa zobrazí ako text chyby (napr. pri ukladaní obrazovky).

## Odporúčaný postup v praxi

1. Skontrolujte doklady za mesiac (reporty, zostatky).
2. V **Mesačné uzávierky** mesiac **uzavrite**.
3. Ak omylom uzavriete zlý mesiac alebo potrebujete opravu: **admin** znovu **otvorí** mesiac, opraví sa, a podľa potreby sa znova uzavrie.

## Technické poznámky (pre vývoj)

- Verzia schémy SQLite obsahuje migráciu na tabuľku `monthly_closures`.
- Logika je v `MonthlyClosureService` (`assertDateOpen`) a volá sa z príslušných služieb (`ReceiptService`, `StockOutService`, `WarehouseService`, `ProductionOrderService`, `InvoiceService`, `QuoteService`) a z `updateStockAfterAudit` v `DatabaseService`.
- Synchronizácia uzávierok na backend (ak existuje) v tejto verzii **nie je** – ide o lokálne pravidlo v danej DB.
