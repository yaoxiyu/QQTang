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

## 目录约定
- `defs/`：定义脚本。
- `data/`：正式资产。
- `catalog/`：索引注册。
- `runtime/`：加载与组装逻辑。
