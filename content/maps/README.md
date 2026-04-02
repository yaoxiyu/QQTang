# maps

## 目录定位
地图资源真相源目录。

## 职责范围
- 地图 catalog 管理
- 地图 resource 定义
- 地图 runtime loader

## 允许放入
- 地图资源脚本与 `.tres`
- 地图资源注册与加载代码

## 禁止放入
- UI 直接硬编码地图真相
- battle 运行时流程
- 临时测试逻辑

## 对外依赖
- 可被 room、battle、simulation 读取
- 不依赖前台 UI 流程

## 维护约束
- 地图真相只能从本层进入
- catalog/resource/runtime loader 分层明确
- 新地图接入先走本目录体系
