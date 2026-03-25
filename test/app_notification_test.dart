import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pilot/models/app_notification.dart';

void main() {
  group('MessagePriority', () {
    test('fromString returns correct enum values', () {
      expect(MessagePriority.fromString('INFO'), MessagePriority.info);
      expect(MessagePriority.fromString('WARNING'), MessagePriority.warning);
      expect(MessagePriority.fromString('URGENT'), MessagePriority.urgent);
    });

    test('fromString returns info for unknown or null', () {
      expect(MessagePriority.fromString('UNKNOWN'), MessagePriority.info);
      expect(MessagePriority.fromString(null), MessagePriority.info);
    });

    test('value strings are correct', () {
      expect(MessagePriority.info.value, 'INFO');
      expect(MessagePriority.warning.value, 'WARNING');
      expect(MessagePriority.urgent.value, 'URGENT');
    });
  });

  group('AppNotification', () {
    test('fromMap defaults priority to info when missing', () {
      final map = <String, dynamic>{
        'id': 1,
        'type': 'USER_MESSAGE',
        'title': 'Test',
        'body': 'Body',
        'created_at': '2026-03-25T10:00:00.000',
        'read': 0,
      };
      final n = AppNotification.fromMap(map);
      expect(n.priority, MessagePriority.info);
      expect(n.isManual, false);
      expect(n.senderUsername, isNull);
    });

    test('fromMap reads new fields correctly', () {
      final map = <String, dynamic>{
        'id': 2,
        'type': 'USER_MESSAGE',
        'title': 'Urgent msg',
        'body': 'Body',
        'created_at': '2026-03-25T10:00:00.000',
        'read': 0,
        'sender_username': 'admin',
        'priority': 'URGENT',
        'is_manual': 1,
      };
      final n = AppNotification.fromMap(map);
      expect(n.priority, MessagePriority.urgent);
      expect(n.isManual, true);
      expect(n.senderUsername, 'admin');
    });

    test('toMap includes new fields', () {
      final n = AppNotification(
        type: 'USER_MESSAGE',
        title: 'Hi',
        body: 'Test',
        createdAt: DateTime(2026, 3, 25),
        senderUsername: 'pavol',
        priority: MessagePriority.warning,
        isManual: true,
      );
      final map = n.toMap();
      expect(map['sender_username'], 'pavol');
      expect(map['priority'], 'WARNING');
      expect(map['is_manual'], 1);
    });

    test('USER_MESSAGE type is in NotificationType enum', () {
      expect(
        NotificationType.fromString('USER_MESSAGE'),
        NotificationType.userMessage,
      );
    });
  });
}
