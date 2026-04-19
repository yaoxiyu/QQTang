# Runtime Topology

## Purpose
Define runtime ownership, formal process entrypoints, and legacy compatibility boundaries.

## Formal Entrypoints
- Client boot scene: `res://scenes/front/boot_scene.tscn`
- Battle scene: `res://scenes/battle/battle_main.tscn`
- Battle DS scene: `res://scenes/network/dedicated_server_scene.tscn`
- Room Service process: `services/room_service/cmd/room_service/main.go`

## Ownership
- `AppRuntimeRoot` is the client runtime composition root.
- `BootSceneController` is the runtime bootstrap owner.
- `Login/Lobby/Room/Loading` are runtime consumers and must not create another runtime graph.
- Opening a consumer scene without runtime must return to boot.

## Room/Battle Split
- Room authority (formal): Go Room Service in `services/room_service`.
- Battle authority (formal): Godot Battle DS runtime.
- Legacy Godot room authority remains compatibility-only:
  - `network/runtime/legacy/room_service_bootstrap.gd`
  - `network/session/legacy/server_room_service.gd`
  - `network/session/legacy/server_room_registry.gd`
  - `network/session/legacy/room_authority_runtime.gd`

## Client Room Protocol Stack
- GDScript facade:
  - `network/runtime/room_client/client_room_runtime.gd`
  - `network/runtime/room_client/room_client_gateway.gd`
- C# protocol layer:
  - `network/client_net/room/RoomWsClient.cs`
  - `network/client_net/room/RoomProtoCodec.cs`
  - `network/client_net/room/RoomSnapshotMapper.cs`
- Transport and wire format:
  - WebSocket binary frames.
  - Protobuf envelope payloads.

## Compatibility Rules
- Old paths under `network/runtime/*` and `network/session/runtime/*` are compatibility shells when marked deprecated.
- New Room client/runtime logic must go to:
  - `network/runtime/room_client/`
  - `network/session/room/model/`
  - `network/session/room/shared/`
- New Room server logic must not be added to Godot legacy room server paths.

