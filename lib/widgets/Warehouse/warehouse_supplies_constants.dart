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

/// Šírky stĺpcov [dp] pre vlastný virtualizovaný riadok tabuľky.
/// Súčet viditeľných stĺpcov určuje celkovú šírku tabuľky.
const Map<String, double> kWarehouseColumnWidths = {
  '#': 44,
  'plu': 90,
  'name': 190,
  'predaj_bez_dph': 112,
  'predaj_s_dph': 112,
  'marza': 80,
  'dph': 64,
  'dph_eur': 80,
  'mnozstvo': 112,
  'zlava': 64,
  'nakup_bez_dph': 112,
  'nakup_s_dph': 112,
  'nakup_dph': 80,
  'recykl': 80,
  'posl_datum': 132,
  'posl_nakup_bez_dph': 152,
  'dodavatel': 144,
  'mena': 64,
  'typ': 80,
  'lokacia': 100,
  'sklad': 100,
  'actions': 116,
};
