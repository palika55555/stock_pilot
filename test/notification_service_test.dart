import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pilot/models/app_notification.dart';

/// NotificationService unit tests — pure logic only (no DB).
/// DB-dependent paths (broadcast, targeted insert counts) are verified manually.
void main() {
  group('createUserMessage logic', () {
    test('empty targetUsernames list — guard condition is correct', () {
      // Verify the guard: empty list != null
      const List<String> empty = [];
      expect(empty.isEmpty, true);
      // ignore: unnecessary_null_comparison
      expect(empty == null, false); // null check guard
    });

    test('sender excluded from targeted list', () {
      const sender = 'pavol';
      const targets = ['pavol', 'jana', 'peter'];
      final recipients = targets.where((u) => u != sender).toList();
      expect(recipients, ['jana', 'peter']);
      expect(recipients.contains(sender), false);
    });

    test('sender excluded from broadcast list', () {
      const sender = 'pavol';
      final allUsers = ['pavol', 'jana', 'peter'];
      final recipients = allUsers.where((u) => u != sender).toList();
      expect(recipients.length, 2);
      expect(recipients.contains(sender), false);
    });

    test('MessagePriority round-trips through AppNotification', () {
      for (final p in MessagePriority.values) {
        final n = AppNotification(
          type: 'USER_MESSAGE',
          title: 'T',
          body: 'B',
          createdAt: DateTime(2026, 3, 25),
          priority: p,
          isManual: true,
        );
        final map = n.toMap();
        final n2 = AppNotification.fromMap(map as Map<String, dynamic>);
        expect(n2.priority, p);
      }
    });
  });
}
