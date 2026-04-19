# Testing Strategy

## Purpose
Define formal test authority for current codebase: layering, execution entrypoints, migration guards, and regression strategy.

## Test Layers
- `res://tests/unit/`: unit tests.
- `res://tests/integration/`: integration flow tests.
- `res://tests/contracts/`: path, runtime, and protocol contract guards.
- `res://tests/smoke/`: smoke stability tests.
- `res://tests/gut/base/`: project GUT base classes.
- `res://tests/helpers/`: helper scripts and test utilities.
- `tests/csharp/QQTang.RoomClient.Tests/`: C# room client SDK unit tests.
- `services/*/.../*_test.go`: Go unit and integration tests for control plane and room authority.

## Execution Entrypoints
- Local validation entry: `scripts/validation/run_phase25_validation.ps1`.
- Proto generation: `scripts/proto/generate_proto.ps1` and `scripts/proto/generate_proto.sh`.
- GUT suite entry: `tests/scripts/run_gut_suite.ps1`.
- CI entry: `.github/workflows/phase25_validate.yml`.
- Legacy custom `tests/cli` runner path is removed and forbidden.

## Constraints
- New capability must add tests at matching layers, minimum unit plus key integration or contract.
- New GDScript tests must inherit one of:
  `QQTUnitTest`, `QQTIntegrationTest`, `QQTContractTest`, `QQTSmokeTest`.
- GDScript test functions must use `test_` prefix and GUT assertions.
- C# room protocol changes under `network/client_net/room/` must include committed xUnit tests.
- Production code must not depend on test folders.
- Legacy style rollback is forbidden, including `extends Node + _ready()`, `signal test_finished`, and `TestAssert.is_true`.

## Migration Guards
- `tests/contracts/path/no_legacy_node_test_style_contract_test.gd`: block legacy Node style test rollback.
- `tests/contracts/path/no_legacy_test_runner_reference_contract_test.gd`: block legacy runner references.
- `tests/contracts/path/legacy_wrapper_guard_test.gd`: block business re-dependency on legacy wrappers.
- `tests/contracts/runtime/room_client_runtime_no_json_path_contract_test.gd`: block JSON formal-path regression.
- `tests/contracts/runtime/room_client_runtime_no_formal_transport_fallback_contract_test.gd`: block formal-path fallback regression.
- Runtime boundary guards:
  `tests/contracts/runtime/battle_runtime_boundary_contract_test.gd`,
  `tests/contracts/runtime/app_runtime_root_boundary_contract_test.gd`,
  `tests/contracts/runtime/room_scene_controller_boundary_contract_test.gd`.

## Reporting Rules
- Raw JUnit XML is runtime artifact only under `tests/reports/raw/`.
- Formal evidence stays in `tests/reports/latest/*.txt` and `*.json`.
- `.godot/`, raw XML, and local appdata artifacts must not be released.
