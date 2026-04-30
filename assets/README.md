# assets

## 目录定位
非脚本、非内容定义类的原始静态资源目录。

## 子目录职责
- `ui/`：UI 图标、头像、界面贴图等原始位图资源。
- `animation/`：角色、泡泡、VFX 等动画源图或经资产流水线生成的可引用位图。
- `generated/`：Phase38 资产流水线生成的确定性变体，例如角色队伍色贴图。

## 维护规则
- 这里放原始贴图、图标、音频等静态资产。
- 若资源需要正式内容 id、catalog 或运行时装配，应在 `content/` 中有对应数据定义。
- `assets/` 不是运行期内容真相；运行期应通过 `content/` 的 catalog/loader 获取正式资源引用。
- AI 或外包产出的新资产应先进入 `content_source/asset_intake/`，通过 asset pipeline 预检后再写入 CSV。
