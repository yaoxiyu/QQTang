# transport

## 目录定位
transport 抽象与实现目录。

## 职责范围
- ENet 实现
- loopback 实现
- 消息编解码
- 调试模拟器

## 允许放入
- `i_battle_transport`
- transport codec/type
- 调试模拟 transport

## 禁止放入
- 高层 battle/room UI 逻辑
- 前台流程控制
- session 主状态机

## 对外依赖
- 可被 `res://network/session/` 使用
- 不依赖 scenes 或 gameplay UI

## 维护约束
- 接口与实现分层明确
- debug simulator 可以保留
- 不把高层业务塞进 transport
