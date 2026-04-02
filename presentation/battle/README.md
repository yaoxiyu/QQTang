# battle

## 目录定位
战斗表现层总目录。

## 职责范围
- actors
- bridge
- hud
- scene 表现控制

## 允许放入
- 战斗表现控制器
- actor view
- HUD 脚本

## 禁止放入
- battle 规则真相
- 仿真核心状态修改
- 前台房间流程逻辑

## 对外依赖
- 可依赖 `res://gameplay/battle/` 与 `res://content/`
- 不应反向侵入 simulation 核心

## 维护约束
- actors/bridge/hud/scene 职责划分清晰
- 表现逻辑只消费数据
- 命名围绕 battle presentation 统一
