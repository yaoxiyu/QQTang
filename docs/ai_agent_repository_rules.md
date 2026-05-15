# QQTang AI Agent 仓库规则

> 此文件为 AGENTS.md 和 CLAUDE.md 的单一来源。修改规则时只改此处，再由脚本或人工同步到根目录。

## 编码风格
- 无论是写新需求，还是修改bug，都要从系统化、工程化、架构化、一致性的角度来思考，而不是打补丁、绕过错误。
- 任何代码都要考虑性能、安全性、可拓展性

## 规范落地原则（防回退）
- 任何已在代码中落地的硬门禁，都必须同步写入本规则文件；未写入规则视为流程缺口。
- 新增门禁时必须同时给出 dev 测试可用的显式后门（默认关闭），避免 dev 自测依赖复杂校验链路。
- 规则优先约束“默认行为 + 例外开关 + 生产禁用条件”，避免只有口头约定。

## Dev 测试后门策略
- 门禁默认从严，但必须保留仅用于本地/测试环境的显式开关，命名统一使用 `QQT_ALLOW_*`。
- dev 后门必须默认关闭，且只允许在 `development/test` 脚本或 compose 中显式开启，不得在生产配置中透传。
- 新增后门时，必须写明适用范围、风险边界和关闭方式；生产路径不得依赖后门才能运行。

## 重构拆分性价比
- 当文件/方法深度耦合且共享状态字段较多（例如 10+）时，不得为“形式拆分”强行提取，先做成本收益评估。
- 可优先采用低风险替代方案：边界收口、门面封装、职责注释、契约测试、监控补齐，而不是一次性大拆。
- 若决定暂不拆分，必须记录原因、风险和后续触发条件（如性能瓶颈、缺陷密度、迭代频率）再进入重构。

## 文档语言
- Codex 新生成的项目文档默认必须使用中文。
- 既有英文文档在用户要求翻译或重写时，应翻译为中文。

## 文档治理规则
- 文档必须按类型落盘，禁止同一主题在多个目录重复维护：
  - `docs/platform_*`：线上接口/协议契约（面向调用方，必须可验证）。
  - `docs/architecture`：仍在生效的架构设计与边界说明（面向开发）。
  - `docs/asset_specs`：资产输入规格契约（面向内容生产管线）。
  - `docs/archive`：历史阶段复盘和已退役方案（只读，不再迭代）。
  - 根目录 `README.md`：开发启动入口，不承载细节设计。
- 新文档必须在开头写明“文档类型、适用范围、权威代码入口、最后更新日期（YYYY-MM-DD）”。
- 涉及命令的文档必须以“可执行路径”为准：命令、脚本路径、端口、环境变量至少逐项可在仓库中定位。
- 同一主题只保留一个“当前版本”文档；旧版必须移动到 `docs/archive/`，并在现行文档写明替代关系。
- 文档引用到兼容脚本或兼容目录时，必须标注“兼容层”与退役条件，避免被误当作正式入口。

## 脚本治理规则
- 脚本分层固定：
  - `scripts/`：仓库级编排入口（内容、验证、docker、proto、dev battle）。
  - `services/*/scripts/`：单服务运维/迁移脚本。
  - `tests/scripts/`：测试编排入口。
  - `tools/`：可复用工具实现，不承载跨域流程编排。
- 禁止长期保留兼容包装脚本或转发层；发现双入口时必须收敛为单一正式入口并删除旧入口。
- 新增脚本前必须先检查是否可扩展现有入口；禁止“同职责新脚本 + 旧脚本并存”。
- 生成性输出（日志、临时报告、缓存）只能写入 `logs/`、`tests/reports/`、`build/` 等输出目录，不得写回源码目录。

## 工具治理规则
- `tools/` 的职责是“工具实现与校验器”，不是流程入口集合；流程入口优先放 `scripts/`。
- 每个工具子目录必须包含可发现入口（`README` 或主脚本注释），说明输入、输出、依赖和调用方式。
- 工具若迁移目录（如新旧入口并存），旧目录只允许保留兼容壳；新增能力必须只进新目录。
- 校验类工具（lint/guard）必须可在 CI 独立执行，且失败即阻断，不允许 soft-fail。

## GDScript 强制预检
- 在运行任何基于 GDScript 的管线、契约测试、集成测试或临时 Godot 脚本前，必须先运行 GDScript 语法预检。
- 如果语法预检报告任何 parse/load 错误，必须立即停止。修复语法错误前，不得继续运行管线或 GDScript 测试。
- 这是一条硬门禁，不是 best-effort 检查。

## 必需命令
- 语法预检：`powershell -ExecutionPolicy Bypass -File tests/scripts/check_gdscript_syntax.ps1`
- 内容管线：`powershell -ExecutionPolicy Bypass -File scripts/content/run_content_pipeline.ps1`
- 内容校验：`powershell -ExecutionPolicy Bypass -File scripts/content/validate_content_pipeline.ps1`

## 执行顺序
1. 运行 GDScript 语法预检。
2. 只有语法预检通过后，才能运行被请求的 Godot 管线或测试命令。
3. 如果命令失败，需要说明失败属于语法、内容数据、运行时脚本还是环境问题。

## 下载和安装审批
- 以后任何下载或安装前，必须先告诉用户需要下载/安装什么，以及为什么需要。
- 必须询问用户选择由 Codex 执行下载/安装，还是由用户手动处理。
- 在用户确认选择前，不得开始下载或安装。

## Bug 排查
- 所有 bug 的排查都要讲究，合理猜测 + 证据验证（日志）：
  - 先排查代码，再排查数据，最后排查环境。
  - 先排查用户，再排查开发，最后排查运维。
  - 先排查大模块，再排查小模块，最后排查具体代码。
  - 先排查重现步骤，再排查日志，没有日志就要添加日志。

## 环境与密钥硬门禁
- `ACCOUNT_ENV/GAME_ENV/ROOM_ENV/DSM_ENV` 为服务环境判定基准；`prod/production` 视为生产环境。
- 生产环境下，以下敏感字段必须拒绝 dev 弱密钥模式（包含空值）：`dev_`、`replace_me`、`changeme`、`qqtang_dev_pass`。
- 适用范围至少覆盖：`ACCOUNT_*` 鉴权密钥、`GAME_*` JWT/内部鉴权密钥、`ROOM_TICKET_SECRET`、`DSM_*` 内部鉴权与 battle ticket 密钥。

## HTTP 安全与执行门禁
- 服务 URL 与 HTTP 解析默认强制 HTTPS（secure-by-default）。
- 仅在本地/测试联调时，可通过 `QQT_ALLOW_INSECURE_HTTP=1` 放开 HTTP；生产环境不得依赖该开关。
- `ds_manager_service` 的 battle DS warm-pool 透传 `QQT_ALLOW_INSECURE_HTTP` 仅允许 `DSM_ENV=development`，在 `test/prod` 显式禁止。
- 同步 HTTP 执行默认禁用；仅允许在显式设置 `QQT_ALLOW_SYNC_HTTP_EXECUTE=1` 时用于本地调试，业务逻辑优先使用异步接口。

## 房间服务部署门禁
- `room_service` 生产环境必须满足：`ROOM_DEPLOYMENT_MODE=single_instance` 且 `ROOM_EXPECTED_REPLICAS=1`。
- 在持久化房间状态能力未启用前，生产环境禁止多副本抢占同一房间状态。
- `/readyz` 必须暴露部署关键元信息头（环境、部署模式、副本期望、实例与分片标识）用于运维巡检。

## DS 管理服务部署门禁
- `ds_manager_service` 生产环境禁止 Docker 池化运行模式（`DSM_POOL_MODE` 不得为 docker 变体）。
- 生产环境下 `DSM_DOCKER_SOCKET` 必须为空，禁止将宿主 docker.sock 暴露到生产运行面。
- `deploy/docker/docker-compose.services.dev.yml` 仅用于开发联调；生产编排以 `deploy/docker/docker-compose.services.prod.yml` 为基准。

## 地图管线入口规范
- 地图管线唯一标准入口是 `tools/map_pipeline/`。
- 地图编辑器入口统一为 `tools/map_pipeline/map_editor.py`。
- 新增脚本、CI、文档引用统一使用 `tools/map_pipeline`，禁止再引入旧目录或转发层。

## CI 与仓库守卫
- 禁止路径守卫必须启用：`tools/project_guard/forbidden_paths_guard.py`，默认种子为 `tools/project_guard/default_forbidden_paths_seed.txt`。
- proto 生成目标守卫必须启用：`tools/lint/check_buf_gen_targets.py`。
- proto 漂移守卫必须启用：`tools/lint/check_proto_generated_clean.ps1`。
- 上述守卫失败时必须阻断合并，不允许以“先过再补”方式跳过。

## 调试日志噪声控制
- 高频调试日志默认关闭，按需显式开启，避免污染运行日志和压低性能。
- 传输层诊断日志开关：`QQT_DEBUG_TRANSPORT_LOGS`。
- 果冻交互诊断日志开关：`QQT_DEBUG_JELLY_LOGS`。

## 音频系统
- 项目唯一的 autoload 单例是 `AudioManager`（`services/audio/audio_manager.gd`），业务代码通过全局变量直接调用。
- 音频播放必须走 AudioManager API（`play_bgm` / `play_sfx` / `play_ui_sfx`），不得直接 `load()` 音频资源或手动创建 AudioStreamPlayer。
- 音频资产 id 定义在 `content_source/csv/audio/audio_assets.csv`，生成到 `content/audio/data/`，由 `AudioCatalog` 提供运行时查询和别名解析。
- 编号音效 `x05_01` ~ `x40_01` 语义未确认，写新功能时不得直接绑定这些 id；走 `_audit_numbered/` 隔离。
- 音频子系统完整 API 和架构文档见 `docs/architecture/audio_system.md`。

## 任务结束时
- 告诉用户需要如何验证本次修改，包括需要重新编译、生成哪些资源，调用什么脚本等
- 若涉及 GDScript 相关流程，验证步骤必须包含：语法预检 -> 目标管线/测试命令 -> 失败归因分类。
- 若涉及内容资源改动，验证步骤必须包含：内容管线与内容校验命令。
- 若涉及协议、目录或门禁改动，验证步骤必须包含对应守卫脚本（project guard / proto guard / 生成目标 guard）。
