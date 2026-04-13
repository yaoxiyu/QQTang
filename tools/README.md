# tools

## 目录定位
工程工具与内容管线脚本目录。

## 子目录职责
- `content_pipeline/`：CSV 读取、校验、生成器、报告与运行入口。
- `start_client.ps1`：启动客户端主入口，走项目 `main_scene`，由 Boot 决定进入 Login 或 Lobby。
- `start_ds_2clients.ps1`：启动 Dedicated Server 和两个客户端联调用本。

## 维护规则
- 这里放编辑器工具、生成器与离线脚本。
- 不把运行时业务逻辑长期堆在工具目录里。

## 当前启动脚本真相

- `start_client.ps1`
  - 启动 Godot 客户端
  - 当前正式登录入口由 `boot_scene.tscn` 统一编排
- `start_ds_2clients.ps1`
  - 启动 `dedicated_server_scene.tscn` 与两个客户端
  - 会把 `--qqt-ds-port` 真实传给 Dedicated Server
  - 会把 `--qqt-ds-room-ticket-secret` 真实传给 Dedicated Server
