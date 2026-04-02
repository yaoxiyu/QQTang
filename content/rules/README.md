# rules

## 目录定位
规则资源入口目录。

## 职责范围
- rule catalog
- rule loader
- 规则资源注册

## 允许放入
- 规则 catalog 与 loader
- 与规则资源装载相关的静态入口

## 禁止放入
- session/runtime 行为
- 前台流程控制
- 分散式规则注册

## 对外依赖
- 可被 gameplay 和 network 消费
- 不反向依赖 scenes 或 UI

## 维护约束
- 规则注册集中在本层
- 命名保持资源语义
- 禁止在其它层散落注册逻辑
