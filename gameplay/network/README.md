# network

## 目录定位
gameplay 侧网络兼容层总目录。

## 职责范围
- 承载 gameplay 历史网络包装
- 保留旧调用兼容入口
- 指向正式 `res://network/` 实现

## 允许放入
- compatibility wrapper
- adapter
- forwarder

## 禁止放入
- 正式网络主逻辑
- transport 具体实现
- 新的 runtime 主流程

## 对外依赖
- 可依赖 `res://network/`
- 不应反向承载正式网络实现

## 维护约束
- 正式逻辑写入 `res://network/`
- 本层以兼容为目标
- 包装边界必须显式文档化
