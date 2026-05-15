# 资源管线操作指南

## 什么时候需要跑管线

在以下目录修改了资源源文件后，需要执行对应管线：

| 修改位置 | 需要执行的管线 |
|----------|-------------|
| `external/assets/source/res/object/` 下的角色部件（body/cloth/hair/face 等） | QQT 分层角色管线 + 主管线 |
| `content_source/asset_intake/` 下的资产包 | 资产管线 + 主管线 |
| `content_source/csv/` 下的数据表 | 主管线 |

## 管线条目

### 1. scan_object_resources

扫描角色部件源文件，生成 `parts.csv` 索引。

```powershell
powershell -ExecutionPolicy Bypass -File scripts/content/scan_object_resources.ps1 -SourceRoot "external/assets/source/res/object"
```

- 输出：`content_source/qqt_object_manifest/parts.csv`
- 触发条件：`external/assets/source/res/object/` 下任何文件有变化

### 2. generate_character_assemblies

从 `parts.csv` 生成角色装配表（角色 ID → 部件 ID 映射）。

```powershell
powershell -ExecutionPolicy Bypass -File scripts/content/generate_character_assemblies.ps1
```

- 输出：`content_source/csv/characters/qqt_character_assemblies.csv`
- 触发条件：新增角色或更改角色部件映射时（仅修改已有角色的动画无需此步）

### 3. bake_layered_characters

将分层源 GIF/PNG 合成运行时 PNG 序列帧条带。

```powershell
powershell -ExecutionPolicy Bypass -File scripts/content/bake_layered_characters.ps1 -AssetPackRoot "external/assets" -AllowExternalOutput
```

- 输出：
  - `external/assets/derived/assets/animation/characters/qqt_layered/<character_id>/`（默认颜色条带）
  - `external/assets/derived/assets/animation/characters/qqt_layered_team_variants/<character_id>/`（8 队颜色变体）
- 动作映射：`stand`→`idle`、`walk`→`run`、`die`→`dead`、`win`→`victory`、`lose`→`defeat`
- 方向规则：`idle`/`run` 输出四方向，其余动作只输出 `down` 方向

### 4. sync_animation_set_rows

将烘焙输出的条带路径同步到动画集 CSV 和运行时 JSON。

```powershell
powershell -ExecutionPolicy Bypass -File scripts/content/sync_animation_set_rows.ps1 -AssetPackRoot "external/assets"
```

- 输出：
  - `content_source/csv/character_animation_sets/character_animation_sets.csv`
  - `content/character_animation_sets/data/runtime_strips/character_animation_strip_sets.json`

### 5. run_content_pipeline

主管线，生成 Godot 运行时资源（`.tres`、目录索引、房间清单等）。

```powershell
powershell -ExecutionPolicy Bypass -File scripts/content/run_content_pipeline.ps1 [-ForceBuild]
```

- `-ForceBuild`：强制全量重建，绕过增量缓存
- 修改 `external/assets/source/` 下的文件时**必须**加 `-ForceBuild`，因为增量缓存不覆盖源目录
- 此命令内部已包含 GDScript 语法预检

### 6. validate_content_pipeline

运行语法检查 + 内容健全性检查 + 契约测试，验证管线输出无误。

```powershell
powershell -ExecutionPolicy Bypass -File scripts/content/validate_content_pipeline.ps1
```

## 常用场景

### 场景 1：修改了部分角色的动画文件

例如修改了 `cloth/cloth11801_die.gif`，按顺序执行：

```powershell
# 1. 扫描源文件，更新哈希
powershell -ExecutionPolicy Bypass -File scripts/content/scan_object_resources.ps1 -SourceRoot "external/assets/source/res/object"

# 2. 烘焙角色动画
powershell -ExecutionPolicy Bypass -File scripts/content/bake_layered_characters.ps1 -AssetPackRoot "external/assets" -AllowExternalOutput

# 3. 同步动画集
powershell -ExecutionPolicy Bypass -File scripts/content/sync_animation_set_rows.ps1 -AssetPackRoot "external/assets"

# 4. 生成运行时资源（必须 ForceBuild）
powershell -ExecutionPolicy Bypass -File scripts/content/run_content_pipeline.ps1 -ForceBuild
```

### 场景 2：只修改了 CSV 数据表

例如修改了角色属性、地图配置等：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/content/run_content_pipeline.ps1
```

### 场景 3：完整重建（从资产包恢复到全管线）

```powershell
powershell -ExecutionPolicy Bypass -File scripts/assets/restore_asset_pack.ps1 -AssetPackRoot external\assets
powershell -ExecutionPolicy Bypass -File scripts/assets/validate_asset_pack.ps1 -AssetPackRoot external\assets
powershell -ExecutionPolicy Bypass -File scripts/content/scan_object_resources.ps1 -SourceRoot "external/assets/source/res/object"
powershell -ExecutionPolicy Bypass -File scripts/content/bake_layered_characters.ps1 -AssetPackRoot "external/assets" -AllowExternalOutput
powershell -ExecutionPolicy Bypass -File scripts/content/sync_animation_set_rows.ps1 -AssetPackRoot "external/assets"
powershell -ExecutionPolicy Bypass -File scripts/content/run_content_pipeline.ps1 -ForceBuild
powershell -ExecutionPolicy Bypass -File scripts/content/validate_content_pipeline.ps1
```

## 数据流

```text
external/assets/source/res/object/        ← 源素材（你修改的文件在这里）
        │
        ▼  scan_object_resources
content_source/qqt_object_manifest/parts.csv
        │
        ▼  bake_layered_characters
external/assets/derived/.../qqt_layered/  ← 烘焙后的 PNG 条带
        │
        ▼  sync_animation_set_rows
content_source/csv/.../animation_sets.csv
content/.../character_animation_strip_sets.json
        │
        ▼  run_content_pipeline
content/.../*.tres                         ← Godot 运行时资源
build/generated/                          ← 目录索引、房间清单
```

## Docker 构建依赖

以下服务 Docker 镜像在构建时会复制 `build/generated/room_manifest/room_manifest.json`：

- `services/room_service/Dockerfile`
- `services/game_service/Dockerfile`

**构建前必须先运行内容管线：**

```powershell
powershell -ExecutionPolicy Bypass -File scripts/content/run_content_pipeline.ps1
powershell -ExecutionPolicy Bypass -File scripts/content/validate_content_pipeline.ps1
```

Docker 构建不得依赖本地手工复制。CI 流程中应确保管线在 Docker build 前执行。

## 注意事项

- 涉及 Godot 的管线命令（`run_content_pipeline`）必须确保 GDScript 语法预检通过后才能执行
- `bake_layered_characters` 需要 `-AllowExternalOutput` 参数才能写入项目外的 `external/assets` 目录
- 修改源素材后必须用 `-ForceBuild`，因为增量缓存不追踪 `external/assets/source/` 目录
