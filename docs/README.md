# docs

## 目录定位
源码真相、工程规则与阶段归档文档层。

## 子目录职责
- 当前目录下的 `current_source_of_truth.md` 是当前源码结构与职责的唯一真相文档。
- `map_theme_material_integration.md` 记录当前地图材质包的格式要求与接入流程。
- `platform_auth/` 与 `platform_game/` 记录当前平台服务 API / 内部协议契约。
- `archive/` 只存放历史基线、阶段报告、已合并专题原文；归档内容不得作为当前实现真相。
- `assets/animation/explosions/normal/` 已作为当前 Phase9 爆炸分段资源落地路径, 爆炸表现直接由 Battle 表现层消费, 不单独新建文档目录。
- 其它 `baseline / validation / cleanup / phase` 文档默认视为历史材料或阶段记录，除非文件内明确声明自己是当前真相。

## 维护规则
- 文档必须反映当前仓库实际结构。
- 历史文档可以保留，但必须明确历史属性，不能和现行规范混淆。
