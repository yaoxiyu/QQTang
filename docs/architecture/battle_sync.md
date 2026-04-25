# Battle Sync Architecture

> Current source of truth for dedicated-server battle frame sync runtime boundaries and performance risks.
> Last updated: 2026-04-25.

## Positioning

Battle sync is GDScript orchestration with native deterministic kernels.

GDScript still owns lifecycle and glue:

- ENet wrapper and transport polling.
- Runtime message routing.
- Dedicated-server authoritative tick scheduling.
- Client authority message ingestion.
- Prediction scheduling.
- Rollback restore and replay loop.
- Scene and presentation handoff.

Native code owns deterministic high-frequency data paths:

- movement calculation,
- explosion propagation,
- checksum,
- packed snapshot payload codec,
- snapshot ring storage,
- authority batch coalescing,
- input buffering and late input policy,
- snapshot diff,
- rollback planning,
- battle message codec.

Repository code and committed tests are the final authority when this document conflicts with implementation.

## Current Runtime Path

Client polling batches authority messages before runtime ingestion:

```text
consume_incoming()
  -> route non-authority messages
  -> coalesce authority messages in native
  -> ClientRuntime.ingest_authority_batch()
  -> at most one rollback/resync
  -> emit presentation tick once
```

Coalescing semantics:

- keep max `INPUT_ACK` per peer,
- keep latest `STATE_SUMMARY`,
- drop stale and intermediate `STATE_SUMMARY` packets before applying authority state,
- dedupe authority events by `event_id` when present, otherwise by tick/type/source/sequence fallback,
- keep latest non-stale `CHECKPOINT` / `AUTHORITATIVE_SNAPSHOT`,
- drop stale and intermediate authority snapshots before rollback,
- preserve authority events by tick,
- apply `MATCH_FINISHED` after coalesced authority state.

## Frame Sync Transport And Tick Truth

Dedicated-server battle sync follows these invariants:

1. Authority simulation ticks must execute one by one. Never skip directly to a final tick.
2. `ServerMatchService` must not run an unbounded `_process()` catch-up loop. A single process frame is budgeted and excessive accumulator backlog is clamped.
3. Multiple simulation ticks produced in one process frame may have their network output merged. This merges delivery, not simulation.
4. `STATE_SUMMARY` is a high-frequency lightweight packet and must not carry full `walls`.
5. Full `walls` state belongs in opening authority state, checkpoint, resume, or future wall deltas.
6. ENet transport is UDP-based and must route battle messages by type:
   - critical handshake, opening, finish: reliable critical channel,
   - `STATE_SUMMARY` / authority delta: unreliable ordered state channel,
   - `INPUT_FRAME` / `INPUT_BATCH`: unreliable ordered input channel,
   - checkpoint / authoritative snapshot: isolated reliable checkpoint channel,
   - ping, pong, debug: unreliable debug channel.
7. Opening full authority state is barriered. DS sends opening state, waits for client ready or timeout, then starts authority ticks with the first active delta ignored.
8. Client prediction advances idle ticks when local input is absent.
9. Client input is sent as `INPUT_BATCH` with recent-frame redundancy.
10. Rollback synchronous replay is budgeted. Very large replay spans force resync instead of replaying many ticks in one frame.

## Native-Backed Paths

Native classes are registered from `addons/qqt_native/src/register_types.cpp`.

| Domain | GDScript boundary | Native implementation |
| --- | --- | --- |
| Checksum | `gameplay/native_bridge/native_checksum_bridge.gd` | `addons/qqt_native/src/checksum/native_checksum_builder.*` |
| Snapshot ring | `gameplay/simulation/snapshot/snapshot_buffer.gd` | `addons/qqt_native/src/snapshot/native_snapshot_ring.*` |
| Snapshot codec | `gameplay/native_bridge/native_packed_state_codec_bridge.gd` | `addons/qqt_native/src/codec/native_packed_state_codec.*` |
| Movement | `gameplay/simulation/systems/movement_system.gd`, `gameplay/native_bridge/native_movement_bridge.gd` | `addons/qqt_native/src/movement/native_movement_kernel.*` |
| Explosion | `gameplay/simulation/systems/explosion_resolve_system.gd`, `gameplay/native_bridge/native_explosion_bridge.gd` | `addons/qqt_native/src/explosion/native_explosion_kernel.*` |
| Authority batch | `gameplay/native_bridge/native_authority_batch_bridge.gd` | `addons/qqt_native/src/sync/native_authority_batch_coalescer.*` |
| Input buffer | `gameplay/simulation/input/input_buffer.gd`, `gameplay/native_bridge/native_input_buffer_bridge.gd` | `addons/qqt_native/src/sync/native_input_buffer.*` |
| Late input policy | `network/session/runtime/authority_runtime.gd`, `gameplay/native_bridge/native_input_buffer_bridge.gd` | `addons/qqt_native/src/sync/native_input_buffer.*` |
| Snapshot diff | `gameplay/network/rollback/rollback_controller.gd`, `gameplay/native_bridge/native_snapshot_diff_bridge.gd` | `addons/qqt_native/src/sync/native_snapshot_diff.*` |
| Rollback planner | `gameplay/network/rollback/rollback_controller.gd`, `gameplay/native_bridge/native_rollback_planner_bridge.gd` | `addons/qqt_native/src/sync/native_rollback_planner.*` |
| Battle message codec | `network/transport/transport_message_codec.gd` | `addons/qqt_native/src/sync/native_battle_message_codec.*` |

## Native Policy

The sync paths above no longer use shadow, execute, or GDScript baseline fallback switches.

Current flag surface is coarse-grained:

```gdscript
require_native_kernels = true
enable_native_checksum = true
enable_native_snapshot_ring = true
enable_native_movement = true
enable_native_explosion = true
enable_native_authority_batch_coalescer = true
enable_native_input_buffer = true
enable_native_snapshot_diff = true
enable_native_rollback_planner = true
enable_native_battle_message_codec = true
```

Important behavior:

- native bridge failures fail closed with `push_error()` and empty or neutral results;
- transport byte payloads must be native codec payloads;
- `Dictionary` messages may still be normalized when passed in-process;
- `msg_type` remains a wire alias for `message_type`;
- rollback replay itself remains GDScript-owned.

Movement and explosion still have coarse enable flags. Turning either flag off re-enters the older GDScript simulation implementation. Treat that as a remaining cleanup risk, not a production rollout path.

## Input Timing

Dedicated-server start configs include:

- `opening_input_freeze_ticks`
- `network_input_lead_ticks`

Default values for dedicated-server topology:

```text
opening_input_freeze_ticks = 2 * TickRunnerScript.TICK_RATE
network_input_lead_ticks = 3
```

During opening freeze:

- clients poll DS authority messages and refresh predicted/presentation world;
- clients do not build or send local input;
- DS rejects input that still arrives during the freeze;
- DS emits one freeze-end log with dropped input count.

Client input target tick resolves from local prediction and latest authority:

```text
target_tick >= latest_authoritative_tick + network_input_lead_ticks
```

Runtime input lead is clamped to `[2, 12]`. Dedicated-server opening uses at least 6 lead ticks, then returns to the configured runtime lead. It should eventually be derived from measured RTT/jitter and adjusted continuously.

## Rollback Boundary

Native owns diff and planning decisions. GDScript still owns applying the plan:

- restore authoritative snapshot,
- inject local replay inputs,
- step predicted world,
- rebuild retained snapshots,
- emit visual corrections.

Synchronous replay is capped. If the replay span exceeds the large-replay guard, GDScript force-resyncs to the authoritative snapshot instead of replaying the entire span in one frame.

Remaining extraction candidates:

- rollback replay loop,
- type-specific battle message payload schema,
- peer compatibility and codec negotiation,
- production profiling for rollback replay cost.

Avoid moving high-level `ClientRuntime`, `AuthorityRuntime`, or router glue into C++ while those paths are still Dictionary-heavy.

## Verification

Latest validation for the native sync cleanup:

```powershell
powershell -ExecutionPolicy Bypass -File tests/scripts/check_gdscript_syntax.ps1
```

```text
[gdsyntax] PASS checked=749
```

Focused native chain suite:

```text
native_chain_cleanup: PASS total=11 pass=11 fail=0
```
