# Internal Finalize Contract

## Scope

This document defines the internal finalize HTTP contract between Dedicated Server and `game_service`.

Base path:

```text
/internal/v1/matches/finalize
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
- Formal config keys are `GAME_INTERNAL_AUTH_KEY_ID`, `GAME_INTERNAL_AUTH_SHARED_SECRET`, and `GAME_INTERNAL_AUTH_MAX_SKEW_SECONDS`.

Purpose:

- Allow `battle_ds` to submit authoritative match results.
- Commit match result, player result, rating delta, reward ledger, and career summary in one service boundary.
- : After finalize commits, `game_service` notifies `room_service` that the source room can transition from `in_battle_frozen` to `awaiting_return`. This enables the post-battle return-to-source-room flow.

Finalize semantics:

- Dedicated Server is the only allowed reporter.
- Client never submits final result payload.
- `match_id` is the primary idempotency key.
- `result_hash` guards against conflicting duplicate finalize attempts.

## State Machine

Finalize state flow:

```text
pending -> committed
pending -> rejected
committed -> committed
```

Rules:

- `pending`: assignment exists and finalize has not yet committed.
- `committed`: all storage-side writes succeeded and settlement summary is stable.
- `rejected`: request is unauthorized, malformed, stale, or hash-conflicting.

## POST /internal/v1/matches/finalize

Commit one authoritative match result.

Request JSON:

```json
{
  "match_id": "match_018",
  "assignment_id": "assign_001",
  "room_id": "room_match_001",
  "room_kind": "matchmade_room",
  "season_id": "season_s1",
  "mode_id": "team_score",
  "rule_set_id": "ranked_rule",
  "map_id": "map_factory",
  "started_at": "2026-04-13T11:57:00Z",
  "finished_at": "2026-04-13T12:00:00Z",
  "finish_reason": "time_up",
  "score_policy": "team_score",
  "winner_team_ids": [1],
  "winner_peer_ids": [101, 102],
  "result_hash": "sha256:abc123",
  "member_results": [
    {
      "account_id": "account_001",
      "profile_id": "profile_001",
      "team_id": 1,
      "peer_id": 101,
      "outcome": "win",
      "player_score": 3,
      "team_score": 9,
      "placement": 1
    },
    {
      "account_id": "account_002",
      "profile_id": "profile_002",
      "team_id": 2,
      "peer_id": 202,
      "outcome": "loss",
      "player_score": 1,
      "team_score": 4,
      "placement": 2
    }
  ]
}
```

Request rules:

- `match_id` and `assignment_id` are required.
- `room_kind` must match assignment authoritative room kind.
- `member_results[]` must contain every committed assignment member once.
- `winner_team_ids` and `winner_peer_ids` may be empty for draw.
- `result_hash` must be deterministic for the same payload semantics.

Success response:

```json
{
  "ok": true,
  "finalize_state": "committed",
  "match_id": "match_018",
  "assignment_id": "assign_001",
  "already_committed": false,
  "result_hash": "sha256:abc123",
  "settlement_summary": {
    "profile_count": 4,
    "season_point_total": 24,
    "career_xp_total": 120,
    "soft_gold_total": 320
  },
  "finalized_at": "2026-04-13T12:00:01Z"
}
```

Success response for idempotent replay:

```json
{
  "ok": true,
  "finalize_state": "committed",
  "match_id": "match_018",
  "assignment_id": "assign_001",
  "already_committed": true,
  "result_hash": "sha256:abc123",
  "finalized_at": "2026-04-13T12:00:01Z"
}
```

Possible error codes:

- `MATCH_FINALIZE_ALREADY_COMMITTED`
- `MATCH_FINALIZE_HASH_MISMATCH`
- `MATCH_FINALIZE_ASSIGNMENT_NOT_FOUND`
- `MATCH_FINALIZE_MEMBER_RESULT_INVALID`
- `MATCH_FINALIZE_UNAUTHORIZED_REPORTER`
- `INTERNAL_AUTH_INVALID`
- `INTERNAL_ERROR`

Idempotency:

- Primary idempotency key is `match_id`.
- If repeated request has the same `match_id` and same `result_hash`, service must return committed success.
- If repeated request has the same `match_id` but different `result_hash`, service must reject with `MATCH_FINALIZE_HASH_MISMATCH`.

Expiry semantics:

- Finalize is valid only while assignment exists in a finalizable state.
- After successful commit, payload is immutable.
- Late finalize for expired or unrelated assignment must be rejected.
