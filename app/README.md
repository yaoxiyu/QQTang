# app

## 目录定位
应用级运行时编排层。

## 职责范围
- 前台流程组织
- 全局运行时根管理
- 调试入口管理

## 允许放入
- 应用级 flow/controller/config 脚本
- 显式的 runtime debug 工具

## 禁止放入
- battle 规则实现
- network transport 细节
- presentation 细节逻辑

## 对外依赖
- 可依赖 `res://scenes/`、`res://network/`、`res://gameplay/battle/`
- 不承载 `res://presentation/` 或仿真层真相

## 维护约束
- 正式流程主干放在 `flow/`
- 调试工具放在 `debug/`
- 不在本层混入阶段性命名
