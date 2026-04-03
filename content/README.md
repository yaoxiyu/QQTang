# content

## 目录定位
内容定义、内容数据资产与运行时内容索引层。

## 子目录职责
- `characters/`：角色本体定义、数值、表现数据与运行时加载。
- `character_skins/`：角色皮肤定义、生成产物与自动扫描 catalog。
- `bubbles/`：泡泡样式与玩法数据。
- `bubble_skins/`：泡泡皮肤定义、生成产物与自动扫描 catalog。
- `maps/`：地图内容定义与地图真相源。
- `map_themes/`：地图主题定义、环境资产引用与生成产物。
- `rules/`：旧规则内容目录，保留给当前仍在使用的旧链路。
- `rulesets/`：新规则集定义、生成产物与自动扫描 catalog。
- `modes/`：玩法模式定义与运行时加载。
- `tiles/`：地图块定义与表现相关配置。
- `items/`：道具定义与道具数据。

## 统一目录规则
- `defs/`：资源定义脚本 `.gd`。
- `data/`：正式内容资产 `.tres`。
- `catalog/`：内容索引与注册入口。
- `runtime/`：运行时加载、装配与 builder。
- `resources/`：仅允许保留尚未迁移的 legacy 资产，不能再作为新真相源。

## 维护规则
- 新内容先进入本层，再被 gameplay / network / presentation 消费。
- 不在 UI、场景或 gameplay 脚本中散落正式内容真相。
