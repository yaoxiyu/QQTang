# Asset Intake

Phase38 资产包提交入口。每个资产包使用统一结构：

```text
content_source/asset_intake/<asset_type>/<asset_key>/
  manifest.json
  source/
  normalized/
  generated/
  preview/
  reports/
```

`asset_intake` 是生产输入，不是运行期内容真相。运行期只能通过 `content/` 的 catalog/loader 消费内容。

正式写入 CSV 前必须通过：

- manifest 必填字段校验。
- 源文件 preflight。
- 商业授权与审核状态门禁。
- CSV patch dry-run。

## Demo 包

当前包含 Phase38 最小闭环 demo：

- `character/phase38_demo_character`
- `bubble/phase38_demo_bubble`
- `map_tile/phase38_demo_horizontal_pass`

这些包用于验证流水线，不代表最终商业美术质量。
