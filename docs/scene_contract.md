# Scene Contract

本文件记录当前正式前台与战斗入口使用的场景路径、关键节点名与脚本挂载约定。

## 正式场景路径

- `res://scenes/front/boot_scene.tscn`
- `res://scenes/front/login_scene.tscn`
- `res://scenes/front/lobby_scene.tscn`
- `res://scenes/front/room_scene.tscn`
- `res://scenes/front/loading_scene.tscn`
- `res://scenes/battle/battle_main.tscn`

## Front Runtime Contract

- 本阶段未新增或删除 Boot / Login / Lobby / Room / Loading 的场景节点
- 本阶段只统一了前台控制器初始化顺序
- `boot_scene.tscn` 对应控制器负责 runtime bootstrap
- `login_scene.tscn`
- `lobby_scene.tscn`
- `room_scene.tscn`
- `loading_scene.tscn`
  上述消费型前台场景控制器统一等待 `AppRuntimeRoot.runtime_ready`
- 若直接打开消费型前台场景且 runtime 缺失, 正式行为是回 `boot_scene.tscn`

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
- `RoomRoot/MainLayout/TopBar`
- `RoomRoot/MainLayout/TopBar/BackToLobbyButton`
- `RoomRoot/MainLayout/TopBar/TitleLabel`
- `RoomRoot/MainLayout/TopBar/RoomMetaLabel`
- `RoomRoot/MainLayout/SummaryCard`
- `RoomRoot/MainLayout/SummaryCard/SummaryVBox`
- `RoomRoot/MainLayout/SummaryCard/SummaryVBox/RoomKindLabel`
- `RoomRoot/MainLayout/SummaryCard/SummaryVBox/RoomIdValueLabel`
- `RoomRoot/MainLayout/SummaryCard/SummaryVBox/ConnectionStatusLabel`
- `RoomRoot/MainLayout/SummaryCard/SummaryVBox/OwnerLabel`
- `RoomRoot/MainLayout/SummaryCard/SummaryVBox/BlockerLabel`
- `RoomRoot/MainLayout/LocalLoadoutCard`
- `RoomRoot/MainLayout/LocalLoadoutCard/LocalLoadoutVBox/PlayerNameRow/PlayerNameInput`
- `RoomRoot/MainLayout/LocalLoadoutCard/LocalLoadoutVBox/CharacterRow/CharacterSelector`
- `RoomRoot/MainLayout/LocalLoadoutCard/LocalLoadoutVBox/CharacterSkinRow/CharacterSkinSelector`
- `RoomRoot/MainLayout/LocalLoadoutCard/LocalLoadoutVBox/BubbleRow/BubbleSelector`
- `RoomRoot/MainLayout/LocalLoadoutCard/LocalLoadoutVBox/BubbleSkinRow/BubbleSkinSelector`
- `RoomRoot/MainLayout/RoomSelectionCard`
- `RoomRoot/MainLayout/RoomSelectionCard/RoomSelectionVBox/MapRow/MapSelector`
- `RoomRoot/MainLayout/RoomSelectionCard/RoomSelectionVBox/RuleRow/RuleSelector`
- `RoomRoot/MainLayout/RoomSelectionCard/RoomSelectionVBox/ModeRow/GameModeSelector`
- `RoomRoot/MainLayout/MemberCard`
- `RoomRoot/MainLayout/MemberCard/MemberVBox/MemberList`
- `RoomRoot/MainLayout/PreviewCard`
- `RoomRoot/MainLayout/PreviewCard/PreviewVBox/MapPreviewLabel`
- `RoomRoot/MainLayout/PreviewCard/PreviewVBox/RulePreviewLabel`
- `RoomRoot/MainLayout/PreviewCard/PreviewVBox/ModePreviewLabel`
- `RoomRoot/MainLayout/PreviewCard/PreviewVBox/CharacterPreviewLabel`
- `RoomRoot/MainLayout/PreviewCard/PreviewVBox/CharacterPreviewViewport`
- `RoomRoot/MainLayout/PreviewCard/PreviewVBox/CharacterSkinPreviewLabel`
- `RoomRoot/MainLayout/PreviewCard/PreviewVBox/CharacterSkinIcon`
- `RoomRoot/MainLayout/PreviewCard/PreviewVBox/BubblePreviewLabel`
- `RoomRoot/MainLayout/PreviewCard/PreviewVBox/BubbleSkinPreviewLabel`
- `RoomRoot/MainLayout/PreviewCard/PreviewVBox/BubbleSkinIcon`
- `RoomRoot/MainLayout/ActionRow/LeaveRoomButton`
- `RoomRoot/MainLayout/ActionRow/ReadyButton`
- `RoomRoot/MainLayout/ActionRow/StartButton`
- `RoomRoot/MainLayout/RoomDebugPanel/DebugLabel`

脚本挂载约定：
- `RoomScene` -> `res://scenes/front/room_scene_controller.gd`
- `RoomHudController` -> `res://presentation/battle/hud/room_hud_controller.gd`
- `RoomRoot/MainLayout/PreviewCard/PreviewVBox/CharacterPreviewViewport` -> `res://presentation/front/preview/room_character_preview.gd`

## Loading Scene

路径：`res://scenes/front/loading_scene.tscn`

关键节点：
- `LoadingScene`
- `LoadingRoot`
- `LoadingRoot/MainLayout`
- `LoadingRoot/MainLayout/LoadingLabel`
- `LoadingRoot/MainLayout/PlayerLoadingList`
- `LoadingRoot/MainLayout/TimeoutHint`

脚本挂载约定：
- `LoadingScene` -> `res://scenes/front/loading_scene_controller.gd`

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
