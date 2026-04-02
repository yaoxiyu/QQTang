# flow

## 目录定位
正式前台流程主干目录。

## 职责范围
- `AppRuntimeRoot`
- `FrontFlowController`
- `SceneFlowController`
- 运行时配置入口

## 允许放入
- 正式前台流程控制器
- 运行时初始化配置

## 禁止放入
- phase/debug 工具堆积
- battle 核心规则
- transport 或低层网络实现

## 对外依赖
- 可依赖 `res://scenes/` 与应用级网络入口
- 不反向承载表现层或仿真层细节

## 维护约束
- 保持 canonical path
- 文件命名使用长期语义
- debug 工具移入 `res://app/debug/`
