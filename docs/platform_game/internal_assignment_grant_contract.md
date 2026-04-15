# Internal Assignment Grant Contract

## Scope

This document defines the internal assignment grant HTTP contract between `account_service` and `game_service`.

Base path:

```text
/internal/v1/assignments/{assignment_id}/grant
```

Authentication:

- Requires signed internal request headers.
- Required headers:
  - `X-Internal-Key-Id`
  - `X-Internal-Timestamp`
  - `X-Internal-Nonce`
  - `X-Internal-Body-SHA256`
  - `X-Internal-Signature`
- Signature canonical string is `METHOD + "\n" + PATH_AND_QUERY + "\n" + TIMESTAMP + "\n" + NONCE + "\n" + BODY_SHA256`.
- Signature algorithm is `HMAC-SHA256(<shared_secret>, canonical_string)`.
- `game_service` rejects unknown key ids, missing headers, body hash mismatch, stale timestamps, invalid signatures, and nonce replay within the configured skew window.
- Formal config keys are `ACCOUNT_GAME_INTERNAL_AUTH_KEY_ID`, `ACCOUNT_GAME_INTERNAL_AUTH_SHARED_SECRET`, `GAME_INTERNAL_AUTH_KEY_ID`, `GAME_INTERNAL_AUTH_SHARED_SECRET`, and `GAME_INTERNAL_AUTH_MAX_SKEW_SECONDS`.

Purpose:

- Allow `account_service` to fetch authoritative assignment lock data before issuing a room ticket for `matchmade_room` or a battle ticket for `battle_entry`.
- Prevent client-supplied map/rule/mode/team fields from being trusted in matchmaking or battle-entry flows.
- Phase23: When `ticket_type=battle` and `battle_id` are provided, grant response additionally includes `battle_server_host`, `battle_server_port`, and `allocation_state`.

Grant semantics:

- Grant is read-only and derived from `assignment` plus `assignment_member`.
- Caller must provide current authenticated member identity.
- Returned lock data is intended to be copied into the room ticket claim without reinterpretation.

## State Machine

Assignment grant states:

```text
assigned -> grantable
grantable -> committed
grantable -> expired
committed -> finalized
```

Rules:

- `assigned`: assignment exists but caller has not requested a grant yet.
- `grantable`: assignment revision is current and ticket may be issued.
- `committed`: member has started room entry using issued ticket.
- `expired`: assignment revision or deadline is no longer valid for ticket issuance.
- `finalized`: match has already finished and no new room-entry grant is allowed.

## GET /internal/v1/assignments/{assignment_id}/grant

Return authoritative ticket grant data for one assignment member.

Query parameters:

```text
account_id=<required>
profile_id=<required>
room_kind=matchmade_room
```

Phase23 battle-entry grant additional query parameters:

```text
ticket_type=battle
battle_id=<required for battle grants>
```

When `ticket_type=battle`, the response includes additional fields: `battle_server_host`, `battle_server_port`, `allocation_state`.

Success response:

```json
{
  "ok": true,
  "assignment_id": "assign_001",
  "assignment_revision": 2,
  "grant_state": "grantable",
  "match_source": "matchmaking",
  "queue_type": "ranked",
  "ticket_role": "join",
  "room_id": "room_match_001",
  "room_kind": "matchmade_room",
  "match_id": "match_018",
  "season_id": "season_s1",
  "server_host": "127.0.0.1",
  "server_port": 9000,
  "locked_map_id": "map_factory",
  "locked_rule_set_id": "ranked_rule",
  "locked_mode_id": "team_score",
  "assigned_team_id": 2,
  "expected_member_count": 4,
  "auto_ready_on_join": true,
  "hidden_room": true,
  "captain_account_id": "account_captain",
  "captain_deadline_unix_sec": 1770000160,
  "commit_deadline_unix_sec": 1770000220
}
```

Possible error codes:

- `MATCHMAKING_ASSIGNMENT_NOT_FOUND`
- `MATCHMAKING_ASSIGNMENT_MEMBER_NOT_FOUND`
- `MATCHMAKING_ASSIGNMENT_EXPIRED`
- `MATCHMAKING_ASSIGNMENT_REVISION_STALE`
- `MATCHMAKING_ASSIGNMENT_GRANT_FORBIDDEN`
- `MATCH_FINALIZE_ALREADY_COMMITTED`
- `INTERNAL_AUTH_INVALID`
- `INTERNAL_ERROR`

Idempotency:

- Read-only endpoint. Multiple reads for the same current revision must return equivalent lock data.

Expiry semantics:

- Returned grant is valid only for the current `assignment_revision`.
- Ticket issuance must fail if revision changes before account_service signs the ticket.
- Once `commit_deadline_unix_sec` is exceeded, grant must be considered expired.
