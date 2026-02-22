/// Jedna položka receptúry – odkaz na surovinu (SkladovaKarta/Product) a množstvo.
class RecepturaPolozka {
  /// Unique ID suroviny (product.unique_id).
  final String idSuroviny;
  /// Množstvo suroviny na jednu jednotku receptúry.
  final double mnozstvo;

  const RecepturaPolozka({
    required this.idSuroviny,
    required this.mnozstvo,
  });

  Map<String, dynamic> toMap({String? recepturaKartaId}) {
    final m = <String, dynamic>{
      'id_suroviny': idSuroviny,
      'mnozstvo': _round3(mnozstvo),
    };
    if (recepturaKartaId != null) m['receptura_karta_id'] = recepturaKartaId;
    return m;
  }

  factory RecepturaPolozka.fromMap(Map<String, dynamic> map) {
    return RecepturaPolozka(
      idSuroviny: map['id_suroviny'] as String? ?? '',
      mnozstvo: (map['mnozstvo'] as num?)?.toDouble() ?? 0.0,
    );
  }

  static double _round3(double v) {
    return (v * 1000).round() / 1000;
  }
}
