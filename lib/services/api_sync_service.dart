import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import '../models/customer.dart';
import '../models/product.dart';

/// Backend API pre sync do PostgreSQL (zákazníci, produkty, login).
/// Všetky volania (dotahovanie zákazníkov, sync produktov, login) používajú rovnakú _apiBase.
/// Pre Coolify/Raspberry zmeň kBackendApiBase na URL svojho backendu (bez koncového lomítka).
const String kBackendApiBase = 'https://backend.stockpilot.sk';

/// Tajný path prefix pre API – musí zodpovedať API_PATH_PREFIX na serveri (obfuskovácia endpointov).
const String kApiPathPrefix = 'sp-9f2a4e1b';

/// Jedna base URL pre všetky endpointy: auth, customers, products, sync.
String get _apiBase => '$kBackendApiBase/api/$kApiPathPrefix';

/// Token z posledného úspešného prihlásenia na backend – používa sa pre GET /customers v apke.
String? _backendToken;

void setBackendToken(String? token) {
  _backendToken = token;
}

String? getBackendToken() => _backendToken;

/// Pošle používateľa (vrátane hesla) do backendu, aby prihlásenie na stockpilot.sk fungovalo rovnako.
/// Volaj po úspešnom lokálnom prihlásení. Počkaj na dokončenie, aby backend login potom našiel toho istého používateľa.
Future<void> syncUserToBackend(User user) async {
  try {
    final uri = Uri.parse('$_apiBase/auth/sync-user');
    final body = jsonEncode({
      'username': user.username,
      'password': user.password,
      'full_name': user.fullName,
      'role': user.role,
      'email': user.email,
      'phone': user.phone,
      'department': user.department,
      'avatar_url': user.avatarUrl,
    });
    await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(const Duration(seconds: 8));
  } catch (_) {
    // offline alebo chyba – ďalej skúsime backend login (môže ísť ak bol user syncnutý skôr)
  }
}

/// Pošle zoznam zákazníkov do backendu – dashboard na webe zobrazí rovnaký počet.
/// Volaj po prihlásení a po pridaní/úprave zákazníka. Vyžaduje token (backend vracia 401 bez neho).
void syncCustomersToBackend(List<Customer> customers) {
  if (customers.isEmpty) return;
  final token = getBackendToken();
  if (token == null || token.isEmpty) return;
  final uri = Uri.parse('$_apiBase/sync/customers');
  final body = jsonEncode({
    'customers': customers.map((c) => c.toMap()).toList(),
  });
  http
      .post(
        uri,
        headers: {'Content-Type': 'application/json', 'Authorization': token},
        body: body,
      )
      .timeout(const Duration(seconds: 10))
      .ignore();
}

/// Pošle zoznam produktov do backendu – webové skenovanie potom zobrazí názov a množstvo.
/// Vyžaduje token (backend vracia 401 bez neho). Volaj po prihlásení alebo pri „Odoslať“ na Domove.
void syncProductsToBackend(List<Product> products) {
  if (products.isEmpty) return;
  final token = getBackendToken();
  if (token == null || token.isEmpty) return;
  final uri = Uri.parse('$_apiBase/sync/products');
  final body = jsonEncode({
    'products': products.map((p) => {
          'uniqueId': p.uniqueId,
          'name': p.name,
          'plu': p.plu,
          'ean': p.ean,
          'unit': p.unit,
          'warehouseId': p.warehouseId,
          'qty': p.qty,
        }).toList(),
  });
  http
      .post(
        uri,
        headers: {'Content-Type': 'application/json', 'Authorization': token},
        body: body,
      )
      .timeout(const Duration(seconds: 15))
      .ignore();
}

/// Prihlásenie na backend (rovnaké údaje ako lokálne) – vráti token alebo null pri chybe.
/// Token potom použite pre [fetchCustomersFromBackendWithToken].
Future<String?> fetchBackendToken(String username, String password) async {
  try {
    final uri = Uri.parse('$_apiBase/auth/login');
    final res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'username': username, 'password': password}),
        )
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return null;
    final map = jsonDecode(res.body) as Map<String, dynamic>?;
    final token = map?['token'] as String?;
    return token != null && token.isNotEmpty ? token : null;
  } catch (_) {
    return null;
  }
}

/// Stiahne zákazníkov z backendu (použije uložený token ak je z prihlásenia).
Future<List<Map<String, dynamic>>?> fetchCustomersFromBackend() async {
  return fetchCustomersFromBackendWithToken(getBackendToken());
}

/// Stiahne zoznam produktov z backendu (EAN priradené na webe sa tým dostanú do apky).
/// [token] z [fetchBackendToken]. Pri null/chybe vráti null.
Future<List<Map<String, dynamic>>?> fetchProductsFromBackendWithToken(String? token) async {
  try {
    final uri = Uri.parse('$_apiBase/products');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) headers['Authorization'] = token;
    final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    final list = jsonDecode(res.body) as List<dynamic>?;
    if (list == null) return null;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  } catch (_) {
    return null;
  }
}

/// Stiahne zoznam zákazníkov z backendu (vrátane úprav z webu).
/// [token] z [fetchBackendToken] – ak null, request zlyhá (401), vráti null.
/// Pri null/chybe vráti null. Nikdy nenahradzujte lokálnu DB prázdnym zoznamom.
Future<List<Map<String, dynamic>>?> fetchCustomersFromBackendWithToken(String? token) async {
  try {
    final uri = Uri.parse('$_apiBase/customers');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) headers['Authorization'] = token;
    final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    final list = jsonDecode(res.body) as List<dynamic>?;
    if (list == null) return null;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  } catch (_) {
    return null;
  }
}

/// Kontrola či boli na webe zmeny (GET /api/sync/check). Používa [SyncCheckService].
Future<Map<String, dynamic>?> fetchSyncCheck() async {
  try {
    final uri = Uri.parse('$_apiBase/sync/check');
    final res = await http.get(uri).timeout(const Duration(seconds: 8));
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    final map = jsonDecode(res.body) as Map<String, dynamic>?;
    return map;
  } catch (_) {
    return null;
  }
}
