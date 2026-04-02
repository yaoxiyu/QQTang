# config

## 目录定位
gameplay 侧配置定义目录。

## 职责范围
- gameplay 静态配置
- map def
- rule def

## 允许放入
- gameplay 所需 def/config 脚本
- 静态结构定义

## 禁止放入
- session/runtime 行为
- UI 控制逻辑
- 临时测试包装

## 对外依赖
- 可被 battle 与 simulation 消费
- 不反向依赖前台流程

## 维护约束
- 只保留配置定义
- def 与 runtime 行为严格分离
- 命名使用长期通用语义
