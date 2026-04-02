# path

## 目录定位
canonical path / legacy wrapper 约束测试目录。

## 职责范围
- canonical path 契约
- legacy wrapper 守卫
- 路径兼容约束

## 允许放入
- 路径与包装层约束测试
- 兼容守卫测试

## 禁止放入
- 业务流程验证
- 长链路集成测试
- 单元测试

## 对外依赖
- 可依赖正式路径与 legacy wrapper 目录
- 不承载业务实现

## 维护约束
- 路径约束必须与当前文件树一致
- 用例名直接表达约束目标
- 文档与测试同步更新
