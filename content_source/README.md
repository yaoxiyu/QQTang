# content_source

## 目录定位
内容生产源文件目录。

## 子目录职责
- `csv/`：策划维护的 CSV 真相源，供内容管线读取并生成 `.tres`。
- `asset_intake/`：Phase38 资产包提交入口，供 AI/美术源文件进入资产流水线。

## 维护规则
- 这里的文件是生产输入，不是运行时直接消费的正式资产。
- 运行时正式资产应生成到 `content/*/data/`。
- `asset_intake/` 不能被 runtime 直接引用；资产包必须先经过 `tools/asset_pipeline/` 生成 CSV patch，再由 `tools/content_pipeline/` 生成正式内容。
