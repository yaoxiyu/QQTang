# 地图材质包格式与接入说明

> 适用范围：当前仓库已落地的 starter map materials 接入链路  
> 文档定位：实现说明文档，不替代 `docs/current_source_of_truth.md`  
> 说明：若本文与当前源码不一致，以当前源码为准，并优先更新本文

---

# 1. 目标

当前项目已经支持将地图主题材质包接入 Battle 正式分层表现链路，用于驱动：

- GroundLayer
- StaticBlockLayer
- BreakableBlockLayer
- OccluderLayer
- EnvironmentRoot

当前实现遵循以下原则：

- 不修改仿真层与网络层
- 地图真相仍来自 `content/maps`
- 主题贴图只进入表现层消费
- 旧的占位表现链路保留为回退

---

# 2. 材质包目录格式要求

项目内正式目录：

- `res://assets/map_themes/grassland/`
- `res://assets/map_themes/snowfield/`
- `res://assets/map_themes/desert/`

每套主题目录当前要求至少包含以下文件：

- `ground.png`
- `ground_variant_a.png`
- `ground_variant_b.png`
- `solid_base.png`
- `solid_overlay.png`
- `breakable_block.png`
- `spawn_marker.png`
- `environment_background.png`
- 两个 occluder 贴图

当前三套主题对应的 occluder 文件名：

- `grassland`
  - `occluder_tall_grass.png`
  - `occluder_tree_small.png`
- `snowfield`
  - `occluder_snow_drift.png`
  - `occluder_pine_small.png`
- `desert`
  - `occluder_dune_small.png`
  - `occluder_cactus_small.png`

建议约束：

- ground, solid, breakable, spawn 贴图按单格素材制作
- 单格贴图默认按 `64x64` 理解，但运行时会按 `cell_size` 缩放
- `environment_background.png` 允许大图，当前 Battle 环境层会按场景尺寸进行缩放
- occluder 贴图允许超出单格高度，但锚点应以“所属格左上角 + 地图 entry 的 offset_px”为准

---

# 3. 主题 ID 与目录映射

当前主题材质注册表位于：

- [map_theme_material_registry.gd](/d:/code/QQTang/presentation/battle/scene/map_theme_material_registry.gd)

当前固定映射关系：

- `map_theme_default -> grassland`
- `map_theme_snow -> snowfield`
- `map_theme_desert -> desert`

当前 registry 返回的材质字段：

- `ground`
- `ground_variants`
- `solid_base`
- `solid_overlay`
- `breakable_block`
- `spawn_marker`
- `environment_background`
- `occluders`

---

# 4. 当前接入链路

## 4.1 GroundLayer

入口：

- [map_view_controller.gd](/d:/code/QQTang/presentation/battle/scene/map_view_controller.gd)

当前行为：

- 地面不再通过 `_draw()` 画纯色格子
- 每个格子会实例化 `Sprite2D`
- 默认使用 `ground.png`
- 通过稳定 hash 稀疏选择 `ground_variant_a.png` 和 `ground_variant_b.png`
- `TileType.SPAWN` 会额外叠加 `spawn_marker.png`

## 4.2 StaticBlockLayer

入口：

- [map_view_controller.gd](/d:/code/QQTang/presentation/battle/scene/map_view_controller.gd)

当前行为：

- 优先使用 `solid_base.png`
- 若主题材质缺失，则回退到旧的 `TilePresentationDef + scene` 占位表现

说明：

- `solid_overlay.png` 当前已进入材质格式要求，但尚未接到独立叠加层

## 4.3 BreakableBlockLayer

入口：

- [map_view_controller.gd](/d:/code/QQTang/presentation/battle/scene/map_view_controller.gd)
- [map_breakable_block_view.gd](/d:/code/QQTang/presentation/battle/tiles/map_breakable_block_view.gd)

当前行为：

- breakable 仍由独立 layer 负责实例创建
- Battle 初始化时按 `runtime_layout.breakable_cells` 创建实例
- 优先使用 `breakable_block.png`
- 若贴图缺失，则回退到原有程序化砖块
- 销毁时仍使用原有 tween 缩小淡出表现

补充：

- 文档建议版 [breakable_block_view.gd](/d:/code/QQTang/presentation/battle/scene/views/breakable_block_view.gd) 已补入仓库
- 当前主链路为了最小改动，仍复用现有 `map_breakable_block_view.tscn`

## 4.4 OccluderLayer

入口：

- [map_view_controller.gd](/d:/code/QQTang/presentation/battle/scene/map_view_controller.gd)
- [map_occluder_view.gd](/d:/code/QQTang/presentation/battle/tiles/map_occluder_view.gd)

当前行为：

- occluder 仍从 `MapResource.foreground_overlay_entries` 稀疏读取
- 当前不会整图铺满
- 优先使用主题目录中的两个 occluder 贴图
- 若贴图缺失，则回退到旧的程序化 canopy 表现
- 玩家进入 occluder 触发区后会执行透明淡出

位置规则：

- occluder 的世界位置由 `cell + offset_px` 决定
- 贴图模式不再额外自动上移一格
- 地图 entry 中的 `offset_px` 是唯一位移真相源

## 4.5 EnvironmentRoot

入口：

- [map_theme_environment_controller.gd](/d:/code/QQTang/presentation/battle/scene/map_theme_environment_controller.gd)

当前行为：

- 应用主题时优先创建 `environment_background.png` 对应的 `Sprite2D`
- 背景挂到 `EnvironmentRoot`
- 旧的 `environment_scene` 仍保留并继续实例化，作为兼容回退

---

# 5. 地图内容侧要求

地图真相仍在：

- `res://content/maps/resources/*.tres`

当前和材质接入直接相关的字段：

- `tile_theme_id`
- `foreground_overlay_entries`

示例：

- [map_classic_square.tres](/d:/code/QQTang/content/maps/resources/map_classic_square.tres)

要求：

- `tile_theme_id` 必须能映射到有效主题 ID
- `foreground_overlay_entries` 用于稀疏 occluder 测试点
- `foreground_overlay_entries.offset_px` 负责具体贴图对位

---

# 6. 接入流程

## 6.1 新增一套地图主题时

1. 将整套贴图放入 `res://assets/map_themes/<theme_dir>/`
2. 补齐本文第 2 节要求的文件名
3. 在 [map_theme_material_registry.gd](/d:/code/QQTang/presentation/battle/scene/map_theme_material_registry.gd) 中补主题 ID 到目录映射
4. 如该主题有专属 occluder 文件名，在 registry 中补 `OCCLUDER_FILES_BY_DIR`
5. 在 `content/map_themes` 中补对应 `MapThemeDef` 资源
6. 将地图资源中的 `tile_theme_id` 指向该主题

## 6.2 调整某张地图的 occluder 位置时

1. 打开对应 `MapResource`
2. 修改 `foreground_overlay_entries`
3. 只调 `cell` 和 `offset_px`
4. 不在代码里再额外写主题专用偏移

## 6.3 替换单格材质时

1. 保持文件名不变直接替换 png
2. 若贴图尺寸变化较大，优先检查视觉对齐
3. 若 occluder 看起来错位，优先调地图 entry 的 `offset_px`

---

# 7. 当前已知边界

- `solid_overlay.png` 当前尚未单独接入显示
- ground variant 的选择是稳定 hash，不是 autotile
- occluder 当前仍是稀疏测试点模式，不是成片自动铺设
- 环境背景缩放当前使用固定场景尺寸，若 Battle 可视区域变化，需要后续统一环境尺寸策略
- 本链路的目标是先跑通正式分层表现，不是最终商业版地图渲染系统

---

# 8. 相关文件

- [map_theme_material_registry.gd](/d:/code/QQTang/presentation/battle/scene/map_theme_material_registry.gd)
- [map_view_controller.gd](/d:/code/QQTang/presentation/battle/scene/map_view_controller.gd)
- [map_theme_environment_controller.gd](/d:/code/QQTang/presentation/battle/scene/map_theme_environment_controller.gd)
- [map_breakable_block_view.gd](/d:/code/QQTang/presentation/battle/tiles/map_breakable_block_view.gd)
- [map_occluder_view.gd](/d:/code/QQTang/presentation/battle/tiles/map_occluder_view.gd)
- [map_classic_square.tres](/d:/code/QQTang/content/maps/resources/map_classic_square.tres)
- [current_source_of_truth.md](/d:/code/QQTang/docs/current_source_of_truth.md)
