# network

## 目录定位
网络相关单元测试目录。

## 职责范围
- checksum
- input/prediction/rollback/snapshot
- config/transport 小粒度验证

## 允许放入
- 网络纯逻辑测试
- 模块级配置与编解码校验

## 禁止放入
- 完整 host-client 集成链路
- UI/场景驱动流程测试
- phase 历史包装目录

## 对外依赖
- 可依赖 `res://network/`、`res://gameplay/network/`、`res://tests/helpers/`
- 不依赖正式场景入口

## 维护约束
- 子目录按测试主题拆分
- 统一 `<subject>_test.gd` 命名
- 逻辑边界小而明确
