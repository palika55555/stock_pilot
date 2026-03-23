# 2FA Support Runbook

## Scope
This runbook describes how to handle common TOTP 2FA incidents in Stock Pilot.

## Common incidents

### 1) User changed/lost authenticator device

1. Verify user identity through existing support process.
2. Ask user to login with a backup code if available.
3. If no backup code is available, admin disables 2FA for the user in DB:
   - set `twofa_enabled=false`
   - clear `twofa_secret_enc`, `twofa_secret_iv`, `twofa_confirmed_at`, `twofa_backup_codes_hash`, `twofa_last_used_step`
4. User logs in again and completes mandatory setup.

### 2) Repeated 2FA failures

1. Check `/health` -> `twofa.metrics.twofa_verify_fail`.
2. Validate server time sync (NTP) and user device time.
3. Confirm user is entering current 6-digit code (not old step).
4. If needed, temporarily use backup code path.

### 3) Brute force suspicion

1. Check rate-limit behavior on `/auth/login`, `/auth/2fa/verify`.
2. Confirm offending IP/request pattern in logs.
3. Escalate to infra for network-level blocking if needed.

## Required environment variables

- `TWOFA_ENCRYPTION_KEY` (32-byte base64 or 64-char hex)
- `TWOFA_ISSUER` (default: `StockPilot`)
- `TWOFA_ENFORCE_ALL=true|false`

## Rollback procedure

If rollout must be paused:

1. Set `TWOFA_ENFORCE_ALL=false`.
2. Keep existing users with `twofa_enabled=true` unchanged.
3. Confirm login path still works for non-2FA users.
4. Investigate and re-enable enforcement after fix.

