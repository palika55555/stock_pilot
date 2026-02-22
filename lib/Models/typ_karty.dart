/// Typ skladovej karty podľa špecifikácie receptúr.
enum TypKarty {
  jednoducha,
  sluzba,
  receptura,
  vratnyObal,
}

extension TypKartyExtension on TypKarty {
  /// Hodnota pre uloženie do DB (products.card_type).
  String get dbValue {
    switch (this) {
      case TypKarty.jednoducha:
        return 'jednoduchá';
      case TypKarty.sluzba:
        return 'služba';
      case TypKarty.receptura:
        return 'receptúra';
      case TypKarty.vratnyObal:
        return 'vratný obal';
    }
  }

  bool get isReceptura => this == TypKarty.receptura;
}

/// Mapovanie reťazca z DB na enum.
TypKarty typKartyFromString(String? value) {
  if (value == null || value.isEmpty) return TypKarty.jednoducha;
  final normalized = value.toLowerCase().trim();
  if (normalized.contains('receptúra') || normalized == 'receptura') return TypKarty.receptura;
  if (normalized.contains('služba') || normalized == 'sluzba') return TypKarty.sluzba;
  if (normalized.contains('vratný') || normalized.contains('obal')) return TypKarty.vratnyObal;
  return TypKarty.jednoducha;
}
