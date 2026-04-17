# Network Control Plane

## 目的
定义控制面边界：`account_service` / `game_service` / `ds_manager_service` 与客户端、Room Service、Battle DS 的职责关系。

## 服务职责
- `account_service`
  - 认证、profile、ticket（room-entry / battle-entry）。
  - 不直接参与 battle 进程编排。
- `game_service`
  - 匹配、房间分配、battle assignment 与状态推进。
  - 对 `ds_manager_service` 发起分配请求。
- `ds_manager_service`
  - 仅负责 battle DS 进程生命周期与端口分配。
  - `allocate/ready/active/reap` 控制面 API。

## 进程职责
- Room Service：只处理 room create/join/resume/snapshot，不承载 battle runtime。
- Battle DS：只处理 battle runtime；通过 manifest/ready/active 与控制面协同。

## 鉴权与协议原则
- internal API 必须统一 formal internal auth。
- 不保留 shared-secret 后门路径。
- 控制面协议签名规则在调用方与服务端保持一致，不允许多套协议并存。

## 一致性原则
- 本地数据库事务只包本地一致性，不包长网络调用。
- 外部分配失败必须有明确状态（如 pending/failed）与可重试策略。
