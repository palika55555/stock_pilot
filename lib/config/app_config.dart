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
  static const String apiBase = '$backendApiBase$apiPrefix';

  /// URL JSON manifestu s najnovšou verziou aplikácie (napr. GitHub raw).
  /// Príklad:
  /// `https://raw.githubusercontent.com/OWNER/repo/main/config/version.json`
  /// Prázdne = kontrola aktualizácií vypnutá.
  static const String appUpdateManifestUrlDefault = '';

  /// Priorita: `--dart-define=APP_UPDATE_MANIFEST_URL=...` → potom [appUpdateManifestUrlDefault].
  static String get appUpdateManifestUrl {
    const env = String.fromEnvironment('APP_UPDATE_MANIFEST_URL');
    if (env.isNotEmpty) return env;
    return appUpdateManifestUrlDefault;
  }
}
