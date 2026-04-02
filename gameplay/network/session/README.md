# session

## 目录定位
compatibility / adapter only 目录。

## 职责范围
- wrapper
- adapter
- 旧接口转发

## 允许放入
- 兼容包装器
- 旧路径适配壳
- 轻量转发脚本

## 禁止放入
- 新增正式业务实现
- 正式 session runtime
- 高耦合网络主逻辑

## 对外依赖
- 可依赖 `res://network/session/`
- 不允许正式实现反向依赖本目录

## 维护约束
- 这里只做 compatibility
- 包装层必须薄且可追溯
- 新逻辑一律进入正式 `res://network/...`
