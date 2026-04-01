# 当前源码真相文档

> 适用范围：当前项目源码现状  
> 目的：本文件是**当前源码结构与职责的唯一真相文档**。后续 AI、人工开发、收尾整改、Phase4/Phase5 延伸，均应以本文件为准。  
> 原则：本文件只描述**当前源码应当如何被理解、如何继续收口**，不再沿用旧阶段文档中的历史路径、历史命名、历史临时结构。  
> 说明：若旧文档与本文件冲突，以本文件为准。

---

# 1. 当前工程总判断

当前源码已经不是早期 Phase1/Phase2 原型状态，而是：

- **Phase3 已基本成型**
- **Phase4 已部分落地**
- 已具备以下关键特征：
  - 离散仿真层独立存在
  - Battle 正式链路已经从测试沙盒走向正式场景
  - Room / Loading / Battle 已形成前台链路
  - 网络层已开始抽象出 transport / bootstrap / runtime 结构
  - 地图资源化已经开始落地（MapCatalog / MapLoader / MapResource）

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

## 2.2 正式玩法入口已经不是早期测试场景

当前正式玩法入口应理解为：

- Front 场景链路负责：
  - Loading
  - Room
  - Battle 进入前准备
- Battle 场景链路负责：
  - battle runtime 启动
  - presentation bridge
  - HUD / 网络状态面板等表现层控制

任何旧测试沙盒路径、旧 phase2 sandbox 场景，都不应再被理解为正式入口。

## 2.3 当前工程已经采用 canonical path 思路

当前应以现有源码中的正式目录为准，典型包括：

- `res://app/flow/...`
- `res://network/...`
- `res://gameplay/battle/...`
- `res://presentation/...`
- `res://content/maps/...`
- `res://scenes/front/...`

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

## 3.5 `res://content/maps/`

**定位：地图资源真相源**

职责包括：

- map catalog
- map loader
- map resource
- 地图资源注册
- 后续扩图的唯一资源入口

约束：

- 新地图进入工程时，必须先进入此目录体系
- 不允许继续让 Room UI 直接硬编码地图列表作为长期方案
- 地图 ID、版本、资源、hash 等信息都应由该体系统一管理

## 3.6 `res://scenes/front/`

**定位：正式前台场景控制器目录**

职责包括：

- loading_scene_controller
- room_scene_controller
- 其它前台场景控制脚本

约束：

- 前台场景负责“流程入口”和“UI 交互”
- 不负责伪造 battle 规则真相
- debug 自举只能是显式可控能力，不能作为默认正式行为

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

## 5.3 Battle 启动链路要求

Battle 的正式启动应理解为：

1. 前台 Room 确定房间状态与开战配置
2. 配置被写入 battle start config
3. battle runtime 按 battle start config 启动
4. presentation bridge 消费 battle tick / result
5. HUD 与 network status panel 仅表现状态，不定义玩法真相

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

## 6.2 旧 phase2/phase3 临时测试场景
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
