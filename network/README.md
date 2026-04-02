# network

## 目录定位
正式联机实现主目录。

## 职责范围
- runtime
- session
- transport
- 错误路由与 runtime 诊断

## 允许放入
- 正式联机实现
- 网络 bootstrap/config/diagnostics

## 禁止放入
- 把正式逻辑写回 gameplay legacy 层
- UI 场景主流程
- 与联机无关的临时脚本

## 对外依赖
- 可依赖 `res://content/`、`res://gameplay/battle/`
- 不反向依赖 gameplay legacy wrapper

## 维护约束
- 联机正式逻辑以此为主
- runtime/session/transport 分层明确
- 路径命名长期稳定
