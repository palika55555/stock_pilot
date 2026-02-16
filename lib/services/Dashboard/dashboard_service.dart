import 'dart:async';
import 'package:stock_pilot/services/Database/database_service.dart';

class DashboardService {
  final DatabaseService _db = DatabaseService();

  Future<Map<String, dynamic>> getOverviewStats() async {
    final stats = await _db.getDashboardStats();
    final recentInbound = await _db.getRecentInboundReceiptsWithTotal(limit: 5);
    final recentOutbound = await _db.getRecentStockOutsWithTotal(limit: 5);
    stats['recentInbound'] = recentInbound;
    stats['recentOutbound'] = recentOutbound;
    return stats;
  }
}
