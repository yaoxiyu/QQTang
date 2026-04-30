# Phase38 Asset Pipeline

`tools/asset_pipeline/` 负责把 `content_source/asset_intake/` 中的资产包转换为 CSV patch plan。

职责：

- 读取 `manifest.json`。
- 根据 `docs/asset_specs/` 和 `asset_spec_registry.py` 校验规格。
- 调用 `plugins/<asset_type>/` 做资产类型 preflight。
- 生成 dry-run 报告。
- 在 `-WriteCsv` 且授权通过时写入 `content_source/csv/`。

正式 `.tres`、`SpriteFrames`、catalog 仍由 `tools/content_pipeline/` 生成。

示例：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/content/run_asset_pipeline.ps1 -All -DryRun
powershell -ExecutionPolicy Bypass -File scripts/content/run_asset_pipeline.ps1 -All -WriteCsv -GenerateVariants
```

## 插件

插件位于：

```text
tools/asset_pipeline/plugins/<asset_type>/
```

每个插件至少有 `schema.json`，可选 `plugin.py` 实现 preflight、variant、CSV patch。新增资产类型应新增插件，不改主入口分支。
