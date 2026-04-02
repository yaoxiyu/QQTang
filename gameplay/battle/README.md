# battle

## 目录定位
battle 启动装配层。

## 职责范围
- 把 room config 落地为 battle runtime
- 组织 battle 生命周期
- 对接 simulation 与 presentation bridge

## 允许放入
- battle bootstrap
- battle runtime 相关配置与状态

## 禁止放入
- HUD 流程
- 前台房间 UI
- transport 细节

## 对外依赖
- 可依赖 `res://content/`、`res://gameplay/simulation/`、`res://presentation/`
- 不反向成为前台流程目录

## 维护约束
- 只做玩法装配与运行时承接
- 不在这里塞表现层逻辑
- 命名保持 battle 语义稳定
