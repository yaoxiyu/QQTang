# Architecture Debt Register

## DEBT-001 app_runtime_root orchestration overload
- Risk level: P1
- Status: in_progress
- Related dirs: `app/flow/`
- Forbidden new-logic dirs: `app/flow/app_runtime_root.gd`
- Planned phase: milestone-2026-q2-runtime
- Done definition: root stays as orchestrator only, delegated modules own init/context/network/registry, root size <= 450 lines
- Owner: front-runtime
- Last updated: 2026-04-17
- Linked tests/docs: `tests/contracts/runtime/runtime_initialization_contract_test.gd`, `tests/contracts/runtime/runtime_context_objects_contract_test.gd`

## DEBT-002 room scene controller mixed concerns
- Risk level: P1
- Status: in_progress
- Related dirs: `scenes/front/`, `app/front/room/`
- Forbidden new-logic dirs: `scenes/front/room_scene_controller.gd`
- Planned phase: milestone-2026-q2-front-room
- Done definition: selector, submit, snapshot logic moved to dedicated collaborators, controller <= 420 lines
- Owner: front-runtime
- Last updated: 2026-04-17
- Linked tests/docs: `tests/integration/front/room_to_loading_to_battle_flow_test.gd`, `docs/architecture/front_flow.md`

## DEBT-003 HTTP lifecycle not fully unified
- Risk level: P1
- Status: in_progress
- Related dirs: `app/infra/http/`, `app/front/`, `network/services/`, `network/session/runtime/`
- Forbidden new-logic dirs: direct `HTTPClient` lifecycle in gateways and service clients
- Planned phase: milestone-2026-q2-http
- Done definition: all high-frequency clients call shared executor, log fields contain method/url/status/error/log_tag
- Owner: network-runtime
- Last updated: 2026-04-17
- Linked tests/docs: `tests/unit/front/http/http_url_parser_test.gd`, `tests/unit/infra/http/http_request_executor_test.gd`

## DEBT-004 legacy compatibility path naming ambiguity
- Risk level: P2
- Status: in_progress
- Related dirs: `network/session/runtime/`
- Forbidden new-logic dirs: `network/session/runtime/server_room_runtime_compat_impl.gd`
- Planned phase: milestone-2026-q2-runtime-bridge
- Done definition: compat path reduced to forwarding shell <= 100 lines, new logic only in named bridge/runtime files
- Owner: network-runtime
- Last updated: 2026-04-17
- Linked tests/docs: `tests/contracts/path/legacy_runtime_bridge_guard_test.gd`, `tests/contracts/path/canonical_path_contract_test.gd`

## DEBT-005 cross-service contract coverage gap
- Risk level: P1
- Status: open
- Related dirs: `tests/contracts/`, `tests/integration/e2e/`, `services/game_service/`, `services/ds_manager_service/`
- Forbidden new-logic dirs: ad-hoc local debug scripts as sole verification source
- Planned phase: milestone-2026-q2-contracts
- Done definition: internal auth, manual room alloc transaction, invalid entry ticket, resume window, ds lifecycle are all covered by committed suites
- Owner: architecture
- Last updated: 2026-04-17
- Linked tests/docs: `tests/contracts/ds_manager/dsm_internal_auth_contract_test.go`, `tests/integration/e2e/ds_control_plane_e2e_test.go`

## DEBT-006 release hygiene and evidence governance
- Risk level: P1
- Status: in_progress
- Related dirs: `.gitignore`, `tests/reports/`, `tools/release/`, `services/`
- Forbidden new-logic dirs: checked-in local `.env`, root-level mixed latest/archive reports
- Planned phase: milestone-2026-q2-release
- Done definition: release sanity check script blocks dirty artifacts, reports split into latest/archive, local env and logs excluded
- Owner: build-and-release
- Last updated: 2026-04-17
- Linked tests/docs: `tools/release/release_sanity_check.py`, `tests/reports/latest/network_suite_latest.txt`
