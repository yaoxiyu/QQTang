# account_service

## 本地环境

开发数据库：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\db-up.ps1 -Target dev
```

测试数据库：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\db-up.ps1 -Target test
```

执行 migration：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\db-apply-migration.ps1 -Target dev
powershell -ExecutionPolicy Bypass -File .\scripts\db-apply-migration.ps1 -Target test
```

运行集成测试：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\test-integration.ps1
```

启动服务：

```powershell
go run ./cmd/account_service
```

## 当前落地边界

- PostgreSQL 通过 `pgxpool` 接入
- Auth/Profile/RoomTicket 最小闭环已打通
- `/healthz` 与 `/readyz` 已区分
- 开发库与测试库已隔离
