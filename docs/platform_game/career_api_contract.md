# Career API Contract

## Scope

This document defines the public career summary HTTP contract served by `game_service`.

Base path:

```text
/api/v1/career/me
```

Authentication:

- Requires `Authorization: Bearer <access_token>`.
- JWT validation uses the same shared secret as `account_service`.

Purpose:

- Provide Lobby-facing aggregated progression data.
- Return current season snapshot and latest match summary without forcing client-side aggregation.

Data semantics:

- `career_summaries` is the primary source for lifetime aggregates.
- `season_rating_snapshots` is the primary source for current season rating and rank tier.
- Response is optimized for Lobby refresh and should remain lightweight.

## State Machine

Career summary freshness states:

```text
missing -> ready
ready -> refreshing
refreshing -> ready
refreshing -> stale
stale -> ready
```

Rules:

- `missing`: no historical match data exists yet.
- `ready`: summary reflects latest committed finalize visible to this profile.
- `refreshing`: aggregation is being rebuilt or repaired.
- `stale`: read path is available but summary may lag behind the latest finalize.

## GET /api/v1/career/me

Return current profile career summary and current season progression.

Success response:

```json
{
  "ok": true,
  "profile_id": "profile_001",
  "account_id": "account_001",
  "summary_state": "ready",
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
  "last_match_finished_at": "2026-04-13T12:00:00Z",
  "season_matches_played": 8,
  "season_wins": 4,
  "season_losses": 3,
  "season_draws": 1,
  "updated_at": "2026-04-13T12:00:02Z"
}
```

Success response when no data exists yet:

```json
{
  "ok": true,
  "profile_id": "profile_001",
  "account_id": "account_001",
  "summary_state": "missing",
  "current_season_id": "season_s1",
  "current_rating": 1000,
  "current_rank_tier": "bronze",
  "career_total_matches": 0,
  "career_total_wins": 0,
  "career_total_losses": 0,
  "career_total_draws": 0,
  "career_win_rate_bp": 0,
  "last_match_id": "",
  "last_match_outcome": "",
  "last_match_finished_at": null,
  "season_matches_played": 0,
  "season_wins": 0,
  "season_losses": 0,
  "season_draws": 0,
  "updated_at": "2026-04-13T12:00:02Z"
}
```

Possible error codes:

- `AUTH_ACCESS_TOKEN_INVALID`
- `PROFILE_NOT_FOUND`
- `CAREER_SUMMARY_NOT_FOUND`
- `INTERNAL_ERROR`

Idempotency:

- Read-only endpoint. Repeated reads are safe.

Expiry semantics:

- Response has no hard TTL for callers.
- `summary_state = stale` means data is readable but may not yet include the latest finalized match.
- Client may allow manual refresh when state is `stale` or `refreshing`.
