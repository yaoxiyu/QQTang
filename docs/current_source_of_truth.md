# 当前文档入口

设计文档已迁移到仓库外部归档。本仓库 `docs/` 只保留当前仍需随代码维护的平台 API 与内部协议契约。

## 保留范围

- `docs/platform_auth/`：账号、资料、票据与错误码契约。
- `docs/platform_game/`：匹配、职业、结算、Battle 分配与内部 Game Service 契约。
- `docs/platform_room/`：Room Service runtime 契约。

## 解释权

1. 协议契约文档描述服务边界和调用语义。
2. 设计、阶段、验收、债务、运行时说明不在仓库内维护。
3. 如果文档与代码冲突，以仓库代码和已提交测试为准。

## Phase38 资产流水线例外

Phase38 新增的 `docs/asset_specs/` 是随工具代码维护的资产规格契约，用于约束 `content_source/asset_intake/` 和 `tools/asset_pipeline/`。这些规格不替代运行期代码真相；若规格、CSV、generator 或测试冲突，以当前代码和已提交测试为准。
