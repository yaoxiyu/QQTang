## 日志级别
class_name LogLevelConstants

## 日志级别枚举
enum Level {
	DEBUG = 0,
	INFO = 1,
	WARN = 2,
	ERROR = 3,
	FATAL = 4,
}

## 日志类型（模块分类）
enum Type {
	APP,           ## 应用级（启动、生命周期、runtime）
	FRONT,         ## 前台流程（boot、login、lobby、room、loading）
	NET,           ## 网络传输（transport、connection、peer）
	SESSION,       ## 会话管理（room session、member）
	MATCH,         ## 匹配与开战协调
	BATTLE,        ## 战斗运行时（bootstrap、lifecycle）
	SIMULATION,    ## 仿真层（systems、entities、events）
	SYNC,          ## 同步与 rollback（checkpoint、summary、prediction）
	CONTENT,       ## 内容系统（catalog、loader、pipeline）
	PRESENTATION,  ## 表现层（bridge、hud、view）
	AUTH,          ## 认证（login、gateway、session）
	PROFILE,       ## 档案与设置
}

## 日志级别字符串映射
static func level_to_string(level: int) -> String:
	match level:
		Level.DEBUG: return "DEBUG"
		Level.INFO: return "INFO"
		Level.WARN: return "WARN"
		Level.ERROR: return "ERROR"
		Level.FATAL: return "FATAL"
		_: return "UNKNOWN"

## 日志类型字符串映射
static func type_to_string(log_type: int) -> String:
	match log_type:
		Type.APP: return "APP"
		Type.FRONT: return "FRONT"
		Type.NET: return "NET"
		Type.SESSION: return "SESSION"
		Type.MATCH: return "MATCH"
		Type.BATTLE: return "BATTLE"
		Type.SIMULATION: return "SIM"
		Type.SYNC: return "SYNC"
		Type.CONTENT: return "CONTENT"
		Type.PRESENTATION: return "PRESENTATION"
		Type.AUTH: return "AUTH"
		Type.PROFILE: return "PROFILE"
		_: return "UNKNOWN"
