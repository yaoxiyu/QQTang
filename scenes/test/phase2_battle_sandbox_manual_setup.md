# Phase2 Battle Sandbox 手动搭建说明

## 1. 创建场景

新建一个根节点为 `Node` 的场景。
将根节点命名为 `Phase2BattleSandbox`。
保存为 `res://scenes/test/phase2_battle_sandbox.tscn`。

## 2. 根节点下的子节点结构

在 `Phase2BattleSandbox` 下按下面顺序添加 4 个直接子节点：

1. `SandboxBootstrap`，类型 `Node`
2. `PresentationRoot`，类型 `Node2D`
3. `CanvasLayer`，类型 `CanvasLayer`
4. `SandboxDebugCommands`，类型 `Node`

## 3. 表现层节点结构

在 `PresentationRoot` 下添加 3 个子节点：

1. `ActorLayer`，类型 `Node2D`
2. `FxLayer`，类型 `Node2D`
3. `DebugDrawLayer`，类型 `Node2D`

给 `PresentationRoot` 挂脚本：
`res://presentation/sandbox/phase2/presentation_bridge.gd`

只要节点名保持和这里一致，导出的默认路径就不用改。

## 4. HUD 节点结构

在 `CanvasLayer` 下添加 2 个 `Label`：

1. `SimpleDebugHud`
2. `NetDebugOverlay`

分别挂脚本：

- `SimpleDebugHud` -> `res://presentation/sandbox/phase2/simple_debug_hud.gd`
- `NetDebugOverlay` -> `res://presentation/sandbox/phase2/net_debug_overlay.gd`

建议布局：

- `SimpleDebugHud` 放左上角，位置可设为 `(16, 16)`
- `NetDebugOverlay` 放右上角，位置可设为 `(-16, 16)`，宽度大约 `260`

## 5. 启动与调试脚本

给这两个节点挂脚本：

- `SandboxBootstrap` -> `res://gameplay/sandbox/phase2/sandbox_bootstrap.gd`
- `SandboxDebugCommands` -> `res://gameplay/sandbox/phase2/sandbox_debug_commands.gd`

如果场景节点名和本文档一致，`SandboxBootstrap` 的导出路径也不需要额外调整。

## 6. 运行方式

这个 sandbox 直接读取物理键盘输入，不依赖 InputMap，所以不用额外配置输入映射。

操作方式：

- 玩家 1：`WASD` 移动，`Space` 放泡泡
- 玩家 2：方向键移动，`Enter` 放泡泡
- `F5`：重开对局
- `F6`：切换延迟档位
- `F7`：切换丢包档位
- `P`：暂停
- `O`：单步推进一个 Tick

## 7. 说明

- 这个 sandbox 是单进程实验场，但采用的是服务端权威推进方式。
- 它复用了现有 `simulation/session` 底座，只额外增加了一层很薄的表现和调试壳。
- 当前版本里的 prediction、rollback、smoothing 计数还是占位显示，先服务于最小可玩验证。
