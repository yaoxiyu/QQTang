# Room Service Runtime Contract

## Scope
This document defines the formal runtime contract of Phase24 Room Service.

## Formal Identity
- Service entrypoint: `services/room_service/cmd/room_service/main.go`
- Runtime language: Go.
- Protocol: WebSocket binary frames with protobuf wire payloads.
- Default room endpoint port: `9100` (`ROOM_WS_ADDR`, default `127.0.0.1:9100`).
- Health endpoints:
  - `/healthz`
  - `/readyz`

## Required Config
- `ROOM_HTTP_ADDR`
- `ROOM_WS_ADDR`
- `ROOM_TICKET_SECRET`
- `ROOM_MANIFEST_PATH`
- `ROOM_GAME_SERVICE_GRPC_ADDR`
- `ROOM_INSTANCE_ID`
- `ROOM_SHARD_ID`
- `ROOM_LOG_LEVEL`

## Runtime Architecture
```text
cmd/room_service/main.go
  -> internal/config
  -> internal/manifest (load room_manifest.json)
  -> internal/registry
  -> internal/roomapp (in-memory room authority)
  -> internal/wsapi (ws + protobuf gateway)
  -> internal/gameclient (grpc control-plane client)
```

## Responsibilities
- Verify room tickets for create/join/resume operations.
- Validate loadout and selection legality from room manifest.
- Maintain room aggregate state in memory.
- Support:
  - create room
  - join room
  - resume room
  - leave room
  - update profile
  - update selection
  - toggle ready
- Push room snapshot with `snapshot_revision`.
- Reject invalid requests with operation-level error payload.

## Not In Scope
- Battle runtime execution.
- Battle input authority.
- Battle scene orchestration in Godot runtime.

## Legacy Compatibility
- Old Godot room server paths are deprecated compatibility shells.
- Formal Room Service authority is no longer `res://scenes/network/room_service_scene.tscn`.

