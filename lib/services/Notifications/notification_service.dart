import 'dart:convert';
import '../../models/app_notification.dart';
import '../../models/receipt.dart';
import '../Database/database_service.dart';

class NotificationService {
  final DatabaseService _db = DatabaseService();

  Future<int> getUnreadCount(String? username) async {
    return _db.getUnreadNotificationCount(username);
  }

  /// Notifikácie na zobrazenie (max 30 dní, s filtrom).
  Future<List<AppNotification>> getNotifications({
    required String? username,
    bool unreadOnly = false,
    String? typeFilter, // 'receipt' | 'stock' | null = all
    int limit = 100,
    int offset = 0,
  }) async {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    String? typeValue;
    if (typeFilter == 'receipt') {
      typeValue = null; // filter by type in code for receipt-related types
    } else if (typeFilter == 'stock') {
      typeValue = 'STOCK_LOW';
    }
    var list = await _db.getAppNotifications(
      targetUsername: username,
      unreadOnly: unreadOnly,
      typeFilter: typeValue,
      limit: limit,
      offset: offset,
      olderThan: cutoff,
    );
    if (typeFilter == 'receipt') {
      list = list.where((n) => _isReceiptType(n.type)).toList();
    }
    return list;
  }

  bool _isReceiptType(String type) {
    return type == 'RECEIPT_SUBMITTED' ||
        type == 'RECEIPT_APPROVED' ||
        type == 'RECEIPT_REJECTED' ||
        type == 'RECEIPT_RECALLED' ||
        type == 'RECEIPT_REVERSED' ||
        type == 'RECEIPT_PENDING_LONG';
  }

  Future<void> markRead(int id) => _db.markNotificationRead(id);
  Future<void> markAllRead(String? username) => _db.markAllNotificationsRead(username);

  Future<void> archiveOld() async {
    await _db.deleteNotificationsOlderThan(const Duration(days: 30));
  }

  Future<void> createForReceiptSubmitted({
    required InboundReceipt receipt,
    required String creatorName,
  }) async {
    final managers = await _db.getManagersAndAdmins();
    final title = 'Nová príjemka na schválenie';
    final body = 'Nová príjemka čaká na schválenie: ${receipt.receiptNumber} od $creatorName';
    for (final u in managers) {
      await _db.insertAppNotification(AppNotification(
        type: 'RECEIPT_SUBMITTED',
        title: title,
        body: body,
        receiptId: receipt.id,
        receiptNumber: receipt.receiptNumber,
        createdAt: DateTime.now(),
        targetUsername: u.username,
      ));
    }
    // Pre používateľov bez roly manager/admin tiež jedna notifikácia s target_username = null
    if (managers.isEmpty) {
      await _db.insertAppNotification(AppNotification(
        type: 'RECEIPT_SUBMITTED',
        title: title,
        body: body,
        receiptId: receipt.id,
        receiptNumber: receipt.receiptNumber,
        createdAt: DateTime.now(),
      ));
    }
  }

  Future<void> createForReceiptApproved({
    required InboundReceipt receipt,
    required String approverName,
  }) async {
    if (receipt.username == null) return;
    await _db.insertAppNotification(AppNotification(
      type: 'RECEIPT_APPROVED',
      title: 'Príjemka schválená',
      body: 'Vaša príjemka ${receipt.receiptNumber} bola schválená používateľom $approverName.',
      receiptId: receipt.id,
      receiptNumber: receipt.receiptNumber,
      extraData: jsonEncode({
        'approved_at': receipt.approvedAt?.toIso8601String(),
        'approver_note': receipt.approverNote,
      }),
      createdAt: DateTime.now(),
      targetUsername: receipt.username,
    ));
  }

  Future<void> createForReceiptRejected({
    required InboundReceipt receipt,
    required String rejectionReason,
  }) async {
    if (receipt.username == null) return;
    await _db.insertAppNotification(AppNotification(
      type: 'RECEIPT_REJECTED',
      title: 'Príjemka zamietnutá',
      body: 'Vaša príjemka ${receipt.receiptNumber} bola zamietnutá. Dôvod: $rejectionReason',
      receiptId: receipt.id,
      receiptNumber: receipt.receiptNumber,
      extraData: jsonEncode({'rejection_reason': rejectionReason}),
      createdAt: DateTime.now(),
      targetUsername: receipt.username,
    ));
  }

  Future<void> createForReceiptRecalled({
    required InboundReceipt receipt,
    required String creatorName,
  }) async {
    final managers = await _db.getManagersAndAdmins();
    final body = '$creatorName stiahol príjemku ${receipt.receiptNumber} zo schválenia';
    for (final u in managers) {
      await _db.insertAppNotification(AppNotification(
        type: 'RECEIPT_RECALLED',
        title: 'Príjemka stiahnutá',
        body: body,
        receiptId: receipt.id,
        receiptNumber: receipt.receiptNumber,
        createdAt: DateTime.now(),
        targetUsername: u.username,
      ));
    }
  }

  Future<void> createForReceiptReversed({
    required InboundReceipt receipt,
    required String userName,
    required String reason,
  }) async {
    final admins = await _db.getUsersWithRole('admin');
    final targetUsernames = {receipt.username}.whereType<String>().toSet();
    for (final a in admins) {
      targetUsernames.add(a.username);
    }
    final body = 'Príjemka ${receipt.receiptNumber} bola stornovaná používateľom $userName. Dôvod: $reason';
    for (final un in targetUsernames) {
      await _db.insertAppNotification(AppNotification(
        type: 'RECEIPT_REVERSED',
        title: 'Príjemka stornovaná',
        body: body,
        receiptId: receipt.id,
        receiptNumber: receipt.receiptNumber,
        extraData: jsonEncode({'reason': reason}),
        createdAt: DateTime.now(),
        targetUsername: un,
      ));
    }
  }

  Future<void> createForReceiptPendingLong({
    required InboundReceipt receipt,
    required int hours,
  }) async {
    final managers = await _db.getManagersAndAdmins();
    final body = 'Príjemka ${receipt.receiptNumber} čaká na schválenie už $hours hodín';
    for (final u in managers) {
      await _db.insertAppNotification(AppNotification(
        type: 'RECEIPT_PENDING_LONG',
        title: 'Pripomienka: príjemka čaká',
        body: body,
        receiptId: receipt.id,
        receiptNumber: receipt.receiptNumber,
        extraData: jsonEncode({'hours': hours}),
        createdAt: DateTime.now(),
        targetUsername: u.username,
      ));
    }
  }

  Future<void> createForStockLow({
    required String productName,
    required String warehouseName,
    required int currentQty,
    required int minQty,
  }) async {
    final managers = await _db.getManagersAndAdmins();
    final body =
        'Produkt $productName v sklade $warehouseName je stále pod minimálnou zásobou ($currentQty/$minQty)';
    for (final u in managers) {
      await _db.insertAppNotification(AppNotification(
        type: 'STOCK_LOW',
        title: 'Nízka zásoba',
        body: body,
        extraData: jsonEncode({
          'product_name': productName,
          'warehouse_name': warehouseName,
          'current_qty': currentQty,
          'min_qty': minQty,
        }),
        createdAt: DateTime.now(),
        targetUsername: u.username,
      ));
    }
  }

  // Production order notifications
  Future<void> createForProductionSubmitted({
    required String orderNumber,
    required double plannedQuantity,
    required int orderId,
  }) async {
    final managers = await _db.getManagersAndAdmins();
    final body = 'Výrobný príkaz $orderNumber čaká na schválenie. Plánované množstvo: $plannedQuantity ks';
    for (final u in managers) {
      await _db.insertAppNotification(AppNotification(
        type: 'PRODUCTION_SUBMITTED',
        title: 'Výrobný príkaz čaká na schválenie',
        body: body,
        extraData: jsonEncode({'production_order_id': orderId, 'order_number': orderNumber, 'planned_quantity': plannedQuantity}),
        createdAt: DateTime.now(),
        targetUsername: u.username,
      ));
    }
    if (managers.isEmpty) {
      await _db.insertAppNotification(AppNotification(
        type: 'PRODUCTION_SUBMITTED',
        title: 'Výrobný príkaz čaká na schválenie',
        body: body,
        extraData: jsonEncode({'production_order_id': orderId, 'order_number': orderNumber}),
        createdAt: DateTime.now(),
      ));
    }
  }

  Future<void> createForProductionApproved({
    required String orderNumber,
    required int orderId,
    required String targetUsername,
  }) async {
    await _db.insertAppNotification(AppNotification(
      type: 'PRODUCTION_APPROVED',
      title: 'Výrobný príkaz schválený',
      body: 'Výrobný príkaz $orderNumber bol schválený.',
      extraData: jsonEncode({'production_order_id': orderId, 'order_number': orderNumber}),
      createdAt: DateTime.now(),
      targetUsername: targetUsername,
    ));
  }

  Future<void> createForProductionRejected({
    required String orderNumber,
    required String rejectionReason,
    required int orderId,
    required String targetUsername,
  }) async {
    await _db.insertAppNotification(AppNotification(
      type: 'PRODUCTION_REJECTED',
      title: 'Výrobný príkaz zamietnutý',
      body: 'Výrobný príkaz $orderNumber bol zamietnutý. Dôvod: $rejectionReason',
      extraData: jsonEncode({'production_order_id': orderId, 'order_number': orderNumber, 'rejection_reason': rejectionReason}),
      createdAt: DateTime.now(),
      targetUsername: targetUsername,
    ));
  }

  Future<void> createForProductionCompleted({
    required String orderNumber,
    required double actualQuantity,
    required int orderId,
  }) async {
    final managers = await _db.getManagersAndAdmins();
    final body = 'Výrobný príkaz $orderNumber bol dokončený. Skutočné množstvo: $actualQuantity ks';
    for (final u in managers) {
      await _db.insertAppNotification(AppNotification(
        type: 'PRODUCTION_COMPLETED',
        title: 'Výrobný príkaz dokončený',
        body: body,
        extraData: jsonEncode({'production_order_id': orderId, 'order_number': orderNumber, 'actual_quantity': actualQuantity}),
        createdAt: DateTime.now(),
        targetUsername: u.username,
      ));
    }
  }
}
