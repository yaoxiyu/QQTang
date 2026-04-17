# Current Source Of Truth (Index)

> 适用范围：当前项目源码现状  
> 定位：本文件是“总索引 + 总规则”文档，不承载全部细节解释权。  
> 细节解释权已拆分到 `docs/architecture/*.md`。

---

## 1. 总规则

1. 解释权分层：总规则在本文件，专题细节在架构分文档。  
2. 冲突处理：若分文档之间冲突，以“更贴近当前代码且范围更窄”的文档为准；若仍冲突，以仓库当前实现与契约测试为准。  
3. 历史文档属性：`docs/archive/*` 默认为历史材料，不作为当前实现真相。  
4. 禁止单点膨胀：不得把新的全局规范再塞回本文件形成巨型总文档。  

---

## 2. 架构索引

- 运行时拓扑：[`docs/architecture/runtime_topology.md`](./architecture/runtime_topology.md)
- 前台流程：[`docs/architecture/front_flow.md`](./architecture/front_flow.md)
- 网络控制面：[`docs/architecture/network_control_plane.md`](./architecture/network_control_plane.md)
- 内容管线：[`docs/architecture/content_pipeline.md`](./architecture/content_pipeline.md)
- 测试策略：[`docs/architecture/testing_strategy.md`](./architecture/testing_strategy.md)
- 架构债务台账：[`docs/architecture_debt_register.md`](./architecture_debt_register.md)

---

## 3. 目录解释权边界

1. `docs/current_source_of_truth.md`  
只维护解释权规则、文档边界、入口索引。

2. `docs/architecture/*.md`  
维护对应专题的正式语义与约束，作为工程实现对齐依据。

3. `docs/archive/*.md`  
仅保留历史决策与阶段记录，不作为当前实施规范。

---

## 4. 维护要求

1. 变更任何核心结构时，必须同步更新对应专题文档。  
2. 若新增架构域，先新增 `docs/architecture/<domain>.md`，再在本索引登记。  
3. 文档内容必须可映射到真实代码路径与测试契约。  
