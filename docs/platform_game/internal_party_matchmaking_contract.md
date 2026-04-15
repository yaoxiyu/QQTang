# Internal Party Matchmaking Contract

## Scope

Phase22 formal matchmaking uses internal DS -> game_service party queue APIs.

Phase23 note: After successful assignment, `game_service` now triggers battle allocation via `ds_manager_service` before reporting `battle_ready`. The assigned response no longer implies a direct DS endpoint for the `matchmade_room` pattern. Instead, `battle_server_host/port` come from the allocation flow. See `internal_battle_allocation_contract.md`.

Base paths:

```text
POST /internal/v1/matchmaking/party-queue/enter
POST /internal/v1/matchmaking/party-queue/cancel
GET  /internal/v1/matchmaking/party-queue/status
```

Authentication:

- Internal HMAC auth, or `X-Internal-Secret` during current DS compatibility.

## Enter Party Queue

Request:

```json
{
  "party_room_id": "room_abc",
  "queue_type": "ranked",
  "match_format_id": "2v2",
  "selected_mode_ids": ["mode_classic", "mode_score_team"],
  "members": [
    {
      "account_id": "acc_1",
      "profile_id": "profile_1",
      "device_session_id": "dev_1",
      "seat_index": 0
    }
  ]
}
```

Rules:

- `queue_type`: `casual` or `ranked`.
- `match_format_id`: `1v1`, `2v2`, or `4v4`.
- `members.size()` must equal the required party size for the format.
- `selected_mode_ids[]` must contain at least one mode.
- Request must not contain `map_id`, `rule_set_id`, `selected_map_ids[]`, or `preferred_map_pool_id`.

Success:

```json
{
  "ok": true,
  "queue_state": "queued",
  "queue_entry_id": "party_queue_001",
  "party_room_id": "room_abc",
  "queue_key": "ranked:2v2",
  "queue_type": "ranked",
  "match_format_id": "2v2",
  "selected_mode_ids": ["mode_classic", "mode_score_team"],
  "queue_status_text": "Searching for teams"
}
```

## Cancel Party Queue

Request:

```json
{
  "party_room_id": "room_abc",
  "queue_entry_id": "party_queue_001"
}
```

Success:

```json
{
  "ok": true,
  "queue_state": "cancelled",
  "queue_entry_id": "party_queue_001",
  "party_room_id": "room_abc"
}
```

## Status

Query:

```text
party_room_id=room_abc&queue_entry_id=party_queue_001
```

Assigned response:

```json
{
  "ok": true,
  "queue_state": "assigned",
  "queue_entry_id": "party_queue_001",
  "party_room_id": "room_abc",
  "assignment_id": "assign_001",
  "assignment_revision": 1,
  "room_id": "room_match_001",
  "room_kind": "matchmade_room",
  "server_host": "127.0.0.1",
  "server_port": 9000,
  "mode_id": "mode_classic",
  "rule_set_id": "ruleset_classic",
  "map_id": "map_classic_square",
  "captain_account_id": "acc_1"
}
```

## Assignment Policy

Party queue key:

```text
{queue_type}:{match_format_id}
```

Pairing rules:

- Same `queue_type`.
- Same `match_format_id`.
- Both parties are full premade teams.
- `selected_mode_ids[]` intersection is non-empty.

Final authority order:

```text
selected_mode_ids[] intersection -> final mode_id -> random legal map_id -> bound rule_set_id
```

The client and pre-queue match room never choose the final map.

