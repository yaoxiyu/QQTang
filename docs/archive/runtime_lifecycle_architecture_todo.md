# Runtime Lifecycle Architecture TODO

> Archival note: this document is retained as historical route context. Still-valid lifecycle debt has been merged into `docs/current_source_of_truth.md`; do not treat this archived file as current truth.

> 文档定位：记录 Phase13 完成后，建议单独立项处理的运行时生命周期架构优化项。  
> 状态：`Phase14 Route A Implemented`  
> 优先级：`Medium`  
> 原则：本文件记录 runtime lifecycle 架构专题的落地结果与剩余事项；若与 [`current_source_of_truth.md`](D:\code\QQTang\docs\current_source_of_truth.md) 冲突，以当前真相文档为准。

---

# 1. 落地结果

Phase14 已按 Route A 落地以下结果：

- `AppRuntimeRoot` 仍保持普通节点, 未升级为 Autoload
- `AppRuntimeRoot` 已具备显式生命周期状态:
  - `NONE`
  - `ATTACH_PENDING`
  - `INITIALIZING`
  - `READY`
  - `DISPOSING`
  - `DISPOSED`
  - `ERROR`
- `runtime_state_changed`, `runtime_ready`, `runtime_disposing`, `runtime_disposed`, `runtime_error` 已成为正式生命周期信号
- `ensure_in_tree()` 已收口为 bootstrap owner 创建入口
- `get_existing()` 已成为纯消费者查询入口
- `Boot` 成为唯一正式 runtime bootstrap owner
- `Login / Lobby / Room / Loading` 已统一改为消费 `runtime_ready`
- `FrontFlow` 错误路由与 `ClientRoomRuntime` transport 回调已改为只消费现有 runtime
- runtime lifecycle contract 与 front runtime ready / missing redirect 测试已补齐

当前该专题不再是纯 TODO, 而是已完成第一阶段收口。

---

# 2. 仍需继续评估的后续问题

当前已落地方案仍有这些后续评估点：

1. `AppRuntimeRoot` 仍是动态插入场景树, 不是项目启动期固定装配
2. Boot 仍承担 runtime 创建责任, 尚未升级为项目级单例入口
3. 后续若接 Auth、Reconnect、DS Return, 仍要继续验证现有 lifecycle contract 是否足够
4. 是否最终升级为 Autoload, 仍需单独立项评估

所以建议在后续单独阶段中，把：

- runtime 根创建
- runtime initialized 信号
- 测试隔离策略
- 场景切换时的 runtime ownership

统一收口。

---

# 3. 已完成项

- [x] 让 `AppRuntimeRoot` 生命周期显式化
- [x] 让前台 scene controller 不再轮询 / 重试 runtime ready
- [x] 让 `FrontFlow / SceneFlow / Room / Battle / Network` 的初始化顺序更可预测
- [x] 为 runtime 生命周期补 contract test
- [x] 为缺失 runtime 的前台重定向补集成测试

---

# 4. 路线结论

Phase14 已选择并落地下面路线：

## 路线 A：保留非 Autoload，但补全显式 initialized 生命周期

做法：

- `AppRuntimeRoot` 保持普通节点，不改成 Autoload
- 增加例如 `initialized()` / `runtime_ready()` 信号
- `ensure_in_tree()` 只负责存在性，不负责调用方时序兜底
- `Boot / Login / Lobby / Room` 全部改成订阅 ready 信号，而不是 deferred + retry

优点：

- 对当前系统侵入较小
- 不会大范围冲击现有测试与 battle/network 生命周期
- 更容易做增量迁移

缺点：

- 仍然保留“运行时根是动态插入场景树”的模式

## 路线 B：把 `AppRuntimeRoot` 正式升级为 Autoload

做法：

- 在 `project.godot` 中注册 `AppRuntimeRoot` 为 Autoload
- 场景层不再负责 ensure runtime 存在
- 所有系统统一依赖全局单例 runtime 生命周期

优点：

- 启动模型最清晰
- 前台场景与 runtime 生命周期彻底解耦
- 更适合后续产品化扩展

缺点：

- 会波及测试、battle、network、runtime cleanup
- 需要系统级回归验证
- 不适合和 Phase13 验收混在一起做

---

# 5. 当前建议

当前建议是：

- **不要在 Phase14 收尾期间直接切路线 B**
- 当前继续以已落地的**路线 A**为正式真相
- 当测试系统、DS 链路、Battle 生命周期都稳定后，再决定是否继续升级到路线 B

换句话说：

> 先做“显式 initialized 生命周期收口”，再决定是否做 Autoload 化。

---

# 6. 已波及系统

后续如果立项，需要重点评估这些模块：

- `res://app/flow/app_runtime_root.gd`
- `res://app/flow/front_flow_controller.gd`
- `res://app/flow/scene_flow_controller.gd`
- `res://scenes/front/boot_scene_controller.gd`
- `res://scenes/front/login_scene_controller.gd`
- `res://scenes/front/lobby_scene_controller.gd`
- `res://scenes/front/room_scene_controller.gd`
- `res://network/runtime/room_client/client_room_runtime.gd`
- `res://network/session/battle_session_adapter.gd`
- `res://network/session/match_start_coordinator.gd`
- `res://tests/contracts/runtime/...`
- `res://tests/integration/front/...`
- `res://tests/integration/network/...`

---

# 7. 非目标

后续做这个优化时，明确**不应顺手混入**：

- Auth 正式联网化
- 公共房列表
- 匹配队列
- 好友系统
- 大规模 UI 改版
- Battle 玩法规则调整

这个专题只处理：

- runtime 生命周期
- 初始化顺序
- 场景与全局运行时的边界
- 测试隔离与清理一致性

---

# 8. 已达成的验收点

当前阶段已达成：

1. 前台场景不再依赖 deferred + retry 才能拿到 runtime
2. runtime ready 已有显式生命周期事件
3. `Boot -> Login / Lobby` 已切为 runtime ready 驱动
4. `Login / Lobby / Room / Loading` 缺失 runtime 时已显式回 Boot
5. 已补 runtime contract 与 front integration 测试

---

# 9. Remaining TODO

- [ ] 用完整回归测试继续验证 Battle / DS / front 主链路
- [ ] 继续评估 `BattleSessionAdapter / ClientRoomRuntime` 与 runtime lifecycle 的长期耦合点
- [ ] 决定是否需要在未来阶段升级为 Autoload

---

# 10. 一句话结论

Phase14 已完成 Route A:

> `AppRuntimeRoot` 已从隐式全局节点收口为显式生命周期运行时根, 后续只需在此基础上继续验证与评估是否升级为 Autoload。
