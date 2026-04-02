# gameplay

## 目录定位
玩法逻辑与仿真装配层。

## 职责范围
- battle 启动装配
- 配置定义
- simulation 主体
- legacy wrapper 容器

## 允许放入
- gameplay 侧 battle/config/simulation 逻辑
- 显式 compatibility 包装层

## 禁止放入
- UI 流程主逻辑
- 编辑器缓存
- 调试日志产物

## 对外依赖
- 可依赖 `res://content/` 与正式 `res://network/`
- 不承载 presentation UI 主流程

## 维护约束
- 正式实现与 legacy wrapper 分区明确
- 仿真层不可被 Node/UI 反向侵入
- 不新增 phase 型目录
