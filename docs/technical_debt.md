# 工程技术债台账

本文档记录需要随代码演进闭环的工程技术债。债务条目必须能落到明确模块、风险和验收标准，避免变成泛泛的待办列表。

## TD-2026-05-01-001 同步泡泡类型与威力到战斗逻辑

### 背景

泡泡内容表已新增 `type`、`power`、`footprint_cells`、`player_obtainable` 字段。当前内容加载、目录索引和爆炸表现层已经能读取并使用这些字段；但核心战斗模拟仍主要沿用旧逻辑：泡泡放置使用玩家 `bomb_range`，爆炸解析默认十字传播。

### 当前状态

- 已完成：内容表字段、生成资源、catalog metadata、战斗内容清单。
- 已完成：type1/type2 爆炸火焰表现资源映射。
- 未完成：战斗判定、放置占格、快照、checksum、native kernel 同步。

### 目标

让泡泡玩法判定与内容表定义一致，并保证 GDScript、native、联机、回放和表现层行为一致。

### 范围

- `BubbleState` 增加并序列化 `bubble_type`、`power`、`footprint_cells`。
- 放置泡泡时从玩家选择的 `bubble_style_id` 解析泡泡定义，写入 `BubbleState`。
- type1 十字爆炸：
  - power1：中心 + 上下左右各 1 格。
  - power2：中心 + 上下左右各 2 格。
- type2 n*n 爆炸：
  - power1：3x3。
  - power2：6x6。
- power1 泡泡占 1 格，power2 泡泡占 4 格。
- 多格占位需要同步放置校验、移动阻挡、泡泡索引、链爆查询、索引清理。
- 同步 snapshot、checksum、native bridge、native kernel。
- 增加 GDScript/native parity 测试和联机确定性测试。

### 风险

- 多格泡泡如果只写中心格，会导致移动、链爆、清理和客户端表现不一致。
- native 路径遗漏会造成服务器/客户端判定分叉。
- 表现层已经支持 type2 火焰，但逻辑未同步前不能作为玩法判定正确的依据。

### 验收标准

- type1/type2、power1/power2 的覆盖格与内容表定义一致。
- power2 泡泡的 4 格占位能正确阻挡、触发、清理。
- GDScript 与 native 爆炸结果 parity 通过。
- 网络确定性测试通过，snapshot/checksum 无新增漂移。
