# Runtime Topology

## Purpose
Define runtime ownership and formal process entrypoints.

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
- Room authority (formal only): `services/room_service/cmd/room_service/main.go`.
- Battle authority (formal only): `network/runtime/battle_dedicated_server_bootstrap.gd`.

## Client Room Protocol Stack
- GDScript facade:
  - `network/runtime/room_client/client_room_runtime.gd`
  - `network/runtime/room_client/room_client_gateway.gd`
- C# protocol transport and codec:
  - `network/client_net/room/RoomWsClient.cs`
  - `network/client_net/room/RoomProtoCodec.cs`
  - `network/client_net/room/RoomClientEnvelopeFactory.cs`
  - `network/client_net/room/RoomServerEnvelopeParser.cs`
- C# runtime-agnostic core mapping:
  - `network/client_net/room/RoomClientEnvelopeFactoryCore.cs`
  - `network/client_net/room/RoomSnapshotMapperCore.cs`
  - `network/client_net/room/RoomCanonicalMessageMapperCore.cs`
  - `network/client_net/room/RoomGodotInteropConverter.cs`
- Transport and wire format:
  - WebSocket binary frames.
  - Protobuf envelope payloads.

## Service Runtime Generation Boundaries
- Room service generated protobuf and grpc code:
  - `services/room_service/internal/gen/qqt/room/v1/`
  - `services/room_service/internal/gen/qqt/internal/game/v1/`
- Game service generated protobuf and grpc code:
  - `services/game_service/internal/gen/qqt/room/v1/`
  - `services/game_service/internal/gen/qqt/internal/game/v1/`
- `gamev1shim` packages are compatibility bridge for Go `internal` path visibility and are not business logic layers.

## Compatibility Rules
- Legacy/compat runtime shells are removed.
- Removed legacy/compat paths include:
  - `gameplay/front/flow/`
  - `gameplay/network/session/`
  - `network/runtime/legacy/`
  - `network/session/legacy/`
  - `network/runtime/dedicated_server_bootstrap.gd`
  - `network/session/runtime/server_room_runtime.gd`
  - `network/session/runtime/server_room_runtime_compat_impl.gd`
  - `network/session/runtime/legacy_room_runtime_bridge.gd`
- Reintroduction of removed legacy/compat paths is forbidden.
- New Room client/runtime logic must go to:
  - `network/runtime/room_client/`
  - `network/session/room/model/`
  - `network/session/room/shared/`
- New Room server logic must not be added to any removed Godot legacy room server paths.
