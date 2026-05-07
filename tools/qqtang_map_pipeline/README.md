# QQTang mapElem 资产分析管线

本工具扫描 `external/assets/maps/elements` 下的正式 mapElem 资源, 按 Phase39 规则自动推断 `footprint`, `anchor`, `sort_mode`, `confidence`, 输出给正式地图表使用的视觉元数据和地图元素表。

```powershell
python tools/qqtang_map_pipeline/analyze_map_elems.py
```

输出:

- `content_source/csv/maps/map_elem_visual_meta.csv`
- `content_source/csv/map_elements/map_elements.csv`
- `tools/qqtang_map_pipeline/generated/map_elem_visual_meta.json`

低置信度资源需要人工复核, 不应直接依赖图片尺寸决定玩法碰撞。

地图编辑器:

```powershell
python tools/qqtang_map_pipeline/qqtang_map_editor.py
```

默认读取仓库内 `external/assets/maps/elements`. 点击一键导出后会生成 `.qqtang_map.json`, `.preview.png`, 并同步更新正式地图 CSV:

- `content_source/csv/maps/maps.csv`
- `content_source/csv/maps/map_match_variants.csv`
- `content_source/csv/maps/map_floor_tiles.csv`
- `content_source/csv/maps/map_surface_instances.csv`
- `content/maps/previews/<map_id>.preview.png`

导出后运行正式内容管线生成 `content/maps/resources/<map_id>.tres`.
