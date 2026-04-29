# tools

## 目录定位
工程工具、环境编排和客户端启动脚本。

## 当前正式入口
- `db-up.ps1`：启动 DB docker（支持 `dev/test`，默认 `dev`）。
- `db-migrate.ps1`：写入 SQL 迁移（兼容新库和已有库升级流程）。
- `run-services.ps1`：一键启动 account/game/ds_manager/room 全部服务。
- `start-clients.ps1`：一键启动多个客户端（支持参数化实例数量）。
- `services/room_service/scripts/run-room-service.ps1`：room_service 单服务启动脚本。

## Profile 约定
- 所有工具脚本统一支持 `-Profile dev|test`，默认 `dev`。
- `test` 使用独立 docker compose、容器和端口，不污染 `dev`。

## 典型命令
```powershell
# 1) 启 DB
powershell -ExecutionPolicy Bypass -File .\tools\db-up.ps1 -Profile dev

# 2) 执行迁移
powershell -ExecutionPolicy Bypass -File .\tools\db-migrate.ps1 -Profile dev

# 3) 一键起服务
powershell -ExecutionPolicy Bypass -File .\tools\run-services.ps1 -Profile dev

# 4) 一键起 2 个客户端
powershell -ExecutionPolicy Bypass -File .\tools\start-clients.ps1 -Profile dev -Count 2 -GodotDir "F:\godot"
```

## 维护规则
- 新逻辑只允许写在正式入口脚本。
- 不再新增只做参数转发的兼容脚本；旧入口应删除并在文档中改到正式入口。
