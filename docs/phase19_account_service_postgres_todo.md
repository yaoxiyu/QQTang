# Phase19 AccountService PostgreSQL 落地待办

## 目标

基于 `05_Phase19_PostgreSQL接入与Go_AccountService落地补充文档.md`，把当前仓库中的 `services/account_service` 从“已有一版可运行雏形”推进到“符合 Phase19 正式化约束的最小闭环实现”。

本清单只覆盖平台账号服务与 PostgreSQL 落地，不改 Godot 前台壳、Room、DS 主链路。

## 当前实现现状

已存在：

- `services/account_service` 的 `cmd / internal / migrations` 基本目录
- `accounts / player_profiles / player_owned_assets / account_sessions / room_entry_tickets` migration
- `auth / profile / ticket / httpapi / storage` 基础代码
- register/login/refresh/profile/room-ticket 的初版实现

当前状态：

- Phase19 PostgreSQL 接入与 Go AccountService 最小闭环已完成
- 开发库与测试库已通过独立 compose 隔离
- 集成测试已切换到 test 专用 database，不再默认触碰开发库
- 配置解析已改为严格失败，不再静默回退
- `ACCOUNT_LOG_SQL` 已接入 `pgx` trace 日志
- dev/test 数据库镜像已固定到当前 `latest` 对应 digest，并标注应用版本 `18.3.0`

## 验收结论

- 账号服务已具备工程化最小交付形态
- 核心链路、环境隔离、配置校验、数据库接入、基础测试与本地脚本已落地
- 当前文档用于记录本轮正式化收口结果

## 执行顺序

### Step 1 基础设施对齐

- [x] 新增 `services/account_service/.env.example`
- [x] 新增 `services/account_service/docker-compose.dev.yml`
- [x] 将配置结构改为文档要求字段：
  - [x] `HTTPListenAddr`
  - [x] `PostgresDSN`
  - [x] `AccessTokenTTLSeconds`
  - [x] `RefreshTokenTTLSeconds`
  - [x] `RoomTicketTTLSeconds`
  - [x] `TokenSignSecret`
  - [x] `RoomTicketSignSecret`
  - [x] `AllowMultiDevice`
  - [x] `LogSQL`
- [x] `LoadFromEnv()` 增加必填校验和 TTL 正值校验
- [x] 存储层切换为 `pgxpool.Pool`
- [x] `main.go` 按文档顺序重组启动装配
- [x] 增加 `/readyz`，并使用 `SELECT 1` 检测 DB 可用性

### Step 2 HTTP 合同对齐

- [x] 路由统一切换到 `/api/v1/*`
- [x] 增加 `POST /api/v1/tickets/room-entry`
- [x] 保留或移除旧路由时明确兼容策略
- [x] 更新 `docs/platform_auth/*.md` 中的路径和示例

### Step 3 Repository 与事务对齐

- [x] Repository 基于 `pgx` 抽象统一 Query 接口
- [x] register 改为单事务：
  - [x] 新建 account
  - [x] 新建 profile
  - [x] 写默认 owned assets
  - [x] 建初始 session
- [x] login 改为单事务：
  - [x] 按策略撤销旧 session
  - [x] 创建新 session
  - [x] 更新 `last_login_at`
- [x] refresh 改为单事务：
  - [x] 校验旧 session
  - [x] 撤销旧 session 或旧 refresh 语义失效
  - [x] 创建新 session
- [x] logout 撤销语义补充精确条件：仅撤销未撤销 session

### Step 4 会话安全与一致性

- [x] access token claims 中纳入 `session_id`
- [x] `ValidateAccessToken()` 增加 session 查询与 revoked 校验
- [x] `refresh_token` 继续只存 hash
- [x] `allow_multi_device` 从配置注入，不再硬编码
- [x] 密码哈希升级为更适合正式落地的方案，并保留 `password_algo`

### Step 5 验证与收口

- [x] 本地 PostgreSQL 启动成功
- [x] migration 成功执行
- [x] `/healthz` 正常
- [x] `/readyz` 在 DB 正常时成功、DB 不可用时失败
- [x] register/login/refresh/logout/profile/ticket 本地 curl 闭环通过
- [x] 更新本文档状态与剩余风险

## 本轮执行结果

- 已将 dev/test PostgreSQL 镜像固定为当前 `latest` 对应 digest
- 当前镜像对应应用版本：`18.3.0`
- 已成功启动本地 PostgreSQL，并在容器内执行 `0001_phase19_auth_init.sql`
- 已成功验证：
  - `GET /healthz`
  - `GET /readyz`
  - `POST /api/v1/auth/register`
  - `POST /api/v1/auth/login`
  - `POST /api/v1/auth/refresh`
  - `POST /api/v1/auth/logout`
  - `GET /api/v1/profile/me`
  - `POST /api/v1/tickets/room-entry`
- 已验证 DB 停止时 `/readyz` 返回 `DB_NOT_READY`，DB 恢复后再次返回成功
- 已补 `config` / `storage` 单元测试
- 已补 test 专用 compose、schema reset、migration、integration test 一键脚本

本轮修复的关键实现问题：

- 修复 opaque token 长度超过 `VARCHAR(64)` 的一致性缺陷
  - 原因：ID 前缀加 `32 bytes` 随机串编码后超出表结构上限
  - 处理：将 opaque token 随机体调整为 `16 bytes`
- 补齐 `accounts.login_name` 唯一约束到 `AUTH_ACCOUNT_ALREADY_EXISTS` 的错误映射
- 增加基于 PostgreSQL 的自动化集成测试
  - 位置：`services/account_service/internal/httpapi/integration_test.go`
  - 覆盖：`healthz / readyz / register / login / refresh / profile / room ticket / logout / duplicate register`
