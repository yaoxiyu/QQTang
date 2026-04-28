# Internal Battle Allocation Contract

## Scope

This document defines the internal battle allocation HTTP contracts between `game_service`, `ds_manager_service`, and `battle_ds`.

Current introduces a three-step allocation flow:

1. `game_service` requests `ds_manager_service` to allocate a battle DS instance.
2. `battle_ds` reports ready to both `ds_manager_service` and `game_service`.
3. `game_service` updates assignment to `battle_ready` and notifies room_service.

---

## ds_manager_service Endpoints

Base URL: `http://<ds_manager_host>:<ds_manager_port>`

Default: `http://127.0.0.1:18090`

### POST /internal/v1/battles/allocate

Allocate a new battle DS instance. Called by `game_service`.

Request JSON:

```json
{
  "battle_id": "battle_001",
  "assignment_id": "assign_001",
  "match_id": "match_018",
  "host_hint": "127.0.0.1",
  "expected_member_count": 4
}
```

Request rules:

- `battle_id` required.
- `assignment_id` and `match_id` are passed through to the spawned process.
- `host_hint` is optional; `ds_manager_service` may override with `DSM_DS_HOST`.
- `expected_member_count` is informational.

Behavior:

- Allocates a port from the configured port pool (`DSM_PORT_RANGE_START` to `DSM_PORT_RANGE_END`).
- Spawns a Godot headless process with `DSM_BATTLE_SCENE_PATH` (default `res://scenes/network/dedicated_server_scene.tscn`).
- Sets up process exit callback to mark instance as finished or failed.

Success response:

```json
{
  "ok": true,
  "ds_instance_id": "inst_abc123",
  "allocation_state": "starting",
  "server_host": "127.0.0.1",
  "server_port": 19010
}
```

Possible error codes:

- `MISSING_BATTLE_ID`
- `ALLOCATION_FAILED` (port pool exhausted or duplicate battle_id)
- `PROCESS_START_FAILED`

### POST /internal/v1/battles/{battle_id}/ready

Mark a battle DS instance as ready. Called by `battle_ds` after it finishes bootstrap.

Path parameter:

- `battle_id`: the battle instance identifier.

No request body required.

Success response:

```json
{
  "ok": true,
  "battle_id": "battle_001",
  "state": "ready"
}
```

Possible error codes:

- `MISSING_BATTLE_ID`
- `MARK_READY_FAILED`

### POST /internal/v1/battles/{battle_id}/reap

Force-reap a battle DS instance. Called by `game_service` or operator tooling.

Path parameter:

- `battle_id`: the battle instance identifier.

No request body required.

Behavior:

- Kills the Godot process if still running.
- Releases the port allocation.

Success response:

```json
{
  "ok": true,
  "battle_id": "battle_001",
  "ds_instance_id": "inst_abc123",
  "reaped": true
}
```

Possible error codes:

- `MISSING_BATTLE_ID`
- `NOT_FOUND`

### Health Check

- `GET /healthz` returns `{"ok":true}`.

---

## game_service Battle Allocation Endpoints

### POST /internal/v1/battles/manual-room/create

Create an assignment and allocate a battle for a manual (custom) room. Called by `room_service` when a custom room is ready to start battle.

Authentication:

- Internal HMAC auth.

Request JSON:

```json
{
  "source_room_id": "room_abc",
  "source_room_kind": "private_room",
  "mode_id": "mode_classic",
  "rule_set_id": "ruleset_classic",
  "map_id": "map_classic_square",
  "expected_member_count": 2,
  "members": [
    {
      "account_id": "acc_1",
      "profile_id": "profile_1",
      "assigned_team_id": 1
    },
    {
      "account_id": "acc_2",
      "profile_id": "profile_2",
      "assigned_team_id": 2
    }
  ],
  "host_hint": "127.0.0.1"
}
```

Request rules:

- `source_room_id`, `mode_id`, `members[]` required.
- `host_hint` optional.
- `expected_member_count` defaults to `len(members)` if not provided.
- First member becomes captain with `ticket_role = "create"`.

Behavior:

- Creates assignment with `queue_type = "manual"`, `allocation_state = "assigned"`, `room_return_policy = "return_to_source_room"`.
- Creates assignment members with `battle_join_state = "assigned"`, `room_return_state = "pending"`.
- Calls `ds_manager_service` to allocate a battle DS instance.

Success response:

```json
{
  "ok": true,
  "assignment_id": "assign_abc123",
  "battle_id": "battle_abc123",
  "match_id": "match_abc123",
  "ds_instance_id": "inst_abc123",
  "allocation_state": "starting",
  "server_host": "127.0.0.1",
  "server_port": 19010
}
```

### POST /internal/v1/battles/{battle_id}/ready

Mark a battle as ready in `game_service`. Called by `battle_ds` after successful bootstrap.

Authentication:

- Internal HMAC auth.

Path parameter:

- `battle_id`: the battle instance identifier.

No request body required.

Behavior:

- Updates the battle instance state to `battle_ready`.
- Updates the assignment `allocation_state` to `battle_ready`.
- This triggers downstream notification to `room_service` which updates `RoomSnapshot.battle_entry_ready = true`.

Success response:

```json
{
  "ok": true,
  "battle_id": "battle_001",
  "state": "battle_ready"
}
```

Possible error codes:

- `MISSING_BATTLE_ID`
- `BATTLE_NOT_FOUND`
- `BATTLE_ALREADY_READY`
- `INTERNAL_ERROR`

---

## ds_manager_service Configuration

| Env Variable | Default | Description |
|---|---|---|
| `DSM_HTTP_ADDR` | `127.0.0.1:18090` | HTTP listen address |
| `DSM_GODOT_EXECUTABLE` | `godot4` | Path to Godot executable |
| `DSM_PROJECT_ROOT` | (empty) | Path to Godot project root |
| `DSM_BATTLE_SCENE_PATH` | `res://scenes/network/dedicated_server_scene.tscn` | Scene to run for battle DS |
| `DSM_BATTLE_TICKET_SECRET` | `dev_battle_ticket_secret` | Shared secret for battle ticket verification |
| `DSM_DS_HOST` | `127.0.0.1` | DS host address reported to clients |
| `DSM_PORT_RANGE_START` | `19010` | Start of port pool |
| `DSM_PORT_RANGE_END` | `19050` | End of port pool (exclusive) |
| `DSM_READY_TIMEOUT_SEC` | `15` | Seconds to wait for DS ready before reaping |
| `DSM_IDLE_REAP_TIMEOUT_SEC` | `300` | Seconds of idle before reaping a DS instance |

## Allocation State Machine

```text
assigned -> starting -> ready -> active -> finished
                    \-> failed
                    \-> reaped
```

- `assigned`: assignment created, allocation not yet requested.
- `starting`: DS process spawned, waiting for ready report.
- `ready`: DS process bootstrapped and accepting connections.
- `active`: at least one client connected.
- `finished`: battle completed normally.
- `failed`: DS process crashed or exited abnormally.
- `reaped`: instance force-removed by reaper or operator.

## Automatic Reaping

`ds_manager_service` runs a background reaper goroutine (10-second interval):

- Instances in `starting` state for longer than `DSM_READY_TIMEOUT_SEC` are killed and released.
- Instances idle for longer than `DSM_IDLE_REAP_TIMEOUT_SEC` are killed and released.

