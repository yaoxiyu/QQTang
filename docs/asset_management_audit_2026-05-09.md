# 资产管理审计（2026-05-09）

## 结论（先回答你的要求是否合理）
- 你的方向合理：`external` 放资产本体，仓库内仅保留配置/manifest/`.tres`/索引，是可扩展且利于版本治理的方案。
- 但不建议“一次性硬切”：
  - 当前 `assets` 下仍有大量 UI/特效资源被直接引用。
  - 直接全量迁移会引发大面积路径失效、导入缓存重建、内容管线与编辑器回归风险。
- 工程化建议：分阶段迁移，先把运行时路径体系统一为 `asset://`，再逐步把实体文件搬到 `external`。

## 当前盘点（四目录）
- `assets`：约 629 文件（包含大量 `.png` 与 `.import`）。
- `content`：约 1611 文件（以 catalog/defs/data 资源定义为主）。
- `content_source`：约 372 文件（CSV 源数据）。
- `external`：约 20242 文件（资产包主仓，二进制资源约 7305）。

## 混乱点（本次识别）
- 路径协议混用：`res://external/assets/...` 与 `asset://...` 并存。
- 内容数据中仍有 `res://external/assets/...` 直链：
  - `content_source/csv/ui/ui_asset_catalog.csv` 多行。
  - `content_source/csv/vfx_animation_sets/vfx_animation_sets.csv`。
- 表现层脚本硬编码 `res://external/assets/...`：
  - `presentation/battle/actors/explosion_actor_view.gd`。

## 本次已开始整理（低风险落地）
1. 将爆炸特效脚本的资源路径切换为 `asset://`，并通过 `AssetPathResolver` 解析。
   - 文件：`presentation/battle/actors/explosion_actor_view.gd`
   - 特点：保留 resolver 的 project fallback，不破坏现有资源仍在 `assets` 的运行。

2. 将果冻 VFX 源 CSV 的 strip 路径切换为 `asset://`。
   - 文件：`content_source/csv/vfx_animation_sets/vfx_animation_sets.csv`

3. 新增资产路径策略审计脚本（用于持续收敛）。
   - 文件：`scripts/assets/audit_asset_path_policy.ps1`
   - 作用：扫描 `res://external/assets/` 引用并输出违规清单（支持临时 allowlist）。

## 风险与瓶颈
- 最大瓶颈是 UI 资源：当前 `ui_asset_catalog.csv` 仍大量直接指向 `res://external/assets/source/res/object/ui/...`。
- 若立即搬迁文件到 `external`，需要同步改：
  - CSV 源路径
  - 生成物 `.tres/.json`
  - 运行时加载器（确保全部走 resolver）
  - 编辑器导入与 CI 验证链路

## 下一步（建议顺序）
1. 先改 `content_source/csv/ui/ui_asset_catalog.csv`：统一到 `asset://qqt-assets/...`。
2. 跑内容管线重生成 UI catalog。
3. 用审计脚本做门禁：新增规则“新增内容禁止 `res://external/assets/`”。
4. 分目录迁移 `assets/ui`、`assets/animation` 到 `external`，每批做回归。

---

## 最新进展（继续批次）

### 已完成的目录收敛（本轮）
1. 下线历史 mapElem 镜像目录（重复维护源）  
   - 删除：`external/assets/source/res/object/mapElem`  
   - 保留：`external/assets/maps/elements`（当前管线与运行时引用路径）

2. 下线无引用 UI 副本目录  
   - 删除：`external/assets/ui`  
   - 保留：`external/assets/source/res/object/ui`（当前场景与内容唯一引用路径）

3. 更新 `external/assets` 目录约定  
   - 文件：`external/assets/README.md`  
   - 补充了 mapElem/UI 的单路径策略，避免后续再次出现双份资产。

### 重复资产结构复查（删除后）
- `animation` vs `derived/assets/animation`：`overlap_count=0`（内容不重叠）
- 结论：这两者不是镜像关系，职责不同，当前不应合并或互删。

### 可执行迁移白名单（下一批）
- 可继续删（满足“无引用 + 重复镜像”）：  
  - `external/assets/source/res/object/mapElem`（已执行）  
  - `external/assets/ui`（已执行）
- 暂不动（运行时/管线强依赖）：  
  - `external/assets/animation`（爆炸段动画直接 `res://` 引用）  
  - `external/assets/maps/elements`（地图管线输入根）  
  - `external/assets/source/res/object/ui`（大量场景与 UI catalog 直接引用）

### 门禁验证结果
1. `tests/scripts/check_gdscript_syntax.ps1`：PASS  
2. `scripts/content/validate_content_pipeline.ps1`：PASS（contracts 10/10）
