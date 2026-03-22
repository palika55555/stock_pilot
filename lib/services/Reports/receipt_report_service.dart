import '../Database/database_service.dart';

/// Reporty príjemiek: prehľad, pohyby, dodávatelia, schvaľovanie, ceny, obstarávacie náklady.
class ReceiptReportService {
  final DatabaseService _db = DatabaseService();

  Future<String?> _userId() async {
    await DatabaseService.restoreCurrentUser();
    return DatabaseService.currentUserId;
  }

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
    final uid = await _userId();
    if (uid == null) {
      return _emptySummary();
    }

    final db = await _db.database;
    var where = 'r.user_id = ?';
    final args = <Object?>[uid];

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
      final vat = sumW * 0.2;
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

  Map<String, dynamic> _emptySummary() => {
        'rows': <Map<String, dynamic>>[],
        'totalCount': 0,
        'totalWithoutVat': 0.0,
        'totalVat': 0.0,
        'totalWithVat': 0.0,
        'countByStatus': <String, int>{},
      };

  /// B) Súhrn podľa dodávateľa (počet príjemiek, súčet riadkov bez DPH).
  Future<Map<String, dynamic>> getSupplierSummaryReport({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final uid = await _userId();
    if (uid == null) {
      return {'rows': <Map<String, dynamic>>[], 'grandTotalNet': 0.0};
    }
    final db = await _db.database;
    var where = 'r.user_id = ?';
    final args = <Object?>[uid];
    if (dateFrom != null) {
      where += ' AND r.created_at >= ?';
      args.add(dateFrom.toIso8601String());
    }
    if (dateTo != null) {
      where += ' AND r.created_at <= ?';
      args.add(DateTime(dateTo.year, dateTo.month, dateTo.day, 23, 59, 59).toIso8601String());
    }

    final rows = await db.rawQuery('''
      SELECT COALESCE(NULLIF(TRIM(r.supplier_name), ''), '(bez dodávateľa)') AS supplier_label,
             COUNT(*) AS receipt_count,
             SUM((SELECT COALESCE(SUM(qty * unit_price), 0) FROM inbound_receipt_items WHERE receipt_id = r.id)) AS sum_net
      FROM inbound_receipts r
      WHERE $where
      GROUP BY supplier_label
      ORDER BY sum_net DESC
    ''', args);

    double grand = 0;
    final out = <Map<String, dynamic>>[];
    for (final r in rows) {
      final net = (r['sum_net'] as num?)?.toDouble() ?? 0;
      grand += net;
      out.add({
        'supplier_label': r['supplier_label'],
        'receipt_count': r['receipt_count'],
        'sum_net': net,
      });
    }
    return {'rows': out, 'grandTotalNet': grand};
  }

  /// C) Metriky schvaľovania (priemerný čas v hodinách, počty).
  Future<Map<String, dynamic>> getApprovalPerformanceReport({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final uid = await _userId();
    if (uid == null) {
      return {
        'approvedCount': 0,
        'rejectedCount': 0,
        'avgHoursApproval': null,
        'submittedWithApprovalData': 0,
      };
    }
    final db = await _db.database;
    var where = 'user_id = ?';
    final args = <Object?>[uid];
    if (dateFrom != null) {
      where += ' AND created_at >= ?';
      args.add(dateFrom.toIso8601String());
    }
    if (dateTo != null) {
      where += ' AND created_at <= ?';
      args.add(DateTime(dateTo.year, dateTo.month, dateTo.day, 23, 59, 59).toIso8601String());
    }

    final agg = await db.rawQuery('''
      SELECT
        SUM(CASE WHEN status = 'schvalena' THEN 1 ELSE 0 END) AS approved_n,
        SUM(CASE WHEN status = 'rejected' THEN 1 ELSE 0 END) AS rejected_n,
        SUM(CASE WHEN status = 'schvalena' AND submitted_at IS NOT NULL AND approved_at IS NOT NULL THEN 1 ELSE 0 END) AS with_times_n,
        AVG(CASE WHEN status = 'schvalena' AND submitted_at IS NOT NULL AND approved_at IS NOT NULL
          THEN (julianday(approved_at) - julianday(submitted_at)) * 24.0
          ELSE NULL END) AS avg_hours
      FROM inbound_receipts
      WHERE $where
    ''', args);

    final row = agg.isEmpty ? <String, dynamic>{} : agg.first;
    final avg = row['avg_hours'];
    return {
      'approvedCount': (row['approved_n'] as num?)?.toInt() ?? 0,
      'rejectedCount': (row['rejected_n'] as num?)?.toInt() ?? 0,
      'avgHoursApproval': avg != null ? (avg as num).toDouble() : null,
      'submittedWithApprovalData': (row['with_times_n'] as num?)?.toInt() ?? 0,
    };
  }

  /// D) Vývoj nákupných cien z položiek príjemiek.
  Future<List<Map<String, dynamic>>> getPriceHistoryReport({
    DateTime? dateFrom,
    DateTime? dateTo,
    String? productSearch,
  }) async {
    final uid = await _userId();
    if (uid == null) return [];
    final db = await _db.database;
    var where = 'r.user_id = ?';
    final args = <Object?>[uid];
    if (dateFrom != null) {
      where += ' AND r.created_at >= ?';
      args.add(dateFrom.toIso8601String());
    }
    if (dateTo != null) {
      where += ' AND r.created_at <= ?';
      args.add(DateTime(dateTo.year, dateTo.month, dateTo.day, 23, 59, 59).toIso8601String());
    }
    if (productSearch != null && productSearch.trim().isNotEmpty) {
      final q = '%${productSearch.trim()}%';
      where += ' AND (i.product_name LIKE ? OR i.plu LIKE ? OR i.product_unique_id LIKE ?)';
      args.addAll([q, q, q]);
    }

    final rows = await db.rawQuery('''
      SELECT r.receipt_number, r.created_at, i.product_unique_id, i.product_name, i.plu,
             i.qty, i.unit, i.unit_price
      FROM inbound_receipt_items i
      JOIN inbound_receipts r ON i.receipt_id = r.id
      WHERE $where
      ORDER BY r.created_at DESC, i.product_name ASC
      LIMIT 2000
    ''', args);

    return rows
        .map(
          (r) => {
            'receipt_number': r['receipt_number'],
            'created_at': r['created_at'],
            'product_unique_id': r['product_unique_id'],
            'product_name': r['product_name'],
            'plu': r['plu'],
            'qty': r['qty'],
            'unit': r['unit'],
            'unit_price': (r['unit_price'] as num?)?.toDouble() ?? 0,
          },
        )
        .toList();
  }

  /// E) Obstarávacie náklady k príjemkám (doprava, clo, …).
  Future<List<Map<String, dynamic>>> getAcquisitionCostsReport({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final uid = await _userId();
    if (uid == null) return [];
    final db = await _db.database;
    var where = 'r.user_id = ?';
    final args = <Object?>[uid];
    if (dateFrom != null) {
      where += ' AND r.created_at >= ?';
      args.add(dateFrom.toIso8601String());
    }
    if (dateTo != null) {
      where += ' AND r.created_at <= ?';
      args.add(DateTime(dateTo.year, dateTo.month, dateTo.day, 23, 59, 59).toIso8601String());
    }

    try {
      final rows = await db.rawQuery('''
      SELECT c.id, c.cost_type, c.description, c.amount_without_vat, c.vat_percent, c.amount_with_vat,
             c.cost_supplier_name, c.document_number, c.sort_order,
             r.receipt_number, r.created_at, r.supplier_name AS receipt_supplier
      FROM receipt_acquisition_costs c
      JOIN inbound_receipts r ON c.receipt_id = r.id
      WHERE $where
      ORDER BY r.created_at DESC, c.sort_order ASC
    ''', args);

      return rows
          .map(
            (r) => {
              'id': r['id'],
              'cost_type': r['cost_type'],
              'description': r['description'],
              'amount_without_vat': (r['amount_without_vat'] as num?)?.toDouble() ?? 0,
              'vat_percent': r['vat_percent'],
              'amount_with_vat': (r['amount_with_vat'] as num?)?.toDouble() ?? 0,
              'cost_supplier_name': r['cost_supplier_name'],
              'document_number': r['document_number'],
              'receipt_number': r['receipt_number'],
              'created_at': r['created_at'],
              'receipt_supplier': r['receipt_supplier'],
            },
          )
          .toList();
    } catch (_) {
      return [];
    }
  }
}
