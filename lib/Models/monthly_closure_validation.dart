/// Výsledok kontrol pred uzavretím mesiaca.
class MonthlyClosureValidationResult {
  final List<String> blocking;
  final List<String> warnings;

  const MonthlyClosureValidationResult({
    required this.blocking,
    required this.warnings,
  });

  bool get canClose => blocking.isEmpty;

  bool get hasWarnings => warnings.isNotEmpty;

  static const empty = MonthlyClosureValidationResult(blocking: [], warnings: []);
}
