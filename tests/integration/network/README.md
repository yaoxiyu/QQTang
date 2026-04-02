# network

## 目录定位
网络链路集成测试目录。

## 职责范围
- host/client bootstrap
- 网络 match flow
- 权威同步与回放链路验证

## 允许放入
- 网络链路 runner
- replay/determinism 集成测试

## 禁止放入
- transport 纯单元测试
- 路径契约测试
- 长时间 smoke 稳定性测试

## 对外依赖
- 可依赖正式 `res://network/` 与必要 `res://gameplay/battle/`
- 不依赖 phase 历史目录

## 维护约束
- 以链路验证为目标
- 全路径引用保持 canonical
- runner 名称去 phase 化
