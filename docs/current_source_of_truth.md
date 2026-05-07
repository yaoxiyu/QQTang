# 当前文档入口

设计文档已迁移到仓库外部归档。本仓库 `docs/` 只保留当前仍需随代码维护的平台 API 与内部协议契约。

## 保留范围

- `docs/platform_auth/`：账号、资料、票据与错误码契约。
- `docs/platform_game/`：匹配、职业、结算、Battle 分配与内部 Game Service 契约。
- `docs/platform_room/`：Room Service runtime 契约。
- `docs/technical_debt.md`：工程技术债台账。

## 解释权

1. 协议契约文档描述服务边界和调用语义。
2. 设计、阶段、验收和运行时说明不在仓库内维护；工程技术债允许在仓库内维护。
3. 如果文档与代码冲突，以仓库代码和已提交测试为准。

## Phase38 资产流水线例外

Phase38 新增的 `docs/asset_specs/` 是随工具代码维护的资产规格契约，用于约束 `content_source/asset_intake/` 和 `tools/asset_pipeline/`。这些规格不替代运行期代码真相；若规格、CSV、generator 或测试冲突，以当前代码和已提交测试为准。

## Battle 地图表现真相

当前 Battle 地图运行期表现以 `presentation/battle/scene/map_view_controller.gd` 和已提交测试为准。地图语义仍归仿真和内容数据所有，表现层只消费 `MapRuntimeLayout.surface_entries`、主题材质和 grid cache。

- `BattleMapViewController` 负责地图层级重建、cell 到 view 的索引、grid diff 同步和销毁事件路由。
- surface 地图元素的缩放、锚点、z 排序、die 表现生命周期由 `MapSurfaceElementView` 负责，controller 不应直接写具体贴图适配规则。
- 可破坏 surface 元素被销毁时应播放 die 表现并延迟释放，不允许再引入透明淡出或缩放淡出作为默认销毁效果。
- 48 像素格子是地图表现基准。单格 surface 方块默认按格子宽度归一化，并允许 1px 边缘覆盖，避免原始贴图尺寸或 camera 非整数缩放在相邻方块之间露出缝隙。
