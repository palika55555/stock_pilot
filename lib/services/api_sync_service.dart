import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import '../models/customer.dart';
import '../models/product.dart';
import 'Database/database_service.dart';
import 'auth_storage_service.dart';

/// Backend API pre sync do PostgreSQL (zákazníci, produkty, login).
/// JWT: access token v pamäti + secure storage, refresh token len v secure storage.
const String kBackendApiBase = 'https://backend.stockpilot.sk';
const String kApiPathPrefix = 'sp-9f2a4e1b';
String get _apiBase => '$kBackendApiBase/api/$kApiPathPrefix';

String? _backendToken;

void setBackendToken(String? token) {
  _backendToken = token;
}

String? getBackendToken() => _backendToken;

/// Authorization header value for API: "Bearer <jwt>"
String _bearer(String? token) =>
    (token != null && token.isNotEmpty) ? 'Bearer $token' : '';

/// Save JWT tokens to secure storage and set in-memory access token.
Future<void> saveTokensAndSet(String accessToken, String refreshToken) async {
  await AuthStorageService.instance.saveTokens(
    accessToken: accessToken,
    refreshToken: refreshToken,
  );
  _backendToken = accessToken;
}

/// Clear secure storage and in-memory token (call on logout).
Future<void> clearTokensAndToken() async {
  await AuthStorageService.instance.clearTokens();
  _backendToken = null;
}

/// Restore access token from secure storage (e.g. after app restart).
Future<String?> getBackendTokenAsync() async {
  if (_backendToken != null && _backendToken!.isNotEmpty) return _backendToken;
  final stored = await AuthStorageService.instance.getAccessToken();
  if (stored != null && stored.isNotEmpty) {
    _backendToken = stored;
    return stored;
  }
  return null;
}

/// Use refresh token to get new access token. Saves and sets new tokens. Returns new access or null.
Future<String?> refreshAccessToken() async {
  final refresh = await AuthStorageService.instance.getRefreshToken();
  if (refresh == null || refresh.isEmpty) return null;
  try {
    final uri = Uri.parse('$_apiBase/auth/refresh');
    final res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refreshToken': refresh}),
        )
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return null;
    final map = jsonDecode(res.body) as Map<String, dynamic>?;
    final access = map?['accessToken'] as String?;
    final newRefresh = map?['refreshToken'] as String?;
    if (access != null && access.isNotEmpty) {
      await saveTokensAndSet(access, newRefresh ?? refresh);
      return access;
    }
  } catch (_) {}
  return null;
}

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
        headers: {'Content-Type': 'application/json', 'Authorization': _bearer(token)},
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
        headers: {'Content-Type': 'application/json', 'Authorization': _bearer(token)},
        body: body,
      )
      .timeout(const Duration(seconds: 15))
      .ignore();
}

/// Prihlásenie na backend – JWT. Uloží access + refresh do secure storage a nastaví in-memory token.
/// [rememberMe] => access token 7 dní, inak 24h. Vráti accessToken alebo null.
Future<String?> fetchBackendToken(String username, String password, {bool rememberMe = false}) async {
  try {
    final uri = Uri.parse('$_apiBase/auth/login');
    final res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'username': username, 'password': password, 'rememberMe': rememberMe}),
        )
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return null;
    final map = jsonDecode(res.body) as Map<String, dynamic>?;
    final access = map?['accessToken'] as String?;
    final refresh = map?['refreshToken'] as String?;
    if (access != null && access.isNotEmpty && refresh != null && refresh.isNotEmpty) {
      await saveTokensAndSet(access, refresh);
      return access;
    }
    return null;
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
    if (token != null && token.isNotEmpty) headers['Authorization'] = _bearer(token);
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
    if (token != null && token.isNotEmpty) headers['Authorization'] = _bearer(token);
    final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    final list = jsonDecode(res.body) as List<dynamic>?;
    if (list == null) return null;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  } catch (_) {
    return null;
  }
}

/// Pošle všetky šarže a palety do backendu – web potom zobrazí rovnaké šarže.
/// Volaj po prihlásení a po vytvorení/úprave šarže alebo paliet. Vyžaduje token.
Future<void> syncBatchesToBackend() async {
  final token = getBackendToken();
  if (token == null || token.isEmpty) return;
  try {
    final db = DatabaseService();
    final batches = await db.getProductionBatchesByDateRange('2020-01-01', '2099-12-31');
    final batchPayloads = <Map<String, dynamic>>[];
    final palletPayloads = <Map<String, dynamic>>[];
    for (final b in batches) {
      if (b.id == null) continue;
      final recipe = await db.getRecipeForBatch(b.id!);
      batchPayloads.add({
        'id': b.id,
        'production_date': b.productionDate,
        'product_type': b.productType,
        'quantity_produced': b.quantityProduced,
        'notes': b.notes,
        'created_at': b.createdAt,
        'cost_total': b.costTotal,
        'revenue_total': b.revenueTotal,
        'recipe': recipe
            .map((r) => {
                  'material_name': r.materialName,
                  'quantity': r.quantity,
                  'unit': r.unit,
                })
            .toList(),
      });
      final pallets = await db.getPalletsByBatchId(b.id!);
      for (final p in pallets) {
        if (p.id == null) continue;
        palletPayloads.add({
          'id': p.id,
          'batch_id': p.batchId,
          'product_type': p.productType,
          'quantity': p.quantity,
          'customer_id': p.customerId,
          'status': p.status.label,
        });
      }
    }
    final uri = Uri.parse('$_apiBase/sync/batches');
    final res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json', 'Authorization': _bearer(token)},
          body: jsonEncode({'batches': batchPayloads, 'pallets': palletPayloads}),
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      print('syncBatchesToBackend failed: ${res.statusCode} ${res.body}');
    }
  } catch (e, st) {
    print('syncBatchesToBackend error: $e');
    if (st != null) print(st);
  }
}

/// Stiahne šarže (s receptami a paletami) z backendu – rovnaký princíp ako zákazníci.
/// Vráti zoznam šarží alebo null pri chybe. Potom volaj [DatabaseService.replaceBatchesFromBackend].
Future<List<Map<String, dynamic>>?> fetchBatchesFromBackendWithToken(String? token) async {
  if (token == null || token.isEmpty) return null;
  try {
    final uri = Uri.parse('$_apiBase/batches/sync?from=2020-01-01&to=2099-12-31');
    final res = await http
        .get(uri, headers: {'Content-Type': 'application/json', 'Authorization': _bearer(token)})
        .timeout(const Duration(seconds: 15));
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    final map = jsonDecode(res.body) as Map<String, dynamic>?;
    final list = map?['batches'] as List<dynamic>?;
    if (list == null) return null;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  } catch (_) {
    return null;
  }
}

/// Kontrola či boli na webe zmeny (GET /api/sync/check). Vyžaduje [token] – bez neho backend vracia 401.
Future<Map<String, dynamic>?> fetchSyncCheck({String? token}) async {
  try {
    final uri = Uri.parse('$_apiBase/sync/check');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) headers['Authorization'] = _bearer(token);
    final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 8));
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    final map = jsonDecode(res.body) as Map<String, dynamic>?;
    return map;
  } catch (_) {
    return null;
  }
}
