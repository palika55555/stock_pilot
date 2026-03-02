# Sync/Async & User Isolation Audit Report – Stock Pilot

**Date:** 2025-03-02  
**Scope:** Flutter app + Node/PostgreSQL backend (auth, data isolation, async, sync, API)

---

## SECTION A – Authentication & User Isolation

### Current structure of data in DB

**Backend (PostgreSQL):**
- **Flat structure – NO user separation.**
- Tables: `users`, `customers`, `products`, `stocks`, `production_batches`, `production_batch_recipe`, `pallets`, `schema_migrations`.
- **None** of the data tables have a `user_id` column.
- Path structure is effectively:
  - `users` (id, username, password, …)
  - `customers` (id, local_id, name, ico, …) – shared
  - `products` (id, unique_id, warehouse_id, …) – shared
  - `stocks` – shared
  - `production_batches` / `pallets` – shared

**Flutter (SQLite):**
- Same idea: `products`, `customers`, `inbound_receipts`, `quotes`, etc. have **no `user_id`**.
- Single shared DB; “current user” is only in memory / SharedPreferences (fullname, username, role). All queries are global.

### Authentication flow

- **Login:** Flutter uses local SQLite (`getUserByUsername` + password check). Then optionally calls backend `POST /auth/login` (username/password), gets token, stores it in `api_sync_service.dart` as global `_backendToken`.
- **Token storage:** In-memory only (`String? _backendToken` in `api_sync_service.dart`). Not in SharedPreferences; lost on app restart (user stays “logged in” locally but backend requests fail until next login).
- **Backend token:** Format `Bearer-${base64(user.id)}-${Date.now()}`. Middleware only checks presence of `Authorization: Bearer-...`, **does not** parse or validate the token, and **does not** attach `userId` to the request.

### Queries correctly filtered by user ID

- **Backend:** None. No endpoint filters by user.
- **Flutter:** Only `app_notifications` uses `target_username` in one query. All other data (customers, products, receipts, batches, etc.) is unfiltered.

### Queries NOT filtered by user ID (security risk)

- **Backend – all of these return or modify shared data:**
  - `GET/POST /stocks`
  - `POST /sync/products`, `POST /sync/customers`, `POST /sync/batches`
  - `GET /customers`, `GET /customers/:id`, `PUT /customers/:id`
  - `GET /products`, `GET /products/by-barcode`, `GET/PATCH /products/:uniqueId`
  - `GET/POST /batches/*`, `GET/POST /pallets/*`
  - `GET /dashboard/stats`
  - `GET /sync/check` (returns global `lastCustomersUpdatedAt`; also Flutter does not send `Authorization` for this call, so it gets 401 when auth is required)
- **Flutter:** All `DatabaseService` methods that read/write customers, products, receipts, batches, etc. use no user filter.

### Recommendation: how data should be structured

- **Backend:** Add `user_id INTEGER NOT NULL REFERENCES users(id)` to: `customers`, `products`, `stocks`, `production_batches`, `pallets`. Every SELECT/INSERT/UPDATE/DELETE must use `WHERE user_id = req.userId` (with `req.userId` from token). Sync endpoints must set `user_id` from the authenticated user.
- **Token:** Middleware must decode the Bearer token, validate it (e.g. extract user id from base64 part), set `req.userId`, and reject invalid/expired tokens.
- **Flutter:** Keep single SQLite DB but either: (a) add `user_id` to all tables and pass current user id into all services, or (b) one DB file per user (e.g. path by user id). Prefer (a) for simplicity. On logout: clear backend token and optionally clear or mark local cache for re-fetch on next login.

---

## SECTION B – Async Issues Found

| File | Line / area | Severity | Issue | Fix |
|------|-------------|----------|--------|-----|
| `lib/screens/Login/login_page.dart` | 69–102 | **CRITICAL** | Multiple `await`s after login success; no `mounted` check between them. If user leaves screen (e.g. back), `setState`/`context`/navigation can run after dispose. | After every `await` in the login block, add `if (!mounted) return;` before any `setState`, `context`, or navigation. |
| `lib/screens/Login/login_page.dart` | 62–65 | WARNING | `await _dbService.setRememberMe` / `setSavedUsername` / `clearSavedLogin` called without checking `mounted` before subsequent use of context. | Ensure all context/setState use after these awaits is guarded by `mounted`. |
| `lib/services/sync_check_service.dart` | 34–46 | **CRITICAL** | `fetchSyncCheck()` does not send `Authorization` header. Backend `/sync/check` requires token → 401 → `data` is always null → sync-needed notification never fires. | In `api_sync_service.dart`, add optional token parameter to `fetchSyncCheck` and send `Authorization: token` when provided. `SyncCheckService` should get token (e.g. from a getter) and pass it. |
| `lib/widgets/Time/mobile_time_display_widget.dart` | (initState) | INFO | Uses `Timer.periodic`; need to confirm it’s cancelled in `dispose`. | Ensure `dispose()` cancels the timer (same pattern as `time_display_widget.dart`). |
| Various screens | initState → _loadX() | WARNING | Many screens call async `_load()` from `initState()` without awaiting; some `_load` methods may not check `mounted` before `setState`. | In each `_load` that does async work and then `setState`, add `if (!mounted) return;` before `setState`. |

### StreamSubscription

- **Home_screen.dart:** `_syncSubscription` is assigned in `initState` and **cancelled in `dispose()`** – OK.
- No other `StreamSubscription` found that needs cancellation.

### Async pattern in initState

- Correct pattern used in several places: `initState` calls `_loadData()` (no await); `_loadData()` is `async` and uses `if (!mounted) return` before `setState`. Where this is missing (e.g. some `_load` methods), it should be added.

---

## SECTION C – Sync Issues Found

### Current sync mechanism

- **Type:** Polling + one-way or two-way HTTP. No WebSockets or Firestore.
- **Flow:** On login, Flutter pushes users/customers/products/batches to backend (sync endpoints), then pulls customers/products/batches from backend and replaces or merges local data.
- **Sync check:** `SyncCheckService` calls `GET /sync/check` every 45s. Backend returns `customers_updated_at` (global timestamp). Flutter does **not** send Authorization → 401 → sync check effectively disabled.
- **Offline:** No local queue; failed HTTP calls are ignored or logged. No “offline mode” banner or conflict resolution.
- **Caching:** Local SQLite is the cache. No separate Hive/SharedPreferences cache for API responses.
- **Token persistence:** Backend token is in-memory only; after app restart, backend sync/fetch fails until user logs in again.

### Issues

1. **Sync check broken:** No token sent → 401 → no “sync needed” notification.
2. **No per-user sync:** Backend and Flutter treat all data as global; multiple users overwrite each other’s data on sync.
3. **No loading/error for sync:** Many screens don’t show loading during initial load or sync; errors are often silent (e.g. `catch (_)`).
4. **replaceCustomersFromBackend / replaceBatchesFromBackend:** Replace entire local list with backend list; if backend is not user-scoped, one user’s data overwrites another’s.

### Screens that may not show loading indicators

- Many list screens call `_load()` in `initState`; some may not have an explicit `isLoading` state and `CircularProgressIndicator`. Audit per screen: `customers_page`, `suppliers_page`, `warehouses_page`, `price_quotes_list_screen`, `production_list_screen`, `recipe_list_screen`, `stock_out_screen`, `goods_receipt_screen`, etc.

### Screens that may not handle errors

- Same as above; many `_load` methods use `try/catch` but only log or ignore; no SnackBar or error state. Examples: various modals and list screens that call `_db.get...()` or API without showing error to user.

---

## SECTION D – Security Issues

1. **Data accessible without per-user isolation:** Any authenticated user (any valid Bearer token) can read/update all customers, products, batches, pallets. Token is not tied to user id in backend logic.
2. **Token not validated:** Backend only checks that header starts with `Bearer-`; it does not decode or verify the token, so a forged token with the same prefix could be used.
3. **No user_id in requests:** Backend never reads `user_id` from token; even if client sent `user_id` in body, it should be ignored and taken from token only.
4. **Endpoints that don’t verify user:** All non-auth endpoints require *a* token but do not verify that the token belongs to the user whose data is being accessed (because there is no per-user data).
5. **Info leak:** `GET /health/db-tables` is unprotected (no API path prefix or auth); it exposes table and migration list. Consider moving behind same prefix/auth or keeping only for internal use.
6. **Sync overwrites:** `sync/customers` and `sync/products` do `DELETE FROM customers` / `DELETE FROM products` then insert; with multiple users, one user’s sync wipes another’s data.

---

## Summary of required fixes

1. **Backend:** Add `user_id` to all data tables; parse Bearer token to `req.userId`; filter all queries and sync inserts by `req.userId`; never trust `user_id` from body.
2. **Flutter:** Send token with `fetchSyncCheck`; add `mounted` checks in login flow; on logout clear backend token; consider persisting token and passing current user id into services for future per-user local DB.
3. **Async:** Add `if (!mounted) return` before every `setState`/context use after await in login and in any `_load` that updates state asynchronously; ensure all timers/subscriptions are cancelled in `dispose`.
4. **Sync:** Fix sync check with auth; implement per-user backend data and sync; add loading/error states where missing.

---

## STEP 6: Verification checklist (after fixes)

- [x] Backend: Token parsed and `req.userId` set; all DB queries filter by `user_id`.
- [x] Backend: Migration 008 adds `user_id` to customers, products, stocks, production_batches, pallets.
- [x] No user can access another user's data (all endpoints use `req.userId`).
- [x] Flutter: All async in login flow guarded by `mounted` before setState/context.
- [x] Flutter: `StreamSubscription` in HomeScreen cancelled in `dispose()`.
- [x] Flutter: Timer in `mobile_time_display_widget` cancelled in `dispose()`.
- [x] Flutter: `fetchSyncCheck` sends Authorization token; SyncCheckService passes token.
- [x] Flutter: Logout clears backend token in drawer, user options sheet, mobile user info.
- [ ] All screens show loading/error/empty states (partial; many screens still need explicit states).
- [x] Auth token sent with every API request (Flutter uses token from getBackendToken where needed).
- [ ] Token refresh: not implemented (token does not expire on backend; optional).
- [x] Logout clears backend token (in-memory); local DB remains until next login.
- [ ] App works offline: read from local SQLite only; no offline queue for writes (future).
- [ ] No console errors or unhandled exceptions: run app and test manually.

---

## Implementation Summary (post-fix)

### CRITICAL 1: JWT & secure storage ✅
- **Backend:** `jsonwebtoken` added. Login returns `accessToken` (24h or 7d if rememberMe), `refreshToken` (30d). `POST /auth/refresh` with body `{ refreshToken }` returns new tokens. Middleware verifies JWT and sets `req.userId`, `req.userEmail`, `req.userRole`. All API requests use `Authorization: Bearer <jwt>`.
- **Flutter:** `flutter_secure_storage` for access + refresh tokens. `AuthStorageService` read/write. `api_sync_service`: `saveTokensAndSet`, `clearTokensAndToken`, `getBackendTokenAsync`, `refreshAccessToken`. All HTTP calls use `Bearer $token`. Login sends `rememberMe` and stores tokens via `saveTokensAndSet`.

### CRITICAL 2: Local SQLite user_id ⏸️ deferred
- Not implemented in this pass (would require adding `user_id` to many tables and updating all queries in `DatabaseService`). Recommended as a separate task: add `user_id TEXT` to customers, products, receipts, quotes, production_batches, pallets; backfill with a default; then filter all reads/writes by current user and clear on logout.

### CRITICAL 3: Data migration flag ✅
- **Migration 009:** `app_settings` table with `data_isolation_migrated`. Set to `true` automatically if only one user exists; otherwise `false`.
- **Backend:** After migrations, reads flag into `dataIsolationMigrated`. Every API response includes header `X-Data-Isolation-Warning: true` when migration is required.
- **Admin:** `POST /admin/migrate-user-data` (admin only) body: `{ recordType, recordIds, targetUserId, markComplete? }`. When `markComplete: true`, sets `data_isolation_migrated` to true.

### IMPORTANT 4: LogoutService ✅
- `LogoutService.logout(context)` clears tokens (secure storage + in-memory), clears saved login, stops SyncCheckService and SyncService, then `pushAndRemoveUntil` to LoginPage.
- All three logout entry points (drawer, user options sheet, mobile user info) call `LogoutService.logout(context)`.

### IMPORTANT 5: Sync on login ✅
- After backend login, UI shows “Načítavam vaše dáta...” and runs push (customers, products, batches) then `SyncService.initialSync(userId, token)` (pull customers, products, batches and replace local). Then navigates to home. On sync failure, snackbar still allows continuing (offline).

### IMPORTANT 6: Background sync ✅
- `SyncService.startSync(userId)`: 5-min timer + connectivity listener; each run calls `SyncCheckService.triggerCheck()`. Started from HomeScreen `initState`; `SyncService.stopSync()` in HomeScreen `dispose` and from LogoutService.

### Verification checklist (updated)
- JWT signed/verified with JWT_SECRET; token in flutter_secure_storage; refresh token flow; expired token → 401.
- Backend queries use req.userId (from JWT); logout clears token and stops sync.
- Fresh data on login via initialSync; background sync every 5 min; sync uses JWT; logout clears tokens and cancels timers.
- JWT_SECRET from env in production; admin endpoint requires admin role; no user_id from body.

---

*End of report.*
