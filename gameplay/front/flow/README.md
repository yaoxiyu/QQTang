# flow

## 目录定位
legacy wrapper only 目录。

## 职责范围
- 旧前台 flow 路径兼容
- 对 `res://app/flow/` 的继承与转发

## 允许放入
- 仅包装型脚本
- 继承/转发到 `res://app/flow/` 的兼容壳

## 禁止放入
- 新增正式逻辑
- 新的状态机实现
- battle/network 细节逻辑

## 对外依赖
- 只允许依赖 `res://app/flow/`
- 不应成为正式主干依赖方向

## 维护约束
- wrapper 必须保持薄
- 禁止新增正式实现
- 仅保留历史路径兼容价值
