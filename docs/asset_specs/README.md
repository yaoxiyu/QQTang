# Phase38 资产规格

本目录定义 AI、外包美术、内部美术提交资产时必须遵守的工程规格。规格用于 `tools/asset_pipeline/` 的 preflight、normalize、CSV patch 和报告生成。

当前注册规格：

| spec_id | asset_type | 用途 |
|---|---|---|
| `character_sprite_100_v1` | `character` | 100x100 角色 Sprite strip |
| `bubble_animation_64_v1` | `bubble` | 64x64 泡泡 idle 动画 |
| `map_tile_48_v1` | `map_tile` | 48 像素格子与 Tile 语义 |
| `map_theme_48_v1` | `map_theme` | 48 像素地图主题资源 |
| `vfx_jelly_trap_128_v1` | `vfx_jelly_trap` | 128x128 被困果冻 VFX |
| `team_color_palette_v1` | `team_color_palette` | 8 队伍色调色板 |

运行期只消费 `content/` 中的 catalog/loader 输出。`asset_intake` 与源图片只作为生产输入。

## 预检原则

- 先验证 manifest 和源文件，再写 CSV。
- `-DryRun` 不改 CSV。
- `-WriteCsv` 必须满足商业授权和审核状态。
- 队伍色必须由 mask 和 palette 确定性生成，禁止 AI 重画 8 套。
