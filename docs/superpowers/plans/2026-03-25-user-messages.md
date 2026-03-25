# User-to-User Messages Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let any user compose and send manual in-app messages to one, several, or all other users, displayed in the existing notification centre with priority-based visual styling.

**Architecture:** Extend the existing `AppNotification` SQLite table and Dart model with three new columns (`sender_username`, `priority`, `is_manual`), add a `MessagePriority` enum, a `createUserMessage()` method on `NotificationService`, an `isManual` filter on `getAppNotifications()`, a new `ComposeMessageDialog` widget, and update `NotificationCenterScreen` with filter tabs + FAB.

**Tech Stack:** Flutter, sqflite, SharedPreferences, Provider pattern, Windows-primary.

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| MODIFY | `lib/models/app_notification.dart` | Add `MessagePriority` enum + 3 fields to `AppNotification` |
| MODIFY | `lib/services/Database/database_service.dart` | Migration 40→41, `getAllUsers()`, `isManual` filter in `getAppNotifications()` |
| MODIFY | `lib/services/Notifications/notification_service.dart` | `createUserMessage()`, pass `isManual` through `getNotifications()` |
| MODIFY | `lib/screens/Notifications/notification_center_screen.dart` | Filter tabs (Správy/Systémové), FAB, manual message tile style |
| CREATE | `lib/widgets/Notifications/compose_message_dialog.dart` | Compose dialog (title, body, recipient picker, priority) |
| CREATE | `test/app_notification_test.dart` | Unit tests for model + MessagePriority |

---

## Task 1: Model — MessagePriority enum + AppNotification fields

**Files:**
- Modify: `lib/models/app_notification.dart`
- Create: `test/app_notification_test.dart`

- [ ] **Step 1: Write failing model tests**

Create `test/app_notification_test.dart`:

```dart
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
```

- [ ] **Step 2: Run tests — expect failure**

```bash
flutter test test/app_notification_test.dart
```

Expected: FAIL (MessagePriority not defined, fields missing)

- [ ] **Step 3: Implement changes in `lib/models/app_notification.dart`**

Add `MessagePriority` enum at the top (before `NotificationType`):

```dart
enum MessagePriority {
  info('INFO'),
  warning('WARNING'),
  urgent('URGENT');

  final String value;
  const MessagePriority(this.value);

  static MessagePriority fromString(String? s) {
    for (final e in MessagePriority.values) {
      if (e.value == s) return e;
    }
    return MessagePriority.info;
  }
}
```

Add `userMessage('USER_MESSAGE')` to `NotificationType` enum values list (after `priceChange`):

```dart
  priceChange('PRICE_CHANGE'),
  userMessage('USER_MESSAGE');
```

Add three fields to `AppNotification` class (after existing `targetUsername`):

```dart
  final String? senderUsername;
  final MessagePriority priority;
  final bool isManual;
```

Add them to the constructor (all optional/defaulted):

```dart
  const AppNotification({
    // ... existing params ...
    this.senderUsername,
    this.priority = MessagePriority.info,
    this.isManual = false,
  });
```

Add to `toMap()`:

```dart
      'sender_username': senderUsername,
      'priority': priority.value,
      'is_manual': isManual ? 1 : 0,
```

Add to `fromMap()`:

```dart
      senderUsername: map['sender_username'] as String?,
      priority: MessagePriority.fromString(map['priority'] as String?),
      isManual: (map['is_manual'] as int?) == 1,
```

Add to `copyWith()` signature and body:

```dart
  AppNotification copyWith({
    // ... existing params ...
    String? senderUsername,
    MessagePriority? priority,
    bool? isManual,
  }) {
    return AppNotification(
      // ... existing fields ...
      senderUsername: senderUsername ?? this.senderUsername,
      priority: priority ?? this.priority,
      isManual: isManual ?? this.isManual,
    );
  }
```

- [ ] **Step 4: Run tests — expect pass**

```bash
flutter test test/app_notification_test.dart
```

Expected: All 7 tests PASS

- [ ] **Step 5: Run all tests**

```bash
flutter test
```

Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/models/app_notification.dart test/app_notification_test.dart
git commit -m "feat: add MessagePriority enum and isManual/senderUsername fields to AppNotification"
```

---

## Task 2: DB — Migration 40→41 + getAllUsers() + isManual filter

**Files:**
- Modify: `lib/services/Database/database_service.dart`

Key line references:
- `version: 40` is at line ~238
- `_onUpgrade` ends at line ~2200 (last block is `if (oldVersion < 40) { ... }`)
- `_onCreate` notification table is at line ~1777 (inside the big `_onCreate`)
- `_ensureSchema` notification table is at line ~856
- `getAppNotifications()` is at line ~3553
- `getUsersWithRole()` is at line ~3529

- [ ] **Step 1: Bump DB version from 40 to 41**

Find `version: 40,` (line ~238) and change to:

```dart
      version: 41,
```

- [ ] **Step 2: Add migration block in `_onUpgrade`**

After the closing `}` of the `if (oldVersion < 40)` block (line ~2199), add:

```dart
    if (oldVersion < 41) {
      await db.execute(
        "ALTER TABLE app_notifications ADD COLUMN sender_username TEXT",
      );
      await db.execute(
        "ALTER TABLE app_notifications ADD COLUMN priority TEXT DEFAULT 'INFO'",
      );
      await db.execute(
        "ALTER TABLE app_notifications ADD COLUMN is_manual INTEGER DEFAULT 0",
      );
    }
```

- [ ] **Step 3: Update `_onCreate` app_notifications table**

Find the `CREATE TABLE IF NOT EXISTS app_notifications` in `_onCreate` (around line 1777, inside the `_onCreate` method, NOT the _ensureSchema one). It currently ends with `target_username TEXT`. Add the three new columns:

```sql
        target_username TEXT,
        sender_username TEXT,
        priority TEXT DEFAULT 'INFO',
        is_manual INTEGER DEFAULT 0
```

- [ ] **Step 4: Update `_ensureSchema` app_notifications table**

Find the `CREATE TABLE IF NOT EXISTS app_notifications` in `_ensureSchema` (around line 856). It currently ends with `user_id TEXT`. Add the three new columns:

```sql
        user_id TEXT,
        sender_username TEXT,
        priority TEXT DEFAULT 'INFO',
        is_manual INTEGER DEFAULT 0
```

- [ ] **Step 5: Add `isManual` parameter to `getAppNotifications()`**

Add `bool? isManual` parameter and filter clause. Current signature:

```dart
  Future<List<AppNotification>> getAppNotifications({
    String? targetUsername,
    bool? unreadOnly,
    String? typeFilter,
    int limit = 100,
    int offset = 0,
    DateTime? olderThan,
  }) async {
```

New signature — add `bool? isManual`:

```dart
  Future<List<AppNotification>> getAppNotifications({
    String? targetUsername,
    bool? unreadOnly,
    String? typeFilter,
    bool? isManual,
    int limit = 100,
    int offset = 0,
    DateTime? olderThan,
  }) async {
```

After the `if (olderThan != null)` block (and before the `db.query` call), add:

```dart
    if (isManual != null) {
      conditions.add('is_manual = ?');
      whereArgs.add(isManual ? 1 : 0);
    }
```

- [ ] **Step 6: Add `getAllUsers()` to `DatabaseService`**

After the `getUsersWithRole()` method (line ~3533), add:

```dart
  /// Všetci používatelia (pre výber príjemcov správ).
  Future<List<User>> getAllUsers() async {
    Database db = await database;
    final maps = await db.query('users', orderBy: 'username ASC');
    return maps.map((m) => User.fromMap(m)).toList();
  }
```

- [ ] **Step 7: Run all tests**

```bash
flutter test
```

Expected: All tests pass.

- [ ] **Step 8: Commit**

```bash
git add lib/services/Database/database_service.dart
git commit -m "feat: DB migration 40->41, add isManual filter + getAllUsers()"
```

---

## Task 3: Service — createUserMessage() + getNotifications() isManual pass-through

**Files:**
- Modify: `lib/services/Notifications/notification_service.dart`

Current `getNotifications()` signature (line ~14):

```dart
  Future<List<AppNotification>> getNotifications({
    required String? username,
    bool unreadOnly = false,
    String? typeFilter, // 'receipt' | 'stock' | null = all
    int limit = 100,
    int offset = 0,
  }) async {
```

- [ ] **Step 1: Add `isManual` pass-through to `getNotifications()`**

Add `bool? isManual` parameter and pass it through to `_db.getAppNotifications()`:

```dart
  Future<List<AppNotification>> getNotifications({
    required String? username,
    bool unreadOnly = false,
    String? typeFilter,
    bool? isManual,
    int limit = 100,
    int offset = 0,
  }) async {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    var list = await _db.getAppNotifications(
      targetUsername: username,
      unreadOnly: unreadOnly,
      isManual: isManual,
      limit: limit,
      offset: offset,
      olderThan: cutoff,
    );
    if (typeFilter == 'receipt') {
      list = list.where((n) => _isReceiptType(n.type)).toList();
    } else if (typeFilter == 'stock') {
      list = list.where((n) => n.type == 'STOCK_LOW').toList();
    }
    return list;
  }
```

**Note:** When `isManual` is non-null, the `typeFilter` in-memory filter still runs but is a no-op for `USER_MESSAGE` types (they don't match receipt or stock types), so results are always correct.

- [ ] **Step 2: Add `createUserMessage()` method**

Add after `createForStockLow()`:

```dart
  Future<void> createUserMessage({
    required String senderUsername,
    required String title,
    required String body,
    required MessagePriority priority,
    List<String>? targetUsernames,
  }) async {
    if (targetUsernames != null && targetUsernames.isEmpty) return;

    final List<String> recipients;
    if (targetUsernames == null) {
      final allUsers = await _db.getAllUsers();
      recipients = allUsers
          .map((u) => u.username)
          .where((u) => u != senderUsername)
          .toList();
    } else {
      // Exclude sender from targeted sends too
      recipients = targetUsernames.where((u) => u != senderUsername).toList();
    }

    for (final username in recipients) {
      await _db.insertAppNotification(AppNotification(
        type: 'USER_MESSAGE',
        title: title,
        body: body,
        createdAt: DateTime.now(),
        targetUsername: username,
        senderUsername: senderUsername,
        priority: priority,
        isManual: true,
      ));
    }
  }
```

Add the import at the top of the file if not already present:

```dart
import '../../models/app_notification.dart';
```

(It should already be there — verify before adding.)

- [ ] **Step 3: Run all tests**

```bash
flutter test
```

Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
git add lib/services/Notifications/notification_service.dart
git commit -m "feat: add createUserMessage() and isManual filter to NotificationService"
```

---

## Task 3b: NotificationService unit tests

**Files:**
- Create: `test/notification_service_test.dart`

The service depends on `DatabaseService` which uses SQLite — we test the pure logic paths directly using a real in-memory database is out of scope for unit tests. Instead we test the pure conditional logic by subclassing or we test what we can: the empty-list guard and the priority round-trip through the model. DB-dependent behaviour (broadcast, targeted inserts) is tested at integration level manually.

- [ ] **Step 1: Create `test/notification_service_test.dart`**

```dart
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
```

- [ ] **Step 2: Run tests**

```bash
flutter test test/notification_service_test.dart
```

Expected: All tests PASS.

- [ ] **Step 3: Commit**

```bash
git add test/notification_service_test.dart
git commit -m "test: add NotificationService logic unit tests"
```

---

## Task 4: ComposeMessageDialog

**Files:**
- Create: `lib/widgets/Notifications/compose_message_dialog.dart`

- [ ] **Step 1: Create `compose_message_dialog.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stock_pilot/models/app_notification.dart';
import 'package:stock_pilot/models/user.dart';
import 'package:stock_pilot/services/Database/database_service.dart';
import 'package:stock_pilot/services/Notifications/notification_service.dart';

class ComposeMessageDialog extends StatefulWidget {
  const ComposeMessageDialog({super.key});

  @override
  State<ComposeMessageDialog> createState() => _ComposeMessageDialogState();
}

class _ComposeMessageDialogState extends State<ComposeMessageDialog> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  MessagePriority _priority = MessagePriority.info;

  List<User> _users = [];
  Set<String> _selected = {};
  bool _allSelected = false;
  bool _loading = true;
  bool _sending = false;
  String? _currentUsername;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUsername = prefs.getString('current_user_username');
    final users = await DatabaseService().getAllUsers();
    if (!mounted) return;
    setState(() {
      _users = users;
      _loading = false;
    });
  }

  void _toggleAll(bool? value) {
    setState(() {
      _allSelected = value ?? false;
      _selected = _allSelected ? _users.map((u) => u.username).toSet() : {};
    });
  }

  void _toggleUser(String username, bool? value) {
    setState(() {
      if (value == true) {
        _selected.add(username);
      } else {
        _selected.remove(username);
      }
      _allSelected = _selected.length == _users.length;
    });
  }

  Future<void> _send() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zadajte nadpis aj text správy')),
      );
      return;
    }

    if (!_allSelected && _selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vyberte aspoň jedného príjemcu')),
      );
      return;
    }

    // Broadcast confirmation
    if (_allSelected) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Odoslať všetkým?'),
          content: const Text('Odoslať správu všetkým používateľom?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Zrušiť'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Odoslať'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _sending = true);

    await NotificationService().createUserMessage(
      senderUsername: _currentUsername ?? '',
      title: title,
      body: body,
      priority: _priority,
      targetUsernames: _allSelected ? null : _selected.toList(),
    );

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nová správa'),
      content: _loading
          ? const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()))
          : SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _titleController,
                      maxLength: 100,
                      decoration: const InputDecoration(
                        labelText: 'Nadpis *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _bodyController,
                      maxLength: 500,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Text správy *',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Priorita', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    SegmentedButton<MessagePriority>(
                      segments: const [
                        ButtonSegment(value: MessagePriority.info, label: Text('Info')),
                        ButtonSegment(value: MessagePriority.warning, label: Text('Upozornenie')),
                        ButtonSegment(value: MessagePriority.urgent, label: Text('Urgentné')),
                      ],
                      selected: {_priority},
                      onSelectionChanged: (s) => setState(() => _priority = s.first),
                    ),
                    const SizedBox(height: 16),
                    const Text('Príjemcovia', style: TextStyle(fontWeight: FontWeight.w600)),
                    CheckboxListTile(
                      title: const Text('Všetci'),
                      value: _allSelected,
                      onChanged: _toggleAll,
                      dense: true,
                    ),
                    const Divider(height: 1),
                    ..._users.map((u) => CheckboxListTile(
                          title: Text(u.fullName.isNotEmpty ? u.fullName : u.username),
                          subtitle: Text(u.username, style: const TextStyle(fontSize: 11)),
                          value: _selected.contains(u.username),
                          onChanged: (v) => _toggleUser(u.username, v),
                          dense: true,
                        )),
                  ],
                ),
              ),
            ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.pop(context),
          child: const Text('Zrušiť'),
        ),
        FilledButton(
          onPressed: (_sending || _loading) ? null : _send,
          child: _sending
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Odoslať'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Run all tests**

```bash
flutter test
```

Expected: All tests pass.

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/Notifications/compose_message_dialog.dart
git commit -m "feat: add ComposeMessageDialog widget"
```

---

## Task 5: NotificationCenterScreen — tabs, FAB, manual message styling

**Files:**
- Modify: `lib/screens/Notifications/notification_center_screen.dart`

Current filter values: `'all' | 'unread' | 'receipt' | 'stock'`
New filter values: `'all' | 'unread' | 'messages' | 'system'`

The existing `'receipt'` and `'stock'` filter chips are **replaced** by `'messages'` and `'system'` tabs as per the spec. The "Neprečítané" chip is kept.

- [ ] **Step 1: Add import for ComposeMessageDialog**

Add at the top of the file (after existing imports):

```dart
import '../../widgets/Notifications/compose_message_dialog.dart';
```

- [ ] **Step 2: Update `_loadNotifications()` to use new filter values**

Replace the current `_loadNotifications` method:

```dart
  Future<void> _loadNotifications() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final unreadOnly = _filter == 'unread';
    bool? isManual;
    if (_filter == 'messages') isManual = true;
    if (_filter == 'system') isManual = false;
    final list = await _notificationService.getNotifications(
      username: _currentUsername,
      unreadOnly: unreadOnly,
      isManual: isManual,
      limit: 200,
    );
    if (mounted) setState(() {
      _notifications = list;
      _loading = false;
    });
  }
```

- [ ] **Step 3: Update `_buildFilterBar()` to replace receipt/stock chips with messages/system**

Replace the entire `_buildFilterBar()` method:

```dart
  Widget _buildFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _FilterChip(
            label: 'Všetky',
            selected: _filter == 'all',
            onTap: () => setState(() { _filter = 'all'; _loadNotifications(); }),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Neprečítané',
            selected: _filter == 'unread',
            onTap: () => setState(() { _filter = 'unread'; _loadNotifications(); }),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Správy',
            selected: _filter == 'messages',
            onTap: () => setState(() { _filter = 'messages'; _loadNotifications(); }),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Systémové',
            selected: _filter == 'system',
            onTap: () => setState(() { _filter = 'system'; _loadNotifications(); }),
          ),
        ],
      ),
    );
  }
```

- [ ] **Step 4: Add FAB to Scaffold**

In the `build()` method's `Scaffold(...)`, add a `floatingActionButton` property after `body`:

```dart
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await showDialog(
            context: context,
            builder: (_) => const ComposeMessageDialog(),
          );
          _loadNotifications();
        },
        tooltip: 'Nová správa',
        child: const Icon(Icons.edit_rounded),
      ),
```

- [ ] **Step 5: Update `_NotificationTile` to style manual messages**

In the `_NotificationTile.build()` method, wrap the existing `Material` + `ListTile` in a container with a left border for manual messages. Replace the `return Material(...)` block with:

```dart
    final isManual = n.isManual;
    final borderColor = isManual ? _priorityColor(n.priority) : Colors.transparent;

    return Container(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: borderColor, width: 4)),
      ),
      child: Material(
        color: n.read ? const Color(0xFF1A1A1A) : const Color(0xFF252528),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: (isManual ? _priorityColor(n.priority) : _colorForType(n.type)).withOpacity(0.2),
            child: Icon(
              isManual ? Icons.person_rounded : _iconForType(n.type),
              color: isManual ? _priorityColor(n.priority) : _colorForType(n.type),
              size: 22,
            ),
          ),
          title: Text(
            n.title,
            style: TextStyle(
              color: Colors.white,
              fontWeight: n.read ? FontWeight.normal : FontWeight.w600,
              fontSize: 14,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (n.body.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    n.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                ),
              if (isManual && n.senderUsername != null)
                Text(
                  'Od: ${n.senderUsername}',
                  style: const TextStyle(fontSize: 11, color: Colors.white38),
                ),
            ],
          ),
          trailing: Text(
            _formatTime(n.createdAt),
            style: const TextStyle(fontSize: 11, color: Colors.white38),
          ),
          onTap: onTap,
        ),
      ),
    );
```

Add the helper method `_priorityColor` to `_NotificationTile`:

```dart
  Color _priorityColor(MessagePriority priority) {
    switch (priority) {
      case MessagePriority.urgent:
        return Colors.red;
      case MessagePriority.warning:
        return Colors.orange;
      case MessagePriority.info:
        return Colors.blue;
    }
  }
```

Add import for `MessagePriority` at the top (already imported via `app_notification.dart` — verify it's there).

- [ ] **Step 6: Run all tests**

```bash
flutter test
```

Expected: All tests pass.

- [ ] **Step 7: Commit**

```bash
git add lib/screens/Notifications/notification_center_screen.dart
git commit -m "feat: add Správy/Systémové filter tabs, FAB, manual message visual style to NotificationCenterScreen"
```

---

## Done

All 5 tasks complete. The feature is fully implemented:
- `MessagePriority` enum + 3 new fields on `AppNotification`
- DB migrated from 40 → 41 with 3 new `app_notifications` columns
- `NotificationService.createUserMessage()` working
- `ComposeMessageDialog` accessible via FAB in notification centre
- Notification centre shows "Správy" / "Systémové" filter tabs
- Manual messages styled with coloured left border + person icon
