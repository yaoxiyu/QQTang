# Phase36 DSM Docker Warm Pool Baseline

## Current Runtime Chain

The current manual room battle startup path is:

```text
Room owner start
  -> room_service StartManualRoomBattle
  -> game_service CreateManualRoomBattle / AllocateBattle
  -> ds_manager_service POST /internal/v1/battles/allocate
  -> allocator reserves a local host/port
  -> GodotProcessRunner exec.Command starts Godot
  -> Godot Battle DS fetches manifest
  -> Godot Battle DS reports ready to game_service and DSM
  -> room_service receives battle handoff host/port
```

## DSM Local Process Behavior

`services/ds_manager_service/internal/process/godot_process_runner.go` is the current lifecycle owner for Battle DS processes. It builds a command with:

```text
--headless
--path <DSM_PROJECT_ROOT>
<DSM_BATTLE_SCENE_PATH>
--
--qqt-battle-id=<battle_id>
--qqt-assignment-id=<assignment_id>
--qqt-match-id=<match_id>
--qqt-ds-host=<host>
--qqt-ds-port=<port>
--qqt-battle-ticket-secret=<secret>
```

It starts the process with `exec.CommandContext(ctx, r.config.GodotExecutable, args...)`, records the PID in memory, and removes the process entry when the child exits.

## DSM Allocation Behavior

`services/ds_manager_service/internal/httpapi/allocate_handler.go` decodes the allocation request, calls `allocator.Allocate`, then immediately calls `GodotProcessRunner.StartWithCallback`. If process startup fails, it releases the allocation and returns `PROCESS_START_FAILED`.

`services/ds_manager_service/internal/allocator/allocator.go` is a local in-memory port allocator. A DS instance is keyed by `battle_id` and tracks `InstanceID`, `BattleID`, `AssignmentID`, `MatchID`, `Host`, `Port`, `State`, `PID`, and timestamps. The state set is:

```text
starting
ready
active
failed
finished
```

The allocator owns a local TCP port pool from `DSM_PORT_RANGE_START` to `DSM_PORT_RANGE_END`.

## Docker Configuration Risk

`services/ds_manager_service/Dockerfile` builds a Go-only Alpine service image, but still configures DSM as if it can launch a local Godot runtime:

```text
DSM_GODOT_EXECUTABLE=godot4
DSM_PROJECT_ROOT=/workspace
DSM_BATTLE_SCENE_PATH=res://scenes/network/dedicated_server_scene.tscn
DSM_DS_HOST=127.0.0.1
```

`deploy/docker/docker-compose.services.dev.yml` exposes only the DSM HTTP port `18090`. It does not expose dynamic Battle DS ports, while it still sets:

```text
DSM_GODOT_EXECUTABLE
DSM_PROJECT_ROOT
DSM_BATTLE_SCENE_PATH
DSM_DS_HOST=127.0.0.1
```

This means the Docker path depends on Godot being available inside the DSM container, assumes `/workspace` is a valid Godot project root, and can return `127.0.0.1:<port>` as a client battle endpoint.

## GameService Behavior

`services/game_service/internal/battlealloc/service.go` creates a `battle_instances` row in `allocating`, updates assignment allocation state to `allocating`, calls DSM `/internal/v1/battles/allocate`, stores DSM `ds_instance_id/server_host/server_port`, and then writes `starting`.

Current risk: a successful allocate response means DSM started or attempted to start a local process, not necessarily that the Battle DS is connectable.

## RoomService Behavior

`services/room_service/internal/roomapp/service.go` remains the room authority. `StartManualRoomBattle` validates room ownership, readiness, selection, and manual-room constraints, then calls GameService and projects the battle handoff onto the room state.

This boundary should be preserved during Phase36. RoomService should consume GameService assignment projection and must not call DSM directly.

## Godot Battle DS Behavior

`network/runtime/battle_dedicated_server_bootstrap.gd` is already a battle-only runtime. It reads battle identifiers and host/port from command-line arguments, fetches the manifest from GameService, reports ready to GameService and DSM, accepts battle entry requests, and reports active once loading begins.

Current risk: `--qqt-battle-ticket-secret` can place a secret in the process command line.

## Baseline Conclusion

The current implementation is a local process launcher:

```text
DSM -> exec Godot process -> local port -> battle ready callback
```

Phase36 needs to move the official Docker path to:

```text
DSM -> Docker Warm Pool -> DSAgent assign -> Godot Battle DS inside DS container
```

The legacy local process path is useful as a temporary compatibility mode, but it is not a correct Docker runtime model.
