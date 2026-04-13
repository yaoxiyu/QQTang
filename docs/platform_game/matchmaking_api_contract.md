# Matchmaking API Contract

## Scope

This document defines the public matchmaking HTTP contract served by `game_service`.

Base paths:

```text
/api/v1/matchmaking/queue/enter
/api/v1/matchmaking/queue/cancel
/api/v1/matchmaking/queue/status
```

Authentication:

- Requires `Authorization: Bearer <access_token>`.
- JWT validation uses the same shared secret as `account_service`.

Purpose:

- Enter one active queue per profile.
- Poll queue progress until assignment is ready.
- Cancel queue explicitly before assignment commit.

Queue semantics:

- Phase20 only supports `2v2`.
- One `profile_id` can have only one active queue entry in states `queued`, `assigned`, or `committing`.
- Assignment data is authoritative once status becomes `assigned`.
- Client must not synthesize `map_id`, `rule_set_id`, `mode_id`, or `team_id` after assignment.

## State Machine

Queue state flow:

```text
idle -> queued -> assigned -> committing -> finalized
               \-> cancelled
               \-> expired
```

Rules:

- `idle`: no active queue entry.
- `queued`: entry is waiting in matchmaking pool.
- `assigned`: assignment is ready and ticket grant may be requested.
- `committing`: assignment exists and at least one member has started room commit.
- `cancelled`: queue was cancelled by caller or heartbeat timeout.
- `expired`: assignment revision expired or assignment deadline elapsed.
- `finalized`: match result has been committed by DS finalize.

## Queue Key

Queue key format:

```text
{queue_type}:{mode_id}:{rule_set_id}:2v2
```

Examples:

- `casual:team_rescue:rescue_rule:2v2`
- `ranked:team_score:ranked_rule:2v2`

## POST /api/v1/matchmaking/queue/enter

Create one queue entry for the current authenticated profile.

Request JSON:

```json
{
  "queue_type": "ranked",
  "mode_id": "team_score",
  "rule_set_id": "ranked_rule",
  "preferred_map_pool_id": ""
}
```

Request rules:

- `queue_type` must be one of `casual`, `ranked`.
- `mode_id` and `rule_set_id` are required.
- `preferred_map_pool_id` is optional in Phase20 and may be empty.
- If the same `profile_id` already has an active queue entry, request must fail.

Success response:

```json
{
  "ok": true,
  "queue_entry_id": "queue_001",
  "queue_state": "queued",
  "queue_key": "ranked:team_score:ranked_rule:2v2",
  "enqueue_unix_sec": 1770000100,
  "last_heartbeat_unix_sec": 1770000100,
  "assignment_id": "",
  "assignment_revision": 0,
  "expires_at_unix_sec": 1770000400
}
```

Possible error codes:

- `AUTH_ACCESS_TOKEN_INVALID`
- `MATCHMAKING_QUEUE_TYPE_INVALID`
- `MATCHMAKING_MODE_INVALID`
- `MATCHMAKING_RULE_SET_INVALID`
- `MATCHMAKING_QUEUE_ALREADY_ACTIVE`
- `PROFILE_NOT_FOUND`
- `INTERNAL_ERROR`

Idempotency:

- No idempotent replay guarantee.
- Repeating the same request while active queue exists must return `MATCHMAKING_QUEUE_ALREADY_ACTIVE`.

Expiry semantics:

- `expires_at_unix_sec` represents current queue heartbeat expiry for the active entry.
- If heartbeat is not refreshed within TTL, service may auto-cancel the entry.

## POST /api/v1/matchmaking/queue/cancel

Cancel the current active queue entry for the authenticated profile.

Request JSON:

```json
{
  "queue_entry_id": "queue_001"
}
```

Request rules:

- `queue_entry_id` is optional if profile has exactly one active queue.
- If `assigned` entry has already moved into a newer `assignment_revision`, stale cancel must fail.

Success response:

```json
{
  "ok": true,
  "queue_entry_id": "queue_001",
  "queue_state": "cancelled",
  "cancel_reason": "client_cancelled"
}
```

Possible error codes:

- `AUTH_ACCESS_TOKEN_INVALID`
- `MATCHMAKING_QUEUE_NOT_FOUND`
- `MATCHMAKING_ASSIGNMENT_REVISION_STALE`
- `INTERNAL_ERROR`

Idempotency:

- Cancelling an already cancelled entry may return success with the same terminal state.

Expiry semantics:

- Terminal `cancelled` entries are not resumable.
- Caller must re-enter queue with a new queue entry.

## GET /api/v1/matchmaking/queue/status

Return the current queue or assignment state for the authenticated profile.

Query parameters:

```text
queue_entry_id=<optional>
```

Success response when queued:

```json
{
  "ok": true,
  "queue_state": "queued",
  "queue_entry_id": "queue_001",
  "queue_key": "ranked:team_score:ranked_rule:2v2",
  "assignment_id": "",
  "assignment_revision": 0,
  "queue_status_text": "Searching for players",
  "assignment_status_text": "",
  "enqueue_unix_sec": 1770000100,
  "last_heartbeat_unix_sec": 1770000130,
  "expires_at_unix_sec": 1770000430
}
```

Success response when assigned:

```json
{
  "ok": true,
  "queue_state": "assigned",
  "queue_entry_id": "queue_001",
  "queue_key": "ranked:team_score:ranked_rule:2v2",
  "assignment_id": "assign_001",
  "assignment_revision": 2,
  "ticket_role": "join",
  "room_id": "room_match_001",
  "room_kind": "matchmade_room",
  "server_host": "127.0.0.1",
  "server_port": 9000,
  "mode_id": "team_score",
  "rule_set_id": "ranked_rule",
  "map_id": "map_factory",
  "assigned_team_id": 2,
  "captain_account_id": "account_captain",
  "queue_status_text": "Match found",
  "assignment_status_text": "Waiting for ticket request",
  "captain_deadline_unix_sec": 1770000160,
  "commit_deadline_unix_sec": 1770000220
}
```

Possible error codes:

- `AUTH_ACCESS_TOKEN_INVALID`
- `MATCHMAKING_QUEUE_NOT_FOUND`
- `MATCHMAKING_ASSIGNMENT_EXPIRED`
- `MATCHMAKING_ASSIGNMENT_REVISION_STALE`
- `INTERNAL_ERROR`

Idempotency:

- Read-only endpoint. Same state may be polled repeatedly.

Expiry semantics:

- If assignment deadline or revision becomes stale, service must return `expired` or `MATCHMAKING_ASSIGNMENT_REVISION_STALE`.
- Client must stop using old assignment data once stale is reported.
