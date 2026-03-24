/// Parametre vozidla pre OpenRouteService profil driving-hgv (mosty, hmotnosť, rozmery).
class HgvRoutingOptions {
  const HgvRoutingOptions({
    this.heightM = 10.0,
    this.weightT = 40.0,
    this.lengthM = 16.5,
    this.widthM = 2.55,
  });

  /// Max. výška vozidla (m) – nízke mosty / podjazdy.
  final double heightM;

  /// Celková hmotnosť (t).
  final double weightT;

  /// Max. dĺžka súpravy (m).
  final double lengthM;

  /// Max. šírka (m).
  final double widthM;

  static const HgvRoutingOptions defaults = HgvRoutingOptions();

  /// Parsovanie z textových polí; neplatné hodnoty nahradí defaultmi a oreže do povoleného rozsahu.
  factory HgvRoutingOptions.fromTextFields({
    required String heightText,
    required String weightText,
    required String lengthText,
    required String widthText,
  }) {
    double p(String s, double def) {
      final v = double.tryParse(s.trim().replaceAll(',', '.'));
      return v ?? def;
    }

    return HgvRoutingOptions(
      heightM: p(heightText, defaults.heightM).clamp(2.0, 25.0),
      weightT: p(weightText, defaults.weightT).clamp(3.5, 100.0),
      lengthM: p(lengthText, defaults.lengthM).clamp(5.0, 25.0),
      widthM: p(widthText, defaults.widthM).clamp(2.0, 3.5),
    );
  }

  /// Teleso `restrictions` pre OpenRouteService.
  Map<String, dynamic> toOrsRestrictions() => {
        'height': heightM,
        'weight': weightT,
        'length': lengthM,
        'width': widthM,
      };
}
