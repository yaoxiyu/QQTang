# QQTang mapElem 资产分析管线

本工具扫描 `external/assets/maps/elements` 下的正式 mapElem 资源, 自动推断 `footprint`, `anchor`, `sort_mode`, `confidence`, 输出给正式地图表使用的视觉元数据。

```powershell
python tools/qqtang_map_pipeline/analyze_map_elems.py
```

输出:

- `content_source/csv/maps/map_elem_visual_meta.csv`
- `tools/qqtang_map_pipeline/generated/map_elem_visual_meta.json`

低置信度资源需要人工复核, 不应直接依赖图片尺寸决定玩法碰撞。
