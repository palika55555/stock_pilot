// Konfigurácia obrazovky skladových zásob (stĺpce, prefs, rozmer tabuľky).

/// Stĺpce tabuľky, ktoré môže používateľ skryť/zobraziť (v poradí zobrazenia).
const List<({String id, String label})> warehouseSupplyTableColumns = [
  (id: 'predaj_bez_dph', label: 'Predaj bez DPH'),
  (id: 'predaj_s_dph', label: 'Predaj s DPH'),
  (id: 'marza', label: 'Marža'),
  (id: 'dph', label: 'DPH'),
  (id: 'dph_eur', label: 'DPH (€)'),
  (id: 'mnozstvo', label: 'Množstvo'),
  (id: 'zlava', label: 'Zľava'),
  (id: 'nakup_bez_dph', label: 'Nákup bez DPH'),
  (id: 'nakup_s_dph', label: 'Nákup s DPH'),
  (id: 'nakup_dph', label: 'Nákup DPH'),
  (id: 'recykl', label: 'Recykl. popl.'),
  (id: 'posl_datum', label: 'Posl. dátum nákupu'),
  (id: 'posl_nakup_bez_dph', label: 'Posledný nákup bez DPH'),
  (id: 'dodavatel', label: 'Dodávateľ'),
  (id: 'mena', label: 'Mena'),
  (id: 'typ', label: 'Typ'),
  (id: 'lokacia', label: 'Lokácia'),
  (id: 'sklad', label: 'Sklad'),
];

const String kWarehouseSuppliesColumnPrefsKey =
    'warehouse_supplies_visible_columns';

const double kWarehouseSuppliesMinTableWidth = 1700;

/// 25 riadkov namiesto 40 = 37 % menej widgetov na repaint pri každom scroll frame.
/// DataTable nie je virtualizovaný, takže menej riadkov = priamo rýchlejší scroll.
const int kWarehouseSuppliesPageSize = 25;
