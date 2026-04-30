# 内容与资产流水线架构

## 分层

当前项目内容生产分为两段：

```text
content_source/asset_intake/
  -> tools/asset_pipeline/
  -> content_source/csv/
  -> tools/content_pipeline/
  -> content/
  -> presentation / room / battle
```

`asset_pipeline` 负责接收 AI/美术资产包，做 manifest 校验、源文件 preflight、确定性变体生成、CSV patch 和报告。  
`content_pipeline` 负责读取 CSV，生成 `.tres`、`SpriteFrames`、catalog 可加载资源。

## 运行期边界

- runtime 只能通过 `content/` 的 catalog/loader 消费内容。
- `content_source/asset_intake/` 是生产输入，不能被 battle/room 直接引用。
- `assets/` 是素材层，不能替代内容 id、catalog 或 loader。
- gameplay/simulation 不依赖贴图、SpriteFrames、VFX 或场景节点。

## Phase38 新增资产类型

- `character`：角色 strip、特殊姿态、8 队伍色变体。
- `bubble`：泡泡 idle grid/strip。
- `map_tile`：Tile 表现与方向通行语义。
- `map_theme`：地图主题色与背景尺寸检查。
- `vfx_jelly_trap`：被困果冻 VFX 三段动画。
- `emote`：插件扩展 demo，证明新增资产类型不改主入口。

## 验证入口

```powershell
powershell -ExecutionPolicy Bypass -File scripts/validation/run_phase38_asset_pipeline_validation.ps1 -GodotExe godot_binary/Godot_console.exe
```

该入口会执行 asset pipeline dry-run、Python 测试、GDScript 语法预检、content pipeline 和 Phase38 关键 GUT 合同。
