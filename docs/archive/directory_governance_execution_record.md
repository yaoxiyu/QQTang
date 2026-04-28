# Current Execution Record

## 1. Removed Directories And Paths
- `app/http/` removed after `http_response_reader.gd` moved into `app/infra/http/`.
- Legacy/compat runtime/wrapper paths are absent in repository state:
  - `gameplay/front/flow/`
  - `gameplay/network/session/`
  - `network/runtime/legacy/`
  - `network/session/legacy/`
  - `network/runtime/dedicated_server_bootstrap.gd`
  - `network/session/runtime/server_room_runtime.gd`
  - `network/session/runtime/server_room_runtime_compat_impl.gd`
  - `network/session/runtime/legacy_room_runtime_bridge.gd`

## 2. Retired Legacy Tests
- Removed skip-based legacy `ServerRoomRuntime` shell tests:
  - `tests/unit/network/server_room_runtime_battle_input_guard_test.gd`
  - `tests/integration/network/active_match_disconnect_no_immediate_abort_test.gd`
  - `tests/integration/network/active_match_resume_timeout_abort_test.gd`
  - `tests/integration/front/loading_abort_returns_to_room_test.gd`
  - `tests/integration/front/idle_room_resume_returns_to_room_test.gd`
  - `tests/integration/network/rejected_room_join_with_invalid_ticket_test.gd`
- Updated `tests/integration/network/battle_ds_invalid_ticket_reject_test.gd` local probe class name to avoid collision with global `BattleBootstrapProbe`.

## 3. Added Guards / Validation / Release Assets
- Added path guard contract:
  - `tests/contracts/path/no_removed_room_runtime_test_reference_contract_test.gd`
- Added release hygiene script and aligned checks to Current policy:
  - `tools/release/release_sanity_check.py`
- Added formal validation entrypoint:
  - `scripts/validation/run_validation_entry.ps1`
- Added CI entrypoint:
  - `.github/workflows/validation.yml`

## 4. Latest Report Paths
- `tests/reports/latest/validation_latest.txt`
- `tests/reports/latest/validation_latest.json`
- `tests/reports/latest/cross_service_contract_suite_latest.txt`
- `tests/reports/latest/cross_service_contract_suite_latest.json`

## 5. Scene Verification
- Dedicated server scene script binding verified from source text:
  - `res://scenes/network/dedicated_server_scene.tscn` root script points to `res://network/runtime/battle_dedicated_server_bootstrap.gd`.
- Headless scene load probe passed for required scenes:
  - `res://scenes/network/dedicated_server_scene.tscn`
  - `res://scenes/front/boot_scene.tscn`
  - `res://scenes/front/room_scene.tscn`
  - `res://scenes/front/loading_scene.tscn`
  - `res://scenes/battle/battle_main.tscn`

## 6. Next Suggestions
- Keep `run_validation_entry.ps1` as the single formal validation entry in all current docs.
- Keep `release_sanity_check.py` strict on forbidden paths/references and dirty artifacts to prevent rollback.
- Continue routing Room authority behavior coverage to Go `room_service` tests and cross-service contract suite.

