/// Centrálna konfigurácia aplikácie.
/// Meniť tu — nie v business kóde.
class AppConfig {
  AppConfig._();

  /// Base URL backendu (bez trailing slash).
  static const String backendApiBase = 'https://backend.stockpilot.sk';

  /// API prefix – backend montuje router na /api/:API_PATH_PREFIX/.
  /// Bez tohto prefixu backend vráti 404.
  static const String apiPrefix = '/api/sp-9f2a4e1b';

  /// Plná base URL pre API volania.
  static String get apiBase => '$backendApiBase$apiPrefix';
}
