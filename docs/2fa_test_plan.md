# 2FA Test Plan (Web + Flutter)

## Backend API

1. `POST /auth/login` with valid username/password and `twofa_enabled=true` returns:
   - `success=true`
   - `requires2fa=true`
   - `loginChallengeToken`
2. `POST /auth/2fa/verify` with valid TOTP returns JWT tokens.
3. `POST /auth/2fa/verify` with invalid TOTP returns `401`.
4. `POST /auth/2fa/verify` with same timestep TOTP replay returns `401`.
5. `POST /auth/2fa/setup` + `/auth/2fa/confirm` enables 2FA and returns backup codes.
6. `POST /auth/2fa/backup-codes/regenerate` returns a new list of codes.
7. `POST /auth/2fa/disable` with valid password + factor disables 2FA.
8. `/health` contains `twofa.metrics` counters.

## Web login flow

1. Login for account with 2FA enabled shows 2nd step input.
2. Login with backup code works once; repeated use fails.
3. Login for account without 2FA and backend flag `TWOFA_ENFORCE_ALL=true` triggers setup step.
4. Setup + first confirm code leads to dashboard and token is stored only after confirmation.

## Flutter login flow

1. Flutter login for account with 2FA enabled asks for code and proceeds only after verify.
2. Flutter setup flow displays `otpauth` URI and confirms first code.
3. Flutter Settings -> Security -> TOTP allows:
   - status check
   - backup code regeneration
   - disable flow

