# tests

## 目录定位
统一测试入口目录。

## 职责范围
- 按 `unit/integration/contracts/smoke` 分类测试
- 统一 CLI 测试入口
- 测试辅助与执行脚本归档

## 当前结构
- `cli/`：唯一 CLI 入口与命令行测试工程辅助文件
- `helpers/`：可复用测试辅助脚本
- `unit/`：单元测试
- `integration/`：集成链路测试
- `contracts/`：运行时/路径契约测试
- `smoke/`：长链路稳定性冒烟测试
- `scripts/`：PowerShell 测试套件脚本

## 允许放入
- 测试脚本
- 测试 helpers
- 测试运行脚本

## 禁止放入
- 继续按 phase 拆目录
- 测试运行产物长期留仓
- 正式业务实现代码

## 对外依赖
- 可依赖全工程正式路径
- 不应成为正式业务目录的反向依赖源

## 维护约束
- 测试按类型组织
- CLI 入口唯一化
- 测试报告与 appdata 不入库
- runner 与测试执行壳归入对应类型目录，不再保留历史 phase 壳
