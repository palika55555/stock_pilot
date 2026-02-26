import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user.dart';

/// Backend API pre sync používateľa do PostgreSQL (rovnaký login na webe).
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
