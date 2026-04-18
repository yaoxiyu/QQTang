# GUT Migration Baseline 2026Q2

Date: 2026-04-18
Branch: feature/gut-migration-and-architecture-tightening
Scope: Baseline freeze only, no runtime behavior changes

## Test File Baseline

- tests/unit: 73 files
- tests/integration: 61 files
- tests/contracts: 12 files
- tests/smoke: 3 files
- total: 149 files

## Suite Script Baseline

- tests/scripts/run_cross_service_contract_suite.ps1
- tests/scripts/run_integration_suite.ps1
- tests/scripts/run_matchmaking_suite.ps1
- tests/scripts/run_network_suite.ps1
- tests/scripts/run_refactor_validation.ps1

## Large File Baseline

- app/flow/app_runtime_root.gd: 415 lines
- scenes/front/room_scene_controller.gd: 329 lines
- app/front/room/room_use_case.gd: 782 lines
- network/session/battle_session_adapter.gd: 939 lines
- network/session/runtime/client_runtime.gd: 854 lines
- scenes/battle/battle_main_controller.gd: 816 lines
- services/game_service/internal/queue/queue_service.go: 1000 lines

## Known Structural Debt Baseline

- Testing host is still custom runner based, not GUT unified.
- Internal auth exists in signer implementation, but finalize reporting path still needs protocol unification review.
- HTTP lifecycle abstraction exists, but key runtime flows still need consistency checks against direct HTTP client usage.
- Large runtime and battle classes indicate responsibility concentration and boundary expansion risk.
- Queue and allocation orchestration in game service remains highly concentrated in one service file.

## Change Constraint In This Work Package

- No business logic change.
- No gameplay semantics change.
- No engine generated file edits.
