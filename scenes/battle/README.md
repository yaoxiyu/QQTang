# battle

## 目录定位
正式 battle 场景目录。

## 职责范围
- battle 正式入口场景
- battle 场景控制器
- 结算弹窗场景

## 允许放入
- `battle_main.tscn`
- battle 控制器
- 正式结算场景

## 禁止放入
- 临时测试场景
- 前台房间流程场景
- 纯仿真测试 runner

## 对外依赖
- 可依赖 gameplay battle 与 presentation battle
- 不承载内容真相定义

## 维护约束
- `battle_main.tscn` 视为正式入口
- 场景结构语义保持稳定
- 修改路径时同步挂载引用
