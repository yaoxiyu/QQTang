# Content Pipeline

## 目的
定义内容解释权结构：运行时内容、内容源、离线生成工具的边界。

## 三层结构
- `res://content/`
  - 运行时正式内容真相（defs/data/catalog/runtime）。
- `res://content_source/`
  - 生产源输入（CSV 等），不作为运行时直接真相。
- `res://tools/content_pipeline/`
  - 离线生成/校验/报告工具，产物写回 `content/*/data`。

## 运行时规则
- 地图、规则、模式、角色、泡泡、皮肤都走数据驱动 catalog。
- 前台/UI/场景脚本不得长期硬编码内容列表。
- 动画集、皮肤、主题等资源应通过内容定义与 loader 装配，不走临时脚本拼接。
- 地图 authoring 真相位于：
  - `content_source/csv/maps/maps.csv`
  - `content_source/csv/maps/map_match_variants.csv`
- 匹配编制 authoring 真相位于：
  - `content_source/csv/match_formats/match_formats.csv`
- `content/maps/resources/*.tres` 是 generated 正式资源，不是人工编辑真相。
- `build/generated/room_manifest/room_manifest.json` 是跨语言消费快照，不是人工编辑真相。
- `MapDef` 属于 battle 兼容层，不是 authoring 真相。

## 目录约定
- `defs/`：定义脚本。
- `data/`：正式资产。
- `catalog/`：索引注册。
- `runtime/`：加载与组装逻辑。
