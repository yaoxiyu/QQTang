# battle

## 目录定位
battle + presentation + settlement 集成测试目录。

## 职责范围
- battle 生命周期验证
- presentation 同步验证
- settlement 集成回归

## 允许放入
- battle flow 测试
- presentation sync 测试
- settlement 测试

## 禁止放入
- 单元测试
- 纯路径契约测试
- 网络 transport 细节测试

## 对外依赖
- 可依赖 `res://gameplay/battle/`、`res://presentation/`、`res://scenes/battle/`
- 不承担业务实现

## 维护约束
- 测试目标清楚对应 battle 集成面
- 命名统一使用长期语义
- 不继续保留 runner 阶段名
