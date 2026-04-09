# 日志系统迁移报告

## 迁移概览

本次迁移为项目引入了结构化日志系统，并迁移了首批核心运行时模块的 `print()` 调用，按模块分类并设置合理的日志级别。

## 迁移文件清单

### 核心业务代码（已完成）

| 文件 | 原 print 数量 | 日志模块 | 日志级别 |
|------|--------------|---------|---------|
| `gameplay/battle/runtime/battle_bootstrap.gd` | 1 | LogBattle | INFO |
| `gameplay/simulation/systems/explosion_resolve_system.gd` | 3 | LogSimulation | WARN |
| `gameplay/simulation/systems/movement_system.gd` | 2 | LogSimulation | DEBUG |
| `network/runtime/dedicated_server_bootstrap.gd` | 3 | LogNet | INFO/WARN |
| `network/runtime/room_client_gateway.gd` | 1 | LogNet | WARN |
| `network/runtime/network_error_router.gd` | 1 | LogNet | ERROR |
| `network/transport/enet_battle_transport.gd` | 1 | LogNet | DEBUG |
| `network/session/room_session_controller.gd` | 1 | LogSession | INFO |
| `network/session/runtime/runtime_message_router.gd` | 1 | LogSession | DEBUG |
| `network/runtime/client_room_runtime.gd` | 2 | LogNet | WARN/DEBUG |
| `network/session/runtime/client_runtime.gd` | 7 | LogSync | WARN/INFO |
| `network/session/runtime/server_room_registry.gd` | 1 | LogSession | DEBUG |
| `scenes/front/lobby_scene_controller.gd` | 1 | LogFront | DEBUG |
| `app/front/lobby/lobby_use_case.gd` | 1 | LogFront | DEBUG |
| `app/front/lobby/lobby_directory_use_case.gd` | 1 | LogFront | DEBUG |
| `app/front/room/room_use_case.gd` | 2 | LogFront / LogNet | DEBUG / WARN |
| `tools/content_pipeline/content_pipeline_runner.gd` | 1 | LogContent | INFO |

**总计：30 处 print 已迁移（非全量）**

## 日志级别分配原则

### DEBUG（调试）
- 高频调用的诊断信息
- 仅在开发环境启用
- 示例：移动快照、传输日志、消息路由

### INFO（信息）
- 正常流程的关键节点
- 生产环境保留
- 示例：战斗状态变更、服务器启动、内容管线完成

### WARN（警告）
- 异常但不影响流程
- 需要关注但非错误
- 示例：房间异常、同步异常、rollback 事件

### ERROR（错误）
- 错误但可恢复
- 需要立即关注
- 示例：网络错误

## 模块分类

| 模块 | 日志类 | 使用场景 |
|------|--------|---------|
| 战斗运行时 | LogBattle | bootstrap、生命周期 |
| 仿真层 | LogSimulation | 移动、爆炸、系统异常 |
| 网络传输 | LogNet | transport、connection、peer |
| 会话管理 | LogSession | room session、message router |
| 同步回滚 | LogSync | checkpoint、rollback、prediction |
| 内容系统 | LogContent | catalog、pipeline |

## 测试代码

测试代码中的 `print()` 调用（如 `print("test_xxx: PASS")`）**暂未迁移**，原因：
1. 测试输出需要直接可见，不需要日志系统格式化
2. 测试框架可能有自己的输出机制
3. 保持测试代码简洁

如需迁移测试代码，可后续处理。

## 验证

迁移文件需要继续结合 Godot 编译和运行时验证，尤其关注日志初始化、文件输出路径和高频日志场景下的性能表现。

## 后续工作

1. **监控日志输出**：运行游戏检查日志格式、文件路径和级别是否合理
2. **调整日志级别**：根据 debug/release 场景校准客户端与 DS 的默认级别
3. **继续迁移剩余 runtime 直出日志**：优先处理表现层和其他网络路径
4. **性能优化**：继续观察高频日志场景下的批量 flush 和轮转策略
