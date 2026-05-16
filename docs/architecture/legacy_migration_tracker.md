# LegacyMigration 追踪台账

文档类型: 架构设计与治理台账  
适用范围: `LegacyMigration` 相关过渡代码清理与收敛  
权威代码入口: `network/`, `app/front/`, `gameplay/` 下带 `LegacyMigration` 标记的实现  
最后更新日期: 2026-05-16

## 当前状态
- 全仓 `LegacyMigration` 标记引用约 `78` 处, 分布约 `22+` 文件。
- P0（协议与运行时一致性）已完成：双键协议兼容层已删除、空热路径已删除、重复 sanitize 已收敛。
- 当前阶段目标: 继续 P1（运行时语义清理）和 P2（前端/场景注释债务）。

## 分级清理计划

### P0 协议与运行时一致性 ✅ 已完成
- [x] 删除双键协议兼容层, 统一 `message_type`。（2026-05-16）
- [x] 删除 `ServerSession._tick_collect_inputs()` 空热路径。（2026-05-16）
- [x] 删除 authority 输入链路多层 `sanitize()` 冗余, 仅保留 C++ 边界防线。（2026-05-16）
- [x] 删除 `TransportMessageCodec.normalize_message()` 空壳。（2026-05-16）
- [x] 统一 `_make_idle_local_input` 为 `PlayerInputFrame.idle()` 静态工厂。（2026-05-16）
- [x] 删除 `build_decorative_surface_cells` 兼容别名。（2026-05-16）
- [x] 重命名 `_native_input_policy_metrics` → `_input_buffer_metrics`。（2026-05-16）

### P1 运行时语义清理
- [x] 自适应 checkpoint 间隔：累积计数器 → 滑动窗口, 窗口内无 fallback 事件时恢复默认间隔。（2026-05-16）
- [ ] 房间与战斗恢复链路中以 `LegacyMigration` 命名的字段, 按"当前仍生效/可退役"分流。
- [ ] 断线恢复与成员身份绑定路径补契约测试后收敛命名。

### P2 数据与注释债务
- [ ] Legacy Item 双路径：`_apply_legacy_item_effect` / `_resolve_legacy_debug_item_id`，当 `battle_item_id` 为空或 `item_drop_profile` 未配置时静默回退。应在 CSV 加载阶段校验并报错，或改为显式 `QQT_ALLOW_LEGACY_ITEM_EFFECT` flag。
- [ ] `app/front/*` 与 `scenes/*` 的 `LegacyMigration` 注释逐项核销。

## 退出条件
- 代码检索 `LegacyMigration` 引用清零, 或仅保留在 `docs/archive` 历史文档。
- 对应契约测试与集成测试保持通过。
