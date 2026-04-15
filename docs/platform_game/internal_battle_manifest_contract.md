# Internal Battle Manifest Contract

## Scope

This document defines the internal battle manifest HTTP contract between `battle_ds` and `game_service`.

Base path:

```text
/internal/v1/battles/{battle_id}/manifest
```

Authentication:

- Requires signed internal request headers (HMAC-SHA256).
- Required headers:
  - `X-Internal-Key-Id`
  - `X-Internal-Timestamp`
  - `X-Internal-Nonce`
  - `X-Internal-Body-SHA256`
  - `X-Internal-Signature`

Purpose:

- Allow `battle_ds` to fetch authoritative battle configuration after process bootstrap.
- Manifest contains the assignment lock data and expected member list that `battle_ds` uses to validate incoming battle tickets and set up the match.

Manifest semantics:

- Manifest is read-only, derived from the assignment and its members.
- `battle_ds` must fetch the manifest once during startup, before accepting client connections.
- Manifest data is authoritative; `battle_ds` must not trust client-supplied map/rule/mode/team over manifest values.

## GET /internal/v1/battles/{battle_id}/manifest

Return authoritative battle configuration for one battle instance.

Path parameter:

- `battle_id`: the battle instance identifier.

Success response:

```json
{
  "ok": true,
  "assignment_id": "assign_001",
  "battle_id": "battle_001",
  "match_id": "match_018",
  "map_id": "map_factory",
  "rule_set_id": "ranked_rule",
  "mode_id": "mode_team_score",
  "expected_member_count": 4,
  "members": [
    {
      "account_id": "account_001",
      "profile_id": "profile_001",
      "assigned_team_id": 1
    },
    {
      "account_id": "account_002",
      "profile_id": "profile_002",
      "assigned_team_id": 2
    }
  ]
}
```

Response rules:

- `members[]` contains every committed assignment member with their authoritative team assignment.
- `battle_ds` uses `expected_member_count` to know when all players have joined.
- `map_id`, `rule_set_id`, `mode_id` are the authoritative battle configuration.

Possible error codes:

- `MISSING_BATTLE_ID`
- `BATTLE_NOT_FOUND`
- `INTERNAL_AUTH_INVALID`
- `INTERNAL_ERROR`

## Usage By battle_ds

1. `battle_ds` process starts with `--battle-id`, `--assignment-id`, `--match-id` command-line arguments.
2. During bootstrap, `battle_ds` fetches manifest from `game_service`.
3. `battle_ds` uses manifest to configure the match: map, rules, mode, expected players.
4. When a client connects with a battle ticket, `battle_ds` verifies the ticket's `assignment_id` matches the manifest.
5. `battle_ds` reports ready to both `ds_manager_service` and `game_service` after manifest fetch and setup complete.
