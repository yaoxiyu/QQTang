# runtime

## 目录定位
仿真运行时装配层。

## 职责范围
- `sim_world`
- `system_pipeline`
- `tick_runner`
- 地图工厂与运行时上下文

## 允许放入
- 仿真 runtime 装配脚本
- world/context/pipeline/tick 相关实现

## 禁止放入
- 测试 runner
- 前台/表现层控制器
- 非仿真职责的业务壳

## 对外依赖
- 可依赖 `res://gameplay/simulation/` 其它子目录与 `res://content/maps/`
- 不依赖前台 UI

## 维护约束
- 运行时装配与测试代码分离
- 文件名体现正式 runtime 语义
- 不再使用 test/phase 命名
