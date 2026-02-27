import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import '../models/customer.dart';

/// Backend API pre sync používateľa a zákazníkov do PostgreSQL (rovnaké dáta na webe).
const String kBackendApiBase = 'https://backend.stockpilot.sk';

/// Kľúč pre hlavičku X-StockPilot-Key (z build-time: --dart-define=BACKEND_SECRET_KEY=...).
const String kBackendSecretKey = String.fromEnvironment('BACKEND_SECRET_KEY', defaultValue: '');

/// Hlavička malými písmenami (Cloudflare WAF). Kľúč len pre stockpilot.sk – kBackendApiBase už je táto doména.
Map<String, String> get _apiHeaders => {
  'Content-Type': 'application/json',
  if (kBackendSecretKey.isNotEmpty) 'x-stockpilot-key': kBackendSecretKey,
};

/// Pošle používateľa (vrátane hesla) do backendu, aby prihlásenie na stockpilot.sk fungovalo rovnako.
/// Volaj po úspešnom lokálnom prihlásení alebo po vytvorení používateľa. Ignoruje chyby (offline).
void syncUserToBackend(User user) {
  final uri = Uri.parse('$kBackendApiBase/api/auth/sync-user');
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
  http
      .post(
        uri,
        headers: _apiHeaders,
        body: body,
      )
      .timeout(const Duration(seconds: 5))
      .ignore();
}

/// Pošle zoznam zákazníkov do backendu – dashboard na webe zobrazí rovnaký počet.
/// Volaj po prihlásení a po pridaní/úprave zákazníka. Ignoruje chyby (offline).
void syncCustomersToBackend(List<Customer> customers) {
  if (customers.isEmpty) return;
  final uri = Uri.parse('$kBackendApiBase/api/sync/customers');
  final body = jsonEncode({
    'customers': customers.map((c) => c.toMap()).toList(),
  });
  http
      .post(
        uri,
        headers: _apiHeaders,
        body: body,
      )
      .timeout(const Duration(seconds: 10))
      .ignore();
}

/// Stiahne zoznam zákazníkov z backendu (vrátane úprav urobených na webe).
/// Vráti null pri chybe/offline. Volaj po prihlásení a potom zavolaj [DatabaseService.replaceCustomersFromBackend].
Future<List<Map<String, dynamic>>?> fetchCustomersFromBackend() async {
  try {
    final uri = Uri.parse('$kBackendApiBase/api/customers');
    final res = await http.get(uri, headers: _apiHeaders).timeout(const Duration(seconds: 10));
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
    final uri = Uri.parse('$kBackendApiBase/api/sync/check');
    final res = await http.get(uri, headers: _apiHeaders).timeout(const Duration(seconds: 8));
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    final map = jsonDecode(res.body) as Map<String, dynamic>?;
    return map;
  } catch (_) {
    return null;
  }
}
