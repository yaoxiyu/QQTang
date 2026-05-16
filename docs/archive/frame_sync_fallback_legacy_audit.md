# 帧同步 Fallback / Legacy / 兼容逻辑审计

> 文档类型：架构审计报告（历史快照）
> 审计日期：2026-05-16
> 权威代码入口：`gameplay/network/rollback/rollback_controller.gd`、`network/session/runtime/battle_match.gd`、`addons/qqt_native/src/sync/`

## 审计结论

当前帧同步逻辑在设计合理性上无硬伤。原生审计发现 11 项问题，已完成修复 11 项。

## 已修复项

| 问题 | 修复方式 |
|---|---|
| `fallback_input()` hold-move（服务器猜测玩家意图） | 改为 idle fallback（全零） |
| 三重 `sanitize()` 调用（authority 路径） | 仅保留 C++ 边界层 |
| `_tick_collect_inputs()` 空方法 | 删除方法及调用点 |
| `message_type` / `msg_type` 双键 | 统一为 `message_type`，删除 `normalize_message()` |
| `_should_force_resync` 三重决策 | C++ 不再重复判定，仅消费 GDScript 传入值 |
| SnapshotBuffer `_native_ring` 禁用时未置空 | `_refresh_native_mode()` 同步置空 |
| Snapshot diff 不含 walls | 加入 walls 比较 |
| `_make_idle_local_input` 代码重复 | 统一为 `PlayerInputFrame.idle()` |
| `build_decorative_surface_cells` 兼容别名 | 删除，所有调用方直接用 `build_airdrop_blocked_cells` |
| `_native_input_policy_metrics` 命名误导 | 重命名为 `_input_buffer_metrics` |
| 自适应 checkpoint 累积计数器不可恢复 | 改为 60 tick 滑动窗口，窗口内无事件时恢复默认间隔 |

## 仍存在（低优先级，仅治理债务）

- **LegacyMigration 标记扩散**：~78 处引用分布在 ~22 个文件。已建台账 `docs/architecture/legacy_migration_tracker.md` 分级清理。
- **Client 侧 sanitize 双重调用**：`client_session.gd` + `input_ring_buffer.gd`，非同一调用链，影响轻微。

## 设计确认项（无需改动）

| 项 | 理由 |
|---|---|
| Feature Flag 体系（9 个 `enable_native_*`） | 范式统一，`require_native_kernels` 兜底 |
| C++ `sanitize_frame()` 边界防线 | I/O 边界唯一防线 |
| SnapshotBuffer 双模（native/GDScript） | 运行时自动切换，dev 可测试 |
| 资产路径 `fallback_to_project_assets` | 配置驱动，非硬编码 |
| `QQT_ALLOW_*` dev 后门体系 | 命名统一、默认关闭、生产禁用 |
