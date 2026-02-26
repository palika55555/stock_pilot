import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import '../models/customer.dart';

/// Backend API pre sync používateľa a zákazníkov do PostgreSQL (rovnaké dáta na webe).
const String kBackendApiBase = 'https://backend.stockpilot.sk';

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
        headers: {'Content-Type': 'application/json'},
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
        headers: {'Content-Type': 'application/json'},
        body: body,
      )
      .timeout(const Duration(seconds: 10))
      .ignore();
}
