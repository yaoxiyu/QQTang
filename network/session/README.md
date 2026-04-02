# session

## 目录定位
正式 session 主目录。

## 职责范围
- session 对外入口
- 匹配/房间/battle session 协调
- `runtime/` 正式实现承接

## 允许放入
- session 入口脚本
- 面向 runtime 的协调层

## 禁止放入
- gameplay legacy wrapper
- transport 底层实现
- 前台 UI 逻辑

## 对外依赖
- 可依赖 `runtime/` 与 `res://network/transport/`
- 不反向依赖 gameplay compatibility 层

## 维护约束
- 强调 `runtime/` 为正式实现层
- 入口与实现层职责分开
- 路径保持 canonical
