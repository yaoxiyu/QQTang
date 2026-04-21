# 状态系统盘点（State Machine Inventory）

## 1. 目的与范围
本文用于给“房间-匹配-战斗”状态系统改造提供基线清单，覆盖：

1. 状态定义位置（谁定义）
2. 状态写入位置（谁驱动流转）
3. 状态消费位置（谁依赖状态做逻辑/展示）
4. 当前实现中的耦合与不一致点

本文是盘点文档，不是最终方案设计文档。

## 2. 核心状态域与责任边界

| 状态域 | 主要字段 | 责任服务/模块 | 说明 |
|---|---|---|---|
| 房间聚合生命周期 | `LifecycleState` / `room_lifecycle_state` | `room_service` / `network session` | 描述房间层面的阶段，如 `idle`、`queueing`、`battle_handoff` |
| 队列生命周期 | `QueueState` / `room_queue_state` | `game_service.queue`（源头）+ `room_service`（同步投影） | 描述匹配队列阶段，如 `queued`、`assigned`、`finalized` |
| 战斗分配与回流 | `BattleHandoff.AllocationState` / `battle_allocation_state` | `game_service.assignment` + `room_service` | 描述 battle 资源分配和回流阶段 |
| 成员准备状态 | `member.ready` / `snapshot.all_ready` | 房间聚合本地规则 | 与队列状态正交，不应混用 |
| 客户端流程态 | `RoomFlowState` / `SessionLifecycleState` / `BattleFlowState` | 前端 runtime/session | UI 流转控制与诊断，不是业务真相 |

## 3. 状态定义清单

### 3.1 Room Snapshot（客户端消费模型）
- 文件：`gameplay/battle/config/room_snapshot.gd`
- 字段：
  - `room_queue_state`
  - `room_lifecycle_state`
  - `battle_allocation_state`
  - `battle_entry_ready`
  - `match_active`

### 3.2 GDScript Room 运行时状态（legacy migration 兼容层）
- 文件：`network/session/runtime/room_server_state.gd`
- 字段：
  - `room_queue_state` 默认 `idle`
  - `room_lifecycle_state` 注释中定义了完整词表
  - `battle_allocation_state` 注释中定义了词表
  - `match_active`

### 3.3 Room Service 领域模型
- 文件：`services/room_service/internal/domain/models.go`
- 结构：
  - `RoomAggregate.LifecycleState`
  - `RoomAggregate.Queue.QueueState`
  - `RoomAggregate.BattleHandoffState.AllocationState/Ready`

### 3.4 Game Service 队列模型
- 文件：`services/game_service/internal/queue/queue_models.go`
- 结构：
  - `QueueStatus.QueueState`
  - `PartyQueueStatus.QueueState`
  - `PartyQueueStatus.AllocationState`

### 3.5 前端流程态枚举
- `network/session/runtime/room_flow_state.gd`
- `network/session/runtime/session_lifecycle_state.gd`
- `gameplay/battle/runtime/battle_flow_state.gd`
- `app/flow/runtime_lifecycle_state.gd`

## 4. 状态写入（流转）位置清单

### 4.1 Room Service（房间聚合状态写入）
- 文件：`services/room_service/internal/roomapp/service.go`
- 关键写入点：
  - `EnterMatchQueue`：`QueueState=queueing`，`LifecycleState=queueing`
  - `CancelMatchQueue`：`QueueState=cancelled`，`LifecycleState=idle`
  - `StartManualRoomBattle`：写入 `BattleHandoffState`，`LifecycleState=battle_handoff`
  - `AckBattleEntry`：`QueueState=matched`，`LifecycleState=battle_entry_acknowledged`
  - `SyncMatchQueueStatus`：依据 game_service 返回推进 `QueueState/BattleHandoff/LifecycleState`

### 4.2 Game Service（队列状态真相写入）
- 文件：`services/game_service/internal/queue/queue_service.go`
- 关键写入点：
  - `EnterQueue/EnterPartyQueue`：新建 `queued`，匹配成功后转 `assigned`
  - `CancelQueue/CancelPartyQueue`：转 `cancelled`
  - `GetStatus/GetPartyQueueStatus`：心跳与状态收敛，终态回写（如 `failed/expired/finalized`）

### 4.3 Finalize（对 assignment 终态写入）
- 文件：`services/game_service/internal/finalize/finalize_service.go`
- 关键写入点：
  - `Finalize` 成功后：`assignmentRepo.MarkFinalized` + `MarkMembersFinalized`

### 4.4 客户端快照应用写入
- 文件：`network/runtime/room_client/client_room_runtime.gd`
- 关键写入点：
  - `_route_message(ROOM_SNAPSHOT)`
  - `_apply_match_queue_status(ROOM_MATCH_QUEUE_STATUS)` 更新 `_last_snapshot.room_queue_state`

## 5. 状态消费位置清单

### 5.1 UI 可交互判定
- 文件：`app/front/room/room_view_model_builder.gd`
- 关键消费点：
  - `_can_enter_match_queue`
  - `_is_queueing_state`
  - `_build_match_room_blocker_text`
  - `_build_queue_status_text`

### 5.2 UI 控件绑定
- 文件：`app/front/room/room_scene_presenter.gd`
- 消费字段：
  - `can_enter_queue`
  - `can_cancel_queue`
  - `can_ready`
  - `queue_status_text`

### 5.3 房间流程与行为
- 文件：`app/front/room/room_use_case.gd`
- 消费行为：
  - 根据当前 `room_queue_state` 决定取消匹配/请求行为

### 5.4 协议编码与跨端映射
- 文件：`services/room_service/internal/wsapi/encoder.go`
- 消费字段：
  - `SnapshotProjection.LifecycleState`
  - `SnapshotProjection.QueueState.QueueState`
  - `SnapshotProjection.BattleHandoff`

## 6. 当前已出现的状态值词表（运行中可见）

### 6.1 `room_queue_state` / `QueueState`
- `idle`
- `queueing`
- `queued`
- `assigned`
- `committing`
- `allocating`
- `battle_ready`
- `matched`
- `cancelled`
- `failed`
- `expired`
- `finalized`

### 6.2 `LifecycleState`（room_service）
- `idle`
- `queueing`
- `battle_handoff`
- `battle_entry_acknowledged`

### 6.3 `room_lifecycle_state`（GDScript legacy 注释词表）
- `idle`
- `gathering`
- `queueing`
- `assignment_pending`
- `allocating_battle`
- `battle_ready`
- `in_battle_frozen`
- `awaiting_return`
- `destroying`
- `destroyed`

### 6.4 `battle_allocation_state` / `AllocationState`
- `allocating`
- `battle_ready`
- `battle_active`
- `finalizing`
- `finalized`
- `allocated`
- `alloc_failed`
- `pending_allocate`

## 7. 主要一致性风险（供正式设计重点处理）

1. 队列状态与房间生命周期状态存在双轨词表，语义边界不清。
2. `ready`（成员态）与 `queue_state`（队列态）在 UI 判定里耦合，容易出现按钮与后端状态不一致。
3. `matched/battle_ready/assigned` 在不同模块含义接近但不完全等价。
4. Room 端与 Game 端对“终态后的回收时机”不同步，容易出现“终态卡住不可重入”或“前端临时放行”。
5. legacy GDScript 注释词表与 room_service 实际词表存在偏差，文档和代码真相不一致。

## 8. 正式改造建议的文档拆分（你后续可直接展开）

1. `状态字典（Canonical State Dictionary）`
2. `状态机图（Queue FSM / Room FSM / Battle Allocation FSM）`
3. `跨服务投影规则（Game -> Room -> Client Snapshot）`
4. `事件与转移表（Event -> Guard -> Transition -> Side Effects）`
5. `故障补偿与超时策略`
6. `观测性与告警（日志键、指标、trace 维度）`
7. `迁移策略（兼容期双写/读优先级/回滚开关）`

## 9. 附：本次盘点关键文件索引

1. `app/front/room/room_view_model_builder.gd`
2. `app/front/room/room_scene_presenter.gd`
3. `app/front/room/room_use_case.gd`
4. `network/runtime/room_client/client_room_runtime.gd`
5. `network/session/runtime/room_server_state.gd`
6. `network/session/room_session_controller.gd`
7. `services/room_service/internal/domain/models.go`
8. `services/room_service/internal/roomapp/service.go`
9. `services/room_service/internal/wsapi/encoder.go`
10. `services/game_service/internal/queue/queue_models.go`
11. `services/game_service/internal/queue/queue_service.go`
12. `services/game_service/internal/finalize/finalize_service.go`
13. `gameplay/battle/config/room_snapshot.gd`
14. `network/session/runtime/room_flow_state.gd`
15. `network/session/runtime/session_lifecycle_state.gd`
16. `gameplay/battle/runtime/battle_flow_state.gd`
17. `app/flow/runtime_lifecycle_state.gd`

