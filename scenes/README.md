# scenes

## 目录定位
项目级可实例化场景目录。

## 子目录职责
- `front/`：前台正式场景。
- `battle/`：正式 battle 场景。
- `network/`：Dedicated Server 与网络调试相关场景。
- `sandbox/`：仅历史/验证用途的实验场景。
- `actors/`：角色、泡泡等可实例化本体 scene。
- `skins/`：角色皮肤、泡泡皮肤等可挂接 overlay scene。
- `map_themes/`：地图主题环境 scene。

## 维护规则
- 可实例化节点树放这里，不放进 `content/`。
- 正式入口与 debug / sandbox 场景必须明确区分。
