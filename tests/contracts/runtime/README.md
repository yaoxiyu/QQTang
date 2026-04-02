# runtime

## 目录定位
runtime cleanup / lifecycle / debug bootstrap 契约目录。

## 职责范围
- runtime cleanup 契约
- battle lifecycle 契约
- debug bootstrap 契约

## 允许放入
- 运行时生命周期约束测试
- 清理与启动边界测试

## 禁止放入
- 网络集成流测试
- transport 单测
- 冒烟稳定性测试

## 对外依赖
- 可依赖 app/network/gameplay 正式运行时入口
- 不承载正式实现

## 维护约束
- 契约点要和文档一致
- 测试名称使用 `<contract>_test.gd`
- 不保留 phase 命名
