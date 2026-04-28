# Current Execution Record

## Metadata
- Phase: `Current_战斗控制面闭环与LegacyCompat清除`
- Branch: `control-plane-closure-remove-legacy`
- Baseline commit: `23e2339c2e769525118fa36ca2ca01debf3090c1`
- Record date: `2026-04-20`

## Scope Summary
- Completed battle control-plane closure for formal paths.
- Removed legacy/compat runtime and wrapper assets.
- Migrated and formalized replacement tests.
- Added release hygiene gates, validation script, and Current CI workflow.
- Updated architecture/source-of-truth docs to legacy-removed state.

## Step Execution Ledger

### 1. Baseline and inventory
- 1.1 Branch created and baseline recorded.
- 1.2 Legacy inventory exported:
  - `docs/archive/legacy_inventory.txt`
- 1.3 Legacy reference inventory exported:
  - `docs/archive/legacy_reference_inventory.txt`

### 2. Formal replacement tests added
- 2.1 `services/room_service/internal/registry/registry_test.go`
- 2.2 `services/room_service/internal/wsapi/ws_directory_visibility_test.go`
- 2.3 `services/game_service/internal/httpapi/internal_battle_manifest_handler_test.go`
- 2.4 `services/game_service/internal/httpapi/internal_assignment_handler_test.go`
- 2.5 `services/game_service/internal/httpapi/internal_finalize_handler_test.go`
- 2.6 DSM split tests:
  - `services/ds_manager_service/internal/httpapi/dsm_internal_auth_contract_test.go`
  - `services/ds_manager_service/internal/httpapi/ds_control_plane_lifecycle_test.go`
- 2.7 Battle DS E2E added:
  - `tests/integration/e2e/battle_finalize_payload_e2e_test.gd`

### 3. Legacy tests removed
- 3.1 Removed old `server_room_service.gd` dependent unit tests.
- 3.2 Removed old `server_room_registry.gd` dependent tests.
- 3.3 Removed remaining old Room Runtime integration tests.

### 4. Legacy/compat code removed
- 4.1 Removed `gameplay/front/flow/*` wrappers.
- 4.2 Removed `gameplay/network/session/*` wrappers.
- 4.3 Removed `network/runtime/dedicated_server_bootstrap.gd` (after manual scene check).
- 4.4 Removed `network/runtime/legacy/*`.
- 4.5 Removed `network/session/legacy/*`.
- 4.6 Removed compat shells in `network/session/runtime/*`:
  - `server_room_runtime.gd`
  - `server_room_runtime_compat_impl.gd`
  - `legacy_room_runtime_bridge.gd`

### 5. Contract/reference updates
- 5.1 Replaced legacy wrapper guard with:
  - `tests/contracts/path/no_legacy_compat_assets_contract_test.gd`
- 5.2 Replaced legacy runtime bridge guard with:
  - `tests/contracts/path/no_legacy_runtime_bridge_contract_test.gd`
- 5.3 Updated `tests/contracts/path/canonical_path_contract_test.gd`.
- 5.4 Updated `tests/contracts/runtime/room_default_port_contract_test.gd`.
- Extra convergence: unified front default room endpoint source:
  - `app/front/room/room_defaults.gd`

### 6. Release governance
- 6.1 Updated root `.gitignore` for release hygiene.
- 6.2 Added release sanity gate:
  - `tools/release/release_sanity_check.py`
- 6.3 Updated cross-service contract suite:
  - `tests/scripts/run_cross_service_contract_suite.ps1`
- 6.4 Added validation entry:
  - `scripts/validation/run_validation.ps1`
- 6.5 Added CI workflow:
  - `.github/workflows/validate.yml`

### 7. Docs source of truth updates
- 7.1 `docs/architecture/runtime_topology.md`
- 7.2 `docs/architecture/testing_strategy.md`
- 7.3 `docs/platform_room/room_service_runtime_contract.md`
- 7.4 `docs/architecture_debt_register.md` (`DEBT-004/005/006` closed)
- 7.5 `network/README.md`

### 8. Manual Godot checks (confirmed)
- 8.1 `res://scenes/network/dedicated_server_scene.tscn`
  - Root script confirmed: `res://network/runtime/battle_dedicated_server_bootstrap.gd`
- 8.2 Confirmed no legacy path residual/missing resource in:
  - `res://scenes/front/boot_scene.tscn`
  - `res://scenes/front/room_scene.tscn`
  - `res://scenes/front/loading_scene.tscn`
  - `res://scenes/battle/battle_main.tscn`

### 9. Validation
- Cross-service contract suite latest reports:
  - `tests/reports/latest/cross_service_contract_suite_latest.txt`
  - `tests/reports/latest/cross_service_contract_suite_latest.json`
- Final phase validation latest reports:
  - `tests/reports/latest/validation_latest.txt`
  - `tests/reports/latest/validation_latest.json`
- Latest result snapshot:
  - `validation`: `pass=8 fail=0 skip=1`
  - `cross_service_contract_suite`: `pass=7 fail=0`
  - `cross_service_contract_suite_godot`: `total=3 pass=3 fail=0`

## Notable implementation decisions
- `.godot` policy adjusted to practical governance:
  - No longer treated as mandatory-absent in workspace.
  - Enforced as "must not be tracked/staged in git" in release sanity.
- Legacy path keyword scan policy:
  - Legacy path strings can appear in negative-assertion contract tests and debt/governance docs.
  - Pass criterion is no runtime/formal-path references in `app/`, `network/`, `services/`, `scenes/`, and executable scripts.
  - `docs/archive/*` remains historical evidence only.
- `run_gut_suite.ps1` now auto-warms GUT class cache (`--import`) when needed.
- GUT failure error types constrained to `gut,push_error` to avoid non-functional engine noise causing false failures.

## Completion Statement
Current target (battle control-plane closure + full legacy/compat removal + governance formalization) has been executed with committed scripts/tests/contracts/docs and passing validation evidence.

