# rule_defs

## 目录定位
规则定义脚本目录。

## 职责范围
- 规则 def 维护
- 提供 gameplay 侧静态规则定义

## 允许放入
- 规则 def 脚本
- 与规则静态结构直接相关的声明

## 禁止放入
- session/runtime 行为
- 网络协议处理
- 前台流程逻辑

## 对外依赖
- 可被 battle/network 配置校验使用
- 不依赖 scenes 或 UI

## 维护约束
- 只放规则 def
- 不混入行为实现
- 保持长期稳定命名
