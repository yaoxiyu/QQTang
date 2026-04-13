# Account API Contract

## Scope

This document defines the Phase19 account authentication HTTP contract.

Base path:

```text
/api/v1/auth
```

Compatibility note:

- Current service temporarily keeps legacy `/v1/auth/*` routes for local migration.
- New callers should use `/api/v1/auth/*`.

Content type:

```text
application/json
```

Authentication:

- `POST /register` and `POST /login` do not require bearer auth.
- `POST /refresh` uses refresh token in request body.
- `POST /logout` and `GET /session` require `Authorization: Bearer <access_token>`.

Token semantics:

- `access_token` is a short-lived bearer token for authenticated API access.
- `refresh_token` is a long-lived session token used only for session refresh and logout.
- `device_session_id` identifies one client device session.
- Default TTL policy for Phase19 V1:
  - `access_token`: 15 minutes
  - `refresh_token`: 30 days
- When `allow_multi_device = false`, a new login revokes previous active session of the same account.

## Error Model

Common error response:

```json
{
  "ok": false,
  "error_code": "AUTH_INVALID_CREDENTIALS",
  "message": "Account or password is incorrect"
}
```

## POST /api/v1/auth/register

Register a new account and create the initial player profile.

Request JSON:

```json
{
  "account": "player001",
  "password": "P@ssw0rd123",
  "nickname": "PlayerA",
  "client_platform": "windows"
}
```

Rules:

- `account` must be non-empty and unique.
- `password` must be non-empty.
- `nickname` must be non-empty.
- Register creates:
  - one `accounts` row
  - one `player_profiles` row
  - one initial `account_sessions` row

Success response:

```json
{
  "ok": true,
  "account_id": "account_9b4d4fd1",
  "profile_id": "profile_54f43da2",
  "display_name": "PlayerA",
  "auth_mode": "password",
  "access_token": "atk_xxx",
  "refresh_token": "rtk_xxx",
  "device_session_id": "dsess_7e5e77b1",
  "access_expire_at_unix_sec": 1770000900,
  "refresh_expire_at_unix_sec": 1772592000,
  "session_state": "active"
}
```

Possible error codes:

- `AUTH_ACCOUNT_ALREADY_EXISTS`
- `AUTH_ACCOUNT_INVALID`
- `AUTH_PASSWORD_INVALID`
- `PROFILE_NICKNAME_INVALID`
- `INTERNAL_ERROR`

## POST /api/v1/auth/login

Login with account and password.

Request JSON:

```json
{
  "account": "player001",
  "password": "P@ssw0rd123",
  "client_platform": "windows"
}
```

Success response:

```json
{
  "ok": true,
  "account_id": "account_9b4d4fd1",
  "profile_id": "profile_54f43da2",
  "display_name": "PlayerA",
  "auth_mode": "password",
  "access_token": "atk_xxx",
  "refresh_token": "rtk_xxx",
  "device_session_id": "dsess_7e5e77b1",
  "access_expire_at_unix_sec": 1770000900,
  "refresh_expire_at_unix_sec": 1772592000,
  "session_state": "active"
}
```

Possible error codes:

- `AUTH_INVALID_CREDENTIALS`
- `AUTH_ACCOUNT_DISABLED`
- `AUTH_ACCOUNT_BANNED`
- `AUTH_SESSION_REVOKED`
- `INTERNAL_ERROR`

## POST /api/v1/auth/refresh

Refresh access session using refresh token.

Request JSON:

```json
{
  "refresh_token": "rtk_xxx",
  "device_session_id": "dsess_7e5e77b1"
}
```

Rules:

- Refresh token must match one active session.
- Revoked or expired refresh token must be rejected.
- Service may rotate refresh token on success.

Success response:

```json
{
  "ok": true,
  "account_id": "account_9b4d4fd1",
  "profile_id": "profile_54f43da2",
  "display_name": "PlayerA",
  "auth_mode": "password",
  "access_token": "atk_new_xxx",
  "refresh_token": "rtk_new_xxx",
  "device_session_id": "dsess_7e5e77b1",
  "access_expire_at_unix_sec": 1770001800,
  "refresh_expire_at_unix_sec": 1772595600,
  "session_state": "active"
}
```

Possible error codes:

- `AUTH_REFRESH_TOKEN_INVALID`
- `AUTH_REFRESH_TOKEN_EXPIRED`
- `AUTH_SESSION_REVOKED`
- `AUTH_DEVICE_SESSION_MISMATCH`
- `INTERNAL_ERROR`

## POST /api/v1/auth/logout

Revoke the current login session.

Headers:

```text
Authorization: Bearer <access_token>
```

Request JSON:

```json
{
  "refresh_token": "rtk_xxx",
  "device_session_id": "dsess_7e5e77b1"
}
```

Success response:

```json
{
  "ok": true,
  "session_state": "revoked"
}
```

Possible error codes:

- `AUTH_ACCESS_TOKEN_INVALID`
- `AUTH_REFRESH_TOKEN_INVALID`
- `AUTH_SESSION_REVOKED`
- `INTERNAL_ERROR`

## GET /api/v1/auth/session

Validate current access session and return current principal summary.

Headers:

```text
Authorization: Bearer <access_token>
```

Success response:

```json
{
  "ok": true,
  "account_id": "account_9b4d4fd1",
  "profile_id": "profile_54f43da2",
  "display_name": "PlayerA",
  "auth_mode": "password",
  "device_session_id": "dsess_7e5e77b1",
  "access_expire_at_unix_sec": 1770001800,
  "session_state": "active"
}
```

Possible error codes:

- `AUTH_ACCESS_TOKEN_INVALID`
- `AUTH_ACCESS_TOKEN_EXPIRED`
- `AUTH_SESSION_REVOKED`
- `INTERNAL_ERROR`
