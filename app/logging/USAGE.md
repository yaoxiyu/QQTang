# 日志系统使用指南

## 架构概述

```
app/logging/
├── log_types.gd              # 日志级别和类型常量定义
├── log_config.gd             # 日志配置（级别、输出目标、轮转等）
├── log_writer.gd             # 文件写入器（线程安全、日志轮转）
├── log_manager.gd            # 日志管理器核心（全局单例）
├── log_net.gd                # 网络模块日志门面
├── log_front.gd              # 前台流程日志门面
├── log_session.gd            # 会话管理日志门面
├── log_match.gd              # 匹配模块日志门面
├── log_battle.gd             # 战斗模块日志门面
├── log_simulation.gd         # 仿真层日志门面
├── log_sync.gd               # 同步模块日志门面
├── log_content.gd            # 内容系统日志门面
├── log_presentation.gd       # 表现层日志门面
├── log_auth.gd               # 认证模块日志门面
├── log_system_initializer.gd # 初始化器
└── USAGE.md                  # 本文件
```

## 快速开始

### 1. 初始化

**客户端入口（Boot Scene）：**
```gdscript
# scenes/front/boot_scene_controller.gd
func _ready() -> void:
    LogSystemInitializer.initialize_client()
    # ... 其他初始化逻辑
```

**Dedicated Server 入口：**
```gdscript
# network/runtime/dedicated_server_bootstrap.gd
func _ready() -> void:
    LogSystemInitializer.initialize_dedicated_server()
    # ... 其他初始化逻辑
```

### 2. 使用日志

**方式一：模块门面（推荐）**
```gdscript
# 网络模块
LogNet.debug("Connection established to %s:%d" % [host, port])
LogNet.warn("Connection timeout, retrying...")
LogNet.error("Failed to connect: %s" % error_message)

# 战斗模块
LogBattle.info("Battle started with map_id=%s" % map_id)
LogBattle.warn("Bootstrap took longer than expected: %d ms" % elapsed)
LogBattle.error("Failed to initialize battle runtime")

# 同步模块
LogSync.debug("Checkpoint received: tick=%d" % tick)
LogSync.warn("Rollback triggered: drift=%d ticks" % drift)
LogSync.error("Checksum mismatch detected at tick=%d" % tick)
```

**方式二：直接使用 LogManager**
```gdscript
LogManager.debug(LogType.NET, "Packet sent: %d bytes" % size)
LogManager.info(LogType.SESSION, "Player %d joined room" % player_id)
LogManager.warn(LogType.MATCH, "Config validation warning", "match_coordinator.gd", 42)
LogManager.error(LogType.BATTLE, "Bootstrap failed", "battle_bootstrap.gd", 85)
```

### 3. 日志级别

| 级别 | 用途 | 示例 |
|------|------|------|
| DEBUG | 详细调试信息，生产环境关闭 | 包体大小、tick 详情、中间状态 |
| INFO | 正常流程信息 | 连接建立、玩家加入、战斗开始 |
| WARN | 警告但不影响流程 | 配置缺失使用默认值、超时重试 |
| ERROR | 错误但可恢复 | 网络断开重连、资源加载失败 |
| FATAL | 致命错误，流程终止 | 核心系统初始化失败、数据损坏 |

### 4. 日志类型

| 类型 | 模块 | 使用场景 |
|------|------|----------|
| APP | 应用级 | 启动、生命周期、runtime |
| FRONT | 前台流程 | boot、login、lobby、room、loading |
| NET | 网络传输 | transport、connection、peer |
| SESSION | 会话管理 | room session、member |
| MATCH | 匹配开战 | 匹配协调、开战配置 |
| BATTLE | 战斗运行时 | bootstrap、lifecycle |
| SIMULATION | 仿真层 | systems、entities、events |
| SYNC | 同步回滚 | checkpoint、summary、prediction |
| CONTENT | 内容系统 | catalog、loader、pipeline |
| PRESENTATION | 表现层 | bridge、hud、view |
| AUTH | 认证 | login、gateway、session |
| PROFILE | 档案设置 | 玩家档案、设置 |

## 日志输出格式

默认格式：`[{timestamp}] [{level}] [{type}] {tag}{message}`

示例输出：
```
[2026-04-09 15:30:45] [INFO] [NET] Connection established to 192.168.1.100:8080
[2026-04-09 15:30:46] [WARN] [SESSION] session.message_router route room_snapshot
[2026-04-09 15:30:47] [ERROR] [BATTLE] battle.flow_state BOOTSTRAPPING -> RUNNING (runtime_listeners_bound)
```

## 日志文件

- **客户端日志**：`user://logs/client_YYYYMMDD_HHMMSS.log`
- **DS 日志**：`user://logs/dedicated_server_YYYYMMDD_HHMMSS.log`

日志文件会自动轮转（默认 10MB/文件，保留 5 个）。

## 迁移指南

将现有 `print()` 调用迁移到日志系统：

**Before:**
```gdscript
print("[DedicatedServerBootstrap] started on %s:%d" % [host, port])
print("[client_runtime] rollback_corrected entity=%d" % entity_id)
```

**After:**
```gdscript
LogNet.info("started on %s:%d" % [host, port], "", 0, "net.server_bootstrap")
LogSync.debug("rollback_corrected entity=%d" % entity_id, "", 0, "sync.trace sync.client_runtime.rollback")
```

## 性能注意

1. DEBUG 级别在生产环境会默认关闭，debug 构建默认保留 DEBUG，release 构建默认 INFO
2. 高频调用场景（如每 tick）使用 DEBUG 级别
3. 文件写入采用缓冲 flush 和批量轮转检查，避免每条日志都同步刷盘
4. 位置信息（文件:行号）默认关闭以优化性能
