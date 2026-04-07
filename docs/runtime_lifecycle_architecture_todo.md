# Runtime Lifecycle Architecture TODO

> 文档定位：记录 Phase13 完成后，建议单独立项处理的运行时生命周期架构优化项。  
> 状态：`TODO`  
> 优先级：`Medium`  
> 原则：本文件描述**后续优化方向**，不是当前源码真相；若与 [`current_source_of_truth.md`](D:\code\Personal\QQTang\docs\current_source_of_truth.md) 冲突，以当前真相文档为准。

---

# 1. 背景

Phase13 为了严格不偏离原始施工计划，当前采用的是：

- `AppRuntimeRoot.ensure_in_tree(...)` 负责按需确保运行时根存在
- `Boot / Login / Lobby` 场景控制器延迟等待 runtime ready 后再继续前台逻辑

这套做法是**当前阶段可接受的工程化修复**，已经解决了：

- `_ready()` 期间 `add_child()` blocked 报错
- `SceneFlowController.get_tree() == null` 的切场时序错误
- 前台场景在 runtime 尚未装配完成时过早读写依赖的问题

但从长期架构角度看，当前方案仍属于：

> 以“动态确保 runtime 根存在”为核心的生命周期模型

它可以工作，但不是最优终态。

---

# 2. 为什么后续值得优化

当前模型仍有以下长期成本：

1. `AppRuntimeRoot` 的存在性由运行时动态保证，而不是项目启动期固定装配。
2. 前台 scene controller 仍需要感知“runtime 可能尚未 ready”这一时序事实。
3. 测试、场景启动、battle/network 运行时之间的生命周期边界仍偏隐式。
4. 后续如果继续扩展 Auth、Reconnect、DS Return、错误恢复，会越来越依赖稳定的全局运行时生命周期。

所以建议在后续单独阶段中，把：

- runtime 根创建
- runtime initialized 信号
- 测试隔离策略
- 场景切换时的 runtime ownership

统一收口。

---

# 3. 优化目标

建议后续优化目标如下：

1. 让 `AppRuntimeRoot` 生命周期显式化，而不是靠 scene 在 `_ready()` 里被动确保。
2. 让前台 scene controller 不再轮询/重试 runtime ready。
3. 让 `FrontFlow / SceneFlow / Room / Battle / Network` 的初始化顺序可预测、可测试、可观测。
4. 让测试环境与正式运行环境都能稳定复用同一套 runtime 生命周期语义。

---

# 4. 推荐路线

建议优先评估下面两种路线，只能二选一，不要混用。

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

- **不要在 Phase13 验收期间直接做路线 B**
- 若后续单独立项，建议优先从**路线 A**开始
- 当测试系统、DS 链路、Battle 生命周期都稳定后，再决定是否继续升级到路线 B

换句话说：

> 先做“显式 initialized 生命周期收口”，再决定是否做 Autoload 化。

---

# 6. 需要波及的系统

后续如果立项，需要重点评估这些模块：

- `res://app/flow/app_runtime_root.gd`
- `res://app/flow/front_flow_controller.gd`
- `res://app/flow/scene_flow_controller.gd`
- `res://scenes/front/boot_scene_controller.gd`
- `res://scenes/front/login_scene_controller.gd`
- `res://scenes/front/lobby_scene_controller.gd`
- `res://scenes/front/room_scene_controller.gd`
- `res://network/runtime/client_room_runtime.gd`
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

# 8. 验收标准

如果后续开启本待办，建议最终至少满足：

1. 前台场景不再依赖 deferred + retry 才能拿到 runtime。
2. runtime ready 有显式生命周期事件或固定单例入口。
3. `Boot -> Login / Lobby` 不再出现 `_ready()` 阶段的树装配时序错误。
4. `Room / Loading / Battle / DS` 主链路在新生命周期模型下仍全部通过。
5. 合同测试与集成测试不因为 runtime 单例化或初始化方式改变而互相污染。

---

# 9. TODO 清单

- [ ] 评估路线 A 与路线 B 的最终取舍
- [ ] 为 `AppRuntimeRoot` 设计显式 runtime ready 生命周期事件
- [ ] 收口 `ensure_in_tree()` 的职责边界
- [ ] 去掉前台 scene controller 的 runtime retry 逻辑
- [ ] 复核 `BattleSessionAdapter / ClientRoomRuntime` 与 runtime 生命周期耦合点
- [ ] 为 runtime 生命周期补专门 contract test
- [ ] 为场景切换补初始化顺序与 cleanup 回归测试
- [ ] 决定是否需要在后续阶段升级为 Autoload

---

# 10. 一句话结论

当前 Phase13 已经可以验收前台壳功能，但 `AppRuntimeRoot` 生命周期仍值得在后续单独阶段继续优化：

> 这个优化是推荐待办，但不应混入 Phase13 施工范围中直接硬做。
