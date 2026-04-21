# tests

## 目录定位
统一测试主目录, 当前 GDScript 测试正式底座为 GUT。

## 子目录职责
- `unit/`：单元测试。
- `integration/`：集成链路测试。
- `contracts/`：路径、配置与运行时契约测试。
- `smoke/`：长链路冒烟验证。
- `gut/base/`：项目测试基类, 包括 `QQTUnitTest`、`QQTIntegrationTest`、`QQTContractTest`、`QQTSmokeTest`。
- `helpers/`：测试辅助脚本。
- `reports/latest/`：运行期 latest 汇总报告目录（由脚本创建，可在 clean repo 缺失）。
- `reports/raw/`：运行期原始 XML 产物目录（由脚本创建，可在 clean repo 缺失）。
- `scripts/`：suite 脚本与统一 GUT wrapper。

## 维护规则
- 只保留类型化测试结构，不再继续按阶段拆测试目录。
- 新测试文件统一使用 `_test.gd` 后缀。
- 新测试函数统一使用 `test_` 前缀。
- 不允许再引入 `extends Node`、`_ready()`、`signal test_finished`、`TestAssert.is_true` 风格。
- 正式业务代码不能反向依赖测试目录。
- 不保留已退出正式 SUT 的 legacy Godot Room authority 历史测试壳。

## 统一入口
- `tests/scripts/run_gut_suite.ps1`：统一 GUT CLI wrapper。
- `tests/scripts/run_cross_service_contract_suite.ps1`、`run_integration_suite.ps1`、`run_matchmaking_suite.ps1`、`run_network_suite.ps1`、`run_refactor_validation.ps1`：按套件组织调用 `run_gut_suite.ps1`。

## 新增测试
- 单元测试示例：`extends QQTUnitTest`
- 集成测试示例：`extends QQTIntegrationTest`
- 契约测试示例：`extends QQTContractTest`
- 冒烟测试示例：`extends QQTSmokeTest`
- 如需挂树节点, 使用基类提供的 `qqt_add_child()` 与 `qqt_wait_frames()`
