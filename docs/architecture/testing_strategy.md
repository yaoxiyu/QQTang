# Testing Strategy

## 目的
定义测试解释权：目录分层、执行入口、契约守卫与回归策略。

## 测试分层
- `res://tests/unit/`：单元测试。
- `res://tests/integration/`：集成链路测试。
- `res://tests/contracts/`：路径/运行时/协议契约守卫。
- `res://tests/smoke/`：冒烟稳定性测试。

## 执行入口
- CLI 统一入口：`res://tests/cli/run_test.gd`
- 套件脚本：`res://tests/scripts/*`

## 约束
- 新能力必须补对应层级测试（至少 unit + 关键 integration/contract）。
- 业务实现不得反向依赖测试目录。
- 历史阶段测试可保留，但不能作为当前实现解释权来源。

## Wrapper 守卫
- `tests/contracts/path/legacy_wrapper_guard_test.gd` 用于守卫 legacy wrapper 目录不被业务代码重新依赖。
