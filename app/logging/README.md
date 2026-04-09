# 日志系统

## 目录定位
项目级日志基础设施层，为所有业务模块提供统一的结构化日志能力。

## 架构设计

```
app/logging/
├── log_types.gd              # 日志级别 (DEBUG/INFO/WARN/ERROR/FATAL) 和类型常量
├── log_config.gd             # 日志配置（级别、输出目标、轮转策略等）
├── log_writer.gd             # 文件写入器（缓冲写入、线程安全、日志轮转）
├── log_manager.gd            # 日志管理器核心（全局单例，统一调度）
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
├── log_system_initializer.gd # 初始化器（Boot/DS 入口调用）
├── USAGE.md                  # 使用指南
└── README.md                 # 本文件
```

## 核心特性

1. **日志级别**：DEBUG < INFO < WARN < ERROR < FATAL
2. **日志类型**：APP、FRONT、NET、SESSION、MATCH、BATTLE、SIMULATION、SYNC、CONTENT、PRESENTATION、AUTH、PROFILE
3. **标签参数**：支持用可选 `tag` 传递子系统/主题前缀，而不是硬编码进消息正文
4. **双路输出**：同时输出到控制台和文件
5. **文件分离**：客户端日志 (`client_*.log`) 和 DS 日志 (`dedicated_server_*.log`) 自动分离
6. **日志轮转**：按大小自动轮转（默认 10MB/文件，保留 5 个）
7. **缓冲写入**：按批次 flush，避免每条日志都同步落盘
8. **线程安全**：使用 Mutex 保护文件写入
9. **Godot 集成**：自动配置 Godot 原生日志路径

## 子目录职责
- 核心层：`log_types.gd`、`log_config.gd`、`log_writer.gd`、`log_manager.gd`
- 门面层：各模块专用门面（`log_net.gd`、`log_battle.gd` 等），直接静态调用 `LogManager`
- 初始化：`log_system_initializer.gd`

## 维护规则
- 所有业务代码必须通过本日志系统输出，禁止直接使用 `print`/`printerr`/`push_warning`/`push_error`
- 日志文件按运行模式分离（client/dedicated_server）
- 默认按 debug/release 选择日志级别：debug 构建保留 DEBUG，release 构建默认 INFO
- 新增业务模块时，同步创建对应的日志门面类
