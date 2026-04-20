# network

## 目录定位
正式联机实现主目录。

## 子目录职责
- `runtime/`：联机运行期配置、bootstrap 相关运行对象。
- `session/`：正式会话控制、开战协调、battle start config 构建。
- `transport/`：网络传输抽象、协议调试与 transport 支撑。

## 维护规则
- 新增正式联机逻辑优先进入本层。
- 兼容壳已删除：
  - `gameplay/network/session/` 已删除。
  - 旧 dedicated-server bootstrap 脚本已删除。
- 新逻辑必须写入正式路径（如 `network/session/runtime/*`、`network/runtime/battle_dedicated_server_bootstrap.gd`）。
- 任何新逻辑不得写回已删除的 legacy/compat 路径。
