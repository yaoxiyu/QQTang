# Battle Ticket Contract

## Scope

This document defines the battle-entry ticket HTTP contract between clients and `account_service`.

Base path:

```text
/api/v1/tickets/battle-entry
```

Authentication:

- Requires `Authorization: Bearer <access_token>`.

Purpose:

- Client must obtain a short-lived battle ticket before connecting to an allocated `battle_ds`.
- Battle ticket is separate from room ticket. Room ticket is consumed by `room_service`, battle ticket is consumed by `battle_ds`.
- `battle_ds` must not accept room-purpose tickets (`create`, `join`, `resume`).

Ticket semantics:

- Ticket TTL: configurable via `ACCOUNT_BATTLE_TICKET_TTL_SECONDS`, default 45 seconds.
- Ticket is one-time use.
- Expired or consumed ticket must be rejected.
- Ticket purpose is `battle_entry`.
- `account_service` queries `game_service` internal assignment grant to populate authoritative lock data. Client-supplied map/rule/mode/team are never trusted.

## Ticket Claim Schema

Claim payload:

```json
{
  "ticket_id": "bticket_a1b2c3d4e5f6",
  "account_id": "account_9b4d4fd1",
  "profile_id": "profile_54f43da2",
  "device_session_id": "dsess_7e5e77b1",
  "purpose": "battle_entry",
  "room_id": "",
  "room_kind": "",
  "requested_match_id": "match_018",
  "assignment_id": "assign_001",
  "locked_map_id": "map_factory",
  "locked_rule_set_id": "ranked_rule",
  "locked_mode_id": "mode_team_score",
  "assigned_team_id": 2,
  "expected_member_count": 4,
  "display_name": "PlayerA",
  "issued_at_unix_sec": 1770000000,
  "expire_at_unix_sec": 1770000045,
  "nonce": "nonce_128bit",
  "signature": "sig_xxx"
}
```

Rules:

- `purpose` is always `battle_entry`.
- `room_id` and `room_kind` are empty. Battle ticket does not target a room.
- `assignment_id` is required and must correspond to a valid, grantable assignment.
- Lock fields (`locked_map_id`, `locked_rule_set_id`, `locked_mode_id`, `assigned_team_id`, `expected_member_count`) come from internal assignment grant. They are never client-provided.
- `display_name` comes from profile authoritative nickname.

## POST /api/v1/tickets/battle-entry

Issue one battle-entry ticket.

Request JSON:

```json
{
  "assignment_id": "assign_001",
  "battle_id": "battle_001"
}
```

Request rules:

- `assignment_id` required.
- `battle_id` required.
- `account_service` resolves the caller's profile from the access token.
- `account_service` queries `game_service` assignment grant with `ticket_type=battle` to obtain authoritative lock data and battle endpoint.

Success response:

```json
{
  "ok": true,
  "ticket": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.xxx",
  "ticket_id": "bticket_a1b2c3d4e5f6",
  "account_id": "account_9b4d4fd1",
  "profile_id": "profile_54f43da2",
  "device_session_id": "dsess_7e5e77b1",
  "assignment_id": "assign_001",
  "battle_id": "battle_001",
  "match_id": "match_018",
  "map_id": "map_factory",
  "rule_set_id": "ranked_rule",
  "mode_id": "mode_team_score",
  "assigned_team_id": 2,
  "expected_member_count": 4,
  "battle_server_host": "127.0.0.1",
  "battle_server_port": 19010,
  "issued_at_unix_sec": 1770000000,
  "expire_at_unix_sec": 1770000045
}
```

Possible error codes:

- `BATTLE_TICKET_MISSING_FIELDS`
- `BATTLE_TICKET_GRANT_FAILED`
- `BATTLE_TICKET_ASSIGNMENT_GRANT_FAILED`
- `BATTLE_TICKET_ASSIGNMENT_GRANT_FORBIDDEN`
- `AUTH_ACCESS_TOKEN_INVALID`
- `PROFILE_NOT_FOUND`
- `INTERNAL_ERROR`

## Consumption Rules

- Battle ticket purpose is `battle_entry`.
- `CanConsumeBattleTicket(purpose)` returns true only for `battle_entry`.
- `IsRoomOnlyTicket(purpose)` returns true for `create`, `join`, `resume`.
- `battle_ds` must verify ticket purpose before accepting a connection.
- `room_service` must reject `battle_entry` purpose tickets.

## Expiry And Consumption

- Ticket becomes invalid after `expire_at_unix_sec`.
- Ticket becomes invalid after first successful consume.
- `battle_ds` should reject stale, replayed, or mismatched target ticket.
