# 工程技术债台账

本文档记录需要随代码演进闭环的工程技术债。债务条目必须能落到明确模块、风险和验收标准，避免变成泛泛的待办列表。

## TD-2026-05-01-001 同步泡泡类型与威力到战斗逻辑

### 背景

泡泡内容表已新增 `type`、`power`、`footprint_cells`、`player_obtainable` 字段。当前内容加载、目录索引和爆炸表现层已经能读取并使用这些字段；但核心战斗模拟仍主要沿用旧逻辑：泡泡放置使用玩家 `bomb_range`，爆炸解析默认十字传播。

### 当前状态

- 已完成：内容表字段、生成资源、catalog metadata、战斗内容清单。
- 已完成：type1/type2 爆炸火焰表现资源映射。
- 已完成：GDScript 战斗判定、放置占格、泡泡索引、快照、checksum、native bridge 打包字段。
- 已完成：native explosion kernel 支持 `bubble_type`、`power`、`footprint_cells`，type2 / 多格占位不再依赖 GDScript 回退。
- 已完成：GDScript/native parity 专项测试与网络确定性测试。

### 目标

让泡泡玩法判定与内容表定义一致，并保证 GDScript、native、联机、回放和表现层行为一致。

### 范围

- `BubbleState` 增加并序列化 `bubble_type`、`power`、`footprint_cells`。（已完成）
- 放置泡泡时从玩家选择的 `bubble_style_id` 解析泡泡定义，写入 `BubbleState`。（已完成）
- type1 十字爆炸：
  - power1：中心 + 上下左右各 1 格。
  - power2：中心 + 上下左右各 2 格。
- type2 n*n 爆炸：
  - power1：3x3。
  - power2：6x6。
- power1 泡泡占 1 格，power2 泡泡占 4 格。
- 多格占位需要同步放置校验、移动阻挡、泡泡索引、链爆查询、索引清理。（已完成）
- 同步 snapshot、checksum、native bridge、native kernel。（已完成）
- 增加 GDScript/native parity 测试和联机确定性测试。（已完成）

### 风险

- 多格泡泡如果只写中心格，会导致移动、链爆、清理和客户端表现不一致。
- native 路径遗漏会造成服务器/客户端判定分叉。
- 表现层已经支持 type2 火焰，但逻辑未同步前不能作为玩法判定正确的依据。

### 验收标准

- type1/type2、power1/power2 的覆盖格与内容表定义一致。
- power2 泡泡的 4 格占位能正确阻挡、触发、清理。
- GDScript 与 native 爆炸结果 parity 通过。
- 网络确定性测试通过，snapshot/checksum 无新增漂移。

## TD-2026-05-07-001 Legacy API Routes 移除计划

### 债务项
| ID | 文件 | Route | 替代 API | 移除 Phase |
|----|------|-------|---------|-----------|
| LGCY-001 | `docs/platform_auth/account_api_contract.md` | `/v1/auth/*` | `/api/v1/auth/*` | Phase 40 |
| LGCY-002 | `docs/platform_auth/profile_api_contract.md` | `/v1/profile/*` | `/api/v1/profile/*` | Phase 40 |
| LGCY-003 | `docs/platform_auth/room_ticket_contract.md` | `POST /v1/room-tickets` | `POST /api/v1/room-tickets` | Phase 40 |
| LGCY-004 | `docs/platform_auth/room_ticket_contract.md` | `matchmade_room` ticket kind | battle-entry ticket | Phase 39 |
| LGCY-005 | `docs/platform_game/matchmaking_api_contract.md` | 旧 `/v1/matchmaking/*` | Room Service 匹配队列 | Phase 39 |
| LGCY-006 | `docs/platform_game/settlement_api_contract.md` | `server_sync_state = pending` | N/A (convergence) | Phase 39 |

### 保留原因
- 本地开发与 CI 迁移期需要保留旧路由出入口。
- 旧客户端版本可能仍访问旧路由。

### 移除条件
- 所有调用方已切换到新 API。
- 客户端最低版本不再依赖旧路由。
- 至少一个 Phase 的观察期无旧路由流量。

## TD-2026-05-12-001 客户端 ack_tick 心跳超时检测与 DS 自动重连

### 背景

客户端通过 `ClientSession.last_confirmed_tick` 跟踪 DS 下发的 ack_tick（见 [client_session.gd:51](network/session/runtime/client_session.gd#L51)，[client_runtime.gd:192](network/session/runtime/client_runtime.gd#L192)）。当前实现只在收到 ack 时更新计数，没有在 ack_tick 长时间停滞的情况下主动判定链路异常，也没有向上层反馈"DS 已断连"或触发任何重连流程。一旦 DS 进程崩溃、网络中断或 UDP 单向不通，客户端会持续发送输入但观测不到状态推进，表现为"战斗静止"而非显式掉线。

### 当前状态

- 已有：ack_tick 字段、last_confirmed_tick 维护、客户端输入批提交。
- 缺失：ack_tick 停滞阈值判定、断连事件上抛、重连/重入房逻辑、UI 兜底提示。

### 目标

在 ack_tick 长期不更新时，客户端能在有限时间内识别与 DS 的链路断开，触发重连或优雅降级（回大厅/结算占位），并避免误报（短暂抖动不应触发）。

### 范围

- 在 `ClientSession` / `ClientRuntime` 中增加 ack_tick 最近更新时间戳，以帧或实时时钟衡量停滞时长。
- 定义分级阈值：软超时（警告/UI 提示）、硬超时（判定断连）。阈值需可配置，区分弱网和真断连。
- 断连判定后发出 signal/事件，交由会话层或战斗外壳决定：尝试重连 DS（沿用原房间票据/session token）、回退到房间/大厅、或走结算占位。
- 重连成功后需要对齐 tick、重放未确认输入或按服务器权威 snapshot 重建状态，保证确定性不被破坏。
- 与现有 `battle_dedicated_server_bootstrap` 下的 DS 生命周期信号、房间票据复用机制对齐。
- 单机/AI/回放模式不应触发该逻辑。

### 风险

- 阈值过紧会在弱网下误判断连，阈值过松会让玩家长时间"假死"。
- 重连过程若不对齐 tick/seq，会造成输入重复提交或 snapshot 漂移。
- 与 matchmaking/room ticket 流程交互复杂，需要保证重入的权限校验。

### 验收标准

- DS 主动 kill 后，客户端在硬超时内进入断连状态并触发重连或降级路径，不再卡在静止画面。
- 模拟 500ms~2s 网络抖动不触发断连判定。
- 重连成功后 GDScript/native snapshot checksum 保持一致，无重复输入。
- 有对应的集成测试覆盖 DS 崩溃、网络中断、短抖动三种场景。

## TD-2026-05-07-002 Production Legacy/Compat 代码注释登记

运行时 legacy/compat 代码必须在此登记，否则 release sanity 应报错。

扫描命令：`Select-String -Path .\**\*.gd,.\**\*.go -Pattern "LegacyMigration|legacy|compat|fallback"`

登记格式：ID | 文件 | 原因 | 移除条件 | 最晚移除 Phase
