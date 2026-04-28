- [2026-04-19 18:13:52 +08:00] Step 1.1 baseline HEAD: 9174fa41573bda8044c525512014b0b69f96e805

- [2026-04-19 18:17:03 +08:00] Step 1.3 debt register updated: DEBT-007/008/009 created

- [2026-04-19 19:53:20 +08:00] Step 2.1 generated directories prepared with README guards

- [2026-04-19 20:13:57 +08:00] Step 2.2 buf.gen.yaml updated: csharp out -> network/client_net/generated, go paths=source_relative kept

- [2026-04-19 20:17:02 +08:00] Step 2.3 added scripts/proto/generate_proto.ps1 with buf check, clean, generate, non-zero fail behavior

- [2026-04-19 20:20:54 +08:00] Step 2.4 added scripts/proto/generate_proto.sh with buf check, clean, generate, non-zero fail behavior

- [2026-04-19 20:25:42 +08:00] Step 2.5 proto generation succeeded after installing buf and switching buf.gen plugins to remote

- [2026-04-19 20:34:04 +08:00] Step 3.1 updated QQTang.csproj with Google.Protobuf dependency

- [2026-04-19 20:35:10 +08:00] Step 3.2 created tests/csharp/QQTang.RoomClient.Tests/QQTang.RoomClient.Tests.csproj

- [2026-04-19 20:36:14 +08:00] Step 3.3 added QQTang.RoomClient.Tests to QQTang.sln

- [2026-04-19 20:38:41 +08:00] Step 4.1 added RoomClientEnvelopeFactory with 14 message_type -> ClientEnvelope mapping and envelope metadata fill

- [2026-04-19 20:39:26 +08:00] Step 4.2 added RoomServerEnvelopeParser and unified RoomProtocolDecodeException

- [2026-04-19 20:44:07 +08:00] Step 4.3 added RoomCanonicalMessageMapper for OperationAccepted/Rejected, Snapshot, DirectorySnapshot, BattleEntryReady, ResumeRejected, ServerNotice

- [2026-04-19 20:46:55 +08:00] Step 4.4 rewrote RoomProtoCodec to typed protobuf encode/decode and removed passthrough behavior

- [2026-04-19 20:47:17 +08:00] Step 4.4 rewrote RoomProtoCodec to typed protobuf encode/decode; temporary obsolete warnings remain until RoomWsClient rewrite in Step 4.7

- [2026-04-19 20:50:55 +08:00] Step 4.5 rewrote RoomSnapshotMapper to typed RoomSnapshot -> canonical dictionary mapping (selection/member/queue/battle fields, no reconnect token exposure)

- [2026-04-19 20:51:50 +08:00] Step 4.6 expanded RoomClientSessionState and switched envelope sequencing to NextSequence/LastRequestId

- [2026-04-19 20:54:03 +08:00] Step 4.7 rewrote RoomWsClient to protobuf send/receive pipeline and removed JSON path

- [2026-04-19 20:55:53 +08:00] Step 4.8 updated ProtoEnvelopeUtil with NextSequence(state) and wired RoomClientEnvelopeFactory to use it

- [2026-04-19 20:56:17 +08:00] Step 4.9 reviewed WsBinaryFrameReader: no business semantics, no extra copy, no code change required

- [2026-04-19 20:58:09 +08:00] Step 5.1 tightened ClientRoomRuntime facade: online consume prefers ws client, canonical message guard added

- [2026-04-19 21:45:25 +08:00] Step 5.2 isolated _transport as test-only path, added inject_test_room_transport, and made ws client the formal send path

- [2026-04-19 21:48:29 +08:00] Step 6.1 updated domain models: SelectedModeIDs rename, RoomMember TeamID/ConnectionState, RoomQueueState status fields, BattleHandoff AllocationState

- [2026-04-19 21:51:06 +08:00] Step 6.2 added MarkDisconnected(roomID, memberID), kept member in room with resume binding, set connection_state lifecycle to connected/disconnected

- [2026-04-19 21:52:31 +08:00] Step 6.3 added UpdateMatchRoomConfig(input) to roomapp with match-room/owner validation, manifest config validation, map-pool resolve, selection+max-player update and snapshot revision bump

- [2026-04-19 21:54:59 +08:00] Step 6.4 added EnterMatchQueue with owner/all-ready/queue-state guards, gameclient.EnterPartyQueue call, queue fields writeback and snapshot revision bump

- [2026-04-19 21:57:13 +08:00] Step 6.5 added CancelMatchQueue with queueing-state guard, gameclient.CancelPartyQueue call, queue state writeback and snapshot revision bump

- [2026-04-19 21:58:39 +08:00] Step 6.6 added StartManualRoomBattle with manual-room/owner/all-ready guards, gameclient.CreateManualRoomBattle call, battle handoff writeback (assignment/match/battle/server/allocation/ready) and snapshot revision bump

- [2026-04-19 22:00:24 +08:00] Step 6.7 added AckBattleEntry with room/member/assignment validation, gameclient.CommitAssignmentReady call, handoff+queue state writeback and snapshot revision bump

- [2026-04-19 22:04:28 +08:00] Step 6.8 unified snapshotProjectionLocked with lifecycle projection and member reconnect-token redaction; added lifecycle state updates across queue/manual/ack transitions

- [2026-04-19 22:08:40 +08:00] Step 7.1 replaced wsapi decoder/encoder formal path from hand-written protowire to generated protobuf unmarshal/marshal; roomapp+wsapi tests pass

- [2026-04-19 22:09:27 +08:00] Step 7.2 enforced decoder validation (request_id required, protocol_version whitelist, payload required) on generated oneof dispatch

- [2026-04-19 22:11:29 +08:00] Step 7.3 completed encoder payload coverage for OperationAccepted/Rejected, RoomSnapshotPush, RoomDirectorySnapshotPush, BattleEntryReadyPush, ServerNotice with generated protobuf marshal path

- [2026-04-19 22:14:24 +08:00] Step 7.4 expanded dispatcher to handle all 14 room operations with accepted/rejected + snapshot/directory/battle push sequencing and connection-based caller resolution

- [2026-04-19 22:15:41 +08:00] Step 7.5 added connection session context (boundRoomID/boundMemberID/directorySubscribed) with bind/clear/set methods and dispatcher success-path updates


- [2026-04-19 22:23:44 +08:00] Step 7.6 connected server disconnect callback to MarkDisconnected + room snapshot fanout + subscription cleanup

- [2026-04-19 22:23:44 +08:00] Step 7.7 implemented registry-backed directory index/subscribers, subscribe snapshot push, and directory broadcast on create/join/leave/update-selection/update-match-config; roomapp+wsapi tests pass

- [2026-04-19 22:27:01 +08:00] Step 7.8 added ROOM_ALLOWED_ORIGINS policy in config and ws CheckOrigin allowlist enforcement (dev relaxed, production requires allowlist); updated .env.example; roomapp/wsapi tests pass

- [2026-04-19 22:32:18 +08:00] Step 8.1 rewrote room_service gameclient/client.go to real typed gRPC client (dial/stub/timeout/error mapping) and added queue status API model

- [2026-04-19 22:32:18 +08:00] Step 8.2 split gameclient pb mapping into mappers.go and kept roomapp-facing DTO boundary in models.go; added gamev1 shim package to bridge generated internal-path visibility

- [2026-04-19 22:43:49 +08:00] Step 9.1 replaced game_service rpcapi structpb + manual ServiceDesc with generated typed request/response and generated service registration

- [2026-04-19 22:43:49 +08:00] Step 9.2 implemented typed rpcapi mapper layer (rpcapi/mapper.go) and generated service server wiring; added gamev1 shim for generated internal path visibility

- [2026-04-19 22:43:49 +08:00] Step 9.3 kept queue/battlealloc/assignment free of generated gRPC dependencies; typed mapping isolated in rpcapi only

- [2026-04-19 22:43:49 +08:00] Step 10.1 added C# Room SDK unit test files for envelope factory/proto codec/server parser/snapshot mapper/canonical mapper; Godot-runtime-dependent tests marked skip in plain dotnet host

- [2026-04-19 22:43:49 +08:00] Step 10.5 rewrote game_service rpcapi tests to generated client stub + generated request/response and removed structpb Invoke path

- [2026-04-19 22:45:38 +08:00] Step 10.2 rewrote room_service wsapi proto_roundtrip_test to generated protobuf roundtrip assertions (no protowire), including snapshot/member/loadout integrity and reconnect-token leak guard

- [2026-04-19 22:50:56 +08:00] Step 10.3 added ws_dispatcher_full_coverage_test to cover remaining room operations accepted/rejected sequencing through wsapi dispatcher

- [2026-04-19 22:50:56 +08:00] Step 10.4 added roomapp lifecycle tests for disconnect/resume, update_match_room_config, enter/cancel queue, start manual battle, and ack battle entry with fake typed game gRPC server

- [2026-04-19 22:58:39 +08:00] Step 10.6 added canonical room runtime integration tests for create/join/resume request forwarding path

- [2026-04-19 22:58:39 +08:00] Step 10.7 added runtime contract tests to guard against JSON formal path regression and to enforce test-only transport fallback semantics

- [2026-04-19 22:59:03 +08:00] Step 10.8 added runtime contract test to prevent formal path from re-depending on _transport fallback

- [2026-04-19 23:02:01 +08:00] Step 11.1 added scripts/validation/run_validation.ps1 and verified end-to-end run (proto+go+csharp; optional GUT switch)

- [2026-04-19 23:02:01 +08:00] Step 11.2 added .github/workflows/validate.yml with proto-and-go and csharp-room-sdk jobs; proto scripts adjusted to preserve non-generated shim directories

- [2026-04-19 23:18:57 +08:00] Refactored room client C# protocol mapping into runtime-agnostic core + Godot adapter layers; converted previous Godot-host-dependent xUnit skips to pure dotnet tests (7 passed, 0 skipped)

- [2026-04-19 23:33:12 +08:00] Step 13.1 refreshed source-of-truth docs for Current reality: current index, runtime topology, network control plane, room protocol, testing strategy, and room service runtime contract

- [2026-04-19 23:33:12 +08:00] Step 13.2 closed DEBT-007/008/009 in architecture debt register with updated linked tests, validation script, and CI evidence

