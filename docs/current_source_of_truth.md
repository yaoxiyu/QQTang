# 源码收口与结构整改执行文档（AI可执行版）

> 目标：将当前源码收口到统一真相，落实以下整改：
>
> 1. 采用路线A：`res://gameplay/network/session/` 收口为 legacy wrapper / compatibility 层  
> 2. 生成并落地“当前源码真相文档”  
> 3. 关闭默认 debug room 自举  
> 4. 推进 Room 地图/规则入口的数据驱动化  
> 5. 为后续 Phase4/Phase5 建立稳定工程边界  
>
> 本文档面向 AI 执行与人工协作混合施工。  
> 约定：
> - 能由 AI 修改的 `.gd`、`.md`、`.gitignore` 等文本文件，交给 AI 执行
> - 需要在 Godot 编辑器中点击、查看、验证、重新绑定资源的部分，明确标注为【人工操作】
> - AI 不要擅自修改 `.tscn`、`.tres`、`.import`、`.godot/` 等高风险引擎资源，除非本文明确允许

---

# 0. 整改总原则

## 0.1 不推翻现有 battle 主链路
本次整改不是重写项目，而是在当前已有实现基础上做**结构收口**。

## 0.2 优先清语义，再清目录，再清入口
整改顺序必须是：

1. 先明确当前真相
2. 再迁正式 runtime 对象
3. 再补 legacy wrapper
4. 再清 Room debug 默认行为
5. 再做地图/规则数据驱动入口
6. 最后清缓存与打包规范

## 0.3 过渡期间允许兼容，但必须显式兼容
在迁移引用的过程中，可以暂时保留过渡适配，但必须满足：

- 兼容层只 forward
- 不允许在兼容层偷偷新增逻辑
- 所有 TODO 必须写明最终归宿

---

# 1. 执行结果清单（完工判定）

全部完成后，工程应达到以下状态：

1. 存在文档：`docs/current_source_of_truth.md`
2. `res://gameplay/network/session/` 仅保留 wrapper / compatibility 文件
3. 正式 runtime session 对象迁移到新目录（推荐 `res://network/session/runtime/`）
4. Room 默认不自动创建本地 debug 房间
5. Room 的地图列表不再硬编码，改为从 MapCatalog 读取
6. 规则列表至少具备单独注册来源，不再长期写死在 UI 里
7. `.gitignore` 或打包规则明确排除 `.godot/` 等缓存目录
8. 关键场景人工验证通过：
   - Loading -> Room 正常
   - Room 不自动 debug 自举
   - 显式开启 debug 后可以自举
   - 选择地图后可以正确进入 battle
   - battle 启动不因目录迁移而断链

---

# 2. Step 1：落地当前源码真相文档

## 2.1 目标
将《当前源码真相文档》正式落地到源码仓库中，作为后续唯一真相文档。

## 2.2 AI操作
创建文件：

```text
res://docs/current_source_of_truth.md
```

将本次配套提供的《当前源码真相文档》内容完整写入，不要删减。

## 2.3 校验标准
- 文件存在
- Markdown 可读
- 路径、目录语义、路线A 约束、debug 默认关闭约束均完整保留

## 2.4 注意事项
- 不要再把旧 phase 文档复制一遍
- 这是“现状真相文档”，不是历史过程复述文档

---

# 3. Step 2：为 session runtime 新建正式承载目录

## 3.1 目标
建立新的正式目录，承接当前不应继续留在 `res://gameplay/network/session/` 中的运行期 session 对象。

## 3.2 推荐目录
创建目录：

```text
res://network/session/runtime/
```

## 3.3 AI操作
在该目录下准备承接以下文件：

- `battle_match.gd`
- `client_session.gd`
- `room_session.gd`
- `server_session.gd`

## 3.4 执行要求
### 方案要求
- 优先采用“搬迁 + 修正 import/class_name/预加载路径”的方式
- 不要简单复制两份然后都保留长期共存
- 迁移后旧目录只保留 wrapper，不保留正式实现

### 如果项目大量使用 `class_name`
AI 必须检查：
- 是否依赖 `class_name`
- 是否存在同名类重复定义
- 迁移后避免两个脚本暴露同一个 `class_name`

如使用 `class_name`，应采取以下策略之一：

#### 策略A（推荐）
- 正式 runtime 文件保留 `class_name`
- 旧 wrapper 不声明 `class_name`

#### 策略B
- 正式 runtime 文件不使用 `class_name`，统一改显式 preload/load 引用

由 AI 根据现有工程习惯判断，但必须保证 Godot 不出现脚本类重名冲突。

## 3.5 校验标准
- 新目录存在
- 正式 runtime 文件位于新目录
- 项目可正常解析脚本，不出现重复类注册错误

---

# 4. Step 3：迁移旧 session runtime 文件到新正式目录

## 4.1 目标
把原来放在 `res://gameplay/network/session/` 的正式 runtime 对象迁出。

## 4.2 AI操作
检查旧目录中的以下文件：

```text
res://gameplay/network/session/battle_match.gd
res://gameplay/network/session/client_session.gd
res://gameplay/network/session/room_session.gd
res://gameplay/network/session/server_session.gd
```

将它们迁移到：

```text
res://network/session/runtime/
```

建议对应新路径：

```text
res://network/session/runtime/battle_match.gd
res://network/session/runtime/client_session.gd
res://network/session/runtime/room_session.gd
res://network/session/runtime/server_session.gd
```

## 4.3 AI执行细则

### 4.3.1 迁移前先全局搜索引用
AI 必须全局搜索以下内容：

- 文件路径字符串
- `preload(...)`
- `load(...)`
- `class_name`
- 注释中的路径说明
- 文档中的当前路径引用（如 closeout / canonical 文档）

### 4.3.2 修改所有正式引用
将所有正式逻辑引用改为新目录路径，不要继续依赖旧目录。

### 4.3.3 保证功能不变
迁移仅改变“归属目录语义”，不改变业务行为。

### 4.3.4 对外行为不得变化
包括但不限于：
- 房间状态读写
- host/client session 生命周期
- battle match 启动准备
- server/client 相关状态对象交互

## 4.4 风险点
- `class_name` 冲突
- preload 路径漏改
- 旧注释误导后续 AI
- 部分文档引用仍指向旧路径

## 4.5 校验标准
- 旧正式引用已指向新目录
- 项目运行时不因为路径迁移报错
- 行为一致

---

# 5. Step 4：在旧目录补回 legacy wrapper / compatibility 层

## 5.1 目标
让 `res://gameplay/network/session/` 成为真正的兼容层，而不是正式实现层。

## 5.2 旧目录未来应保留的文件
建议在该目录中建立或补回以下文件：

```text
res://gameplay/network/session/battle_session_adapter.gd
res://gameplay/network/session/match_start_coordinator.gd
res://gameplay/network/session/room_session_controller.gd
```

如果现有工程已有同义正式文件，则这里应实现为 wrapper / forwarding 壳。

## 5.3 wrapper 设计原则
每个 wrapper 必须满足：

1. 文件头注释明确写：
   - 该文件为 legacy compatibility wrapper
   - 正式实现位于何处
2. 不新增复杂状态
3. 不承载正式业务逻辑
4. 只做以下几类事情：
   - 转发到新正式实现
   - 保持旧调用兼容
   - 给旧接口返回新对象/代理对象
   - 输出 deprecation 注释或 warning（如合适）

## 5.4 AI执行建议
### 可选模式A：纯转发
例如：
- 内部 `preload` 新正式类
- 构造时返回新正式对象
- 或通过成员持有新正式对象并转发方法

### 可选模式B：薄控制器适配
对于必须保留旧 API 形态的情况：
- 保留相同方法签名
- 内部映射到新目录实现
- 方法体尽可能只做参数转译

## 5.5 严禁事项
- 不允许在 wrapper 中写新的 session 生命周期规则
- 不允许在 wrapper 中堆额外业务判断
- 不允许把 wrapper 重新写胖

## 5.6 校验标准
- `gameplay/network/session/` 内不再承载正式 runtime 对象
- 旧目录文件能被理解为兼容层
- 注释清晰

---

# 6. Step 5：关闭默认 debug room 自举

## 6.1 目标
保证 RoomScene 默认进入时，不自动进行本地 loop debug 房间初始化。

## 6.2 AI操作
检查并修改：

```text
res://app/flow/app_runtime_config.gd
```

将以下默认值改为**关闭**：

- `enable_local_loop_debug_room = false`
- `auto_create_room_on_enter = false`
- `auto_add_remote_debug_member = false`

## 6.3 同步检查调用链
AI 还必须检查以下文件的调用关系：

- `res://scenes/front/room_scene_controller.gd`
- `res://app/flow/phase3_debug_tools.gd`

确认行为变为：

### 默认路径
- RoomScene 启动
- `_initialize_runtime()` 执行
- 但不会自动 bootstrap 本地房间

### 显式 debug 路径
只有当 runtime config 明确开启时，才允许：
- 自动创建房间
- 自动加假成员
- 自动选默认地图/规则
- 自动进入 debug 房间流程

## 6.4 AI实现要求
- 保留 debug 能力
- 只改变默认值与默认行为
- 不要直接删掉 debug 工具链

## 6.5 校验标准
- 默认进 Room 时为空房或等待用户操作
- 开 debug 开关时仍可自举

## 6.6 【人工操作】验证步骤
1. 在 Godot 编辑器打开项目
2. 正常启动前台流程进入 Room
3. 观察是否自动出现本地房间成员、自动创建房间、自动补地图/规则  
   - 预期：**不会**
4. 再由 AI 或人工临时开启 debug 配置
5. 重新运行进入 Room  
   - 预期：会按 debug 配置自动自举

---

# 7. Step 6：将 Room 的地图列表改为由 MapCatalog 驱动

## 7.1 目标
消除 `room_scene_controller.gd` 中对地图列表的长期硬编码。

## 7.2 AI操作
检查文件：

```text
res://scenes/front/room_scene_controller.gd
```

重点关注当前 `_populate_selectors()` 或等价逻辑。

## 7.3 现状问题
当前地图项可能类似写死：

- `default_map`
- `large_map`

这不满足长期数据驱动要求。

## 7.4 目标做法
RoomScene 的地图选项必须改为：

1. 从 `MapCatalog` 读取可用地图列表
2. 将地图显示名、地图 ID 显示到 UI
3. 用户选择结果写入当前房间状态/开战配置
4. battle 启动时使用该选择结果，而不是 UI 本地写死值

## 7.5 AI详细执行步骤

### 7.5.1 先定位目录与 API
AI 先检查：

- `res://content/maps/catalog/map_catalog.gd`
- `res://content/maps/runtime/map_loader.gd`
- `res://content/maps/resources/*.tres`

确认 `MapCatalog` 当前可提供什么：
- 地图 ID 列表
- 地图描述对象
- 地图显示名
- 地图资源引用
- 地图版本/hash（如已有）

### 7.5.2 若 `MapCatalog` 缺少读取接口，先补接口
允许 AI 在 `map_catalog.gd` 中新增**只读查询接口**，例如：

- 获取全部地图定义
- 获取地图 ID 列表
- 通过地图 ID 获取定义对象
- 获取默认地图 ID

要求：
- 不破坏现有调用
- 尽量只增不改
- 保持只读、轻量、纯查询

### 7.5.3 修改 RoomScene 的选择器填充逻辑
把原先写死的地图列表，改为：

- 启动时读取 `MapCatalog`
- 清空现有地图选择器
- 按 catalog 顺序填入地图项
- 每一项绑定真实 `map_id`

### 7.5.4 修改“当前选择写回”逻辑
用户切换地图时，Room 逻辑必须写回到：
- room snapshot / room state / start config
- 不允许 UI 只改显示、不改真实数据

### 7.5.5 修改 battle 启动链路校验
检查 battle 启动用到的配置对象（例如 `BattleStartConfig`），确认：
- `map_id`
- `map_version`
- `map_content_hash`

来自真实地图定义或加载结果，而不是 UI 写死值。

## 7.6 风险点
- UI 控件 item text / item metadata 绑定方式不规范
- map_id 只在 UI 保存，未写回房间状态
- battle 仍回退到默认地图
- debug room snapshot 继续写死默认图

## 7.7 校验标准
- Room 地图列表来源于 MapCatalog
- 新增地图资源后，只要注册 catalog，即可在 Room 中显示
- 选择不同地图后进入 battle，实际进入的地图正确

## 7.8 【人工操作】验证步骤
1. 启动项目进入 Room
2. 查看地图下拉框/选择器内容  
   - 预期：来源于当前 catalog
3. 在 Room 中切换到不同地图
4. 点击开始战斗或进入 battle
5. 观察 battle 实际加载结果  
   - 预期：与所选地图一致

---

# 8. Step 7：把规则列表从 UI 硬编码中剥离

## 8.1 目标
规则集不再长期硬编码在 `room_scene_controller.gd` 中。

## 8.2 推荐最低落地方案
由于当前文档重点在地图资源化，规则可以先采用**轻量注册表方案**，不必一步做到资源化。

## 8.3 推荐目录
AI 可创建：

```text
res://content/rules/
```

推荐新增：

```text
res://content/rules/rule_catalog.gd
```

## 8.4 AI实现要求
在 `rule_catalog.gd` 中提供只读注册信息，例如：

- `classic`
- `team`

每项至少包含：
- `rule_id`
- `display_name`
- 可选：描述、是否默认、扩展参数

## 8.5 RoomScene 改造
- `_populate_selectors()` 不再直接写死规则项
- 改为从 `RuleCatalog` 读取
- 用户选择写回当前房间状态或开战配置

## 8.6 为什么先用 catalog 而不是直接资源化
原因：

- 当前阶段目标是**去硬编码**
- 规则资源化可以放到下一轮
- 先把“入口真相源”统一，比一步做满更稳

## 8.7 校验标准
- Room 中规则列表来自 RuleCatalog
- battle 启动使用的 rule_set_id 来自真实选择结果

## 8.8 【人工操作】验证步骤
1. 进入 Room
2. 查看规则选择器
3. 切换不同规则
4. 开战并检查 battle 使用的规则 ID/配置  
   - 预期：与所选规则一致

---

# 9. Step 8：清理 debug snapshot / bootstrap 中的硬编码地图与规则

## 9.1 目标
避免 debug 路径继续把地图和规则写死成：

- `default_map`
- `classic`

## 9.2 AI操作
重点检查：

```text
res://network/runtime/network_bootstrap.gd
```

如果其中存在类似 `_build_debug_room_snapshot()` 的逻辑，要做如下调整：

## 9.3 改造要求
### 方案A（推荐）
调试快照构造时，优先读取：
- `MapCatalog.get_default_map_id()`
- `RuleCatalog.get_default_rule_id()`

### 方案B
若已有 Room 当前配置，则优先用当前配置；没有时才回退到 catalog 默认值。

## 9.4 禁止事项
- 不要继续把 `selected_map_id = "default_map"` 写死
- 不要继续把 `rule_set_id = "classic"` 写死为长期方案

## 9.5 校验标准
- debug 自举路径也能跟随当前 catalog 默认值或当前房间选择
- 不再依赖散落硬编码

---

# 10. Step 9：瘦身 `network_bootstrap.gd`（本轮做最小必要拆分）

## 10.1 目标
防止 `network_bootstrap.gd` 继续膨胀，给后续真实联机扩展留空间。

## 10.2 本轮不追求大拆
本轮只做最小必要拆分，避免风险过高。

## 10.3 推荐拆分项
若 `network_bootstrap.gd` 当前同时承担以下职责：

- 控件绑定
- debug UI 响应
- host/client 启动
- transport poll
- 状态文案刷新
- debug snapshot 构建

则优先把**UI 状态映射与控件绑定**拆出去。

## 10.4 推荐新增文件
可新增：

```text
res://network/runtime/network_debug_panel.gd
```

定位：
- 只负责按钮、标签、输入框、状态显示
- 不负责底层 transport / session 真逻辑

## 10.5 AI执行方式
### 最低落地要求
即使不完整拆类，也至少要做到：
- 把纯 UI 更新辅助函数移出去
- 保证 bootstrap 文件中保留生命周期和主流程编排

### 如果本轮风险较高
允许先只加 TODO 注释和职责分区注释，但必须：
- 把纯 UI 代码区域显式标记
- 约束后续不再继续往里堆逻辑

## 10.6 校验标准
- `network_bootstrap.gd` 不再继续变胖
- 文件职责边界更清楚
- 不影响当前联机调试链路

---

# 11. Step 10：更新文档与注释中的旧路径

## 11.1 目标
减少后续 AI 被旧路径误导。

## 11.2 AI操作
全局搜索以下旧路径表达：

- `res://battle/bootstrap/`
- `res://battle/presentation/`
- `res://battle/ui/`
- `res://front/loading/`
- `res://front/room/`

## 11.3 修改策略
### 对代码注释
直接改为当前正式路径。

### 对历史文档
不要强行篡改历史内容，但可在文档开头加说明：

> 本文中的部分路径为历史路径，请以 `docs/current_source_of_truth.md` 为准。

### 对 closeout / canonical 文档
如果这些文档被视为当前仍有效，可直接补充“当前路径映射说明”。

## 11.4 校验标准
- 关键现行文档不再误导
- 新 AI 首先读到 current_source_of_truth 时不会走偏

---

# 12. Step 11：补充 `.gitignore` 或打包排除规则

## 12.1 目标
确保正式源码包不再混入 `.godot/`、shader cache、编辑器状态文件。

## 12.2 AI操作
检查项目根目录是否存在：

```text
.gitignore
```

如果没有，则创建；如果有，则补充以下排除项（按工程已有风格合并）：

```gitignore
.godot/
.import/
*.translation
*.tmp
*.log
```

如果项目已有更细排除规则，以不冲突方式合并。

## 12.3 说明
是否排除 `.import/` 需根据你的仓库策略决定。  
如果当前项目需要提交 `.import/`，则 AI 只处理 `.godot/`、cache、editor 状态等。  
AI 不得擅自删除仓库中已有重要资源索引，除非明确确认其可安全重建。

## 12.4 【人工操作】打包要求
以后打正式源码包时，人工必须确保压缩时排除：

- `.godot/`
- shader cache
- editor states
- 临时日志
- 本地用户布局配置

## 12.5 校验标准
- 仓库忽略规则存在
- 重新打包后源码目录更干净

---

# 13. Step 12：人工回归验证清单（必须执行）

以下步骤必须由人工在 Godot 编辑器内执行，AI 不可替代。

## 13.1 验证一：脚本是否全部可解析
【人工操作】
1. 打开 Godot 工程
2. 等待脚本重新加载
3. 检查是否报以下问题：
   - class_name 冲突
   - preload 路径失效
   - 资源脚本丢失
   - 场景绑定脚本失效

通过标准：
- 无红色脚本错误
- 关键场景可以正常打开

## 13.2 验证二：Loading -> Room
【人工操作】
1. 运行项目
2. 进入 Loading
3. 正常切到 Room

通过标准：
- 不崩溃
- 不丢脚本
- Room UI 正常显示

## 13.3 验证三：Room 默认不自举
【人工操作】
1. 在默认配置下进入 Room
2. 观察是否自动建房、自动加成员、自动补地图规则

通过标准：
- 默认不自动 debug 自举

## 13.4 验证四：显式打开 debug 后仍能自举
【人工操作】
1. 临时把 debug 开关打开
2. 重新运行进入 Room

通过标准：
- 可以自动创建调试房间
- 可以按设计补默认成员和默认设置

## 13.5 验证五：地图选择能真实进入 battle
【人工操作】
1. 在 Room 切换地图A
2. 开战，观察 battle 结果
3. 退出后切换地图B
4. 再开战，观察 battle 结果

通过标准：
- 实际进入地图与 Room 选择一致

## 13.6 验证六：规则选择能真实写入 battle 配置
【人工操作】
1. 在 Room 选择不同规则
2. 开战
3. 检查 battle 日志、状态对象或调试输出

通过标准：
- `rule_set_id` 与 Room 选择一致

## 13.7 验证七：旧兼容路径不再承载正式逻辑
【人工操作 + AI辅助查看】
1. 打开 `res://gameplay/network/session/`
2. 检查目录中的文件
3. 查看其内容是否只是 wrapper / compatibility

通过标准：
- 没有正式 runtime 大逻辑继续留在旧目录

---

# 14. Step 13：提交规范（建议）

## 14.1 建议分为 4 次提交
建议 AI 或人工按以下逻辑拆提交，便于回滚：

### 提交1：文档与真相源
- `docs/current_source_of_truth.md`
- 旧文档注释修正

### 提交2：session runtime 迁移与 wrapper 落地
- 新目录建立
- runtime 文件迁移
- wrapper 建立
- 引用改造

### 提交3：Room / Map / Rule 数据驱动整改
- RoomScene 改造
- MapCatalog 对接
- RuleCatalog 新增
- debug snapshot 硬编码收口

### 提交4：debug 默认值与工程清理
- app_runtime_config 默认值改造
- `.gitignore`
- 注释/文档收尾

## 14.2 原因
这样若发生问题，可快速定位：
- 是目录迁移问题
- 还是 Room 数据驱动问题
- 还是 debug 配置问题

---

# 15. 本轮整改的硬性禁止事项

1. 不要重写 battle 核心逻辑
2. 不要改动地图资源内容本身，除非只是补合法 metadata
3. 不要擅自大改 `.tscn`
4. 不要删除 debug 工具链，只关闭默认开启行为
5. 不要在 wrapper 中新增复杂业务逻辑
6. 不要让 `gameplay/network/session/` 继续名不副实
7. 不要让 Room 继续长期硬编码 map/rule 列表

---

# 16. AI执行时的交付要求

AI 完成修改后，必须输出以下结果给人工：

## 16.1 变更摘要
列出：
- 新增了哪些文件
- 迁移了哪些文件
- 修改了哪些引用
- 哪些地方需要人工重新检查

## 16.2 风险摘要
列出：
- 是否涉及 `class_name`
- 是否涉及 preload 路径迁移
- 是否涉及场景脚本重新绑定风险
- 是否需要人工重新打开场景保存

## 16.3 人工验证清单
必须把本文第13节复制给人工，提醒逐项验证。

---

# 17. 一句话施工结论

本轮整改的核心目标不是“增加新功能”，而是：

> 用最小破坏成本，把当前已经有效的工程收口成一套目录语义清晰、默认行为纯净、入口数据驱动、兼容层边界明确的正式工程结构。
