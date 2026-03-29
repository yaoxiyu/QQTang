# Phase3 Closeout Report

## Scope
本报告记录 Phase3 收尾阶段已经完成的结构收口、调试边界治理、Battle 生命周期加固、测试补齐与文档交接结果。

## Completed Work

### A. Canonical path and wrapper governance
- Formal flow canonical path is `res://app/flow/...`.
- Formal session canonical path is `res://network/session/...`.
- Legacy wrappers remain only under `res://gameplay/front/flow/...` and `res://gameplay/network/session/...`.
- Legacy wrappers are marked as compatibility-only and must not receive business logic.

### B. Debug room bootstrap decoupling
- RoomScene no longer hard-codes debug local loop room creation.
- Debug room bootstrap now depends on `AppRuntimeConfig`.
- `Phase3DebugTools` only executes local loop bootstrap when debug mode is explicitly enabled.

### C. Battle lifecycle hardening
- `BattleSessionAdapter` now exposes lifecycle states: `IDLE`, `STARTING`, `RUNNING`, `FINISHING`, `SHUTTING_DOWN`, `STOPPED`.
- `BattleMainController` now shuts down in a stricter order: stop tick/input, disconnect runtime stream signals, stop session runtime, release bootstrap, reset bridge/hud/settlement, then unregister and cleanup the scene.
- `AppRuntimeRoot.debug_dump_runtime_structure()` now reports battle lifecycle state, battle root child names, active scene state, and cleanup-related flags.

### D. Phase2 sandbox cleanup
- Phase2 sandbox scene and runtime dependencies are retired.
- Formal Battle entry is `res://scenes/battle/battle_main.tscn` only.
- Migration and scene contract documents explicitly state sandbox retirement.

### E. Phase3 test expansion
- Existing Phase3 runners remain available: room flow, battle flow, presentation sync, settlement, multi-match stability.
- New structure/runtime contract runners were added:
  - `canonical_path_contract_test_runner.gd`
  - `debug_room_bootstrap_test_runner.gd`
  - `battle_lifecycle_contract_test_runner.gd`
  - `runtime_cleanup_contract_test_runner.gd`
- `tests/phase3/README.md` documents execution order and responsibilities.

## Stable Debug Features Kept
- Delay profile toggle.
- Packet-loss profile toggle.
- Forced prediction divergence trigger.
- Item drop-rate debug toggle.
- Remote debug input toggle.
- Local loop room bootstrap through explicit runtime config.

## Verified Results
- Formal room -> loading -> battle -> settlement -> room loop remains available.
- BattleMain remains the only formal battle scene entry.
- HUD, settlement, prediction/rollback debug surface, item spawn and item pickup messaging remain functional.
- Multi-match stability runner still verifies repeated match cleanup.

## Known Environment Limitation
A subset of structure/runtime contract runners may crash in the local Godot CLI because the engine fails to open `user://logs/...` before test output is produced. This is an engine/runtime environment issue, not a Phase3 parse error. In that case, run the same runner inside the editor or after clearing the local user log directory.

## Explicitly Not Done In Phase3 Closeout
These items remain outside Phase3 closeout scope and are deferred to Phase4 or later:
- Real online socket/relay/dedicated-server integration.
- Production map authoring pipeline.
- Lobby/backend services.
- Spectator/replay product UI.
- New gameplay systems, new items, new characters, progression, cosmetics, commerce.

## Closeout Status
Phase3 is now in a state suitable for entering Phase4.
The remaining work after this point is extension work, not closeout debt.
