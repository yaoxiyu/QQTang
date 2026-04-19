# Room Protocol

## Scope
Define Phase24 room protocol truth from client to Room Service and Room Service to game control plane.

## Client <-> Room Service
- Transport: WebSocket.
- Frame type: binary only.
- Payload: protobuf envelope wire format.
- Request requirements:
  - `request_id` is required.
  - operation payload must be oneof-style valid.
- Response types:
  - `OperationAccepted`
  - `OperationRejected`
  - `RoomSnapshotPush`
  - room-directory and notice pushes when applicable.

## Client Protocol Layer Ownership
- C# owns protobuf encode/decode and WebSocket I/O:
  - `network/client_net/room/RoomWsClient.cs`
  - `network/client_net/room/RoomProtoCodec.cs`
  - `network/client_net/shared/ProtoEnvelopeUtil.cs`
- GDScript is facade only:
  - `network/runtime/room_client/client_room_runtime.gd`
  - `network/runtime/room_client/room_client_gateway.gd`
- Front use case must not manipulate protobuf bytes directly.

## Room Service <-> Game Service
- Control plane protocol: internal gRPC.
- Contract source: `proto/qqt/internal/game/v1/room_control.proto`.
- Required RPCs:
  - `EnterPartyQueue`
  - `CancelPartyQueue`
  - `GetPartyQueueStatus`
  - `CreateManualRoomBattle`
  - `CommitAssignmentReady`

## Contract Source Of Truth
- Room protobuf schemas:
  - `proto/qqt/room/v1/room_models.proto`
  - `proto/qqt/room/v1/room_client.proto`
  - `proto/qqt/room/v1/room_server.proto`
- No new hand-written ad-hoc binary room wire structure is allowed.

