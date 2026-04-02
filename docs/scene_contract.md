# Scene Contract

本文件记录当前正式前台与战斗入口使用的场景路径、关键节点名与脚本挂载约定。

## 正式场景路径

- `res://scenes/front/room_scene.tscn`
- `res://scenes/front/loading_scene.tscn`
- `res://scenes/battle/battle_main.tscn`

## 退役说明

- 历史 sandbox 场景已退役
- 正式前台流程只能进入 `res://scenes/battle/battle_main.tscn`
- 后续测试、工具、调试若需载入正式战斗，默认使用 `battle_main.tscn`
- `res://scenes/sandbox/simulation_prototype.tscn` 仅保留为 sandbox / prototype 调试场景，不是正式入口

## Room Scene

路径：`res://scenes/front/room_scene.tscn`

关键节点：
- `RoomScene`
- `RoomHudController`
- `RoomRoot`
- `RoomRoot/MainLayout`
- `RoomRoot/MainLayout/TitleLabel`
- `RoomRoot/MainLayout/MemberList`
- `RoomRoot/MainLayout/ActionRow/ReadyButton`
- `RoomRoot/MainLayout/ActionRow/StartButton`
- `RoomRoot/MainLayout/SelectorRow/MapSelector`
- `RoomRoot/MainLayout/SelectorRow/RuleSelector`
- `RoomRoot/MainLayout/RoomDebugPanel/DebugLabel`

## Loading Scene

路径：`res://scenes/front/loading_scene.tscn`

关键节点：
- `LoadingScene`
- `LoadingRoot`
- `LoadingRoot/MainLayout`
- `LoadingRoot/MainLayout/LoadingLabel`
- `LoadingRoot/MainLayout/PlayerLoadingList`
- `LoadingRoot/MainLayout/TimeoutHint`

## BattleMain

路径：`res://scenes/battle/battle_main.tscn`

BattleMain 是当前正式战斗入口，前台流程层只允许切入正式 BattleMain 场景。

关键节点：
- `BattleMain`
- `BattleMain/BattleBootstrap`
- `BattleMain/BattleBootstrap/PresentationBridge`
- `BattleMain/WorldRoot`
- `BattleMain/WorldRoot/MapRoot`
- `BattleMain/WorldRoot/ActorLayer`
- `BattleMain/WorldRoot/FxLayer`
- `BattleMain/WorldRoot/DebugLayer`
- `BattleMain/BattleCameraController`
- `BattleMain/SpawnFxController`
- `BattleMain/CanvasLayer`
- `BattleMain/CanvasLayer/BattleHUD`
- `BattleMain/CanvasLayer/CountdownPanel`
- `BattleMain/CanvasLayer/PlayerStatusPanel`
- `BattleMain/CanvasLayer/NetworkStatusPanel`
- `BattleMain/CanvasLayer/MatchMessagePanel`
- `BattleMain/CanvasLayer/SettlementPopupAnchor`
- `BattleMain/CanvasLayer/SettlementPopupAnchor/SettlementController`
- `BattleMain/CanvasLayer/SettlementPopupAnchor/SettlementController/ResultLabel`
- `BattleMain/CanvasLayer/SettlementPopupAnchor/SettlementController/DetailLabel`
- `BattleMain/AudioRoot`

脚本挂载约定：
- `BattleBootstrap` -> `res://gameplay/battle/runtime/battle_bootstrap.gd`
- `PresentationBridge` -> `res://presentation/battle/bridge/presentation_bridge.gd`
- `BattleCameraController` -> `res://presentation/battle/scene/battle_camera_controller.gd`
- `SpawnFxController` -> `res://presentation/battle/scene/spawn_fx_controller.gd`
- `BattleHUD` -> `res://presentation/battle/hud/battle_hud_controller.gd`
- `CountdownPanel` -> `res://presentation/battle/hud/countdown_panel.gd`
- `PlayerStatusPanel` -> `res://presentation/battle/hud/player_status_panel.gd`
- `NetworkStatusPanel` -> `res://presentation/battle/hud/network_status_panel.gd`
- `MatchMessagePanel` -> `res://presentation/battle/hud/match_message_panel.gd`
- `SettlementController` -> `res://presentation/battle/hud/settlement_controller.gd`

## Cleanup Rule

- 正式流程层只允许使用 `SceneFlowController.BATTLE_SCENE_PATH = res://scenes/battle/battle_main.tscn`
- 正式路径不得反向依赖任何 sandbox 场景或 sandbox 表现组件
- sandbox 场景只能用于原型验证、测试或开发期调试
