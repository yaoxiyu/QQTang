# runtime

## 目录定位
表现层运行时桥接目录。

## 职责范围
- 运行时 presentation bridge
- 兼容旧 bridge 路径时的承接层

## 允许放入
- runtime bridge
- 兼容性桥接脚本

## 禁止放入
- 仿真逻辑
- 前台流程状态机
- HUD 细节堆积

## 对外依赖
- 可依赖 `res://presentation/battle/bridge/`
- 不定义 gameplay 真相

## 维护约束
- 若为兼容层，要写清与 `battle/bridge` 的关系
- 桥接逻辑尽量薄
- 不扩散成新的正式业务中心
