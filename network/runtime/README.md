# runtime

## 目录定位
联机运行时启动与错误处理层。

## 职责范围
- bootstrap
- runtime config
- diagnostics
- 错误路由

## 正式 / 调试边界
- `dedicated_server_bootstrap.gd`
  - 正式 Dedicated Server 启动脚本
- `client_room_runtime.gd`
  - 正式客户端 Room 接入运行时
- `network_bootstrap.gd`
  - 仅限 debug-only / QA transport shell
  - 不得继续扩展为正式产品入口

## 允许放入
- 网络启动脚本
- 运行时配置与诊断
- 错误处理辅助

## 禁止放入
- transport 编解码细节
- battle HUD 逻辑
- gameplay legacy wrapper

## 对外依赖
- 可依赖 `res://network/session/` 与 `res://network/transport/`
- 不依赖前台场景控制器实现细节

## 维护约束
- 关注启动、配置、诊断
- 不与 session/runtime 语义混写
- 调试能力保留但要显式
- debug bootstrap 的日志、文案、README 都必须显式标注 `DEBUG ONLY`
