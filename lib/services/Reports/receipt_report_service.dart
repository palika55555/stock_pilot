import '../Database/database_service.dart';

/// Reporty príjemiek: prehľad, pohyby, dodávatelia, schvaľovanie, ceny, obstarávacie náklady.
class ReceiptReportService {
  final DatabaseService _db = DatabaseService();

  /// A) Prehľad príjemiek. Filtre: dateFrom, dateTo, status, warehouseId, supplierName, username, movementTypeCode.
  Future<Map<String, dynamic>> getReceiptSummaryReport({
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
    int? warehouseId,
    String? supplierName,
    String? username,
    String? movementTypeCode,
    String? currentUserRole,
    String? currentUsername,
  }) async {
    final db = await _db.database;
    var where = '1=1';
    final args = <Object?>[];

    if (dateFrom != null) {
      where += ' AND r.created_at >= ?';
      args.add(dateFrom.toIso8601String());
    }
    if (dateTo != null) {
      where += ' AND r.created_at <= ?';
      args.add(DateTime(dateTo.year, dateTo.month, dateTo.day, 23, 59, 59).toIso8601String());
    }
    if (status != null && status.isNotEmpty) {
      where += ' AND r.status = ?';
      args.add(status);
    }
    if (warehouseId != null) {
      where += ' AND r.warehouse_id = ?';
      args.add(warehouseId);
    }
    if (supplierName != null && supplierName.isNotEmpty) {
      where += ' AND r.supplier_name LIKE ?';
      args.add('%$supplierName%');
    }
    if (username != null && username.isNotEmpty) {
      where += ' AND r.username = ?';
      args.add(username);
    }
    if (movementTypeCode != null && movementTypeCode.isNotEmpty) {
      where += ' AND r.movement_type_code = ?';
      args.add(movementTypeCode);
    }
    if (currentUserRole == 'user' && currentUsername != null) {
      where += ' AND r.username = ?';
      args.add(currentUsername);
    }

    final rows = await db.rawQuery('''
      SELECT r.id, r.receipt_number, r.created_at, r.movement_type_code,
             r.warehouse_id, r.supplier_name, r.status, r.approver_username, r.approved_at,
             (SELECT COUNT(*) FROM inbound_receipt_items WHERE receipt_id = r.id) as item_count,
             (SELECT SUM(qty * unit_price) FROM inbound_receipt_items WHERE receipt_id = r.id) as sum_without_vat
      FROM inbound_receipts r
      WHERE $where
      ORDER BY r.created_at DESC
    ''', args);

    double totalWithoutVat = 0;
    double totalVat = 0;
    final List<Map<String, dynamic>> resultRows = [];
    for (final r in rows) {
      final sumW = (r['sum_without_vat'] as num?)?.toDouble() ?? 0;
      final vat = sumW * 0.2; // zjednodušene 20% DPH
      totalWithoutVat += sumW;
      totalVat += vat;
      resultRows.add({
        'receipt_number': r['receipt_number'],
        'created_at': r['created_at'],
        'movement_type_code': r['movement_type_code'],
        'warehouse_id': r['warehouse_id'],
        'supplier_name': r['supplier_name'],
        'item_count': r['item_count'],
        'sum_without_vat': sumW,
        'vat': vat,
        'sum_with_vat': sumW + vat,
        'status': r['status'],
        'approver_username': r['approver_username'],
        'approved_at': r['approved_at'],
      });
    }

    final byStatus = <String, int>{};
    for (final r in rows) {
      final s = r['status'] as String? ?? '';
      byStatus[s] = (byStatus[s] ?? 0) + 1;
    }

    return {
      'rows': resultRows,
      'totalCount': resultRows.length,
      'totalWithoutVat': totalWithoutVat,
      'totalVat': totalVat,
      'totalWithVat': totalWithoutVat + totalVat,
      'countByStatus': byStatus,
    };
  }
}
