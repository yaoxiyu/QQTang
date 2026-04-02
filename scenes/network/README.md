# network

## 目录定位
网络启动 / Dedicated Server 场景目录。

## 职责范围
- 网络启动场景
- Dedicated Server 启动场景

## 正式入口约束
- `res://scenes/network/dedicated_server_scene.tscn`
  - 当前唯一正式 Dedicated Server 进程入口
- `res://scenes/network/network_bootstrap_scene.tscn`
  - 仅限 QA / transport / protocol 调试壳
  - 不是正式产品入口
  - 不允许继续承载正式 Room / Battle 业务

## 允许放入
- 网络入口 `.tscn`
- 与启动场景直接绑定的控制脚本

## 禁止放入
- 房间 UI
- battle 表现层逻辑
- 临时测试场景

## 对外依赖
- 可依赖 `res://network/runtime/`
- 不依赖 gameplay legacy wrapper

## 维护约束
- 仅存放网络启动型场景
- 正式入口路径保持稳定
- 路径调整需同步 bootstrap 引用
- `network_bootstrap_scene.tscn` 只能保留 debug-only 语义
