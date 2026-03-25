# Design Spec: User-to-User Messages (Manual Alerts)

**Date:** 2026-03-25
**Status:** Approved
**Scope:** Extend existing notification system with manual user-to-user messages

---

## 1. Context

The stock_pilot Flutter app already has a notification system (`AppNotification`, `NotificationService`,
`NotificationCenterScreen`) that delivers system-generated alerts (receipt approvals, low stock, etc.)
via a local SQLite table `app_notifications` with a `target_username` column.

This spec extends that system so any user can manually compose and send messages to one, several, or
all other users. Recipients see the message in the existing notification centre.

**Stack:** Flutter, SQLite (sqflite), Provider pattern, Windows-primary.

---

## 2. Core Rules

- Any authenticated user can send a message to any other user(s).
- Sender selects recipients individually or broadcasts to all users at once.
- Messages have a priority: **INFO** | **WARNING** | **URGENT**.
- Recipients see messages in the notification centre and can mark them as read.
- No reply/thread — one-way only.
- No new screen for viewing; messages appear in the existing notification centre.

---

## 3. Data Layer

### 3.1 DB Migration: version 40 → 41

```sql
ALTER TABLE app_notifications ADD COLUMN sender_username TEXT;
ALTER TABLE app_notifications ADD COLUMN priority        TEXT    DEFAULT 'INFO';
ALTER TABLE app_notifications ADD COLUMN is_manual       INTEGER DEFAULT 0;
```

- Existing rows are unaffected (NULL sender, 'INFO' priority, is_manual = 0).
- `priority` values: `'INFO'`, `'WARNING'`, `'URGENT'`.
- `is_manual = 1` distinguishes manuálne správy from system-generated notifications.

### 3.2 Updated Dart model: `AppNotification`

Add three nullable/defaulted fields:

```dart
final String? senderUsername;   // who sent (null for system notifications)
final String  priority;         // 'INFO' | 'WARNING' | 'URGENT', default 'INFO'
final bool    isManual;         // false for system, true for user messages
```

Add `userMessage('USER_MESSAGE')` to `NotificationType` enum.

Update `toMap()`, `fromMap()`, and `copyWith()` accordingly.

---

## 4. Business Logic

### 4.1 `NotificationService.createUserMessage()`

```dart
Future<void> createUserMessage({
  required String senderUsername,
  required String title,
  required String body,
  required String priority,       // 'INFO' | 'WARNING' | 'URGENT'
  List<String>? targetUsernames,  // null = broadcast to all users
}) async
```

- If `targetUsernames == null`: call `DatabaseService().getAllUsers()` and insert one
  `AppNotification` per user (excluding sender).
- If `targetUsernames` is a non-empty list: insert one notification per listed username.
- Each notification: `type = 'USER_MESSAGE'`, `isManual = true`, `senderUsername`, `priority`.
- Caller must validate that title and body are non-empty before calling.

### 4.2 `DatabaseService.getAllUsers()`

```dart
Future<List<AppUser>> getAllUsers()
```

Returns all users from the `users` table, ordered by username. Used to populate the recipient picker.

---

## 5. UI

### 5.1 `NotificationCenterScreen` — filter tabs

Add a `TabBar` (or `SegmentedButton`) above the notification list:

| Tab | Filter |
|-----|--------|
| Všetko | no filter |
| Správy | `isManual == true` |
| Systémové | `isManual == false` |

### 5.2 Manual message visual style

`AppNotification` cards where `isManual == true` render differently:

- Icon: `Icons.person_rounded` (instead of bell)
- Left coloured border:
  - INFO → `Colors.blue`
  - WARNING → `Colors.orange`
  - URGENT → `Colors.red`
- Subtitle line: `"Od: [senderUsername]"`

### 5.3 FAB — compose button

Add a `FloatingActionButton` with `Icons.edit_rounded` to `NotificationCenterScreen`.
Tapping it opens `ComposeMessageDialog`.

### 5.4 New widget: `ComposeMessageDialog`

File: `lib/widgets/Notifications/compose_message_dialog.dart`

Fields:
- **Nadpis** — `TextField`, required, max 100 chars
- **Správa** — `TextField` multiline, required, max 500 chars
- **Príjemcovia** — scrollable checkbox list of all users (loaded via `getAllUsers()`);
  "Všetci" toggle at top selects/deselects all
- **Priorita** — `SegmentedButton<String>` with three values: Info / Upozornenie / Urgentné

On "Odoslať":
1. Validate title and body non-empty; show `SnackBar` if invalid.
2. Build `targetUsernames` list from selected checkboxes (or `null` if "Všetci" selected).
3. Call `NotificationService().createUserMessage(...)`.
4. `Navigator.pop(context)`.

---

## 6. Files Affected / Created

| Action | File |
|--------|------|
| MODIFY | `lib/models/app_notification.dart` |
| MODIFY | `lib/services/Database/database_service.dart` |
| MODIFY | `lib/services/Notifications/notification_service.dart` |
| MODIFY | `lib/screens/Notifications/notification_center_screen.dart` |
| CREATE | `lib/widgets/Notifications/compose_message_dialog.dart` |

---

## 7. Database Migration Version

- **Current DB version:** 40
- **New DB version:** 41
- **`onUpgrade` handler:** runs when `oldVersion < 41`:
  ```sql
  ALTER TABLE app_notifications ADD COLUMN sender_username TEXT;
  ALTER TABLE app_notifications ADD COLUMN priority        TEXT    DEFAULT 'INFO';
  ALTER TABLE app_notifications ADD COLUMN is_manual       INTEGER DEFAULT 0;
  ```
- **`onDowngrade`:** throws `DatabaseException` (standard policy).

---

## 8. Testing

**Unit tests** for `NotificationService.createUserMessage()`:
- Broadcast (null targetUsernames) → one notification per user except sender
- Targeted (list of 2 usernames) → exactly 2 notifications inserted
- Empty list → no notifications inserted

**Widget tests** for `ComposeMessageDialog`:
- Submit with empty title → SnackBar shown, no navigation
- "Všetci" toggle selects all users
- Priority selector changes priority value

**Model tests** for `AppNotification`:
- `fromMap` with missing priority column defaults to `'INFO'`
- `fromMap` with missing is_manual column defaults to `false`
