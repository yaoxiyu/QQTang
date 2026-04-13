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

一键按 dev 配置启动服务：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run-dev.ps1
```

浏览器注册页：

```text
http://127.0.0.1:18080/register
```

当前客户端正式语义：

- Login 场景只负责登录
- Register 按钮会打开浏览器注册页
- room ticket 由 account service 签发，Dedicated Server 用同一份服务端密钥验签，客户端不持有该密钥

当前 dev 默认边界：

- `account_service`: `127.0.0.1:18080`
- Dedicated Server: `127.0.0.1:9000`

## 当前落地边界

- PostgreSQL 通过 `pgxpool` 接入
- Auth/Profile/RoomTicket 最小闭环已打通
- `/healthz` 与 `/readyz` 已区分
- 开发库与测试库已隔离
- 默认注册页已挂载到 `GET /register`
