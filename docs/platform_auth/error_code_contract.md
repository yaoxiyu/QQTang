# Error Code Contract

## Scope

This document defines the canonical Phase19 error codes shared by client, platform account service, and Dedicated Server room ticket validation.

Error response shape:

```json
{
  "ok": false,
  "error_code": "AUTH_INVALID_CREDENTIALS",
  "message": "Account or password is incorrect"
}
```

## General Rules

- `error_code` is stable and machine-readable.
- `message` is human-readable and may be localized later.
- Client use case layer should branch by `error_code`, not by `message`.
- HTTP handlers should map contract errors to consistent status codes.

## Auth Domain

| Error Code | Meaning | Suggested HTTP Status |
|---|---|---|
| `AUTH_ACCOUNT_ALREADY_EXISTS` | Register account already exists | `409` |
| `AUTH_ACCOUNT_INVALID` | Account name invalid or empty | `400` |
| `AUTH_PASSWORD_INVALID` | Password invalid or empty | `400` |
| `AUTH_INVALID_CREDENTIALS` | Login account or password mismatch | `401` |
| `AUTH_ACCOUNT_DISABLED` | Account disabled | `403` |
| `AUTH_ACCOUNT_BANNED` | Account banned | `403` |
| `AUTH_ACCESS_TOKEN_INVALID` | Access token malformed or unverifiable | `401` |
| `AUTH_ACCESS_TOKEN_EXPIRED` | Access token expired | `401` |
| `AUTH_REFRESH_TOKEN_INVALID` | Refresh token malformed or unknown | `401` |
| `AUTH_REFRESH_TOKEN_EXPIRED` | Refresh token expired | `401` |
| `AUTH_SESSION_REVOKED` | Session already revoked | `401` |
| `AUTH_DEVICE_SESSION_MISMATCH` | Device session mismatch | `409` |

## Profile Domain

| Error Code | Meaning | Suggested HTTP Status |
|---|---|---|
| `PROFILE_NOT_FOUND` | Current account profile missing | `404` |
| `PROFILE_NICKNAME_INVALID` | Nickname empty or invalid | `400` |
| `PROFILE_LOADOUT_NOT_OWNED` | Selected loadout not owned by current profile | `409` |

## Ticket Domain

| Error Code | Meaning | Suggested HTTP Status |
|---|---|---|
| `ROOM_TICKET_PURPOSE_INVALID` | Invalid ticket purpose | `400` |
| `ROOM_TICKET_TARGET_INVALID` | `room_id` or `room_kind` does not satisfy purpose contract | `400` |
| `ROOM_TICKET_LOADOUT_NOT_OWNED` | Selected room loadout not owned | `409` |
| `ROOM_TICKET_REQUESTED_MATCH_INVALID` | Invalid or missing requested match id for resume | `400` |
| `ROOM_TICKET_INVALID` | Ticket malformed or signature invalid | `401` |
| `ROOM_TICKET_EXPIRED` | Ticket expired | `401` |
| `ROOM_TICKET_CONSUMED` | Ticket already consumed | `409` |
| `ROOM_TICKET_PURPOSE_MISMATCH` | Ticket purpose does not match DS request type | `409` |
| `ROOM_TICKET_ROOM_MISMATCH` | Ticket room target mismatches request room | `409` |
| `ROOM_TICKET_ACCOUNT_MISMATCH` | Resume ticket account mismatches member binding | `403` |
| `ROOM_TICKET_PROFILE_MISMATCH` | Resume ticket profile mismatches member binding | `403` |

## Reconnect Domain

| Error Code | Meaning | Suggested HTTP Status |
|---|---|---|
| `ROOM_RECONNECT_TOKEN_INVALID` | Reconnect token invalid | `401` |
| `ROOM_RECONNECT_WINDOW_EXPIRED` | Resume window expired | `409` |
| `ROOM_MEMBER_NOT_FOUND` | Room member session missing | `404` |
| `ROOM_MATCH_NOT_FOUND` | Requested active match missing | `404` |

## Content Domain

| Error Code | Meaning | Suggested HTTP Status |
|---|---|---|
| `CONTENT_ASSET_INVALID` | Asset id is unknown or unsupported | `400` |

## Internal Domain

| Error Code | Meaning | Suggested HTTP Status |
|---|---|---|
| `INTERNAL_ERROR` | Unexpected server-side failure | `500` |
