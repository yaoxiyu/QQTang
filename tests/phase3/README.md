# Phase3 Tests

## Execution order
1. `room_flow_test_runner.gd`
2. `battle_flow_test_runner.gd`
3. `presentation_sync_test_runner.gd`
4. `settlement_test_runner.gd`
5. `multi_match_stability_test_runner.gd`
6. `canonical_path_contract_test_runner.gd`
7. `debug_room_bootstrap_test_runner.gd`
8. `battle_lifecycle_contract_test_runner.gd`
9. `runtime_cleanup_contract_test_runner.gd`

## Test responsibilities
- `room_flow_test_runner.gd`: front flow, room session, canonical scene path, AppRoot structure.
- `battle_flow_test_runner.gd`: battle bootstrap, battle root registration, session adapter runtime, item spawn, rollback debug hooks.
- `presentation_sync_test_runner.gd`: presentation bridge, actor registry, map view, spawn fx routing.
- `settlement_test_runner.gd`: settlement UI, HUD debug dump, reusable item pickup messages.
- `multi_match_stability_test_runner.gd`: repeated match stability, actor/fx cleanup, context recreation.
- `canonical_path_contract_test_runner.gd`: canonical path contract, no sandbox dependency, wrapper purity.
- `debug_room_bootstrap_test_runner.gd`: debug on/off room bootstrap behavior.
- `battle_lifecycle_contract_test_runner.gd`: lifecycle transitions and lifecycle debug dump contract.
- `runtime_cleanup_contract_test_runner.gd`: shutdown cleanup, battle root cleanup, runtime metric reset.

## Local validation notes
- Prefer running `room_flow`, `battle_flow`, `presentation_sync`, `settlement`, `multi_match` first.
- `canonical_path_contract`, `debug_room_bootstrap`, and `battle_lifecycle_contract` are structure/runtime contract tests and may hit the local Godot `user://logs` crash in this environment. If that happens, validate by opening the runner in the editor or re-running after clearing the local user log directory.
- Any test that touches real scene loading should be considered a runtime test, not a pure structure test.

## Validation focus
- No sandbox runtime dependency remains.
- Debug room bootstrap is no longer hard-wired into formal room initialization.
- Battle lifecycle can be observed through adapter state and AppRoot dump.
- Shutdown returns runtime metrics, battle root, and battle scene registration to a clean state.
