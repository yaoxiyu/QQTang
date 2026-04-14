# Scene Contract

> Archival note: this document is a historical source document. Its still-valid contract content has been merged into `docs/current_source_of_truth.md`; do not treat this archived file as current truth.

本文件记录当前正式前台与战斗入口使用的场景路径、关键节点名与脚本挂载约定。

## 正式场景路径

- `res://scenes/front/boot_scene.tscn`
- `res://scenes/front/login_scene.tscn`
- `res://scenes/front/lobby_scene.tscn`
- `res://scenes/front/room_scene.tscn`
- `res://scenes/front/loading_scene.tscn`
- `res://scenes/battle/battle_main.tscn`

## Front Runtime Contract

- Phase16 新增 Lobby RecentCard 节点: RecentRoomKindLabel, RecentRoomDisplayNameLabel
- Phase16 新增 Room SummaryCard 节点: LifecycleStatusLabel, PendingActionStatusLabel
- Phase16 新增 Loading MainLayout 节点: LoadingPhaseLabel, LoadingStatusLabel
- Phase17 新增 Lobby RecentCard 节点: ReconnectMatchLabel, ReconnectStateLabel
- Phase17 新增 Room SummaryCard 节点: ReconnectWindowLabel, ActiveMatchResumeLabel
- Phase17 新增 Loading MainLayout 节点: LoadingModeLabel, ResumeHintLabel
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
- `RoomRoot/MainLayout/SummaryCard/SummaryVBox/LifecycleStatusLabel`
- `RoomRoot/MainLayout/SummaryCard/SummaryVBox/OwnerLabel`
- `RoomRoot/MainLayout/SummaryCard/SummaryVBox/BlockerLabel`
- `RoomRoot/MainLayout/SummaryCard/SummaryVBox/PendingActionStatusLabel`
- `RoomRoot/MainLayout/SummaryCard/SummaryVBox/ReconnectWindowLabel`
- `RoomRoot/MainLayout/SummaryCard/SummaryVBox/ActiveMatchResumeLabel`
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

Phase17 约定：
- 普通开局通过 `FrontFlowController.request_start_match()` 从 Room 进入 Loading，并继续提交 `MATCH_LOADING_READY`。
- 战中恢复通过 `FrontFlowController.request_resume_match()` 从 Lobby 或 Room 进入 Loading，`LoadingUseCase.loading_mode` 必须为 `resume_match`。
- `resume_match` 模式不提交 `MATCH_LOADING_READY`，只做本地 payload 准备，随后进入 Battle。
- Battle 启动前必须把 `AppRuntimeRoot.current_resume_snapshot` 交给 `BattleSessionAdapter`，由 adapter 注入 checkpoint。

## Phase17 Room Resume UI Contract

- `ReconnectWindowLabel` 与 `ActiveMatchResumeLabel` 只由 `RoomViewModelBuilder -> RoomScenePresenter` 写入。
- `RoomSceneController` 不得再绕过 presenter 自行拼接恢复窗口文本。
- `RoomMemberState.connection_state` 是成员连接状态的 UI 真相，支持 `connected / disconnected / resuming`。
- manual leave 会清理本地 reconnect ticket；普通断线只在服务端恢复窗口内保留 member session。

关键节点：
- `LoadingScene`
- `LoadingRoot`
- `LoadingRoot/MainLayout`
- `LoadingRoot/MainLayout/LoadingLabel`
- `LoadingRoot/MainLayout/LoadingModeLabel`
- `LoadingRoot/MainLayout/LoadingPhaseLabel`
- `LoadingRoot/MainLayout/ResumeHintLabel`
- `LoadingRoot/MainLayout/PlayerLoadingList`
- `LoadingRoot/MainLayout/TimeoutHint`
- `LoadingRoot/MainLayout/LoadingStatusLabel`

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
