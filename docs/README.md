# docs

## 目录定位
源码真相、工程规则与阶段归档文档层。

## 子目录职责
- `current_source_of_truth.md` 是当前解释权总索引（只维护总规则与入口，不承载全部细节）。
- `architecture/` 是当前正式架构解释权目录，按专题拆分：
  - `runtime_topology.md`
  - `front_flow.md`
  - `network_control_plane.md`
  - `battle_sync.md`
  - `content_pipeline.md`
  - `testing_strategy.md`
  - `battle_handoff_projection_repair_plan.md`
- `architecture_debt_register.md` 是正式架构债务台账（debt register）。
- `battle_sync_rule_audit.md` 是 Battle 同步规则详细审计材料；当前运行时边界和后续性能债务以 `architecture/battle_sync.md` 为入口。
- `map_theme_material_integration.md` 记录当前地图材质包的格式要求与接入流程。
- `platform_auth/` 与 `platform_game/` 记录当前平台服务 API / 内部协议契约。
- `archive/` 只存放历史基线、阶段报告、已合并专题原文；归档内容不得作为当前实现真相。
- `assets/animation/explosions/normal/` 已作为当前 Current 爆炸分段资源落地路径, 爆炸表现直接由 Battle 表现层消费, 不单独新建文档目录。
- 其它 `baseline / validation / cleanup / phase` 文档默认视为历史材料或阶段记录，除非文件内明确声明自己是当前真相。

## 维护规则
- 文档必须反映当前仓库实际结构。
- 历史文档可以保留，但必须明确历史属性，不能和现行规范混淆。
- 禁止把 `current_source_of_truth.md` 再次演化为巨型总文档；新增细节应进入 `architecture/` 对应专题。
- 新识别的架构债务必须优先登记到 `architecture_debt_register.md`，再进入排期。

## 本地配置与目录卫生
- 所有服务本地配置统一使用 `services/*/.env`，真实密钥仅允许保存在本地，不得提交。
- 模板文件统一使用 `.env.example`：
  - 仓库总模板：`/.env.example`
  - 服务模板：`services/account_service/.env.example`、`services/game_service/.env.example`、`services/ds_manager_service/.env.example`
- 新增环境变量时，必须同步更新对应 `.env.example`，并保持变量名与代码读取名一致。
- 本地运行日志、打包产物与密钥目录（如 `logs/`、`build/`、`dist/`、`secrets/`）属于不可提交内容，依赖 `.gitignore` 统一屏蔽。

