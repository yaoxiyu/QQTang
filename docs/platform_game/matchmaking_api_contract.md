# Matchmaking API Contract

## Status

This public client queue API is **legacy** after .
`MatchmakingUseCase` is retained only for old tests and backend smoke coverage.

Formal flow:

```text
Lobby -> match room -> DS room authority -> internal party queue -> hidden matchmade_room -> loading -> battle
```

Lobby and Room formal UI must not call this API directly.

Legacy base paths:

```text
/api/v1/matchmaking/queue/enter
/api/v1/matchmaking/queue/cancel
/api/v1/matchmaking/queue/status
```

Authentication:

- `Authorization: Bearer <access_token>`

Legacy semantics:

- One authenticated `profile_id` enters queue as a single entry.
- Request may include `mode_id`, `rule_set_id`, and `selected_map_ids`.
- This path is retained for old tests and compatibility only.

formal constraints:

- Do not use `selected_map_ids[]` as formal matchmaking input.
- Do not let Lobby directly enter queue.
- Do not let client choose final `map_id` or `rule_set_id`.
- Use [internal_party_matchmaking_contract.md](internal_party_matchmaking_contract.md) for DS -> game_service party queue.
