# Runtime Topology

## 目的
定义运行时拓扑、进程入口、生命周期归属与兼容层边界。  
本文件只讲“运行时结构真相”，不展开前台业务细节。

## 正式入口
- 客户端主入口：`res://scenes/front/boot_scene.tscn`
- 战斗场景入口：`res://scenes/battle/battle_main.tscn`
- Room Service 入口：`res://scenes/network/room_service_scene.tscn`
- Battle DS 入口：`res://scenes/network/dedicated_server_scene.tscn`

## Runtime Ownership
- `AppRuntimeRoot` 当前是运行时组合根。
- `BootSceneController` 是 runtime bootstrap owner。
- `Login/Lobby/Room/Loading` 都是 runtime 消费者，不得隐式创建第二套 runtime。
- 直接打开消费型前台场景且 runtime 缺失时，必须回到 boot。

## 网络运行时分层
- `network/session/runtime/room_authority_runtime.gd`：房间权威（create/join/resume/snapshot）。
- `network/battle/runtime/server_battle_runtime.gd`：战斗权威（match/loading/resume/finalize）。
- `network/session/runtime/server_room_registry.gd`：目录与路由装配。

## Wrapper / Compatibility 约束
- `res://gameplay/network/session/` 仅允许 legacy wrapper，不承载新逻辑。
- `res://network/runtime/dedicated_server_bootstrap.gd` 仅兼容转发。
- `res://network/session/runtime/server_room_runtime.gd` 仅兼容转发。
- 新逻辑必须写入正式承载路径（`network/session/runtime/*`、`network/runtime/*_bootstrap.gd`）。
