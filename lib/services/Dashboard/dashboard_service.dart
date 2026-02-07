import 'dart:async';
import '../database/database_service.dart';

class DashboardService {
  final DatabaseService _db = DatabaseService();

  Future<Map<String, dynamic>> getOverviewStats() async {
    // V budúcnosti tu bude reálna logika výpočtu z viacerých tabuliek
    return await _db.getDashboardStats();
  }
}
