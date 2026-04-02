# front

## 目录定位
Loading / Room 正式前台场景目录。

## 职责范围
- loading 场景
- room 场景
- 对应控制器

## 允许放入
- 正式前台 `.tscn`
- 前台控制器脚本

## 禁止放入
- sandbox 原型场景
- battle 运行时规则实现
- 阶段性测试入口

## 对外依赖
- 可依赖 `res://app/flow/` 与必要的 `res://network/`
- 不反向定义 content 真相

## 维护约束
- 只放正式前台场景和控制器
- 路径命名稳定可长期维护
- 不把 debug 原型混入正式入口
