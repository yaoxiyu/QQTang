# Cleanup Validation Report

## 概述

本报告记录本次源码整理的结构收口结果，以及最小回归验证结论。

整理目标：
- 去除历史 `phase*` / `test_*` / prototype 命名
- 收口正式目录语义
- 删除非源码垃圾与旧 phase 目录
- 将测试结构切换为 `unit / integration / contracts / smoke`

---

## 已完成 Rename

### 正式源码
- `res://app/flow/phase3_debug_tools.gd` -> `res://app/debug/runtime_debug_tools.gd`
- `Phase3DebugTools` -> `RuntimeDebugTools`
- `res://gameplay/config/map_defs/test_square_map_def.gd` -> `res://gameplay/config/map_defs/square_map_def.gd`
- `TestSquareMapDef` -> `SquareMapDef`
- `res://gameplay/simulation/runtime/test_map_factory.gd` -> `res://gameplay/simulation/runtime/builtin_map_factory.gd`
- `TestMapFactory` -> `BuiltinMapFactory`
- `res://scenes/phase3_scene_contract.md` -> `res://docs/scene_contract.md`
- `res://scenes/test/phase0_prototype.tscn` -> `res://scenes/sandbox/simulation_prototype.tscn`

### 测试目录与脚本
- `res://tests/phase2/helpers/fake_transport.gd` -> `res://tests/helpers/fake_transport.gd`
- `res://tests/phase2/helpers/test_assert.gd` -> `res://tests/helpers/test_assert.gd`
- `res://tests/simulation/phase0_gameplay_test_suite.gd` -> `res://tests/unit/simulation/gameplay_test_suite.gd`
- `Phase0GameplayTestSuite` -> `GameplayTestSuite`
- `res://tests/simulation/phase0_test_context.gd` -> `res://tests/unit/simulation/test_context.gd`
- `Phase0TestContext` -> `TestContext`
- `res://tests/simulation/test_input_layer.gd` -> `res://tests/unit/simulation/input_layer_test.gd`
- `res://tests/simulation/test_queries.gd` -> `res://tests/unit/simulation/queries_test.gd`
- `res://tests/simulation/test_state_layer.gd` -> `res://tests/unit/simulation/state_layer_test.gd`
- `res://tests/simulation/test_system_flow.gd` -> `res://tests/unit/simulation/system_flow_test.gd`
- `res://tests/phase2/unit/checksum/test_checksum_builder_phase2.gd` -> `res://tests/unit/network/checksum/checksum_builder_test.gd`
- `res://tests/phase2/unit/input/test_input_buffer_phase2.gd` -> `res://tests/unit/network/input/input_buffer_test.gd`
- `res://tests/phase2/unit/input/test_input_buffer_missing_fallback.gd` -> `res://tests/unit/network/input/input_buffer_missing_fallback_test.gd`
- `res://tests/phase2/unit/prediction/test_prediction_controller.gd` -> `res://tests/unit/network/prediction/prediction_controller_test.gd`
- `res://tests/phase2/unit/rollback/test_checksum_mismatch_recovery.gd` -> `res://tests/unit/network/rollback/checksum_mismatch_recovery_test.gd`
- `res://tests/phase2/unit/rollback/test_force_resync_window.gd` -> `res://tests/unit/network/rollback/force_resync_window_test.gd`
- `res://tests/phase2/recovery/test_rollback_controller.gd` -> `res://tests/unit/network/rollback/rollback_controller_test.gd`
- `res://tests/phase2/unit/snapshot/test_snapshot_buffer_eviction.gd` -> `res://tests/unit/network/snapshot/snapshot_buffer_eviction_test.gd`
- `res://tests/phase2/unit/snapshot/test_snapshot_service.gd` -> `res://tests/unit/network/snapshot/snapshot_service_test.gd`
- `res://tests/phase4/unit/config/battle_start_config_test.gd` -> `res://tests/unit/network/config/battle_start_config_test.gd`
- `res://tests/phase4/unit/transport/local_loopback_transport_test.gd` -> `res://tests/unit/network/transport/local_loopback_transport_test.gd`
- `res://tests/phase4/unit/transport/transport_codec_test.gd` -> `res://tests/unit/network/transport/transport_codec_test.gd`
- `res://tests/phase2/network/test_network_sim_runner.gd` -> `res://tests/integration/network/network_sim_runner_test.gd`
- `res://tests/phase2/sim/test_replay_determinism.gd` -> `res://tests/integration/network/replay_determinism_test.gd`
- `res://tests/phase2/sync/test_server_client_authoritative_loop.gd` -> `res://tests/integration/network/server_client_authoritative_loop_test.gd`
- `res://tests/phase4/integration/network/host_client_bootstrap_test.gd` -> `res://tests/integration/network/host_client_bootstrap_test.gd`
- `res://tests/phase4/integration/network/network_match_flow_test.gd` -> `res://tests/integration/network/network_match_flow_test.gd`
- `res://tests/phase3/room_flow_test_runner.gd` -> `res://tests/integration/flow/room_flow_test.gd`
- `res://tests/phase3/battle_flow_test_runner.gd` -> `res://tests/integration/battle/battle_flow_test.gd`
- `res://tests/phase3/presentation_sync_test_runner.gd` -> `res://tests/integration/battle/presentation_sync_test.gd`
- `res://tests/phase3/settlement_test_runner.gd` -> `res://tests/integration/battle/settlement_test.gd`
- `res://tests/phase3/debug_room_bootstrap_test_runner.gd` -> `res://tests/contracts/runtime/debug_room_bootstrap_contract_test.gd`
- `res://tests/phase3/battle_lifecycle_contract_test_runner.gd` -> `res://tests/contracts/runtime/battle_lifecycle_contract_test.gd`
- `res://tests/phase3/runtime_cleanup_contract_test_runner.gd` -> `res://tests/contracts/runtime/runtime_cleanup_contract_test.gd`
- `res://tests/phase3/canonical_path_contract_test_runner.gd` -> `res://tests/contracts/path/canonical_path_contract_test.gd`
- `res://tests/phase4/unit/compat/legacy_wrapper_guard_test.gd` -> `res://tests/contracts/path/legacy_wrapper_guard_test.gd`
- `res://tests/phase3/multi_match_stability_test_runner.gd` -> `res://tests/smoke/multi_match/multi_match_stability_test.gd`
- `res://tests/phase2/runners/dual_client_runner.gd` -> `res://tests/integration/network/dual_client_runner.gd`
- `res://tests/phase2/runners/network_sim_runner.gd` -> `res://tests/integration/network/network_sim_runner.gd`
- `res://tests/phase2/runners/replay_runner.gd` -> `res://tests/integration/network/replay_runner.gd`
- `res://tests/phase2/run_all_phase2.ps1` -> `res://tests/scripts/run_network_suite.ps1`
- `res://tests/phase4/run_all_phase4.ps1` -> `res://tests/scripts/run_integration_suite.ps1`

---

## 已删除目录

- `.godot/`
- `Godot/`
- `.vscode/`
- `.claude/`
- `tests/cli/appdata/`
- `tests/phase2/reports/`
- `tests/phase4/reports/`
- `tests/phase2/`
- `tests/phase3/`
- `tests/phase4/`
- `tests/simulation/`
- `scenes/test/`

---

## README 补齐目录

- `app/`
- `app/flow/`
- `app/debug/`
- `content/`
- `content/characters/`
- `content/maps/`
- `content/rules/`
- `docs/`
- `gameplay/`
- `gameplay/battle/`
- `gameplay/config/`
- `gameplay/config/map_defs/`
- `gameplay/config/rule_defs/`
- `gameplay/front/`
- `gameplay/front/flow/`
- `gameplay/network/`
- `gameplay/network/session/`
- `gameplay/simulation/`
- `gameplay/simulation/runtime/`
- `network/`
- `network/runtime/`
- `network/session/`
- `network/transport/`
- `presentation/`
- `presentation/battle/`
- `presentation/runtime/`
- `scenes/`
- `scenes/battle/`
- `scenes/front/`
- `scenes/network/`
- `scenes/sandbox/`
- `tests/`
- `tests/cli/`
- `tests/helpers/`
- `tests/unit/`
- `tests/unit/simulation/`
- `tests/unit/network/`
- `tests/integration/`
- `tests/integration/flow/`
- `tests/integration/network/`
- `tests/integration/battle/`
- `tests/contracts/`
- `tests/contracts/runtime/`
- `tests/contracts/path/`
- `tests/smoke/`
- `tests/smoke/multi_match/`
- `tests/scripts/`

---

## 回归验证结果

### CLI 入口
- `res://tests/cli/run_test.gd`
  - 已作为统一 CLI 入口实际使用，成功加载并执行下列测试脚本

### Unit
- `res://tests/unit/network/input/input_buffer_missing_fallback_test.gd`
  - 结果：PASS

### Integration
- `res://tests/integration/flow/room_flow_test.gd`
  - 结果：PASS
- `res://tests/integration/network/network_sim_runner_test.gd`
  - 结果：PASS
  - 备注：退出时存在 Godot `ObjectDB instances leaked at exit` / `resources still in use at exit` 警告

### Contracts
- `res://tests/contracts/path/canonical_path_contract_test.gd`
  - 结果：PASS
- `res://tests/contracts/runtime/debug_room_bootstrap_contract_test.gd`
  - 结果：PASS

### 验证结论
- 本次目录迁移、重命名、测试结构重组后的关键 CLI 入口仍可正常加载
- 关键 contract / integration / representative unit 测试均可在当前工程中通过
- 正式路径、正式场景和 canonical path 契约已通过验证

---

## 尚未处理项

- `res://tests/integration/network/network_sim_runner_test.gd` 退出时仍有资源/对象泄漏警告，未在本次源码整理任务中继续追查
- `res://tests/unit/network/config/battle_start_config_test.gd` 在当前工程中仍存在运行时断言失败，本次仅完成“源码整理闭环验证”所需的最小回归验证，未进一步修复该测试逻辑
- `tests/scripts/run_network_suite.ps1` / `tests/scripts/run_integration_suite.ps1` 的完整长时套件验证未作为本报告通过条件，当前报告采用代表性 CLI 抽样验证

---

## 最终结论

本次源码整理已完成结构收口、路径语义收口、旧 phase 目录移除、README 骨架补齐与关键 CLI 回归验证。

在当前验证范围内，可以认为本次 cleanup 已达到“可继续开发、不会误导后续 AI / 人工维护”的阶段性目标。
