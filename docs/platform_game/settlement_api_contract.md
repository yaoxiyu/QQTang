# Settlement API Contract

## Scope

This document defines the public settlement summary HTTP contract served by `game_service`.

Base path:

```text
/api/v1/settlement/matches/{match_id}
```

Authentication:

- Requires `Authorization: Bearer <access_token>`.
- JWT validation uses the same shared secret as `account_service`.

Purpose:

- Provide authoritative progression deltas after battle ends.
- Support the settlement second-stage sync UI without blocking immediate local BattleResult display.

Settlement semantics:

- Victory/defeat/draw main outcome still comes from local `BattleResult`.
- Rating, rank tier, rewards, and career roll-up come from this endpoint.
- Caller must only request summaries for matches that belong to the authenticated profile.

## State Machine

Settlement sync states:

```text
pending -> committed
pending -> failed
failed -> committed
committed -> committed
```

Rules:

- `pending`: DS finalize has not completed or summary materialization is not yet visible.
- `failed`: finalize failed or summary fetch is temporarily unavailable.
- `committed`: authoritative summary is available and stable.

## GET /api/v1/settlement/matches/{match_id}

Return one authoritative settlement summary for the authenticated profile.

Success response when pending:

```json
{
  "ok": true,
  "match_id": "match_018",
  "profile_id": "profile_001",
  "server_sync_state": "pending",
  "rating_before": 1000,
  "rating_delta": 0,
  "rating_after": 1000,
  "rank_tier_after": "bronze",
  "season_point_delta": 0,
  "career_xp_delta": 0,
  "gold_delta": 0,
  "reward_summary": [],
  "career_summary": {
    "current_season_id": "season_s1",
    "current_rating": 1000,
    "current_rank_tier": "bronze",
    "career_total_matches": 17,
    "career_total_wins": 8,
    "career_total_losses": 7,
    "career_total_draws": 2
  },
  "updated_at": "2026-04-13T12:00:03Z"
}
```

Success response when committed:

```json
{
  "ok": true,
  "match_id": "match_018",
  "profile_id": "profile_001",
  "server_sync_state": "committed",
  "outcome": "win",
  "rating_before": 1000,
  "rating_delta": 24,
  "rating_after": 1024,
  "rank_tier_after": "silver",
  "season_point_delta": 12,
  "career_xp_delta": 30,
  "gold_delta": 80,
  "reward_summary": [
    {
      "reward_type": "season_point",
      "delta": 12
    },
    {
      "reward_type": "career_xp",
      "delta": 30
    },
    {
      "reward_type": "soft_gold",
      "delta": 80
    }
  ],
  "career_summary": {
    "current_season_id": "season_s1",
    "current_rating": 1024,
    "current_rank_tier": "silver",
    "career_total_matches": 18,
    "career_total_wins": 9,
    "career_total_losses": 7,
    "career_total_draws": 2,
    "career_win_rate_bp": 5000,
    "last_match_id": "match_018",
    "last_match_outcome": "win",
    "last_match_finished_at": "2026-04-13T12:00:00Z"
  },
  "updated_at": "2026-04-13T12:00:04Z"
}
```

Possible error codes:

- `AUTH_ACCESS_TOKEN_INVALID`
- `SETTLEMENT_MATCH_NOT_FOUND`
- `SETTLEMENT_MATCH_FORBIDDEN`
- `MATCH_FINALIZE_PENDING`
- `INTERNAL_ERROR`

Idempotency:

- Read-only endpoint. Repeated reads are safe.

Expiry semantics:

- Settlement summary remains queryable after finalize.
- `server_sync_state = pending` is temporary and should eventually converge to `committed` or `failed`.
- Client may return to Lobby even if response remains `pending`.
