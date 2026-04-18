# Testing Strategy

## 目的
定义当前正式测试解释权：目录分层、GUT 运行入口、迁移守卫与回归策略。

## 测试分层
- `res://tests/unit/`：单元测试。
- `res://tests/integration/`：集成链路测试。
- `res://tests/contracts/`：路径/运行时/协议契约守卫。
- `res://tests/smoke/`：冒烟稳定性测试。
- `res://tests/gut/base/`：项目自己的 GUT 基类与测试薄适配层。
- `res://tests/helpers/`：测试 helper 与扫描/伪服务辅助脚本。

## 执行入口
- CLI 统一入口：`tests/scripts/run_gut_suite.ps1`
- 套件脚本：`res://tests/scripts/*.ps1`
- GDScript 测试唯一正式底座：GUT
- 历史自写 runner 已删除，不再允许重新引入旧 `tests/cli` runner 入口

## 约束
- 新能力必须补对应层级测试（至少 unit + 关键 integration/contract）。
- 新测试必须继承 `QQTUnitTest`、`QQTIntegrationTest`、`QQTContractTest`、`QQTSmokeTest` 之一。
- 测试函数必须使用 `test_` 前缀，失败必须通过 GUT 断言体现。
- 业务实现不得反向依赖测试目录。
- 禁止恢复 `extends Node + _ready()`、`signal test_finished`、`TestAssert.is_true` 等 legacy 写法。

## 迁移守卫
- `tests/contracts/path/no_legacy_node_test_style_contract_test.gd`：禁止 legacy Node 风格测试回流。
- `tests/contracts/path/no_legacy_test_runner_reference_contract_test.gd`：禁止重新引用旧 runner。
- `tests/contracts/path/legacy_wrapper_guard_test.gd`：守卫 legacy wrapper 目录不被业务代码重新依赖。
- `tests/contracts/runtime/battle_runtime_boundary_contract_test.gd`、`tests/contracts/runtime/app_runtime_root_boundary_contract_test.gd`、`tests/contracts/runtime/room_scene_controller_boundary_contract_test.gd`：守体量与职责边界。

## 报告约定
- 原始 JUnit XML 仅作为运行产物写入 `tests/reports/raw/`。
- 正式解释权报告仍为 `tests/reports/latest/*.txt` 与 `*.json`。
- raw XML、`.godot/`、本地 `APPDATA` 测试产物不得进入正式 release 包。

