import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import '../models/customer.dart';
import '../models/project.dart';
import '../models/product.dart';
import '../models/warehouse.dart';
import '../models/supplier.dart';
import 'Database/database_service.dart';
import 'Auth/hash_service.dart';
import 'auth_storage_service.dart';
import '../config/app_config.dart';

/// Backend API pre sync do PostgreSQL (zákazníci, produkty, login).
/// JWT: access token v pamäti + secure storage, refresh token len v secure storage.
///
/// Všetky requesty musia ísť na baseUrl + apiPrefix (napr. /api/sp-9f2a4e1b).
/// Backend montuje router na /api/:API_PATH_PREFIX/ – bez tohto prefixu 404.

String? _backendToken;

void setBackendToken(String? token) {
  _backendToken = token;
}

String? getBackendToken() => _backendToken;

/// Authorization header value for API: "Bearer token"
String _bearer(String? token) =>
    (token != null && token.isNotEmpty) ? 'Bearer $token' : '';

/// Výsledok backend loginu – prístupový token, refresh token, userId a voliteľný profil z backendu (pre vytvorenie/aktualizáciu lokálneho používateľa).
class BackendLoginResult {
  final String? accessToken;
  final String? refreshToken;
  final String? userId;
  final Map<String, dynamic>? userProfile;
  final bool requires2fa;
  final bool requires2faSetup;
  final String? loginChallengeToken;

  /// Nadriadený (owner) – ak je prihlásený sub-user.
  final String? ownerId;
  final String? ownerUsername;
  final String? ownerFullName;

  BackendLoginResult({
    this.accessToken,
    this.refreshToken,
    this.userId,
    this.userProfile,
    this.requires2fa = false,
    this.requires2faSetup = false,
    this.loginChallengeToken,
    this.ownerId,
    this.ownerUsername,
    this.ownerFullName,
  });
}

/// Z profilu vráteného backendom pri prihlásení (a hesla z formulára) vytvorí model User pre lokálnu DB.
User userFromBackendProfile(String username, String password, Map<String, dynamic>? profile) {
  final p = profile ?? {};
  // Nikdy neukladáme plaintext heslo — vždy hashujeme.
  final salt = HashService.generateSalt();
  final hashedPassword = HashService.hashPassword(password, salt);
  return User(
    id: null,
    username: p['username']?.toString() ?? username,
    password: hashedPassword,
    passwordSalt: salt,
    fullName: p['full_name']?.toString() ?? p['fullName']?.toString() ?? username,
    role: p['role']?.toString() ?? 'user',
    email: p['email']?.toString() ?? '',
    phone: p['phone']?.toString() ?? '',
    department: p['department']?.toString() ?? '',
    avatarUrl: p['avatar_url']?.toString() ?? p['avatarUrl']?.toString() ?? 'https://i.pravatar.cc/150?u=$username',
    joinDate: DateTime.now(),
  );
}

/// Save JWT tokens to secure storage and set in-memory access token.
Future<void> saveTokensAndSet(
  String accessToken,
  String refreshToken, {
  String? userId,
}) async {
  await AuthStorageService.instance.saveTokens(
    accessToken: accessToken,
    refreshToken: refreshToken,
  );
  if (userId != null && userId.isNotEmpty) {
    await AuthStorageService.instance.saveUserId(userId);
  }
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
    final uri = Uri.parse('${AppConfig.apiBase}/auth/refresh');
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
/// Ak je aktuálne prihlásený admin a pridáva kolegu (role=user), posielame token – backend nastaví owner_id,
/// takže kolega sa zobrazí v "Moji kolegovia" na webe.
Future<void> syncUserToBackend(User user) async {
  try {
    final uri = Uri.parse('${AppConfig.apiBase}/auth/sync-user');
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
    final token = getBackendToken();
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': _bearer(token),
    };
    await http
        .post(uri, headers: headers, body: body)
        .timeout(const Duration(seconds: 8));
  } catch (_) {
    // offline alebo chyba – ďalej skúsime backend login (môže ísť ak bol user syncnutý skôr)
  }
}

/// Pošle zoznam zákazníkov do backendu – dashboard na webe zobrazí rovnaký počet.
/// Volaj po prihlásení a po pridaní/úprave zákazníka. Vyžaduje token (backend vracia 401 bez neho).
/// Vráti Future, ktoré dokončí po úspešnom odoslaní – po await volaj [SyncCheckService.updateLastKnownFromServer],
/// aby sa nezobrazila hláška „Na webe boli zmeny v zákazníkoch“.
Future<void> syncCustomersToBackend(List<Customer> customers) async {
  if (customers.isEmpty) return;
  final token = getBackendToken();
  if (token == null || token.isEmpty) return;
  final uri = Uri.parse('${AppConfig.apiBase}/sync/customers');
  final body = jsonEncode({
    'customers': customers.map((c) => c.toMap()).toList(),
  });
  final res = await http
      .post(
        uri,
        headers: {'Content-Type': 'application/json', 'Authorization': _bearer(token)},
        body: body,
      )
      .timeout(const Duration(seconds: 10));
  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw Exception('sync customers failed: ${res.statusCode}');
  }
}

/// Pošle zoznam zákaziek do backendu.
Future<void> syncProjectsToBackend(List<Project> projects) async {
  final token = getBackendToken();
  if (token == null || token.isEmpty) return;
  final uri = Uri.parse('${AppConfig.apiBase}/sync/projects');
  final body = jsonEncode({'projects': projects.map((p) => p.toMap()).toList()});
  final res = await http
      .post(uri, headers: {'Content-Type': 'application/json', 'Authorization': _bearer(token)}, body: body)
      .timeout(const Duration(seconds: 10));
  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw Exception('sync projects failed: ${res.statusCode}');
  }
}

/// Stiahne zákazky z backendu.
Future<List<Map<String, dynamic>>?> fetchProjectsFromBackend() async {
  final token = getBackendToken();
  if (token == null || token.isEmpty) return null;
  try {
    final uri = Uri.parse('${AppConfig.apiBase}/projects');
    final res = await http
        .get(uri, headers: {'Content-Type': 'application/json', 'Authorization': _bearer(token)})
        .timeout(const Duration(seconds: 10));
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    final list = jsonDecode(res.body) as List<dynamic>?;
    if (list == null) return null;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  } catch (_) {
    return null;
  }
}

int _qtyIntForSync(double q) {
  if (!q.isFinite) return 0;
  return q.round();
}

/// Pošle zoznam produktov do backendu – webové skenovanie potom zobrazí názov a množstvo.
/// Vyžaduje token (backend vracia 401 bez neho). Volaj po prihlásení alebo pri „Odoslať“ na Domove.
Future<void> syncProductsToBackend(List<Product> products) async {
  if (products.isEmpty) return;
  final token = getBackendToken();
  if (token == null || token.isEmpty) return;
  final uri = Uri.parse('${AppConfig.apiBase}/sync/products');
  final payload = <Map<String, dynamic>>[];
  for (final p in products) {
    final uid = p.uniqueId?.trim();
    if (uid == null || uid.isEmpty) continue;
    payload.add({
      'uniqueId': uid,
      'name': p.name,
      'plu': p.plu,
      'ean': p.ean,
      'unit': p.unit,
      'warehouseId': p.warehouseId,
      'qty': _qtyIntForSync(p.qty),
    });
  }
  if (payload.isEmpty) return;
  final body = jsonEncode({'products': payload});
  final timeout = Duration(seconds: payload.length > 800 ? 120 : 15);
  final res = await http
      .post(
        uri,
        headers: {'Content-Type': 'application/json', 'Authorization': _bearer(token)},
        body: body,
      )
      .timeout(timeout);
  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw Exception('sync products failed: ${res.statusCode} ${res.body}');
  }
}

/// Pošle zoznam skladov do backendu – web zobrazí sklady.
Future<void> syncWarehousesToBackend(List<Warehouse> warehouses) async {
  if (warehouses.isEmpty) return;
  final token = getBackendToken();
  if (token == null || token.isEmpty) return;
  final uri = Uri.parse('${AppConfig.apiBase}/sync/warehouses');
  final body = jsonEncode({
    'warehouses': warehouses.map((w) => w.toMap()).toList(),
  });
  final res = await http
      .post(
        uri,
        headers: {'Content-Type': 'application/json', 'Authorization': _bearer(token)},
        body: body,
      )
      .timeout(const Duration(seconds: 10));
  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw Exception('sync warehouses failed: ${res.statusCode}');
  }
}

/// Pošle zoznam dodávateľov do backendu – web zobrazí dodávateľov.
Future<void> syncSuppliersToBackend(List<Supplier> suppliers) async {
  if (suppliers.isEmpty) return;
  final token = getBackendToken();
  if (token == null || token.isEmpty) return;
  final uri = Uri.parse('${AppConfig.apiBase}/sync/suppliers');
  final body = jsonEncode({
    'suppliers': suppliers.map((s) => s.toMap()).toList(),
  });
  final res = await http
      .post(
        uri,
        headers: {'Content-Type': 'application/json', 'Authorization': _bearer(token)},
        body: body,
      )
      .timeout(const Duration(seconds: 10));
  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw Exception('sync suppliers failed: ${res.statusCode}');
  }
}

/// Prihlásenie na backend – JWT. Uloží access + refresh + userId do secure storage a nastaví in-memory token.
/// [rememberMe] => access token 7 dní, inak 24h. Vráti detaily loginu alebo null.
Future<BackendLoginResult?> fetchBackendToken(
  String username,
  String password, {
  bool rememberMe = false,
}) async {
  try {
    final uri = Uri.parse('${AppConfig.apiBase}/auth/login');
    final res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          // Nikdy nelogujeme heslo.
          body: jsonEncode({'username': username, 'password': password, 'rememberMe': rememberMe}),
        )
        .timeout(const Duration(seconds: 10));

    if (res.statusCode != 200) {
      return null;
    }
    final map = jsonDecode(res.body) as Map<String, dynamic>?;
    final access = map?['accessToken'] as String?;
    final refresh = map?['refreshToken'] as String?;
    final requires2fa = map?['requires2fa'] == true;
    final requires2faSetup = map?['requires2faSetup'] == true;
    final loginChallengeToken = map?['loginChallengeToken'] as String?;
    String? userId;
    String? ownerId;
    String? ownerUsername;
    String? ownerFullName;
    final user = map?['user'];
    if (user is Map<String, dynamic>) {
      final rawId = user['id'];
      if (rawId != null) {
        userId = rawId.toString();
      }
      final rawOwnerId = user['ownerId'];
      if (rawOwnerId != null) {
        ownerId = rawOwnerId.toString();
      }
      ownerUsername = user['ownerUsername']?.toString();
      ownerFullName = user['ownerFullName']?.toString();
    }
    if ((requires2fa || requires2faSetup) && loginChallengeToken != null && loginChallengeToken.isNotEmpty) {
      return BackendLoginResult(
        requires2fa: requires2fa,
        requires2faSetup: requires2faSetup,
        loginChallengeToken: loginChallengeToken,
      );
    }
    if (access != null && access.isNotEmpty && refresh != null && refresh.isNotEmpty) {
      await saveTokensAndSet(access, refresh, userId: userId);
      return BackendLoginResult(
        accessToken: access,
        refreshToken: refresh,
        userId: userId,
        userProfile: user is Map<String, dynamic> ? Map<String, dynamic>.from(user) : null,
        ownerId: ownerId,
        ownerUsername: ownerUsername,
        ownerFullName: ownerFullName,
      );
    }
    return null;
  } catch (_) {
    return null;
  }
}

Future<BackendLoginResult?> verify2faLogin({
  required String loginChallengeToken,
  String? totpCode,
  String? backupCode,
}) async {
  try {
    final uri = Uri.parse('${AppConfig.apiBase}/auth/2fa/verify');
    final res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'loginChallengeToken': loginChallengeToken,
            if (totpCode != null && totpCode.isNotEmpty) 'totpCode': totpCode,
            if (backupCode != null && backupCode.isNotEmpty) 'backupCode': backupCode,
          }),
        )
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return null;
    final map = jsonDecode(res.body) as Map<String, dynamic>?;
    final access = map?['accessToken'] as String?;
    final refresh = map?['refreshToken'] as String?;
    final user = map?['user'];
    String? userId;
    String? ownerId;
    String? ownerUsername;
    String? ownerFullName;
    if (user is Map<String, dynamic>) {
      final rawId = user['id'];
      if (rawId != null) userId = rawId.toString();
      final rawOwnerId = user['ownerId'];
      if (rawOwnerId != null) ownerId = rawOwnerId.toString();
      ownerUsername = user['ownerUsername']?.toString();
      ownerFullName = user['ownerFullName']?.toString();
    }
    if (access == null || access.isEmpty || refresh == null || refresh.isEmpty) return null;
    await saveTokensAndSet(access, refresh, userId: userId);
    return BackendLoginResult(
      accessToken: access,
      refreshToken: refresh,
      userId: userId,
      userProfile: user is Map<String, dynamic> ? Map<String, dynamic>.from(user) : null,
      ownerId: ownerId,
      ownerUsername: ownerUsername,
      ownerFullName: ownerFullName,
    );
  } catch (_) {
    return null;
  }
}

Future<Map<String, dynamic>?> setup2faWithChallenge(String loginChallengeToken) async {
  try {
    final uri = Uri.parse('${AppConfig.apiBase}/auth/2fa/setup');
    final res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'loginChallengeToken': loginChallengeToken}),
        )
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return null;
    final map = jsonDecode(res.body) as Map<String, dynamic>?;
    if (map?['success'] == true) return map;
  } catch (_) {}
  return null;
}

Future<BackendLoginResult?> confirm2faSetup({
  required String loginChallengeToken,
  required String totpCode,
}) async {
  try {
    final uri = Uri.parse('${AppConfig.apiBase}/auth/2fa/confirm');
    final res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'loginChallengeToken': loginChallengeToken, 'totpCode': totpCode}),
        )
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return null;
    final map = jsonDecode(res.body) as Map<String, dynamic>?;
    final access = map?['accessToken'] as String?;
    final refresh = map?['refreshToken'] as String?;
    final user = map?['user'];
    String? userId;
    String? ownerId;
    String? ownerUsername;
    String? ownerFullName;
    if (user is Map<String, dynamic>) {
      final rawId = user['id'];
      if (rawId != null) userId = rawId.toString();
      final rawOwnerId = user['ownerId'];
      if (rawOwnerId != null) ownerId = rawOwnerId.toString();
      ownerUsername = user['ownerUsername']?.toString();
      ownerFullName = user['ownerFullName']?.toString();
    }
    if (access == null || access.isEmpty || refresh == null || refresh.isEmpty) return null;
    await saveTokensAndSet(access, refresh, userId: userId);
    return BackendLoginResult(
      accessToken: access,
      refreshToken: refresh,
      userId: userId,
      userProfile: user is Map<String, dynamic> ? Map<String, dynamic>.from(user) : null,
      ownerId: ownerId,
      ownerUsername: ownerUsername,
      ownerFullName: ownerFullName,
    );
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
/// Načíta všetky stránky (API má max. 100 položiek na stránku pri ?page=).
Future<List<Map<String, dynamic>>?> fetchProductsFromBackendWithToken(String? token) async {
  try {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) headers['Authorization'] = _bearer(token);
    const pageSize = 100;
    const maxPages = 500;
    final all = <Map<String, dynamic>>[];
    final seenKeys = <String>{};
    var page = 1;
    while (true) {
      final uri = Uri.parse('${AppConfig.apiBase}/products').replace(
        queryParameters: {'page': '$page', 'limit': '$pageSize'},
      );
      final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 60));
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic> && decoded['items'] is List) {
        final items = decoded['items'] as List<dynamic>;
        final total = (decoded['total'] as num?)?.toInt() ?? 0;
        for (final e in items) {
          if (e is! Map) continue;
          final map = Map<String, dynamic>.from(e);
          final key = (map['unique_id'] ?? map['id'])?.toString();
          if (key != null && key.isNotEmpty) {
            if (seenKeys.add(key)) all.add(map);
          } else {
            all.add(map);
          }
        }
        if (all.length >= total || items.isEmpty) break;
        page++;
        if (page > maxPages) break;
        continue;
      }
      // Fallback: niektoré deploye vracajú priamo List bez total/items.
      // V takom prípade iterujeme cez page, kým pribúdajú nové položky.
      if (decoded is List<dynamic>) {
        if (decoded.isEmpty) break;
        var addedThisPage = 0;
        for (final e in decoded) {
          if (e is! Map) continue;
          final map = Map<String, dynamic>.from(e);
          final key = (map['unique_id'] ?? map['id'])?.toString();
          if (key != null && key.isNotEmpty) {
            if (seenKeys.add(key)) {
              all.add(map);
              addedThisPage++;
            }
          } else {
            all.add(map);
            addedThisPage++;
          }
        }
        // Ak backend ignoruje page a posiela stále tú istú prvú stránku,
        // zastavíme sa, aby sme sa necyklili do nekonečna.
        if (addedThisPage == 0 || decoded.length < pageSize) break;
        page++;
        if (page > maxPages) break;
        continue;
      }
      return null;
    }
    return all;
  } catch (_) {
    return null;
  }
}

/// Stiahne zoznam zákazníkov z backendu (vrátane úprav z webu).
/// [token] z [fetchBackendToken] – ak null, request zlyhá (401), vráti null.
/// Pri null/chybe vráti null. Nikdy nenahradzujte lokálnu DB prázdnym zoznamom.
Future<List<Map<String, dynamic>>?> fetchCustomersFromBackendWithToken(String? token) async {
  try {
    final uri = Uri.parse('${AppConfig.apiBase}/customers');
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
    final uri = Uri.parse('${AppConfig.apiBase}/sync/batches');
    final res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json', 'Authorization': _bearer(token)},
          body: jsonEncode({'batches': batchPayloads, 'pallets': palletPayloads}),
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      // sync failed silently
    }
  } catch (_) {
    // ignore errors
  }
}

/// Stiahne šarže (s receptami a paletami) z backendu – rovnaký princíp ako zákazníci.
/// Vráti zoznam šarží alebo null pri chybe. Potom volaj [DatabaseService.replaceBatchesFromBackend].
Future<List<Map<String, dynamic>>?> fetchBatchesFromBackendWithToken(String? token) async {
  if (token == null || token.isEmpty) return null;
  try {
    final uri = Uri.parse('${AppConfig.apiBase}/batches/sync?from=2020-01-01&to=2099-12-31');
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
    final uri = Uri.parse('${AppConfig.apiBase}/sync/check');
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

// ============================================================
// SYNC: Prijemky
// ============================================================

/// Pošle všetky prijemky (vrátane položiek a nákladov) do backendu.
Future<void> syncReceiptsToBackend() async {
  final token = getBackendToken();
  if (token == null || token.isEmpty) return;
  try {
    final db = DatabaseService();
    final receipts = await db.getInboundReceipts();
    final receiptPayloads = <Map<String, dynamic>>[];
    final itemPayloads = <Map<String, dynamic>>[];
    final costPayloads = <Map<String, dynamic>>[];
    for (final r in receipts) {
      if (r.id == null) continue;
      final map = r.toMap();
      map['local_id'] = r.id;
      map.remove('id');
      // linked_stock_out_id → local_id referencia
      map['linked_stock_out_local_id'] = map.remove('linked_stock_out_id');
      receiptPayloads.add(map);
      final items = await db.getInboundReceiptItems(r.id!);
      for (final item in items) {
        if (item.id == null) continue;
        final im = item.toMap();
        im['local_id'] = item.id;
        im.remove('id');
        im['receipt_local_id'] = r.id;
        im.remove('receipt_id');
        itemPayloads.add(im);
      }
      final costs = await db.getReceiptAcquisitionCosts(r.id!);
      for (final cost in costs) {
        if (cost.id == null) continue;
        final cm = cost.toMap();
        cm['local_id'] = cost.id;
        cm.remove('id');
        cm['receipt_local_id'] = r.id;
        cm.remove('receipt_id');
        costPayloads.add(cm);
      }
    }
    final uri = Uri.parse('${AppConfig.apiBase}/sync/receipts');
    final res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json', 'Authorization': _bearer(token)},
          body: jsonEncode({'receipts': receiptPayloads, 'items': itemPayloads, 'costs': costPayloads}),
        )
        .timeout(const Duration(seconds: 30));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      // sync failed silently
    }
  } catch (_) {
    // ignore errors
  }
}

/// Stiahne všetky prijemky z backendu.
Future<Map<String, dynamic>?> fetchReceiptsFromBackend(String token) async {
  try {
    final uri = Uri.parse('${AppConfig.apiBase}/receipts/all');
    final res = await http
        .get(uri, headers: {'Content-Type': 'application/json', 'Authorization': _bearer(token)})
        .timeout(const Duration(seconds: 20));
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    return jsonDecode(res.body) as Map<String, dynamic>?;
  } catch (_) {
    return null;
  }
}

// ============================================================
// SYNC: Výdajky
// ============================================================

/// Pošle všetky výdajky (vrátane položiek a pohybov) do backendu.
Future<void> syncStockOutsToBackend() async {
  final token = getBackendToken();
  if (token == null || token.isEmpty) return;
  try {
    final db = DatabaseService();
    final outs = await db.getStockOuts();
    final outPayloads = <Map<String, dynamic>>[];
    final itemPayloads = <Map<String, dynamic>>[];
    final movementPayloads = <Map<String, dynamic>>[];
    for (final s in outs) {
      if (s.id == null) continue;
      final map = s.toMap();
      map['local_id'] = s.id;
      map.remove('id');
      map['linked_receipt_local_id'] = map.remove('linked_receipt_id');
      outPayloads.add(map);
      final items = await db.getStockOutItems(s.id!);
      for (final item in items) {
        if (item.id == null) continue;
        final im = item.toMap();
        im['local_id'] = item.id;
        im.remove('id');
        im['stock_out_local_id'] = s.id;
        im.remove('stock_out_id');
        itemPayloads.add(im);
      }
      final movements = await db.getStockMovementsByStockOutId(s.id!);
      for (final mv in movements) {
        if (mv.id == null) continue;
        final mm = mv.toMap();
        mm['local_id'] = mv.id;
        mm.remove('id');
        mm['stock_out_local_id'] = s.id;
        mm.remove('stock_out_id');
        movementPayloads.add(mm);
      }
    }
    final uri = Uri.parse('${AppConfig.apiBase}/sync/stock-outs');
    final res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json', 'Authorization': _bearer(token)},
          body: jsonEncode({'stock_outs': outPayloads, 'items': itemPayloads, 'movements': movementPayloads}),
        )
        .timeout(const Duration(seconds: 30));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      // sync failed silently
    }
  } catch (_) {
    // ignore errors
  }
}

/// Stiahne všetky výdajky z backendu.
Future<Map<String, dynamic>?> fetchStockOutsFromBackend(String token) async {
  try {
    final uri = Uri.parse('${AppConfig.apiBase}/stock-outs/all');
    final res = await http
        .get(uri, headers: {'Content-Type': 'application/json', 'Authorization': _bearer(token)})
        .timeout(const Duration(seconds: 20));
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    return jsonDecode(res.body) as Map<String, dynamic>?;
  } catch (_) {
    return null;
  }
}

// ============================================================
// SYNC: Receptúry
// ============================================================

/// Pošle všetky receptúry (vrátane ingrediencií) do backendu.
Future<void> syncRecipesToBackend() async {
  final token = getBackendToken();
  if (token == null || token.isEmpty) return;
  try {
    final db = DatabaseService();
    final recipes = await db.getRecipes();
    final recipePayloads = <Map<String, dynamic>>[];
    final ingredientPayloads = <Map<String, dynamic>>[];
    for (final r in recipes) {
      if (r.id == null) continue;
      final map = r.toMap();
      map['local_id'] = r.id;
      map.remove('id');
      recipePayloads.add(map);
      final ingredients = await db.getRecipeIngredients(r.id!);
      for (final ing in ingredients) {
        if (ing.id == null) continue;
        final im = ing.toMap();
        im['local_id'] = ing.id;
        im.remove('id');
        im['recipe_local_id'] = r.id;
        im.remove('recipe_id');
        ingredientPayloads.add(im);
      }
    }
    final uri = Uri.parse('${AppConfig.apiBase}/sync/recipes');
    final res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json', 'Authorization': _bearer(token)},
          body: jsonEncode({'recipes': recipePayloads, 'ingredients': ingredientPayloads}),
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      // sync failed silently
    }
  } catch (_) {
    // ignore errors
  }
}

/// Stiahne všetky receptúry z backendu.
Future<Map<String, dynamic>?> fetchRecipesFromBackend(String token) async {
  try {
    final uri = Uri.parse('${AppConfig.apiBase}/recipes/all');
    final res = await http
        .get(uri, headers: {'Content-Type': 'application/json', 'Authorization': _bearer(token)})
        .timeout(const Duration(seconds: 15));
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    return jsonDecode(res.body) as Map<String, dynamic>?;
  } catch (_) {
    return null;
  }
}

// ============================================================
// SYNC: Výrobné príkazy
// ============================================================

/// Pošle všetky výrobné príkazy do backendu.
Future<void> syncProductionOrdersToBackend() async {
  final token = getBackendToken();
  if (token == null || token.isEmpty) return;
  try {
    final db = DatabaseService();
    final orders = await db.getProductionOrders();
    final payloads = <Map<String, dynamic>>[];
    for (final o in orders) {
      if (o.id == null) continue;
      final map = o.toMap();
      map['local_id'] = o.id;
      map.remove('id');
      map['recipe_local_id'] = map.remove('recipe_id');
      map['raw_materials_stock_out_local_id'] = map.remove('raw_materials_stock_out_id');
      map['finished_goods_receipt_local_id'] = map.remove('finished_goods_receipt_id');
      payloads.add(map);
    }
    final uri = Uri.parse('${AppConfig.apiBase}/sync/production-orders');
    final res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json', 'Authorization': _bearer(token)},
          body: jsonEncode({'production_orders': payloads}),
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      // sync failed silently
    }
  } catch (_) {
    // ignore errors
  }
}

/// Stiahne všetky výrobné príkazy z backendu.
Future<Map<String, dynamic>?> fetchProductionOrdersFromBackend(String token) async {
  try {
    final uri = Uri.parse('${AppConfig.apiBase}/production-orders/all');
    final res = await http
        .get(uri, headers: {'Content-Type': 'application/json', 'Authorization': _bearer(token)})
        .timeout(const Duration(seconds: 15));
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    return jsonDecode(res.body) as Map<String, dynamic>?;
  } catch (_) {
    return null;
  }
}

// ============================================================
// SYNC: Cenové ponuky
// ============================================================

/// Pošle všetky cenové ponuky (vrátane položiek) do backendu.
Future<void> syncQuotesToBackend() async {
  final token = getBackendToken();
  if (token == null || token.isEmpty) return;
  try {
    final db = DatabaseService();
    final quotes = await db.getQuotes();
    final quotePayloads = <Map<String, dynamic>>[];
    final itemPayloads = <Map<String, dynamic>>[];
    for (final q in quotes) {
      if (q.id == null) continue;
      final map = q.toMap();
      map['local_id'] = q.id;
      map.remove('id');
      quotePayloads.add(map);
      final items = await db.getQuoteItems(q.id!);
      for (final item in items) {
        if (item.id == null) continue;
        final im = item.toMap();
        im['local_id'] = item.id;
        im.remove('id');
        im['quote_local_id'] = q.id;
        im.remove('quote_id');
        itemPayloads.add(im);
      }
    }
    final uri = Uri.parse('${AppConfig.apiBase}/sync/quotes-full');
    final res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json', 'Authorization': _bearer(token)},
          body: jsonEncode({'quotes': quotePayloads, 'items': itemPayloads}),
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      // sync failed silently
    }
  } catch (_) {
    // ignore errors
  }
}

/// Stiahne všetky cenové ponuky z backendu.
Future<Map<String, dynamic>?> fetchQuotesFromBackend(String token) async {
  try {
    final uri = Uri.parse('${AppConfig.apiBase}/quotes/all');
    final res = await http
        .get(uri, headers: {'Content-Type': 'application/json', 'Authorization': _bearer(token)})
        .timeout(const Duration(seconds: 15));
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    return jsonDecode(res.body) as Map<String, dynamic>?;
  } catch (_) {
    return null;
  }
}

// ============================================================
// SYNC: Transporty
// ============================================================

/// Pošle všetky transporty do backendu.
Future<void> syncTransportsToBackend() async {
  final token = getBackendToken();
  if (token == null || token.isEmpty) return;
  try {
    final db = DatabaseService();
    final transports = await db.getAllTransports();
    final payloads = transports.map((t) {
      final map = t.toMap();
      map['local_id'] = t.id;
      map.remove('id');
      return map;
    }).toList();
    final uri = Uri.parse('${AppConfig.apiBase}/sync/transports');
    final res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json', 'Authorization': _bearer(token)},
          body: jsonEncode({'transports': payloads}),
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      // sync failed silently
    }
  } catch (_) {
    // ignore errors
  }
}

/// Stiahne všetky transporty z backendu.
Future<Map<String, dynamic>?> fetchTransportsFromBackend(String token) async {
  try {
    final uri = Uri.parse('${AppConfig.apiBase}/transports/all');
    final res = await http
        .get(uri, headers: {'Content-Type': 'application/json', 'Authorization': _bearer(token)})
        .timeout(const Duration(seconds: 15));
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    return jsonDecode(res.body) as Map<String, dynamic>?;
  } catch (_) {
    return null;
  }
}

// ============================================================
// SYNC: Firemné údaje
// ============================================================

/// Pošle firemné údaje do backendu.
Future<void> syncCompanyToBackend() async {
  final token = getBackendToken();
  if (token == null || token.isEmpty) return;
  try {
    final db = DatabaseService();
    final company = await db.getCompany();
    if (company == null) return;
    final map = company.toMap();
    map.remove('id');
    map.remove('logo_path');
    final uri = Uri.parse('${AppConfig.apiBase}/sync/company');
    final res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json', 'Authorization': _bearer(token)},
          body: jsonEncode({'company': map}),
        )
        .timeout(const Duration(seconds: 10));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      // sync failed silently
    }
  } catch (_) {
    // ignore errors
  }
}

/// Stiahne firemné údaje z backendu.
Future<Map<String, dynamic>?> fetchCompanyFromBackend(String token) async {
  try {
    final uri = Uri.parse('${AppConfig.apiBase}/company/info');
    final res = await http
        .get(uri, headers: {'Content-Type': 'application/json', 'Authorization': _bearer(token)})
        .timeout(const Duration(seconds: 10));
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    return jsonDecode(res.body) as Map<String, dynamic>?;
  } catch (_) {
    return null;
  }
}

// ============================================================
// SYNC: Faktúry
// ============================================================

/// Pošle všetky faktúry do backendu (bulk sync).
Future<void> syncInvoicesToBackend() async {
  final token = getBackendToken();
  if (token == null || token.isEmpty) return;
  try {
    final db = DatabaseService();
    final invoices = await db.getInvoices();
    final invoicePayloads = <Map<String, dynamic>>[];
    final itemPayloads = <Map<String, dynamic>>[];
    for (final inv in invoices) {
      if (inv.id == null) continue;
      final map = inv.toMap();
      map['local_id'] = inv.id;
      map.remove('id');
      invoicePayloads.add(map);
      final items = await db.getInvoiceItems(inv.id!);
      for (final item in items) {
        if (item.id == null) continue;
        final im = item.toMap();
        im['local_id'] = item.id;
        im.remove('id');
        im['invoice_local_id'] = inv.id;
        im.remove('invoice_id');
        itemPayloads.add(im);
      }
    }
    final uri = Uri.parse('${AppConfig.apiBase}/sync/invoices-full');
    final res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json', 'Authorization': _bearer(token)},
          body: jsonEncode({'invoices': invoicePayloads, 'items': itemPayloads}),
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      // sync failed silently (404 = endpoint chýba na serveri, app použije lokálny SEPA/EPC QR)
    }
  } catch (_) {
    // ignore errors
  }
}

/// Stiahne Pay by Square QR string pre faktúru z backendu.
Future<String?> fetchInvoiceQrString(int invoiceId, String token) async {
  try {
    final uri = Uri.parse('${AppConfig.apiBase}/invoices/$invoiceId/qr');
    final res = await http
        .get(uri, headers: {'Content-Type': 'application/json', 'Authorization': _bearer(token)})
        .timeout(const Duration(seconds: 10));
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>?;
    return data?['qr_string'] as String?;
  } catch (_) {
    return null;
  }
}

/// Stiahne URL na export faktúry ako Pohoda XML.
String getInvoicePohodaExportUrl(int invoiceId) =>
    '${AppConfig.apiBase}/invoices/$invoiceId/export/pohoda';

/// Stiahne URL na export faktúry ako ISDOC XML.
String getInvoiceIsdocExportUrl(int invoiceId) =>
    '${AppConfig.apiBase}/invoices/$invoiceId/export/isdoc';

// --- Rozšírená cenotvorba – pricing_rules ---

/// Stiahne všetky pravidlá cenotvorby pre daný produkt z backendu.
Future<List<Map<String, dynamic>>?> fetchPricingRulesFromBackend(
  String productId,
  String token,
) async {
  try {
    final uri = Uri.parse('${AppConfig.apiBase}/products/${Uri.encodeComponent(productId)}/pricing-rules');
    final res = await http
        .get(uri, headers: {'Content-Type': 'application/json', 'Authorization': _bearer(token)})
        .timeout(const Duration(seconds: 10));
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    final list = jsonDecode(res.body) as List<dynamic>?;
    if (list == null) return null;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  } catch (_) {
    return null;
  }
}

/// Synchronizuje pravidlá cenotvorby na backend (bulk replace).
/// Pošle celý zoznam pravidiel – backend vymaže staré a vloží nové.
Future<bool> syncPricingRulesToBackend(
  String productId,
  List<Map<String, dynamic>> rules,
  String token,
) async {
  try {
    final uri = Uri.parse('${AppConfig.apiBase}/products/${Uri.encodeComponent(productId)}/pricing-rules/bulk');
    final body = jsonEncode({'rules': rules});
    final res = await http
        .put(uri,
            headers: {'Content-Type': 'application/json', 'Authorization': _bearer(token)},
            body: body)
        .timeout(const Duration(seconds: 15));
    return res.statusCode >= 200 && res.statusCode < 300;
  } catch (_) {
    return false;
  }
}
