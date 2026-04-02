# items

## 目录定位
道具内容真相层。

## 职责范围
- 道具资源定义
- 道具目录注册
- 道具加载与运行时 manifest 构建

## 允许放入
- catalog
- runtime loader
- resource definition
- `.tres` item resources

## 禁止放入
- 掉落随机逻辑
- 仿真状态更新
- HUD / FX 表现逻辑

## 对外依赖
- 可被 `gameplay/`、`network/`、`presentation/` 消费
- 不直接依赖 Room / Battle 场景节点

## 维护约束
- item 可见性必须通过 catalog 管理
- item 资源必须可被 loader 校验
- simulation 内部仍使用轻量 `item_type`，内容层负责映射语义
