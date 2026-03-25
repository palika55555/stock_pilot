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

**Note on existing notification types:** Several production-order notification types (`PRODUCTION_SUBMITTED`,
`PRODUCTION_APPROVED`, `PRODUCTION_REJECTED`, `PRODUCTION_COMPLETED`) are inserted as raw strings in
`NotificationService` without being members of the `NotificationType` enum. `NotificationType.fromString()`
therefore returns `null` for those rows. The `is_manual` flag (not `NotificationType`) is the reliable
discriminator between system notifications and user messages.

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

- Existing rows are unaffected (NULL sender, `'INFO'` priority, `is_manual = 0`).
- `priority` values: `'INFO'`, `'WARNING'`, `'URGENT'` — enforced by `MessagePriority` enum (see §3.3).
- `is_manual = 1` distinguishes manuálne správy from system-generated notifications.

**`_onCreate` update:** The three new columns must also be added to the `CREATE TABLE app_notifications`
statement inside `_onCreate` so that fresh installs include them from the start.

### 3.2 Updated Dart model: `AppNotification`

Add three nullable/defaulted fields:

```dart
final String? senderUsername;        // who sent (null for system notifications)
final MessagePriority priority;      // INFO | WARNING | URGENT, default INFO
final bool    isManual;              // false for system, true for user messages
```

Add `userMessage('USER_MESSAGE')` to `NotificationType` enum.

Update `toMap()`, `fromMap()`, and `copyWith()` accordingly. `fromMap` must default `priority` to
`MessagePriority.info` when the column is absent or unrecognised, and `isManual` to `false`.

### 3.3 New enum: `MessagePriority`

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
    return MessagePriority.info; // safe default
  }
}
```

Defined in `lib/models/app_notification.dart` alongside the existing `NotificationType` enum.

---

## 4. Business Logic

### 4.1 `NotificationService.createUserMessage()`

```dart
Future<void> createUserMessage({
  required String senderUsername,
  required String title,
  required String body,
  required MessagePriority priority,
  List<String>? targetUsernames,  // null = broadcast to all users
}) async
```

Behaviour:
- If `targetUsernames == null`: call `DatabaseService().getAllUsers()` and insert one
  `AppNotification` per user whose username ≠ `senderUsername`.
- If `targetUsernames` is a non-empty list: insert one notification per listed username.
- **If `targetUsernames` is an empty list (`[]`): return immediately — no notifications inserted.**
- Each notification: `type = 'USER_MESSAGE'`, `isManual = true`, `senderUsername`, `priority`.
- Caller must validate that title and body are non-empty before calling.
- `priority` is typed as `MessagePriority` — no invalid values possible at call site.

### 4.2 `DatabaseService.getAllUsers()`

```dart
Future<List<User>> getAllUsers()
```

- Returns all users (`User` model, `lib/models/user.dart`) from the `users` table, ordered by
`username` ascending.
- Excludes users with an inactive/deleted flag if such a column exists in the `users` table;
  otherwise returns all rows.
- **Does not exclude the sender** — exclusion happens in `createUserMessage()` for both the
  broadcast path AND the targeted path (filter out senderUsername in both cases). The dialog
  shows all users including the current user so they can explicitly choose, but the service
  always skips inserting a notification to the sender.

---

## 5. UI

### 5.1 `NotificationCenterScreen` — filter tabs

Add a `TabBar` above the notification list with three tabs. The new tabs **replace** any existing
`typeFilter` dropdown/segmented button that filters by receipt/stock type — those sub-filters are
removed to keep the UI uncluttered. If finer filtering is needed in future it can be a separate
feature.

| Tab | Filter applied to query |
|-----|------------------------|
| Všetko | no filter (all notifications) |
| Správy | `is_manual = 1` |
| Systémové | `is_manual = 0` |

Filtering is done at the DB query level (pass an `isManual` bool parameter to
`getAppNotifications()`) rather than in-memory, to avoid loading unnecessary rows.

### 5.2 Manual message visual style

`AppNotification` cards where `isManual == true` render differently:

- Icon: `Icons.person_rounded` (instead of bell)
- Left coloured border (4 px):
  - `MessagePriority.info` → `Colors.blue`
  - `MessagePriority.warning` → `Colors.orange`
  - `MessagePriority.urgent` → `Colors.red`
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
  "Všetci" toggle at top selects/deselects all. The current user is shown but selecting them
  has no effect (service skips self-insertion).
- **Priorita** — `SegmentedButton<MessagePriority>` with three values: Info / Upozornenie / Urgentné

On "Odoslať":
1. Validate title and body non-empty; show `SnackBar` if invalid.
2. If "Všetci" is selected: show a brief `AlertDialog` confirmation ("Odoslať správu všetkým
   používateľom?") before proceeding. User must confirm.
3. Build `targetUsernames` list from selected checkboxes (or `null` if "Všetci" confirmed).
4. Call `NotificationService().createUserMessage(...)`.
5. `Navigator.pop(context)`.

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
- **`_onCreate` update:** Add the same three columns to the `CREATE TABLE app_notifications`
  statement so fresh installs include them from the start.
- **`onDowngrade`:** throws `DatabaseException` (standard policy).

---

## 8. Testing

**Unit tests** for `NotificationService.createUserMessage()`:
- Broadcast (`null` targetUsernames) → one notification per user except sender
- Targeted (list of 2 usernames) → exactly 2 notifications inserted
- **Empty list (`[]`) → no notifications inserted (returns immediately)**
- `MessagePriority.urgent` is stored and round-tripped correctly

**Widget tests** for `ComposeMessageDialog`:
- Submit with empty title → SnackBar shown, no navigation
- "Všetci" toggle selects all users and shows confirmation dialog before sending
- Priority selector changes `MessagePriority` value

**Model tests** for `AppNotification`:
- `fromMap` with missing `priority` column defaults to `MessagePriority.info`
- `fromMap` with missing `is_manual` column defaults to `false`
- `MessagePriority.fromString('UNKNOWN')` returns `MessagePriority.info`
