# QQTang 外部资产包与可复现派生资产设计

## 1. 背景

当前 QQTang 项目已经接入大量来自原始 QQTang 资源包的角色、特效和 UI 资源。随着分层角色烘焙、8 队伍色变体、运行时动画集生成等能力增加，源码仓库中出现了三类不同性质的文件：

- 源资产：从外部资源包复制或提取而来，例如 `res/object/**`。
- 派生资产：由脚本根据源资产和配置生成，例如 `assets/animation/characters/qqt_layered/**`。
- 运行时缓存/生成资源：Godot 或内容管线生成的运行时资源，例如 `content/character_animation_sets/generated/sprite_frames/**`。

这些文件如果全部进入源码仓库，会带来明显问题：

- Git 提交体积过大，当前 `content/character_animation_sets/generated/sprite_frames` 约 697 MB。
- 代码评审被大量二进制或生成资源淹没。
- CI、检出、分支切换和冲突处理成本上升。
- 资源更新缺少版本、hash 和来源约束，长期不可追踪。
- 运行时加载策略和资源生成策略耦合，难以优化进房间和进战斗卡顿。

因此需要把资产体系从“源码目录里堆文件”升级为“源码仓库保存规则和清单，外部资产包保存大体积资源，运行时按 manifest 加载”的工程化架构。

## 2. 目标

### 2.1 核心目标

1. 源码仓库只保存可审查、可复现、体积可控的内容。
2. 大体积源资产和派生资产移动到外部资产包，可放云盘、制品库或本地缓存。
3. `qqt_layered`、`qqt_layered_team_variants` 等派生资产可以由固定输入在任意机器上重新生成。
4. 运行时不依赖巨大的 `SpriteFrames .tres`，优先使用 runtime strip manifest + PNG strip。
5. 资源加载支持异步、按需、可缓存、可释放。
6. 所有外部资产都有版本、hash、生成输入和校验入口。

### 2.2 非目标

本设计不要求立即实现在线下载器，也不要求替代云盘。第一阶段只要求：

- 本地可配置资产包根目录。
- 脚本可校验资产包完整性。
- 运行时可从外部目录或项目内 fallback 读取资源。
- 大体积生成资源不再进入 Git。

## 3. 术语定义

| 术语 | 定义 | 是否进源码仓库 |
| --- | --- | --- |
| 源资产 | 外部提取的原始素材，如 `res/object/cloth/*.png` | 否 |
| 源资产索引 | 扫描源资产得到的路径、尺寸、动作、方向、hash 清单 | 是 |
| 装配配置 | 角色由哪些部件组成，如 `qqt_character_assemblies.csv` | 是 |
| 层级规则 | 部件合成顺序、方向特例、`_m` 层级规则 | 是 |
| 派生资产 | 脚本烘焙出的 PNG strip，如 `qqt_layered` | 默认否 |
| 运行时 strip manifest | 记录动画集对应 PNG strip 的小型 JSON | 是 |
| 资产包 manifest | 记录外部资产包版本、文件、hash 和生成信息 | 是或随包 |
| 运行时缓存 | 运行时加载后生成的 Texture/SpriteFrames/region 数据 | 否 |

## 4. 资产分类与提交边界

### 4.1 源码仓库保留

源码仓库应保留以下内容：

```text
content_source/csv/**
content_source/qqt_object_manifest/**
content/character_animation_sets/data/runtime_strips/**
scripts/content/**
scripts/assets/**
tools/content_pipeline/**
content/**/defs/**
content/**/catalog/**
content/**/runtime/**
docs/**
tests/**
```

这些文件的共同特点是：

- 体积小。
- 可文本审查。
- 描述规则、索引、配置或代码。
- 可以用于重新生成派生资产。

### 4.2 外部资产包保存

外部资产包保存以下内容：

```text
qqt-assets/
  source/
    res/object/**
  derived/
    assets/animation/characters/qqt_layered/**
    assets/animation/characters/qqt_layered_team_variants/**
    assets/animation/overlays/team_color/**
    assets/animation/vfx/**
  manifests/
    asset_pack_manifest.json
    qqt_layered_bake_manifest.json
```

其中：

- `source/res/object/**` 是源资产。
- `derived/**` 是派生资产。
- `manifests/**` 是资产包自身的完整性和生成证明。

### 4.3 不应提交的目录

以下目录原则上不应进入源码仓库：

```text
res/**
assets/animation/characters/qqt_layered/**
assets/animation/characters/qqt_layered_team_variants/**
assets/animation/overlays/**
assets/animation/vfx/**
content/character_animation_sets/generated/sprite_frames/**
```

特别是 `content/character_animation_sets/generated/sprite_frames/**`，当前约 697 MB，必须从长期方案中移除。

## 5. 总体架构

```text
                ┌──────────────────────┐
                │ 外部源资产 res/object │
                └──────────┬───────────┘
                           │ scan
                           ▼
┌─────────────────────────────────────────────────┐
│ 源码仓库                                         │
│                                                 │
│ parts.csv                                       │
│ qqt_character_assemblies.csv                    │
│ qqt_character_layer_rules.csv                   │
│ team_palettes.csv                               │
│ bake_qqt_layered_characters.ps1                 │
│ sync_qqt_animation_set_rows.ps1                 │
└──────────────────┬──────────────────────────────┘
                   │ bake
                   ▼
┌─────────────────────────────────────────────────┐
│ 外部派生资产包                                   │
│                                                 │
│ qqt_layered PNG strips                          │
│ qqt_layered_team_variants PNG strips            │
│ overlays PNG strips                             │
│ asset_pack_manifest.json                        │
│ qqt_layered_bake_manifest.json                  │
└──────────────────┬──────────────────────────────┘
                   │ resolve + validate
                   ▼
┌─────────────────────────────────────────────────┐
│ 运行时                                           │
│                                                 │
│ AssetPathResolver                               │
│ CharacterAnimationStripLoader                   │
│ CharacterAnimationCache                         │
│ Room/Battle Async Loading                       │
└─────────────────────────────────────────────────┘
```

## 6. 可复现生成模型

`qqt_layered` 和 `qqt_layered_team_variants` 必须被定义为派生资产。派生资产不能依赖人工修改，也不能依赖本机绝对路径。

### 6.1 生成输入

生成结果只允许依赖以下输入：

```text
source/res/object/**
content_source/qqt_object_manifest/parts.csv
content_source/csv/characters/qqt_character_assemblies.csv
content_source/csv/characters/qqt_character_layer_rules.csv
content_source/csv/team_colors/team_palettes.csv
scripts/content/bake_qqt_layered_characters.ps1
```

如果以上输入完全一致，则生成出的像素结果必须一致。

### 6.2 输出

烘焙输出：

```text
derived/assets/animation/characters/qqt_layered/{character_id}/{action}_{direction}.png
derived/assets/animation/characters/qqt_layered_team_variants/{character_id}/team_{team_id}/{action}_{direction}.png
derived/assets/animation/overlays/team_color/leg1/team_{team_id}/{action}_{direction}.png
```

### 6.3 一致性级别

工程上建议区分两种 hash：

| hash 类型 | 用途 |
| --- | --- |
| 文件 hash | 快速校验资产包未被篡改 |
| 像素 hash | 校验视觉内容一致，避免 PNG 压缩参数差异误判 |

PNG 编码器在不同环境可能产生不同压缩字节，因此派生资产的强一致性应优先使用像素 hash。文件 hash 仍然有价值，但不应作为跨平台复现的唯一依据。

### 6.4 bake manifest

每次烘焙输出必须生成：

```text
manifests/qqt_layered_bake_manifest.json
```

建议结构：

```json
{
  "schema_version": 1,
  "bake_id": "qqt_layered_bake",
  "bake_version": "2",
  "created_at_utc": "2026-04-30T00:00:00Z",
  "toolchain": {
    "os": "windows",
    "powershell": "7.x",
    "image_backend": "System.Drawing"
  },
  "inputs": {
    "parts_csv_sha256": "...",
    "assemblies_csv_sha256": "...",
    "layer_rules_csv_sha256": "...",
    "team_palettes_csv_sha256": "...",
    "bake_script_sha256": "...",
    "source_object_manifest_sha256": "..."
  },
  "outputs": {
    "qqt_layered_file_count": 970,
    "team_variant_file_count": 2464,
    "overlay_file_count": 64,
    "pixel_hash": "..."
  }
}
```

## 7. 外部资产包结构

建议资产包根目录如下：

```text
external/\n  assets/
    asset_pack.json
    source/
      res/object/
        body/
        cloth/
        hair/
        ...
    derived/
      assets/animation/characters/qqt_layered/
      assets/animation/characters/qqt_layered_team_variants/
      assets/animation/overlays/team_color/
      assets/animation/vfx/
    manifests/
      asset_pack_manifest.json
      qqt_layered_bake_manifest.json
```

`asset_pack.json` 是资产包入口：

```json
{
  "schema_version": 1,
  "asset_pack_id": "qqt-assets",
  "version": "2026.04.30",
  "layout_version": 1,
  "source_root": "source",
  "derived_root": "derived",
  "manifests": {
    "file_manifest": "manifests/asset_pack_manifest.json",
    "qqt_layered_bake": "manifests/qqt_layered_bake_manifest.json"
  }
}
```

`asset_pack_manifest.json` 记录文件级完整性：

```json
{
  "schema_version": 1,
  "asset_pack_id": "qqt-assets",
  "version": "2026.04.30",
  "files": [
    {
      "path": "derived/assets/animation/characters/qqt_layered/10101/idle_down.png",
      "size": 12345,
      "sha256": "...",
      "pixel_sha256": "..."
    }
  ]
}
```

## 8. 本地资产根配置

源码仓库提交模板：

```text
config/local_asset_roots.example.json
```

本地实际文件 ignored：

```text
config/local_asset_roots.json
```

示例：

```json
{
  "asset_roots": [
    {
      "asset_pack_id": "qqt-assets",
      "root": "external/assets",
      "enabled": true
    }
  ],
  "fallback_to_project_assets": true
}
```

运行时和脚本都不应直接写死 `external`，必须通过统一 resolver 获取。

## 9. AssetPathResolver 设计

### 9.1 职责

`AssetPathResolver` 是所有外部资产路径访问的唯一入口。

职责：

- 读取本地资产根配置。
- 读取资产包 `asset_pack.json`。
- 将逻辑路径解析为实际文件路径。
- 支持项目内 fallback。
- 输出缺失资产的明确错误。
- 提供校验入口。

### 9.2 逻辑路径

系统内部统一使用逻辑路径，不直接传本机绝对路径：

```text
asset://qqt-assets/derived/assets/animation/characters/qqt_layered/10101/idle_down.png
asset://qqt-assets/source/res/object/cloth/cloth10101_stand_3.png
res://content/character_animation_sets/data/runtime_strips/character_animation_strip_sets.json
```

`res://` 仍用于源码仓库内小型配置和脚本资源。

### 9.3 解析顺序

解析一个 asset uri 的顺序：

1. 本地配置启用的外部资产包。
2. 环境变量指定的资产根，例如 `QQT_ASSET_ROOT`。
3. 项目目录 fallback，例如 `res://assets/...`。
4. 返回缺失错误。

### 9.4 错误信息

缺失资产必须报告：

```text
asset_pack_id
logical_path
expected_version
searched_roots
suggested_command
```

示例：

```text
Missing asset:
  pack: qqt-assets
  path: derived/assets/animation/characters/qqt_layered/10101/idle_down.png
  expected version: 2026.04.30
  searched:
    external/assets
    project fallback
  fix:
    scripts/assets/validate_asset_pack.ps1 -AssetPackRoot external/assets
```

## 10. Runtime Strip Manifest + PNG Strip

### 10.1 定义

PNG strip 是横向拼接的动画帧图：

```text
run_down.png = [frame0][frame1][frame2][frame3]
```

runtime strip manifest 是描述动画集如何从 PNG strip 播放的 JSON：

```json
{
  "animation_set_id": "char_anim_qqt_10101_team_01",
  "frame_width": 100,
  "frame_height": 100,
  "run_fps": 8,
  "strips": {
    "run_down": "asset://qqt-assets/derived/assets/animation/characters/qqt_layered_team_variants/10101/team_01/run_down.png",
    "idle_down": "asset://qqt-assets/derived/assets/animation/characters/qqt_layered_team_variants/10101/team_01/idle_down.png"
  }
}
```

### 10.2 为什么替代 SpriteFrames `.tres`

当前 `content/character_animation_sets/generated/sprite_frames` 体积约 697 MB。它的主要问题是：

- 每个角色动画集被 Godot 资源格式膨胀。
- Git diff 不可读。
- 变更会导致大文件频繁更新。
- 加载时反序列化成本高。

runtime strip manifest + PNG strip 的优势：

- manifest 很小，可进 Git。
- PNG strip 可外置。
- 可按需加载单个角色、单个队伍色。
- 可在 loading 阶段异步预热。
- 可按缓存生命周期释放。

### 10.3 当前短期实现

当前项目已有：

```text
content/character_animation_sets/data/runtime_strips/character_animation_strip_sets.json
content/character_animation_sets/runtime/character_animation_strip_loader.gd
```

短期可以继续让 `CharacterAnimationStripLoader` 读取 strip，然后构造 `SpriteFrames` 供现有 `CharacterSpriteBodyView` 使用。这是兼容改造，风险较低。

### 10.4 长期优化

长期建议从“运行时切图生成 `ImageTexture`/`SpriteFrames`”升级为“Texture2D + region_rect 播放”：

- 每个动作加载一张 Texture2D。
- 每帧只修改 `Sprite2D.region_rect`。
- 不为每一帧创建独立 ImageTexture。
- 降低对象数量和内存碎片。

长期播放模型：

```text
CharacterAnimationClip
  texture: Texture2D
  frame_width: int
  frame_height: int
  frame_count: int
  fps: float
  loop: bool
```

## 11. 运行时加载策略

### 11.1 房间场景

房间内不应加载所有角色资源。

策略：

- 进入房间时只加载玩家当前选择角色的 `wait_down` 或 `idle_down`。
- 角色选择面板只加载当前选中角色预览。
- 翻页时可预加载当前页可见角色，但必须分帧或异步。
- 未选中角色按钮显示文本、编号、小型占位图，不立即加载完整动画。

### 11.2 战斗 loading

战斗 loading 阶段必须根据 `BattleStartConfig` 精确预加载：

- 本局地图。
- 本局玩家角色。
- 本局玩家队伍色动画。
- 本局泡泡样式。
- 本局状态特效。

禁止在战斗正式开始后同步加载大资源。

### 11.3 战斗中

战斗中只允许使用已加载资源。

如果资源缺失：

1. 使用本角色基础色动画 fallback。
2. 使用 `12301` 问号 fallback。
3. 上报明确错误，但不阻塞模拟逻辑。

## 12. 缓存设计

### 12.1 缓存层级

| 缓存层级 | 生命周期 | 内容 |
| --- | --- | --- |
| 永驻缓存 | 应用进程 | 默认问号、UI 小图标、小型 manifest |
| 房间缓存 | 进入房间到离开房间 | 当前选择角色、当前页预览 |
| 战斗缓存 | battle loading 到结算结束 | 本局地图、角色、泡泡、特效 |
| 临时缓存 | 单次工具/预览 | 编辑器预览、测试加载 |

### 12.2 缓存 key

角色动画缓存 key：

```text
animation_set_id + asset_pack_version + content_hash
```

示例：

```text
char_anim_qqt_10101_team_03|qqt-assets@2026.04.30|qqt_10101_team_03_layered_bake_v2
```

### 12.3 释放策略

- 离开房间时释放房间缓存。
- 战斗结束并返回房间后释放战斗缓存。
- 永驻缓存只保留极小资源。
- 大 Texture 不应进入全局永久缓存。

## 13. 内容管线设计

### 13.1 脚本分层

建议新增：

```text
scripts/assets/
  resolve_asset_roots.ps1
  validate_asset_pack.ps1
  build_asset_pack_manifest.ps1
  publish_asset_pack.ps1
  restore_asset_pack.ps1
```

现有内容脚本继续保留：

```text
scripts/content/
  scan_qqt_object_resources.ps1
  generate_qqt_character_assemblies.ps1
  bake_qqt_layered_characters.ps1
  sync_qqt_animation_set_rows.ps1
  run_content_pipeline.ps1
  validate_content_pipeline.ps1
```

### 13.2 推荐命令流

完整重建：

```powershell
scripts/assets/restore_asset_pack.ps1 -AssetPackRoot external\assets
scripts/assets/validate_asset_pack.ps1 -AssetPackRoot external\assets
scripts/content/scan_qqt_object_resources.ps1 -ObjectRoot external\assets\source\res\object
scripts/content/bake_qqt_layered_characters.ps1 -OutputRoot external\assets\derived\assets\animation\characters\qqt_layered
scripts/content/sync_qqt_animation_set_rows.ps1
scripts/content/run_content_pipeline.ps1
scripts/content/validate_content_pipeline.ps1
```

注意：涉及 GDScript 的管线命令仍必须先跑项目规定的 GDScript 语法预检。

### 13.3 外部输出安全

当前 `bake_qqt_layered_characters.ps1` 有清理输出目录逻辑。支持外部目录后，必须调整安全规则：

- 允许清理 `ProjectPath/assets/animation/**`。
- 允许清理显式传入且通过 `-AllowExternalOutput` 确认的资产包目录。
- 禁止清理未确认的任意绝对路径。

建议参数：

```powershell
-AssetPackRoot external\assets
-AllowExternalOutput
```

没有 `-AllowExternalOutput` 时，脚本不得递归删除项目外目录。

## 14. Git 与忽略规则

`.gitignore` 应包含：

```gitignore
/res/
/assets/animation/characters/qqt_layered/
/assets/animation/characters/qqt_layered_team_variants/
/assets/animation/overlays/
/assets/animation/vfx/
/content/character_animation_sets/generated/sprite_frames/
/config/local_asset_roots.json
__pycache__/
*.pyc
```

同时保留：

```text
content/character_animation_sets/data/runtime_strips/character_animation_strip_sets.json
content_source/qqt_object_manifest/**
content_source/csv/**
```

## 15. CI 与验证

### 15.1 无资产包 CI

无资产包 CI 只跑：

- GDScript 语法预检。
- 纯配置/纯逻辑测试。
- CSV schema 校验。
- manifest schema 校验。

不得要求下载完整资产包。

### 15.2 有资产包 CI

有资产包 CI 可跑：

- 资产包 hash 校验。
- 派生资产复现校验。
- 内容管线。
- runtime strip loader 测试。
- 战斗资源加载集成测试。

### 15.3 校验级别

| 级别 | 内容 | 目的 |
| --- | --- | --- |
| schema | JSON/CSV 字段完整 | 防止格式错误 |
| path | manifest 指向文件存在 | 防止缺资源 |
| hash | 文件 sha256 匹配 | 防止误替换 |
| pixel hash | PNG 解码后像素一致 | 防止视觉变更 |
| runtime load | Godot 能加载并播放 | 防止运行时崩溃 |

## 16. 迁移计划

### 阶段 1：提交边界收敛

- 将 `content/character_animation_sets/generated/sprite_frames/**` 加入忽略。
- 确认所有角色动画优先走 `CharacterAnimationStripLoader`。
- 保留 runtime strip manifest。
- 清理 Python `__pycache__` 等临时文件。

### 阶段 2：资产包根配置

- 新增 `config/local_asset_roots.example.json`。
- 新增 `AssetPathResolver`。
- 运行时 strip manifest 支持 `asset://`。
- 本地支持项目内 fallback。

### 阶段 3：派生资产外置

- 修改烘焙脚本支持 `-AssetPackRoot`。
- 将 `qqt_layered`、`qqt_layered_team_variants` 输出到外部资产包。
- 生成 `qqt_layered_bake_manifest.json`。
- 生成 `asset_pack_manifest.json`。

### 阶段 4：运行时缓存优化

- 房间缓存和战斗缓存分层。
- 进房间只加载默认或上次选择角色。
- 进战斗 loading 精确预加载本局资源。
- 避免战斗中同步硬加载。

### 阶段 5：region 播放优化

- 设计 `CharacterAnimationClip`。
- 从 `SpriteFrames` 兼容层迁移到 `Texture2D + region_rect`。
- 减少每帧独立 `ImageTexture` 对象。
- 降低内存和加载抖动。

## 17. 风险与对策

| 风险 | 影响 | 对策 |
| --- | --- | --- |
| 资产包缺失 | 本地无法运行角色资源 | 明确错误、fallback、校验脚本 |
| 云盘资源版本错 | 视觉或 hash 不一致 | asset pack version + hash |
| 脚本输出不可复现 | 难以定位资源差异 | bake manifest + pixel hash |
| 外部路径写死 | 换机器失效 | 统一 AssetPathResolver |
| 战斗中懒加载 | 卡顿或帧跳 | battle loading 预加载 |
| 大 Texture 永驻 | 内存上涨 | 缓存生命周期分层 |
| `.tres` 继续生成 | 仓库持续膨胀 | 忽略 generated sprite_frames，改用 runtime strip |

## 18. 推荐决策

推荐采用以下决策：

1. `res/object` 作为外部源资产，不进源码仓库。
2. `qqt_layered` 和 `qqt_layered_team_variants` 作为派生资产，不进源码仓库。
3. `content/character_animation_sets/generated/sprite_frames` 废弃为长期运行依赖，不进源码仓库。
4. `runtime strip manifest` 作为源码仓库内的运行时索引保留。
5. 新增 `AssetPathResolver`，统一处理项目内和外部资产包路径。
6. 新增资产包 manifest、bake manifest 和校验脚本。
7. 运行时短期继续兼容 `SpriteFrames`，长期迁移到 `Texture2D + region_rect`。

## 19. 最终形态

最终工程应满足：

- 新机器拉源码后，代码和配置体积小。
- 开发者从云盘恢复资产包到任意本地目录。
- 配置 `local_asset_roots.json`。
- 运行校验脚本确认资产包版本和 hash。
- 项目运行时按需加载外部 PNG strip。
- 大体积派生资产可删除后重新生成。
- Git 提交只包含代码、配置、manifest 和小型测试资源。

这套方案将资产系统从“文件堆放”升级为“可复现、可校验、可外置、可按需加载”的工程化内容系统。
