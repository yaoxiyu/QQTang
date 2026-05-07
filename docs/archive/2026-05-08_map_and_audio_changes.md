# 2026-05-08 地图编辑器 + 管线改动记录

## 一、音频系统（已提交 `3dbd7b6`）

新增 `services/audio/` + `content/audio/` + `content_source/csv/audio/`，
详见 `docs/architecture/audio_system.md`。

## 二、地图管线改动（未提交，本次 session 累积）

### 1. 多格资产 M×N 占格支持

**问题**：地图 elem 不再只占 1 格，需支持 M×N 占格配置。

**改动**：

- **`qqtang_map_editor.py`**
  - `SurfaceInstance` 新增 `footprint_w/footprint_h` 字段，放置时从 AssetMeta 冻结写入，不再依赖运行时推断
  - `_paint_cell` surface 分支：创建实例时写入 footprint
  - `to_config()`：用 `inst.footprint_w/h` 替代 `meta.footprint_w/h`
  - `_surface_instance_at_cell()` / `_surface_rect_overlaps()`：用实例自身 footprint 做碰撞
  - `render_to_image()`：surface 排序和锚点用实例 footprint
  - `sync_official_map_csv()`：CSV 写出新增 `footprint_w/footprint_h` 列
  - `load_official_map_model()`：读 CSV 优先取存储值，列缺失回退 AssetMeta（向后兼容）
  - `append_csv_rows()`：自动检测新列加入 fieldnames，修复保存报错

- **`map_surface_instances.csv`**：新增 `footprint_w,footprint_h` 两列

### 2. 地面层多格渲染修复

**问题**：M×N 地面资产被渲染为 M×N 个 40×40 tile 的复制粘贴。

**改动**：

- **`qqtang_map_editor.py` `render_to_image()`**
  - 改为按 `floor_instances` 迭代渲染
  - 多格资产（`meta.footprint_w>1 or meta.footprint_h>1`）：原图整张拉伸到 M*40×N*40
  - 普通 40×40 资产：逐格平铺 `floor_image()`
  - 未被任何实例覆盖的格子显示棋盘格

### 3. 多格资产拖拽摆放交互

**问题**：多格资产只能点击即放，需要拖拽-松手摆放 + 预览。

**改动**：

- **`qqtang_map_editor.py`**
  - 新增 `_drag_placing` 状态 + `_asset_is_multi_cell()` 判断
  - 1×1 资产：保持原有点击即放行为
  - M×N 资产：左键进入拖拽模式 → 绿色/红色预览跟随 → 松手放置
  - `on_map_left_drag` 首次进入地图时自动激活拖拽模式，支持从左侧面板拖入
  - 修复 `_clear_footprint_overlay` 误重置 `_preview_cell` 导致预览不显示
  - asset canvas + 根窗口绑定 `<ButtonRelease-1>`，松手事件全局生效

### 4. surface 锚点修复

**问题**：1×9 的 tall 资产（bottom_center 锚点）预览和实际渲染错位。
预览以顶部为起点向下，实际以底部为起点向上。

**改动**：

- **`qqtang_map_editor.py` `render_to_image()` surface 分支**
  - `dy` 计算：`CELL_SIZE` → `inst.footprint_h * CELL_SIZE`
  - 1×1 资产等价（`1*40 == 40`），不影响现有行为

### 5. 层级配置文件

**问题**：`classify_asset()` 硬编码 40×40→floor、其他→surface，无法覆盖例外。

**改动**：

- 新建 **`content_source/csv/maps/map_elem_layer_config.csv`**
  - 全量 996 行，按 40×40 规则生成初版（259 floor + 737 surface）
  - `match/elem1_stand` 手动设为 floor
- **`qqtang_map_editor.py`**
  - 新增 `OFFICIAL_LAYER_CONFIG_CSV` 常量 + `load_layer_config()` 函数
  - `scan_assets()`：`classify_asset()` 后查 `layer_config` 覆盖 `layer_hint`，再调 `infer_logic_type()`

### 6. 编辑器中右键编辑占格

**问题**：`classify_asset()` 自动推断可能出错，需要手动修正入口。

**改动**：

- **`qqtang_map_editor.py`**
  - 资产列表右键 → "编辑占格" → 弹出 Spinbox 对话框
  - 保存到 `map_elem_footprint_overrides.csv`，即时刷新 store 和视图
  - 状态栏显示低置信度（<90%）资产的置信度百分比

### 7. 出生点数量 = 人数上限

**问题**：`map_resource.max_player_count` 取自 default variant 而非 spawn count。

**改动**：

- **`generate_maps.gd:172`**：`max_player_count = spawn_points.size()`
- **`qqtang_map_editor.py` `sync_official_map_csv()`**：
  - 硬编码 1v1/2v2/4v4 阈值 → 读取 `match_formats.csv` 遍历
  - 按 `spawn_count >= expected_total_player_count` 决定启用哪些 format
  - 新增 `_load_match_format_player_counts()` 函数
- **`map_match_variants.csv`**：desert01 按新规则重新生成变体行

### 8. 地面 expand 字段

**问题**：管线的 alpha 外扩不再需要，改为可选配置。

**改动**：

- **`map_floor_tiles.csv`**：新增 `expand` 列，全部填 `0`
- **`generate_maps.gd`**：`expand == 1` 才走 `_build_expanded_floor_texture`
- 删除 `content/maps/generated/floor_tiles/` 下 4 个外扩生成文件

### 9. 纯装饰豁免地面校验

**问题**：管线要求每格必须有地面，但纯装饰块不应强制要求下面有地板。

**改动**：

- **`generate_maps.gd`**
  - surface entry 新增 `logic_type` 字段（取自 visual_meta）
  - surface 构建提前到 floor coverage check 之前
  - `_floor_entries_cover_map` 增加 `decoration_cells` 参数
  - `logic_type == "decoration"` 覆盖的格子豁免地面校验
- **`map_elem_visual_meta.csv`**：`match/elem1_stand` 的 `visual_layer` + `logic_type` 改为 floor

## 三、文件清单

### 修改的文件

| 文件 | 主要变更 |
|---|---|
| `tools/qqtang_map_pipeline/qqtang_map_editor.py` | 多格渲染/拖拽/锚点/层级配置/占格编辑/变体生成 |
| `tools/content_pipeline/generators/generate_maps.gd` | max_player_count/spawn、expand 字段、装饰豁免 |
| `content_source/csv/maps/map_floor_tiles.csv` | +expand 列，map_match01 数据 |
| `content_source/csv/maps/map_elem_visual_meta.csv` | match/elem1: visual_layer→floor, logic_type→floor |
| `content_source/csv/maps/map_surface_instances.csv` | +footprint_w/h 列，map_match01 数据 |
| `content_source/csv/maps/map_match_variants.csv` | desert01 按新 spawn 规则重新生成 |
| `content_source/csv/maps/maps.csv` | map_match01 条目 |
| `content/maps/resources/*.tres` | 管线重新生成 |

### 新增的文件

| 文件 | 用途 |
|---|---|
| `content_source/csv/maps/map_elem_layer_config.csv` | 层级配置（996行，40×40→floor，其他→surface） |
| `content/maps/previews/map_match01.preview.png` | match01 预览图 |
| `content/maps/resources/map_match01.tres` | match01 地图资源 |
| `content/maps/resources/map_desert01.tres` | desert01 地图资源 |

### 删除的文件

| 文件 | 原因 |
|---|---|
| `content/maps/generated/floor_tiles/box_elem1_stand.png` + .import | expand=0，不再生成外扩图 |
| `content/maps/generated/floor_tiles/desert_elem12_stand.png` + .import | 同上 |
