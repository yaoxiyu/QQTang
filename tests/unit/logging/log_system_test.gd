extends Node

signal test_finished

const LogSystemInitializerScript = preload("res://app/logging/log_system_initializer.gd")
const LogManagerScript = preload("res://app/logging/log_manager.gd")
const LogLevelConstantsScript = preload("res://app/logging/log_types.gd")
const LogConfigScript = preload("res://app/logging/log_config.gd")
const LogNetScript = preload("res://app/logging/log_net.gd")
const LogBattleScript = preload("res://app/logging/log_battle.gd")
const LogSyncScript = preload("res://app/logging/log_sync.gd")

var _failed: bool = false


func _ready() -> void:
	_run_tests()
	if _failed:
		push_error("log_system_test: FAIL")
	else:
		print("log_system_test: PASS")
	test_finished.emit()


func _run_tests() -> void:
	_test_log_system_initialization()
	_test_log_system_initialization_dedicated_server()
	_test_log_level_filtering()
	_test_log_type_string_mapping()
	_test_log_level_string_mapping()
	_test_facade_pattern()
	_test_config_creation()
	_test_log_file_path_generation()


func _test_log_system_initialization() -> void:
	var err := LogSystemInitializerScript.initialize_client()
	_assert(err == OK, "client logging should initialize successfully")

	var config := LogManagerScript.get_config()
	_assert(config != null, "client config should exist after initialization")
	_assert(String(config.file_prefix) == "client_", "client config should use client_ prefix")

	LogManagerScript.on_exit()


func _test_log_system_initialization_dedicated_server() -> void:
	var err := LogSystemInitializerScript.initialize_dedicated_server()
	_assert(err == OK, "dedicated server logging should initialize successfully")

	var config := LogManagerScript.get_config()
	_assert(config != null, "dedicated server config should exist after initialization")
	_assert(String(config.file_prefix) == "dedicated_server_", "dedicated server config should use dedicated_server_ prefix")

	LogManagerScript.on_exit()


func _test_log_level_filtering() -> void:
	LogSystemInitializerScript.initialize_client()

	var config := LogManagerScript.get_config()
	config.min_level = LogLevelConstantsScript.Level.WARN

	LogManagerScript.debug(LogLevelConstantsScript.Type.APP, "This should be filtered")
	LogManagerScript.info(LogLevelConstantsScript.Type.APP, "This should be filtered")
	LogManagerScript.warn(LogLevelConstantsScript.Type.APP, "This should pass")

	_assert(config.min_level == LogLevelConstantsScript.Level.WARN, "min_level should be updated to WARN")

	LogManagerScript.on_exit()


func _test_log_type_string_mapping() -> void:
	_assert(LogLevelConstantsScript.type_to_string(LogLevelConstantsScript.Type.NET) == "NET", "NET type should map correctly")
	_assert(LogLevelConstantsScript.type_to_string(LogLevelConstantsScript.Type.BATTLE) == "BATTLE", "BATTLE type should map correctly")
	_assert(LogLevelConstantsScript.type_to_string(LogLevelConstantsScript.Type.SYNC) == "SYNC", "SYNC type should map correctly")
	_assert(LogLevelConstantsScript.type_to_string(LogLevelConstantsScript.Type.SESSION) == "SESSION", "SESSION type should map correctly")


func _test_log_level_string_mapping() -> void:
	_assert(LogLevelConstantsScript.level_to_string(LogLevelConstantsScript.Level.DEBUG) == "DEBUG", "DEBUG level should map correctly")
	_assert(LogLevelConstantsScript.level_to_string(LogLevelConstantsScript.Level.INFO) == "INFO", "INFO level should map correctly")
	_assert(LogLevelConstantsScript.level_to_string(LogLevelConstantsScript.Level.WARN) == "WARN", "WARN level should map correctly")
	_assert(LogLevelConstantsScript.level_to_string(LogLevelConstantsScript.Level.ERROR) == "ERROR", "ERROR level should map correctly")
	_assert(LogLevelConstantsScript.level_to_string(LogLevelConstantsScript.Level.FATAL) == "FATAL", "FATAL level should map correctly")


func _test_facade_pattern() -> void:
	LogSystemInitializerScript.initialize_client()

	LogNetScript.debug("Test debug message")
	LogNetScript.info("Test info message")
	LogNetScript.warn("Test warn message")
	LogNetScript.error("Test error message")
	LogBattleScript.info("Battle test message")
	LogSyncScript.debug("Sync test message")

	_assert(LogManagerScript.get_current_log_path() != "", "facade logging should work after initialization")

	LogManagerScript.on_exit()


func _test_config_creation() -> void:
	var client_config := LogConfigScript.create_client_config()
	_assert(client_config != null, "client config should be created")
	_assert(String(client_config.file_prefix) == "client_", "client config should use client_ prefix")
	_assert(client_config.log_directory == "user://logs", "client config should write to user://logs")

	var ds_config := LogConfigScript.create_dedicated_server_config()
	_assert(ds_config != null, "dedicated server config should be created")
	_assert(String(ds_config.file_prefix) == "dedicated_server_", "dedicated server config should use dedicated_server_ prefix")
	_assert(ds_config.location_enabled, "dedicated server config should enable location logging")


func _test_log_file_path_generation() -> void:
	LogSystemInitializerScript.initialize_client()

	var log_path := LogManagerScript.get_current_log_path()
	_assert(log_path != "", "log path should be generated")
	_assert(log_path.contains("client_"), "log path should include client prefix")
	_assert(log_path.begins_with("user://logs/"), "log path should be under user://logs")

	LogManagerScript.on_exit()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("log_system_test: FAIL - %s" % message)
