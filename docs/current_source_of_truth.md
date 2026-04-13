# 当前源码真相文档

> 适用范围：当前项目源码现状  
> 目的：本文件是**当前源码结构与职责的唯一真相文档**。后续 AI、人工开发与收尾整改，均应以本文件为准。  
> 原则：本文件只描述**当前源码应当如何被理解、如何继续收口**，不再沿用旧阶段文档中的历史路径、历史命名、历史临时结构。  
> 说明：若旧文档与本文件冲突，以本文件为准。

---

# 1. 当前工程总判断

当前源码已经不是早期原型状态，而是：

- 前台流程、战斗链路与联机主目录已基本成型
- 测试结构已按类型重组完成
- 已具备以下关键特征：
  - 离散仿真层独立存在
  - Battle 正式链路已经从测试沙盒走向正式场景
  - Room / Loading / Battle 已形成前台链路
  - 网络层已开始抽象出 transport / bootstrap / runtime 结构
  - 内容资源化已经从地图扩展到角色、泡泡、模式、皮肤、规则集与内容管线

当前真正需要做的，不是推翻重写，而是：

1. **统一当前源码真相**
2. **收口历史目录语义**
3. **收口 debug 默认行为**
4. **让地图/规则入口完全数据驱动**
5. **让 AI 后续执行不再被旧文档误导**

---

# 2. 当前唯一正式规范的理解方式

后续一切实现与维护，都按以下原则理解：

## 2.1 仿真层仍然是核心真相源

仿真核心的基本原则不变：

- 格子离散仿真
- 仿真层与 Node/表现层分离
- 数据驱动配置
- 可继续面向服务端权威同步演进

这部分是整个项目最稳定、最不应被 UI/场景脚本侵蚀的核心。

补充约束:

- 玩家移动仍然是格子规则驱动, 不是 physics body 连续碰撞
- 玩家位置真相当前采用 `cell_x/cell_y + offset_x/offset_y` 组合表达
- `cell_x/cell_y` 表示当前站位归属格, `offset_x/offset_y` 表示格内平滑位移
- 移动阻挡判定仍以目标格查询为准, 角色不能进入被阻挡格与可走格之间的非法中间态
- 泡泡、道具、玩家逻辑锚点仍以格心为准
- 泡泡放置归属格**不是**简单取玩家当前 `cell_x/cell_y`
- 当前正式规则由 `res://gameplay/simulation/movement/bubble_place_resolver.gd` 统一定义:
  - 基于 `cell_x/cell_y + offset_x/offset_y + facing`
  - 允许前向放置窗口 `MovementTuning.bubble_forward_place_window_units()`
  - 侧向 tie-break 随朝向决定吸附到相邻格
- `BubblePlacementSystem` 与 dedicated server 客户端本地放泡前置门控必须复用同一套 resolver, 不允许各自维护独立判定逻辑
- dedicated server 模式下, 客户端 `action_place` 只允许做输入门控, 不允许本地预测生成 authority-only 泡泡/道具结果
- dedicated server 权威消息当前必须携带:
  - `players` 位置摘要
  - `bubbles`
  - `items`
  - `events`
  - `CHECKPOINT` 额外携带 `walls` 与 `mode_state`
- 客户端预测世界在 dedicated server 模式下要把上述 authority sideband 恢复进本地 world, 表现层只消费该权威恢复后的结果

## 2.2 正式玩法入口已经不是早期测试场景

当前正式玩法入口应理解为：

- Front 场景链路负责：
  - Boot
  - Login
  - Lobby
  - Loading
  - Room
  - Battle 进入前准备
- Battle 场景链路负责：
  - battle runtime 启动
  - presentation bridge
  - HUD / 网络状态面板等表现层控制

当前正式入口进一步明确为：

- `res://scenes/front/boot_scene.tscn`
  - 当前正式客户端主入口
  - 当前唯一正式 `AppRuntimeRoot` bootstrap owner
- `res://scenes/front/login_scene.tscn`
  - 正式登录前台场景
  - 当前只负责认证信息与服务器连接端点输入
  - 不负责角色 / 角色皮肤 / 泡泡 / 泡泡皮肤选择
  - 角色 / 泡泡及其皮肤属于玩家档案与房间内 loadout 语义, 不属于登录校验语义
- `res://scenes/front/lobby_scene.tscn`
  - 正式大厅前台场景
- `res://scenes/front/room_scene.tscn`
  - 正式房间前台场景
  - 承载 Practice Room 与 Dedicated Server 客户端房间接入
- `res://scenes/network/dedicated_server_scene.tscn`
  - 正式 Dedicated Server 进程入口
- `res://scenes/battle/battle_main.tscn`
  - 正式 Battle 场景入口
- `res://scenes/network/network_bootstrap_scene.tscn`
  - 仅限 QA / transport / protocol 调试
  - **不是正式玩法入口**

任何旧测试沙盒路径、历史 sandbox 场景，都不应再被理解为正式入口。

补充生命周期真相：

- `AppRuntimeRoot` 当前仍是普通节点, 不是 Autoload
- `BootSceneController` 是唯一正式 runtime 创建者, 使用 `ensure_in_tree()`
- `Login / Lobby / Room / Loading` 只消费现有 runtime, 统一使用 `get_existing()`
- 前台初始化顺序当前统一由 `runtime_ready` 驱动, 不再依赖 deferred + retry
- 错误路由与 transport 回调等非启动路径不得隐式创建 runtime

## 2.3 当前工程已经采用 canonical path 思路

当前应以现有源码中的正式目录为准，典型包括：

- `res://app/flow/...`
- `res://app/front/...`
- `res://app/debug/...`
- `res://network/...`
- `res://gameplay/battle/...`
- `res://presentation/...`
- `res://content/...`
- `res://content_source/...`
- `res://scenes/front/...`
- `res://scenes/battle/...`
- `res://assets/...`
- `res://tools/content_pipeline/...`
- `res://tests/unit/...`
- `res://tests/integration/...`
- `res://tests/contracts/...`
- `res://tests/smoke/...`
- `services/account_service/...`

旧文档中如果仍出现：

- `res://battle/bootstrap/...`
- `res://battle/presentation/...`
- `res://front/loading/...`
- `res://front/room/...`

则应视为**历史路径表达**，不再作为现行规范。

---

# 3. 当前正式目录语义（Source of Truth）

本节定义当前目录的**正式语义**。后续任何 AI 或人工改造，都必须服从这些语义。

## 3.1 `res://app/flow/`

**定位：前台流程编排与运行期入口配置层**

职责包括：

- App 级流程切换
- 进入 Room / Battle 的前台编排
- runtime config
- debug 启动选项的配置入口
- 仅做流程编排，不承载底层 battle 规则实现

约束：

- 不要把 battle 规则、网络 transport、地图解析等重逻辑继续塞进这里
- `app_runtime_config.gd` 只负责配置真相，不负责偷做业务逻辑
- `app_runtime_root.gd` 当前已具备显式生命周期状态:
  - `NONE`
  - `ATTACH_PENDING`
  - `INITIALIZING`
  - `READY`
  - `DISPOSING`
  - `DISPOSED`
  - `ERROR`
- `AppRuntimeRoot.ensure_in_tree()` 只允许 bootstrap owner 使用
- `AppRuntimeRoot.get_existing()` 是纯消费者的正式 runtime 查询入口

## 3.1.1 `res://app/front/`

**定位：正式前台壳领域层**

职责包括：

- `auth/`
  - 登录占位网关、登录请求/结果、会话状态
- `profile/`
  - 本地玩家档案、前台设置与 repository
- `lobby/`
  - Lobby 视图状态、Practice / Online 房间入口 use case
- `room/`
  - Room 视图模型、presenter、Room 前台 use case
- `navigation/`
  - 前台入口类型、房间类型、返回目标、拓扑常量

约束：

- 只负责前台状态、交互语义与数据编排
- 不直接承载 battle 规则真相与 transport 协议细节
- Lobby 负责产出 `RoomEntryContext`
- Room 前台层负责消费房间权威状态，不能自行伪造 `mode_id`
- Lobby Directory 与 Online Create/Join 当前允许复用同一条 Dedicated Server transport
- 若 `RoomUseCase` 进入房间时目标 DS transport 已连接，必须直接 dispatch create/join 请求，不能再等待新的 `transport_connected`

## 3.1.2 `res://app/debug/`

**定位：运行期调试工具目录**

职责包括：

- 显式调试工具脚本
- 非默认启用的 debug 辅助能力
- 仅服务开发/验证的运行时辅助

约束：

- 不能成为正式流程的默认入口
- 不承载 battle / network 正式实现
- 调试能力必须由显式开关控制

## 3.2 `res://network/`

**定位：正式联机层主目录**

职责包括：

- session controller / session flow
- transport 抽象
- runtime bootstrap
- host/client 本地调试链路
- 后续真实联机接入的主要承载层

约束：

- 新增联机控制逻辑优先进入这里
- 不再新增新的正式联机逻辑到早期 legacy 路径
- UI 控制、网络状态、连接状态展示逻辑应逐步从胖 bootstrap 中拆开
- `res://network/session/runtime/client_runtime.gd` 是 dedicated server 客户端权威 sideband 恢复、放泡输入门控与 authority event 缓存的当前正式落点
- `res://network/session/runtime/server_session.gd` 是 dedicated server 权威 `STATE_SUMMARY / CHECKPOINT / events` 打包出口

## 3.3 `res://gameplay/battle/`

**定位：正式 battle 运行期与玩法装配层**

职责包括：

- battle 启动装配
- battle runtime 生命周期
- 对接仿真层
- 对接 presentation bridge
- 把 Room 选定的 battle start config 落地到实际 battle

约束：

- 不要在这里做前台 UI 流程
- 不要把表现层 HUD 逻辑混进 gameplay runtime

## 3.4 `res://presentation/`

**定位：表现层、桥接层、HUD 控制层**

职责包括：

- PresentationBridge
- HUD Controller
- 状态面板
- 可视同步消费
- 表现刷新

约束：

- 不允许反向侵入仿真层数据设计
- 表现层消费 tick/result，而不是决定玩法真相

## 3.5 `res://content/`

**定位：正式内容定义、内容数据资产与运行时内容索引层**

职责包括：

- 角色、泡泡、模式、地图、道具、Tile 等内容定义
- 角色皮肤、泡泡皮肤、地图主题、规则集等新增内容类型
- catalog / loader / builder / 自动扫描索引
- 正式运行时消费的 `.tres` 资产真相源

当前子目录应理解为：

- `characters/`
  - 角色本体定义、数值、表现数据与运行时加载
- `character_animation_sets/`
  - 角色主体动画集定义、生成产物、catalog 与 runtime loader
  - `SpriteFrames` 由内容管线预生成，不在 Battle 运行期动态切 strip
- `character_skins/`
  - 角色皮肤定义、生成产物与自动扫描 catalog
  - 语义固定为 overlay，不承载角色主体动画
- `bubbles/`
  - 泡泡样式与玩法配置
  - `BubbleStyleDef.animation_set_id` 是泡泡主体动画的正式入口
- `bubble_animation_sets/`
  - 泡泡主体动画集定义、生成产物与 catalog
  - `SpriteFrames` 由内容管线预生成，不在 Battle 运行期动态切 grid / strip
- `bubble_skins/`
  - 泡泡皮肤定义、生成产物与自动扫描 catalog
- `maps/`
  - 地图内容真相源
- `map_themes/`
  - 地图主题定义与环境 scene 引用
- `rules/`
  - 旧规则目录，保留给当前仍在使用的旧链路
- `rulesets/`
  - 新规则集定义、生成产物与自动扫描 catalog
- `modes/`
  - 玩法模式定义与运行时装配
- `tiles/`
  - 地图块定义与表现配置
- `items/`
  - 道具定义与道具数据

统一目录规则：

- `defs/`
  - 放资源定义脚本 `.gd`
- `data/`
  - 放正式内容资产 `.tres`
- `catalog/`
  - 放索引、注册与自动扫描入口
- `runtime/`
  - 放加载器、builder 与运行时装配逻辑
- `resources/`
  - 仅允许保留尚未迁移完的 legacy 资源，不再作为新正式结构

约束：

- 新内容进入工程时，必须优先进入该目录体系
- 不允许继续让 Room UI 或 battle 启动脚本长期硬编码内容列表
- 内容 ID、版本、hash、默认项等信息由本层统一管理
- `CharacterPresentationDef.animation_set_id` 是角色主体动画的正式入口
- `CharacterPresentationDef.body_view_type` 用于约束 body 消费方式，当前正式值为 `sprite_frames_2d`
- `BubbleStyleDef.animation_set_id` 是泡泡主体动画的正式入口

## 3.5.1 `res://content_source/`

**定位：内容生产源文件目录**

职责包括：

- `csv/` 策划维护源
- 供内容管线读取的原始输入文件
- `character_animation_sets/`
  - 角色主体动画源 CSV
- `bubble_animation_sets/`
  - 泡泡主体动画源 CSV

约束：

- 这里是生产输入，不是运行时直接消费的正式资产目录
- 运行时正式资产必须落到 `res://content/*/data/`

## 3.5.2 `res://tools/content_pipeline/`

**定位：内容管线工具目录**

职责包括：

- CSV 解析基类
- generator
- validator
- report
- editor 运行入口
- 当前动画相关 generator 包括：
  - `generate_character_animation_sets.gd`
  - `generate_bubble_animation_sets.gd`

约束：

- 这里只放离线内容工具，不承载正式游戏运行逻辑
- 生成结果应写回 `res://content/*/data/`

## 3.6 `res://scenes/front/`

**定位：正式前台场景控制器目录**

职责包括：

- boot_scene_controller
- login_scene_controller
- lobby_scene_controller
- loading_scene_controller
- room_scene_controller
- 其它前台场景控制脚本

约束：

- 前台场景负责“流程入口”和“UI 交互”
- 不负责伪造 battle 规则真相
- debug 自举只能是显式可控能力，不能作为默认正式行为
- `boot_scene.tscn` 是当前正式客户端主入口
- `login_scene.tscn` 与 `lobby_scene.tscn` 是正式前台态
- `room_scene.tscn` 不再承担登录入口
- Boot 是当前唯一正式 runtime bootstrap owner
- Login / Lobby / Room / Loading 统一只消费 runtime ready
- 若消费型前台场景被直接打开且 runtime 缺失, 正式语义是显式回 Boot, 不是隐式补建 runtime

## 3.6.1 `res://presentation/front/preview/`

**定位：前台正式预览表现组件目录**

职责包括：

- Room 等前台界面的正式内容预览组件
- 复用正式内容链路进行角色主体动画与皮肤预览

当前正式组件包括：

- `room_character_preview.gd`
  - 复用 `CharacterPresentationDef + CharacterAnimationSetDef + CharacterSkinDef`
  - 通过 `SubViewportContainer + SubViewport + Node2D body scene` 在 Room 中显示角色动画预览
  - 预览动画当前按四方向 `run_*` 轮播，不单独发明 Room 专用角色系统

约束：

- 前台预览必须复用正式内容链路，不允许维护第二套 Room 专用角色表现配置
- Room 角色预览的正式场景入口是 `res://scenes/front/components/room_character_preview.tscn`

## 3.6.2 `res://scenes/`

**定位：项目级可实例化场景目录**

职责包括：

- `front/`
  - 前台正式场景
- `battle/`
  - 正式 battle 场景
- `network/`
  - Dedicated Server 与网络调试场景
- `sandbox/`
  - 历史验证或实验场景
- `actors/`
  - 角色、泡泡等可实例化本体 scene
- `skins/`
  - 角色皮肤、泡泡皮肤等 overlay scene
- `map_themes/`
  - 地图主题环境 scene

约束：

- 可实例化节点树放在这里，不放进 `res://content/`
- 正式入口与调试/实验场景必须明确区分

## 3.6.3 `res://scenes/network/`

**定位：网络运行场景入口目录**

职责包括：

- Dedicated Server 进程场景
- transport / protocol 调试场景

约束：

- `dedicated_server_scene.tscn` 是当前唯一正式 Dedicated Server 入口
- `network_bootstrap_scene.tscn` 仅限 debug-only / QA 回归使用
- 不允许把 `network_bootstrap_scene.tscn` 继续扩展成正式产品入口
- 仅在“运行场景/运行进程”语义下，`dedicated_server_scene.tscn` 才代表 DS 已启动；仅在编辑器中打开该 scene 不构成 DS 运行真相

## 3.7 `res://tests/`

**定位：统一测试主目录**

职责包括：

- `unit/` 单元测试
- `integration/` 集成链路测试
- `contracts/` 路径与运行时契约测试
- `smoke/` 冒烟稳定性测试
- `helpers/` 测试辅助脚本
- `cli/` 唯一命令行测试入口
- `scripts/` 测试套件启动脚本

约束：

- 不再按历史阶段拆分目录
- 测试运行产物、日志、appdata 不入库
- 正式业务实现不得反向依赖测试目录

## 3.8 `res://assets/`

**定位：原始静态资产目录**

职责包括：

- UI 图标
- 头像
- 原始贴图等非脚本静态资源

约束：

- 这里放原始资源文件，不承载内容 id 真相
- 若某类资产参与正式内容装配，仍需要在 `res://content/` 层有对应数据定义
- `res://assets/animation/`
  - 角色与泡泡动画原始 png 资产目录
  - 只作为内容生产源，不作为 Battle 运行期直接消费真相

## 3.9 `services/account_service/`

**定位：平台账号控制面服务目录**

职责包括：

- PostgreSQL 账号库接入
- Account / Profile / Session / Room Ticket 控制面 API
- 开发数据库与测试数据库的本地 compose 管理
- migration 与集成测试脚本

当前正式约束：

- 存储层统一使用 `pgx/v5 + pgxpool`
- `main.go` 只负责启动装配，不承载业务逻辑
- 事务边界放在 service 层，不放 HTTP handler 层
- `register / login / refresh` 已按事务闭环落地
- `refresh_token` 数据库存 hash
- `/healthz` 只反映进程存活，`/readyz` 必须真实探测 DB
- 开发库与测试库必须隔离：
  - dev: `docker-compose.dev.yml`
  - test: `docker-compose.test.yml`
- 客户端与 Dedicated Server 当前都不直接连接 PostgreSQL
- 客户端默认端口边界当前固定为：
  - `account_service` HTTP 默认：`127.0.0.1:18080`
  - Dedicated Server / room directory 默认：`127.0.0.1:9000`
- 前台设置必须分离保存：
  - `account_service_host/account_service_port` 只用于认证、profile、room ticket HTTP
  - `last_server_host/last_server_port` 只用于 Dedicated Server / room directory / room connect
- 客户端当前通过 HTTP 网关访问 `account_service`：
  - `/api/v1/auth/*`
  - `/api/v1/profile/me`
  - `/api/v1/tickets/room-entry`
- Dedicated Server 当前只消费 room ticket 签名与 claim，不直接访问账号数据库
- 本地脚本以 `services/account_service/scripts/` 为准：
  - `db-up.ps1`
  - `db-apply-migration.ps1`
  - `db-reset-test-schema.ps1`
  - `test-integration.ps1`

约束：

- 不允许再新增第二套测试数据库 compose 或重复启动脚本
- 不允许让集成测试默认指向开发库
- `ACCOUNT_LOG_SQL` 已是正式配置项，打开后必须输出 `pgx` SQL trace

---

# 4. 关于 `gameplay/network/session/` 的正式收口策略（已采纳路线A）

本项目已决定采用：

## 路线A：严格收口为 legacy wrapper / compatibility 层

这意味着：

- `res://gameplay/network/session/` **不再承载正式联机业务实现**
- 该目录只允许保留：
  - 兼容包装层（wrapper）
  - 旧接口适配层（adapter）
  - 旧调用重定向层（forwarder）
- **禁止**在该目录继续新增正式业务逻辑

## 4.1 本目录未来允许存在的文件类型

只允许以下类型文件保留在 `res://gameplay/network/session/`：

1. 兼容包装器  
   例如：
   - `battle_session_adapter.gd`
   - `match_start_coordinator.gd`
   - `room_session_controller.gd`

2. 向新正式路径转发的壳文件  
   要求：
   - 自身不存放复杂状态
   - 不新增联机规则
   - 不再生长为第二套正式实现

## 4.2 本目录未来不应保留的内容

以下内容不应继续作为该目录的正式内容：

- 真实 session runtime 数据对象
- 正式 host/client/server 房间状态实现
- 长生命周期 battle match 状态核心
- 任何本应归属 `res://network/...` 的正式联机逻辑

## 4.3 当前收口目标

当前收口目标应为：

- 将现有 `battle_match.gd / client_session.gd / room_session.gd / server_session.gd`
  从 `res://gameplay/network/session/` 迁出到更明确的新正式目录
- 在原目录补回 wrapper / compatibility 文件
- 所有旧引用逐步切换为新正式路径
- 保证过渡期间兼容，但最终语义清晰

## 4.4 推荐的新正式承载目录

建议将现有正式 runtime 对象迁移到例如以下新目录之一：

### 推荐方案
- `res://network/session/runtime/`

此目录承载：

- `battle_match.gd`
- `client_session.gd`
- `room_session.gd`
- `server_session.gd`

并将其正式定义为：

> 网络会话运行期状态对象目录

这样可避免 `gameplay/network/session/` 继续名不副实。

---

# 5. 当前 battle / room / map 的真相约束

## 5.1 Room 默认行为约束

当前正式规范要求：

- RoomScene 默认不能自动自举本地 debug 房间
- 只有显式启用 debug 开关时，才允许：
  - 自动创建房间
  - 自动添加远端调试成员
  - 自动补默认地图/规则
  - 自动走本地 loop 调试逻辑

因此：

- `enable_local_loop_debug_room`
- `auto_create_room_on_enter`
- `auto_add_remote_debug_member`

这三个配置的默认值，应以“**默认关闭**”为目标。

Practice 路径进一步约束为：

- Practice Room 必须通过正式前台 `Lobby -> Practice Room` 进入
- Practice Room 不再依赖 `RuntimeDebugTools` 自动补远端成员
- Practice Room 的最小开战人数由房间权威状态控制，当前正式值为 `1`

Phase18 房间正式真相进一步约束为：

- Room 成员 `team_id` 已成为正式房间状态字段
- `team_id` 当前通过：
  - `RoomMemberState`
  - `RoomSnapshot.members[]`
  - `RoomMemberBindingState`
  - `RoomSessionController.member_profiles`
  统一贯通
- 新进房间成员默认 `team_id = slot_index + 1`
- 房间内组队当前只允许每个客户端修改自己的 `team_id`
- 房间 active match 期间禁止修改 `team_id`
- authoritative room snapshot 下发后，本地 `team_id` 缓存必须被权威状态覆盖
- Room 前台当前正式提供：
  - TeamSelector
  - 成员列表 Team 文案
  - 本地 Team 预览文案

离开房间生命周期进一步约束为：

- 离开 online private room 时，客户端必须：
  - 显式发送 `ROOM_LEAVE`
  - 等待 dedicated server 返回 `ROOM_LEAVE_ACCEPTED` 后再断开 dedicated server room transport
  - 若短时间内未收到 `ROOM_LEAVE_ACCEPTED`，客户端才允许走超时断连兜底
  - 清空本地 `RoomSessionController` 状态
  - 清空 `current_room_snapshot` 与 `current_room_entry_context`
- 客户端离房后到真正断开 transport 之前，迟到的 room snapshot 不允许重新污染本地 Room 状态
- dedicated server 房间在最后一个成员离开后，必须重置整间 `room_state`
- 不允许保留旧 room id、旧成员 profile、旧 ready 状态进入下一次建房 / 加房流程

## 5.2 地图与规则必须走数据驱动

当前正式规范要求：

- 地图列表来自 `MapCatalog`
- 地图加载来自 `MapLoader`
- 地图资源来自 `MapResource`
- Room UI 不再长期硬编码地图项
- battle 的 map_id / version / hash 必须与资源体系一致

规则集同理：

- 不应长期由 UI 脚本写死
- 应逐步收口到 catalog / config / 常量注册表

模式同理：

- `mode_id` 已进入 Room 权威状态
- Battle 启动时优先读取 `RoomSnapshot.mode_id`
- 不允许继续优先信任客户端本地偏好去覆盖房间权威 `mode_id`

## 5.3 Battle 启动链路要求

Battle 的正式启动应理解为：

1. 前台 Room 确定房间状态与开战配置
2. 配置被写入 battle start config
3. Battle 表现层根据 Room 真相重建 `BattleRuntimeConfig` 视觉侧配置，并按 `player_slot` 装配 player visual profile
4. `BattleRuntimeConfigBuilder` 当前会对角色动画配置做前置合法性校验：
   - `character_presentation.body_scene != null`
   - `body_view_type == sprite_frames_2d`
   - `animation_set_id` 非空
   - `CharacterAnimationSetDef` 可加载
   配置不合法时直接 fail-fast，不允许带着空 body 进入 Battle
4. `player_actor_view.gd` 当前已从 `Polygon2D` 占位体升级为正式角色 body 容器，消费 `CharacterPresentationDef`、`CharacterAnimationSetDef` 与 `CharacterSkinDef`
5. presentation bridge 消费 battle tick / result
6. HUD 与 network status panel 仅表现状态，不定义玩法真相

Phase18 Battle 启动链路进一步约束为：

- `BattleStartConfig.player_slots[].team_id` 当前已成为正式字段
- `BattleSimConfigBuilder` 当前会把以下真相写入 `SimConfig.system_flags`：
  - `rule_set`
  - `spawn_assignments`
  - `player_slots`
- `SimWorld` 当前必须按 `player_slots[].team_id` 初始化玩家，不允许再使用 `slot_index % 2` 之类的隐式 team 推导
- 当前正式生命规则栈顺序为：
  - `ExplosionHitSystem`
  - `PlayerLifeTransitionSystem`
  - `JellyInteractionSystem`
  - `PlayerLifeTransitionSystem`
  - `RespawnSystem`
  - `ScoreSystem`
  - `StatusEffectSystem`
- 敌触处决需要在 `JellyInteractionSystem` 后同 tick 再走一次生命结算，不允许把 `players_to_execute` 延迟到下一 tick 才真正死亡
- 果冻当前已有正式超时字段：
  - `rule_set.trapped_timeout_sec`
  - 玩家进入 `TRAPPED` 时写入 `trapped_timeout_ticks`
  - `JellyInteractionSystem` 在无人接触时逐 tick 扣减
  - 倒计时归零后同 tick 进入最终死亡流程
- 复活无敌当前是正式规则字段：
  - `rule_set.respawn_invincible_sec`
  - `RespawnSystem` 在复活瞬间写入 `invincible_ticks`
  - `PreTickSystem` 逐 tick 扣减
  - 无敌窗口内不会被爆炸再次炸死，这是当前明确设计
- `StatusEffectSystem` 当前仅应保留炸砖和爆炸泡泡返还等残余职责，不再作为玩家生命规则真相主入口
- 果冻救援 / 敌触处决必须由仿真层决定，不允许依赖表现层碰撞
- 当前正式接触判定基于玩家脚底中心绝对坐标的固定阈值距离，不允许引入非确定性物理 overlap 作为真相

补充说明：

- `battle_player_visual_profile_builder.gd` 当前会对角色动画视觉装配失败输出明确错误日志
- `player_actor_view.gd` 正式消费 body scene + animation set + skin overlay
- `player_actor_view.gd` 对大位移变更必须直接 snap, 不允许把复活回出生点表现成平滑漂移
- `character_sprite_body_view.gd` 当前动画切换优先按输入状态驱动，再回退到 `move_state`
- `BattleStateToViewMapper` 当前已正式输出：
  - `team_id`
  - `life_state`
  - `pose_state`
- `CharacterSpriteBodyView` 当前已正式支持：
  - `trapped_*`
  - `victory_*`
  - `defeat_*`
  的动画查找与安全回退
- 当前 pose / 动画回退规则为：
  - `trapped_* -> dead_*`
  - `victory_* -> idle_*`
  - `defeat_* -> dead_*`
- `BattleHUD` 当前正式支持：
  - TeamScorePanel
  - LocalLifeStatePanel
- `SettlementController` 当前正式支持：
  - TeamOutcomeLabel
  - ScoreSummaryLabel
- `BattleResult` 当前已扩展队伍结果语义，至少包括：
  - `winner_team_ids`
  - `local_team_id`
  - `team_scores`
  - `player_scores`
  - `local_outcome`
  - `score_policy`

## 5.4 Dedicated Server 联机同步约束

当前 dedicated server 正式同步约束为：

1. 服务端仿真仍是唯一玩法权威
2. 客户端预测世界只保留本地移动预测，不在 dedicated server 模式下预测 authority-only 泡泡/道具生成结果
3. 服务端 `STATE_SUMMARY` 当前必须提供 `bubbles/items/events`
4. 服务端 `CHECKPOINT` 当前必须提供 `players/bubbles/items/walls/mode_state/events`
5. 客户端 `ClientRuntime` 负责把这些权威 sideband 恢复进本地预测世界，再交给 presentation bridge 消费
6. 泡泡与道具这类 authority-only 实体的恢复必须按服务端 `entity_id` 直接恢复, 不允许先本地分配 id 再覆写
7. breakable block 视图必须和权威 grid 双向同步:
   - 不仅删除已消失 block
   - 也要在 rollback / resync 后补回重新出现的 block
8. 调试日志可以存在，但 anomaly / trace 日志默认不应成为正式业务真相的一部分
9. Lobby Public Room / Private Room 的 online enter 以 DS transport ready 为前提:
   - 若 transport 尚未连接，先等待 `transport_connected` 再 dispatch create/join
   - 若 transport 已由 room directory 流程建立并保持可用，必须直接复用并立刻 dispatch create/join

---

# 6. 当前明确废弃/仅历史参考的内容

以下内容只可作为历史参考，不再作为现行规范：

## 6.1 旧路径表达
例如：

- `res://battle/bootstrap/...`
- `res://battle/presentation/...`
- `res://battle/ui/...`
- `res://front/loading/...`
- `res://front/room/...`

## 6.2 旧临时测试场景
任何旧 sandbox、旧过渡验证场景，如果仍存在于缓存或编辑器状态中，只可视为历史遗留，不可视为正式入口。

## 6.3 `.godot/` 下的编辑器状态
这些内容：

- 不是源码真相
- 不是工程设计结构
- 不能作为目录审查依据
- 打包交付时应清理或排除

---

# 7. 当前必须遵守的硬性约束

1. **旧文档若与本文件冲突，以本文件为准**
2. **`gameplay/network/session/` 只保留 legacy wrapper / compatibility 层**
3. **正式联机实现进入 `res://network/...`**
4. **地图必须走 `content/maps` 真相源**
5. **Room 默认不得自动走 debug 自举**
6. **前台场景只负责流程与交互，不伪造玩法真相**
7. **表现层只消费结果，不反向定义仿真**
8. **打包交付时排除 `.godot/`、缓存、编辑器状态文件**
9. **角色主体动画必须走 `content/character_animation_sets` 正式子系统，不能并入 `character_skins`**
10. **泡泡主体动画必须走 `content/bubble_animation_sets` + `BubbleStyleDef.animation_set_id`，不允许保留 Battle 占位圆形回退**
11. **Room 角色预览必须复用 `CharacterPresentationDef + CharacterAnimationSetDef + CharacterSkinDef` 正式链路，不允许维护第二套 Room 专用角色预览配置**
12. **角色动画收口的最小回归测试当前固定为 `tests/contracts/content/character_animation_pipeline_contract_test.gd` 与 `tests/integration/battle/player_actor_animation_binding_test.gd`**
13. **角色站位锚点必须落在 `CharacterAnimationSetDef` 资源字段中统一管理**
   - 地图块继续使用格子左上角为铺设原点
   - 玩家逻辑点, 泡泡, 道具继续使用格心为世界锚点
   - 角色美术锚点固定解释为"脚下占格中心"
   - `pivot_origin` 表示角色资产默认脚底中心点
   - `pivot_adjust` 表示该资产相对默认脚底中心点的固定校准值
   - Battle 运行时不允许再额外写角色显示偏移来修站位, 新角色资产必须按该规范填写
14. **`AppRuntimeRoot` 生命周期当前已显式化, 前台主链路必须以 `runtime_ready` 为统一初始化语义**
15. **只有 Boot 和测试 harness 可以调用 `ensure_in_tree()` 创建 runtime**
16. **Login / Lobby / Room / Loading / FrontFlow 错误路由 / ClientRoomRuntime transport 回调等纯消费者必须使用 `get_existing()`**
17. **非启动路径不得隐式创建 runtime**
18. **Dedicated Server 房间开局已切换为 loading barrier commit 模式，不再依赖固定 timer**
19. **``JOIN_BATTLE_ACCEPTED`` 现在表示 canonical config 已下发、进入 loading 准备阶段，而不是立刻进入 battle**
20. **``MATCH_LOADING_SNAPSHOT`` / ``MATCH_LOADING_READY`` 已成为正式协议，loading barrier 由服务端协调**
21. **Lobby Reconnect 已支持 public_room / private_room 正确分支，不再默认私房恢复**
22. **Settlement Rematch 已变成正式重赛链路，通过 ``pending_room_action`` 延迟到 Room 场景恢复后执行**
23. **Phase17: Active match 断线默认进入恢复窗口，不再立即 abort**
24. **Phase17: Reconnect 已从 room-only 入口升级为 room/battle 统一恢复入口**
25. **Phase17: Dedicated server client input 使用 `controlled_peer_id` 作为 battle 控制身份**
26. **Phase17: Transport peer 仅表示当前连接，不再等同于 active match 控制身份**
27. **Phase17: 房间成员身份通过 `RoomMemberBindingState` 管理，与 transport peer 解耦**
28. **Phase17: 服务端为断线成员保留恢复窗口（默认 20 秒），超时后 abort match**
29. **Phase17: 客户端恢复时通过 `ROOM_RESUME_REQUEST` + `MATCH_RESUME_ACCEPTED` 协议恢复到 active match**
30. **Phase17: Active match resume 使用 `FrontFlowController.request_resume_match()` 进入 `MATCH_LOADING`，不复用普通开局的 `ROOM -> request_start_match()` 前置条件**
31. **Phase17: Resume battle 启动前将 `MatchResumeSnapshot` 交给 `BattleSessionAdapter`；若 client runtime 已启动，`apply_resume_snapshot()` 必须立即注入 checkpoint**
32. **Phase17: Idle room 普通断线保留 member session 短窗口用于 room-only resume；窗口过期、手动 leave、room reset 必须移除 member binding 并使 token 失效**
33. **Phase17: 服务端 battle input 必须校验 `sender_transport_peer_id -> member_id -> match_peer_id`，只接受匹配 `frame.peer_id` 的输入**
34. **Phase17: `ServerRoomRegistry` 必须显式路由 `ROOM_RESUME_REQUEST`，并在 resume 成功后把新 transport peer 绑定回原 room runtime**
35. **Phase17: Room 恢复状态 UI 以 `RoomViewModelBuilder -> RoomScenePresenter` 为单一来源，场景 controller 不再自行拼接恢复窗口文本**
36. **Phase17: 客户端手动离房必须清理本地 reconnect ticket，并持久化到 `FrontSettingsRepository`**
37. **Phase18: `team_id` 已成为 Room -> Battle 的正式配置字段，任何链路都不得再通过 slot 奇偶或其它隐式规则推导 team**
38. **Phase18: `TRAPPED` 与 `REVIVING` 都属于“队伍仍然活跃”的状态，不能在淘汰判定中当作已淘汰**
39. **Phase18: 当前玩家生命处理必须走 `PlayerLifeTransitionSystem / JellyInteractionSystem / RespawnSystem / ScoreSystem` 正式规则栈，不得再把新增生命规则继续堆入旧 `StatusEffectSystem`**
40. **Phase18: 积分模式 `score_policy=team_score` 下，不得走 last survivor 提前结束，`TIME_UP` 必须按 `mode_state.team_scores` 结算**
41. **Phase18: 计分必须发生在最终死亡确认时，不得在进入果冻 `TRAPPED` 时提前记分**
42. **Phase18: Battle 表现层必须通过 `pose_state` 消费胜负姿态与果冻姿态，缺失动画资源时必须按既定回退策略继续运行**
43. **Phase18: 果冻不能无限持续, `TRAPPED` 必须受 `trapped_timeout_sec` 驱动并在超时后自动进入最终死亡流程**
44. **Phase18: 复活回出生点属于位置重置, Battle Actor 必须直接 snap 到权威出生位置, 不允许出现跨格平滑过渡**

---

# 8. 后续 AI 执行时的优先级解释

如果后续 AI 收到多个阶段文档，应按以下优先级理解：

1. 本文件《当前源码真相文档》
2. 最新整改执行文档
3. 最新阶段 closeout / canonical paths 文档
4. 历史 phase 施工文档
5. 更早期的原型设计文档

---

# 9. 一句话结论

当前项目的核心不是“推翻重写”，而是：

> 在保留当前有效实现的基础上，完成目录语义收口、debug 默认行为收口、地图/规则入口数据驱动化，以及 legacy 兼容层回收。

本文件即为当前源码的唯一真相说明。
