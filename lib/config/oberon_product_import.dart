import '../services/migration/oberon_import_spec.dart';

/// Mapovanie z tabuľky v Oberon SQLite do StockPilot `products`.
///
/// **Postup**
/// 1. **SQLite** (.db / .sqlite) alebo na **Windows** súbory **Access** (.mdb, .accdb) — tie sa čítajú cez OLE DB
///    (môže byť potrebný „Microsoft Access Database Engine“ 64-bit).
/// 2. Skopírujte súbor na disk a v aplikácii použite „Import z Oberon“.
/// 3. **Tabuľku** vyberte v aplikácii (tlačidlo „Vybrať tabuľku“) — napr. `SkladoveKarty00001`.
/// 4. **Stĺpce** doladiť tu v `columnMap` podľa vlastnej DB (názvy musia sedieť presne).
///
/// **Kľúče v `columnMap`** = názvy polí v StockPilot (nie vždy treba vyplniť všetky):
/// `name`, `plu`, `ean`, `category`, `qty`, `unit`, `price`, `without_vat`, `vat`,
/// `discount`, `last_purchase_price`, `last_purchase_price_without_vat`, `last_purchase_date`,
/// `currency`, `location`, `purchase_price`, `purchase_price_without_vat`, `purchase_vat`,
/// `recycling_fee`, `product_type`, `supplier_name`, `kind_id`, `warehouse_id`,
/// `min_quantity`, `allow_at_cash_register`, `show_in_price_list`, `is_active`,
/// `temporarily_unavailable`, `stock_group`, `card_type`, `has_extended_pricing`,
/// `iba_cele_mnozstva`
///
/// **Špeciálne:** Ak mapujete `is_active` na stĺpec `Disabled`, aplikácia hodnotu **obráti**
/// (Disabled = áno → produkt neaktívny).
///
/// **Hodnoty** = presný názov stĺpca v Oberon DB.
///
/// Predvolené mapovanie je pre tabuľku typu **SkladoveKarty00001** (ProBlock / Oberon).
const OberonProductImportSpec oberonProductImportSpec = OberonProductImportSpec(
  /// Môže zostať prázdne, ak tabuľku vyberiete v aplikácii (napr. SkladoveKarty00001).
  tableName: '',
  columnMap: <String, String?>{
    'name': 'Description',
    'plu': 'Cislo',
    'ean': 'EAN',
    'price': 'CenaPredajSDPH1',
    'without_vat': 'CenaPredajna1',
    'discount': 'Discount_MaxPercento',
    'last_purchase_price': 'CenaLastNakupna',
    'last_purchase_price_without_vat': 'CenaObstar',
    'purchase_price': 'CenaLastNakupna',
    'purchase_price_without_vat': 'CenaObstar',
    'last_purchase_date': 'DateTime_LastUpdate',
    'is_active': 'Disabled',
  },
  defaultWarehouseId: null,
  defaultCurrency: 'EUR',
  skipIfPluExists: true,
);
