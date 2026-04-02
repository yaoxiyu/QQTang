# characters

## 目录定位
角色资源总入口目录。

## 职责范围
- 角色 catalog 管理
- 角色 resource 定义
- 角色 runtime loader

## 允许放入
- 角色资源脚本与 `.tres`
- 角色资源加载辅助

## 禁止放入
- 玩法逻辑
- 房间流程 UI
- 网络 session 行为

## 对外依赖
- 可依赖基础资源与 loader
- 不依赖前台流程或表现控制器

## 维护约束
- catalog/resource/runtime 边界清晰
- 角色真相不在 UI 层硬编码
- 命名使用长期资源语义
