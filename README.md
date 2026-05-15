# QQTang

QQTang 是一款基于 Godot 引擎开发的多人休闲竞技游戏。

## 环境准备

- [Godot 4.6.2+](https://godotengine.org/) — 编辑器及运行时
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) — 后端服务容器
- [PowerShell 7+](https://github.com/PowerShell/PowerShell) — 构建及启动脚本
- Go 1.24+ — 后端服务编译（仅修改后端代码时需要）

首次使用前，将 Godot 可执行文件放置于 `external/godot_binary/Godot.exe`（Windows）或通过脚本参数 `-GodotPath` 指定路径。

## 快速启动

### 启动后端服务

```powershell
# 开发环境（默认）
.\tools\run-services.ps1

# 测试环境
.\tools\run-services.ps1 -Profile test
```

此脚本会：
1. 启动数据库容器并执行迁移
2. 编译 native 扩展（Windows + Linux）
3. 运行 GDScript 语法预检
4. 生成房间清单（room manifest）
5. 构建 Battle DS Docker 镜像
6. 通过 Docker Compose 启动所有后端服务（account / game / room / ds_manager）

启动后可访问：
| 服务 | 地址 |
|------|------|
| account_service | `http://127.0.0.1:18080` |
| game_service | `http://127.0.0.1:18081` |
| ds_manager_service | `http://127.0.0.1:18090` |
| room_service (HTTP) | `http://127.0.0.1:19100` |
| room_service (WS) | `ws://127.0.0.1:9100` |

常用参数：
| 参数 | 说明 |
|------|------|
| `-Profile` | 环境配置：`dev`（默认）/ `test` |
| `-SkipDb` | 跳过数据库启动 |
| `-SkipBuild` | 跳过所有编译步骤 |
| `-SkipNativeBuild` | 跳过 native 扩展编译 |
| `-ForceBuild` | 强制重新编译 |
| `-LogSQL` | 启用 SQL 日志 |

### 启动客户端（正式流程）

在 Godot 编辑器中打开项目，或通过命令行：
```powershell
.\external\godot_binary\Godot.exe --path .
```
然后走正常流程：登录 → 大厅 → 房间 → 匹配 → 战斗。

---

## 开发战斗快速测试

战斗逻辑的开发迭代不需要走完整的登录-大厅-房间流程，提供了两种快速启动模式。

### 单机模式（Local Loopback）

最快的迭代方式，所有逻辑在一个进程内运行，1 个键盘控制角色 + N 个 AI 角色。

```powershell
.\scripts\run-dev-battle.ps1
```

可选参数：
| 参数 | 默认值 | 说明 |
|------|--------|------|
| `-PlayerCount` | `2` | 总玩家数（1 人 + N-1 AI） |
| `-MapId` | `map_bomb01` | 指定地图（不指定则使用默认地图，启动时会列出所有可用地图） |
| `-RuleSetId` | 自动 | 覆盖规则集 |
| `-GodotPath` | `external/godot_binary/Godot.exe` | Godot 可执行文件路径 |
| `-SkipBuild` | false | 跳过 native 编译 |

战斗内快捷键：
| 按键 | 功能 |
|------|------|
| 方向键 | 移动 |
| 空格 | 放炸弹 |
| `F3` | 切换调试面板 |
| `O` | 切换 AI 自动输入 |
| `J` | 切换延迟模拟配置 |
| `K` | 切换丢包模拟配置 |
| `L` | 强制预测回滚 |

### 双端模式（DS + Client）

用于测试网络相关逻辑（回滚、预测、延迟/丢包）。启动一个 headless DS 进程和一个客户端进程。

```powershell
.\scripts\run-dev-battle.ps1 -Mode ds_client
```

可选参数：
| 参数 | 默认值 | 说明 |
|------|--------|------|
| `-PlayerCount` | `2` | 总玩家数 |
| `-MapId` | `map_bomb01` | 指定地图 |
| `-RuleSetId` | 自动 | 覆盖规则集 |
| `-DsPort` | `19010` | DS 监听端口 |
| `-DsHost` | `127.0.0.1` | DS 监听地址 |

双端模式启动后，DS 进程在后台运行（headless），客户端窗口打开后即可操作角色。关闭客户端后 DS 自动停止。

### 手动启动 DS（Dev Mode）

也可以手动单独启动 dev mode DS：

```powershell
.\external\godot_binary\Godot.exe --headless --path . res://scenes/network/dedicated_server_scene.tscn -- --qqt-dev-mode --qqt-dev-player-count 2 --qqt-port 9000
```

DS 启动后等待客户端连接。客户端同样通过 dev launcher 指定 DS 地址连接：

```powershell
.\external\godot_binary\Godot.exe --path . res://scenes/dev/dev_battle_launcher.tscn -- --qqt-dev-launcher-ds-addr 127.0.0.1 --qqt-dev-launcher-ds-port 9000 --qqt-dev-launcher-player-count 2
```

---

## 内容管线

```powershell
# 运行内容管线（生成 catalog index 等）
powershell -ExecutionPolicy Bypass -File scripts/content/run_content_pipeline.ps1

# 校验内容管线输出
powershell -ExecutionPolicy Bypass -File scripts/content/validate_content_pipeline.ps1
```

## 测试

```powershell
# GDScript 语法预检
powershell -ExecutionPolicy Bypass -File tests/scripts/check_gdscript_syntax.ps1
```
