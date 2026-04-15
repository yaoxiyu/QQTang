# Room Ticket Contract

## Scope

This document defines the room ticket HTTP contract and the ticket claim model used by room_service.

Phase23 note: Room tickets are consumed only by `room_service`. Battle-entry tickets are a separate contract; see `battle_ticket_contract.md`.

Base path:

```text
/api/v1/tickets/room-entry
```

Compatibility note:

- Current service temporarily keeps legacy `POST /v1/room-tickets` for local migration.
- New callers should use `POST /api/v1/tickets/room-entry`.

Authentication:

- Requires `Authorization: Bearer <access_token>`.

Purpose:

- Client must obtain a short-lived room ticket before online create, join, or resume on `room_service`.
- `room_service` only verifies ticket claims. It does not process password or refresh token.
- Phase23: `room_service` must reject `battle_entry` purpose tickets. Use `IsRoomOnlyTicket(purpose)` to validate.

Ticket semantics:

- Ticket TTL: 30 to 60 seconds, current default 45 seconds.
- Ticket is one-time use.
- Expired ticket must be rejected.
- Consumed ticket must be rejected.
- `refresh_token` and `reconnect_token` are never embedded into room ticket claims.

## Ticket Claim Schema

Claim payload:

```json
{
  "ticket_id": "ticket_2ee3f1d2",
  "account_id": "account_9b4d4fd1",
  "profile_id": "profile_54f43da2",
  "device_session_id": "dsess_7e5e77b1",
  "purpose": "create",
  "room_id": "",
  "room_kind": "private_room",
  "requested_match_id": "",
  "assignment_id": "",
  "match_source": "manual",
  "locked_map_id": "",
  "locked_rule_set_id": "",
  "locked_mode_id": "",
  "assigned_team_id": 0,
  "expected_member_count": 0,
  "auto_ready_on_join": false,
  "hidden_room": false,
  "display_name": "PlayerA",
  "allowed_character_ids": ["character_default", "character_knight"],
  "allowed_character_skin_ids": ["skin_default"],
  "allowed_bubble_style_ids": ["bubble_style_default"],
  "allowed_bubble_skin_ids": ["bubble_skin_default"],
  "issued_at_unix_sec": 1770000000,
  "expire_at_unix_sec": 1770000045,
  "nonce": "nonce_128bit",
  "signature": "sig_xxx"
}
```

Rules:

- `display_name` comes from profile authoritative nickname.
- Allowed asset sets are copied from current owned assets snapshot.
- DS uses allowed asset sets for loadout validation without profile service round-trip.
- Matchmade room tickets additionally carry assignment-locked fields granted by `game_service`.

## POST /api/v1/tickets/room-entry

Issue one ticket for create, join, or resume.

Request JSON:

```json
{
  "purpose": "create",
  "room_id": "",
  "room_kind": "private_room",
  "requested_match_id": "",
  "assignment_id": "",
  "selected_character_id": "character_default",
  "selected_character_skin_id": "skin_default",
  "selected_bubble_style_id": "bubble_style_default",
  "selected_bubble_skin_id": "bubble_skin_default"
}
```

Request rules:

- `purpose` must be one of `create`, `join`, `resume`.
- `room_id`:
  - empty for create
  - required for join
  - required for resume
- `requested_match_id`:
  - optional for create and join
  - required when resume targets an active match
- `assignment_id`:
  - empty for manual room flows
  - required for `matchmade_room`
  - when paired with `room_kind = "matchmade_room"`, `account_service` must query `game_service` internal grant and must not trust client-supplied map/rule/mode/team
- Selected loadout must be owned by current profile.

Success response:

```json
{
  "ok": true,
  "ticket": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.xxx",
  "ticket_id": "ticket_2ee3f1d2",
  "account_id": "account_9b4d4fd1",
  "profile_id": "profile_54f43da2",
  "device_session_id": "dsess_7e5e77b1",
  "purpose": "create",
  "room_id": "",
  "room_kind": "private_room",
  "requested_match_id": "",
  "assignment_id": "",
  "match_source": "manual",
  "locked_map_id": "",
  "locked_rule_set_id": "",
  "locked_mode_id": "",
  "assigned_team_id": 0,
  "expected_member_count": 0,
  "auto_ready_on_join": false,
  "hidden_room": false,
  "display_name": "PlayerA",
  "allowed_character_ids": ["character_default", "character_knight"],
  "allowed_character_skin_ids": ["skin_default"],
  "allowed_bubble_style_ids": ["bubble_style_default"],
  "allowed_bubble_skin_ids": ["bubble_skin_default"],
  "issued_at_unix_sec": 1770000000,
  "expire_at_unix_sec": 1770000045
}
```

Possible error codes:

- `AUTH_ACCESS_TOKEN_INVALID`
- `PROFILE_NOT_FOUND`
- `ROOM_TICKET_PURPOSE_INVALID`
- `ROOM_TICKET_TARGET_INVALID`
- `ROOM_TICKET_LOADOUT_NOT_OWNED`
- `ROOM_TICKET_REQUESTED_MATCH_INVALID`
- `ROOM_TICKET_ASSIGNMENT_GRANT_FAILED`
- `ROOM_TICKET_ASSIGNMENT_GRANT_FORBIDDEN`
- `INTERNAL_ERROR`

## Claim Differences By Purpose

### Create ticket

- `purpose = "create"`
- `room_id = ""`
- `room_kind` required
- `requested_match_id = ""`
- Used by DS create flow before room exists

### Join ticket

- `purpose = "join"`
- `room_id` required
- `room_kind` optional but recommended
- `requested_match_id = ""`
- Used by DS join flow to enter an existing room

### Resume ticket

- `purpose = "resume"`
- `room_id` required
- `requested_match_id` may be required for active match resume
- Used together with:
  - `member_id`
  - `reconnect_token`
- DS must additionally verify:
  - `ticket.account_id == binding.account_id`
  - `ticket.profile_id == binding.profile_id`

### Matchmade ticket (Phase23: deprecated flow)

Phase23 note: `matchmade_room` is deprecated. New battle flows use the battle-entry ticket contract instead of room tickets with `matchmade_room` kind. The following is retained for migration compatibility only.

- `room_kind = "matchmade_room"`
- `assignment_id` required
- `match_source = "matchmaking"`
- `locked_map_id`, `locked_rule_set_id`, `locked_mode_id`, and `assigned_team_id` come from internal assignment grant
- `expected_member_count`, `auto_ready_on_join`, and `hidden_room` come from internal assignment grant
- account_service must not trust client-provided selection/team for this case

## Expiry And Consumption

- Ticket becomes invalid after `expire_at_unix_sec`.
- Ticket becomes invalid after first successful consume.
- DS should reject stale, replayed, or mismatched target ticket.
