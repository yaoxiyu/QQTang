# gameplay

## 目录定位
玩法装配、战斗运行时与仿真相关主目录。

## 子目录职责
- `battle/`：战斗启动装配、battle runtime、与内容/表现桥接相关的 gameplay 侧逻辑。
- `simulation/`：离散仿真核心与运行时仿真支撑。
- `front/`：前台玩法态纯数据与组装辅助。
- `config/`：仍被旧链路使用的配置层与历史配置定义。

## 维护规则
- 仿真层不被 Node/UI 反向侵入。
- 正式联机实现优先进入 `res://network/`，不是这里。
- 新逻辑优先落到 battle / simulation / front 的清晰职责边界里。
