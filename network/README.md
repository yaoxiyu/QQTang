# network

## 目录定位
正式联机实现主目录。

## 子目录职责
- `runtime/`：联机运行期配置、bootstrap 相关运行对象。
- `session/`：正式会话控制、开战协调、battle start config 构建。
- `transport/`：网络传输抽象、协议调试与 transport 支撑。

## 维护规则
- 新增正式联机逻辑优先进入本层。
- 不把正式实现继续写回 `gameplay/network/` 的 legacy wrapper。
