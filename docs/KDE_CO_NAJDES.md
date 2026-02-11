# Kde čo nájdeš v kóde (Stock Pilot)

Prehľad štruktúry projektu – v ktorom súbore je ktorá obrazovka, widget alebo funkcia.

---

## Spúšťanie aplikácie

| Čo | Kde |
|----|-----|
| Vstup bod, inicializácia DB, téma, jazyk, „zapamätaj si“, výber úvodnej obrazovky | `lib/main.dart` |
| First run vs Login vs HomeScreen s uloženým používateľom | `lib/main.dart` (funkcia `main`, potom `MyApp`) |

---

## HomeScreen (hlavná obrazovka po prihlásení)

| Čo | Kde |
|----|-----|
| Samotná obrazovka – Scaffold, drawer, appBar, body | `lib/screens/Home/Home_screen.dart` |
| **Bočné menu (drawer)** – položky menu, odhlásenie, nastavenia, sklad, zákazníci, doprava… | `lib/widgets/Common/app_drawer_widget.dart` |
| **Horný pás (AppBar)** – menu ikona, používateľ, doprava, čas + Ponuky, notifikácie, nastavenia, vyhľadávanie | `lib/widgets/Header/home_app_bar_widget.dart` |
| **Telo stránky** – všetko pod AppBarom (prehľad, KPI karty, poznámky, úlohy, pohyby…) | `lib/widgets/Home/home_overview_widget.dart` |

---

## Čo je v HomeOverview (telo Home)

Všetko v **`lib/widgets/Home/home_overview_widget.dart`**:

| Čo na obrazovke | Metóda / časť v súbore |
|-----------------|-------------------------|
| Nadpis „Prehľad“ | `build` → `Text(l10n.overview)` |
| Karta poznámok | `_buildNotesCard` |
| Karta úloh (tasks) | `_buildTasksCard` |
| KPI karty (Produkty, Objednávky, Zákazníci, Tržby) | `_buildKpiCards` → `_DashboardKpiCard` |
| Karta „Cenová ponuka“ (0 €, prechod na zoznam ponúk) | `_buildPriceQuoteCard` |
| Karta posledných pohybov (príjemky / výdajky) | `_buildRecentMovementsCard` → `_buildMovementColumn` |
| Navigácia na príjemky, výdajky, sklad, zákazníkov, cenové ponuky | `_navigateTo` v tom istom súbore |

---

## AppBar (horný pás)

| Čo | Kde |
|----|-----|
| Celý AppBar – menu, používateľ, ikony, čas, akcie | `lib/widgets/Header/home_app_bar_widget.dart` |
| Blok používateľa (meno, rola, avatar) | `lib/widgets/Profile/user_info_widget.dart` |
| Čas + **Ponuky** (počet cenových ponúk, klik → obrazovka ponúk) | `lib/widgets/Time/time_display_widget.dart` |
| Ikony vpravo: vyhľadávanie, nastavenia, notifikácie | `lib/widgets/Header/header_actions_widget.dart` |

---

## Obrazovky (screens)

| Obrazovka | Súbor |
|-----------|--------|
| Prihlásenie | `lib/screens/Login/login_page.dart` |
| Prvý štart (first run) | `lib/screens/first_startup/first_startup_screen.dart` |
| Zákazníci | `lib/screens/Customers/customers_page.dart` |
| Zoznam cenových ponúk | `lib/screens/price_quote/price_quotes_list_screen.dart` |
| Tvorba / úprava cenovej ponuky | `lib/screens/price_quote/price_quote_screen.dart` |
| Sklad – zásoby | `lib/screens/Warehouse/warehouse_supplies.dart` |
| Sklad – zoznam skladov | `lib/screens/Warehouse/warehouses_page.dart` |
| Sklad – pohyby | `lib/screens/Warehouse/warehouse_movements_screen.dart`, `warehouse_movements_list_screen.dart` |
| Príjemky (tovar do skladu) | `lib/screens/goods_receipt/goods_receipt_screen.dart` |
| Výdajky (tovar zo skladu) | `lib/screens/stock_out/stock_out_screen.dart` |
| Nastavenia | `lib/screens/Settings/settings_page.dart` |
| Nastavenie firmy | `lib/screens/Settings/company_edit_screen.dart` |
| Štýl PDF príjemky | `lib/screens/Settings/receipt_pdf_style_screen.dart` |
| Profil používateľa | `lib/screens/Profile/profile_page.dart` |
| Vyhľadávanie | `lib/screens/Search/search_screen.dart` |
| Doprava (kalkulačka) | `lib/screens/Transport/transport_calculator_screen.dart` |
| Skenovanie produktu | `lib/screens/Scanner/scan_product.dart` |
| Dodávatelia | `lib/screens/Suppliers/suppliers_page.dart` |

---

## Modely (dáta)

Všetko v **`lib/models/`**:

| Súbor | Čo obsahuje |
|-------|-------------|
| `user.dart` | Používateľ (login, rola, meno…) |
| `product.dart` | Produkt |
| `customer.dart` | Zákazník |
| `quote.dart` | Cenová ponuka (Quote, QuoteItem, QuoteStatus) |
| `receipt.dart` | Príjemka (InboundReceipt, položky) |
| `stock_out.dart` | Výdajka |
| `warehouse.dart` | Sklad |
| `warehouse_transfer.dart` | Presun medzi skladmi |
| `supplier.dart` | Dodávateľ |
| `company.dart` | Firma (údaje na tlač) |
| `transport.dart` | Doprava |
| `receipt_pdf_style_config.dart` | Konfigurácia vzhľadu PDF príjemky |
| `change_password_request.dart` | Žiadosť na zmenu hesla |

---

## Servisy (logika, databáza)

V **`lib/services/`** (priečinky s veľkým písmenom, napr. `Database/`, `Dashboard/`):

| Servis | Súbor | Na čo slúži |
|--------|--------|-------------|
| Databáza – používatelia, produkty, príjemky, ponuky, „zapamätaj si“… | `lib/services/Database/database_service.dart` | SQLite, všetky tabuľky a CRUD |
| Štatistiky pre Home (KPI, pohyby) | `lib/services/Dashboard/dashboard_service.dart` | `getOverviewStats()` |
| Cenové ponuky (CRUD) | `lib/services/Quote/quote_service.dart` | Ponuky a položky |
| PDF cenovej ponuky | `lib/services/Quote/quote_pdf_service.dart` | Generovanie PDF |
| Príjemky | `lib/services/Receipt/receipt_service.dart` | Príjemky |
| PDF príjemky | `lib/services/Receipt/receipt_pdf_service.dart` | Tlač príjemky |
| Výdajky | `lib/services/StockOut/stock_out_service.dart` | Výdajky |
| Sklad | `lib/services/Warehouse/warehouse_service.dart` | Zásoby, sklady |
| Zákazníci | `lib/services/Customer/customer_service.dart` | CRUD zákazníkov |
| Dodávatelia | `lib/services/Supplier/supplier_service.dart` | CRUD dodávateľov |
| Produkty | `lib/services/Product/product_service.dart` | CRUD produktov |
| Doprava | `lib/services/Transport/transport_service.dart` | Doprava |
| Zmena hesla | `lib/services/Auth/change_password_service.dart` | Zmena hesla |
| Klávesové skratky | `lib/services/Shortcuts/app_shortcuts_service.dart` | Globálne skratky |

---

## Widgety (podľa funkcie)

### Spoločné (Common)
**`lib/widgets/Common/`**

| Súbor | Čo |
|-------|-----|
| `app_drawer_widget.dart` | Bočné menu (drawer) na Home |
| `purple_button.dart` | Fialové tlačidlo |
| `glass_text_field.dart` | Sklené textové pole (login) |
| `glassmorphism_container.dart` | Sklený kontajner |
| `standard_text_field.dart` | Štandardné textové pole |
| `change_password_dialog.dart` | Dialóg na zmenu hesla |
| `responsive_layout_widget.dart` | Responzívny layout |

### Hlavička (Header)
**`lib/widgets/Header/`**

| Súbor | Čo |
|-------|-----|
| `home_app_bar_widget.dart` | Celý AppBar na Home |
| `header_actions_widget.dart` | Ikony vpravo (vyhľadávanie, nastavenia, notifikácie) |

### Domov (Home)
**`lib/widgets/Home/`**

| Súbor | Čo |
|-------|-----|
| `home_overview_widget.dart` | Celý obsah stránky Home (KPI, poznámky, úlohy, cenová ponuka, pohyby) |

### Profil
**`lib/widgets/Profile/`**

| Súbor | Čo |
|-------|-----|
| `user_info_widget.dart` | Blok používateľa v AppBar (meno, rola, avatar) |
| `user_options_sheet_widget.dart` | Spodný sheet po kliknutí na profil (nastavenia, odhlásenie…) |
| `mobile_user_info_widget.dart` | Mobilná verzia používateľa / odhlásenie |

### Príjemky a výdajky (Receipts)
**`lib/widgets/Receipts/`**

| Súbor | Čo |
|-------|-----|
| `goods_receipt_list_widget.dart` | Zoznam príjemiek |
| `goods_receipt_modal_widget.dart` | Modál na pridanie/úpravu príjemky |
| `receipt_card_widget.dart` | Karta jednej príjemky |
| `receipts_widget.dart` | Widget zoznamu príjemok |
| `stock_out_list_widget.dart` | Zoznam výdajok |
| `stock_out_modal_widget.dart` | Modál na výdajku |

### Cenové ponuky (Quotes)
**`lib/widgets/Quotes/`**

| Súbor | Čo |
|-------|-----|
| `quote_document_card_widget.dart` | Karta dokumentu cenovej ponuky |
| `add_quote_item_modal_widget.dart` | Modál na pridanie položky do ponuky |

### Sklad (Warehouse)
**`lib/widgets/Warehouse/`**

| Súbor | Čo |
|-------|-----|
| `warehouse_supplies_card_view_widget.dart` | Karta zásob |
| `warehouse_supplies_header_widget.dart` | Hlavička sekcie zásob |
| `warehouse_list_widget.dart` | Zoznam skladov |
| `add_warehouse_modal_widget.dart` | Modál na pridanie skladu |
| `warehouse_transfer_modal_widget.dart` | Modál na presun medzi skladmi |
| `warehouse_low_stock_modal_widget.dart` | Modál nízkej zásoby |
| `warehouse_quick_stats_widget.dart` | Rýchle štatistiky skladu |

### Čas a Ponuky (Time)
**`lib/widgets/Time/`**

| Súbor | Čo |
|-------|-----|
| `time_display_widget.dart` | Čas + blok „Ponuky“ (počet cenových ponúk, klik → obrazovka ponúk) |
| `mobile_time_display_widget.dart` | Mobilná verzia |

### Ostatné widgety
- **`lib/widgets/Customers/add_customer_modal_widget.dart`** – modál na zákazníka  
- **`lib/widgets/Products/add_product_modal_widget.dart`** – modál na produkt  
- **`lib/widgets/Suppliers/add_supplier_modal_widget.dart`** – modál na dodávateľa  
- **`lib/widgets/Notifications/notifications_sheet_widget.dart`** – sheet notifikácií  
- **`lib/widgets/FirstStartup/FirstStartupApp_widget.dart`** – prvý štart  
- **`lib/widgets/Dashboard/`** – dashboard karty a štatistiky (ak sa niekde používajú)  
- **`lib/widgets/Purchase/purchase_price_history_sheet_widget.dart`** – história nákupných cien  
- **`lib/widgets/Transport/`** – kalkulačka dopravy, autocomplete adries  

### Badges
**`lib/badges/`**

| Súbor | Čo |
|-------|-----|
| `pillBadge.dart` | `ProductBadge` – pill badge (napr. na karte Produkty na Home) |

---

## Jazyky (l10n)

**`lib/l10n/`**

- `app_sk.arb`, `app_en.arb`, `app_cs.arb` – texty pre slovenčinu, angličtinu, češtinu  
- `app_localizations.dart`, `app_localizations_sk.dart`, … – vygenerované gettery pre texty  

---

## Ďalšie

| Čo | Kde |
|----|-----|
| Téma a jazyk (Provider) | `lib/Providers/theme_locale_provider.dart` |
| Utility skript (cesta DB) | `lib/Scripts/show_db_path.dart` |

---

*Dokument vygenerovaný pre projekt Stock Pilot. Pri zmene štruktúry projektu treba dokument aktualizovať.*
