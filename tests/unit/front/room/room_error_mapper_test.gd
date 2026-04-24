extends "res://tests/gut/base/qqt_unit_test.gd"

const RoomErrorMapperScript = preload("res://app/front/room/errors/room_error_mapper.gd")


func test_app_runtime_missing_maps_to_front_error() -> void:
	var result := RoomErrorMapperScript.to_front_error("APP_RUNTIME_MISSING")

	assert_false(bool(result.get("ok", true)), "error result should be marked not ok")
	assert_eq(String(result.get("error_code", "")), "APP_RUNTIME_MISSING", "error code should be preserved")
	assert_eq(String(result.get("message", "")), "运行时尚未初始化", "default message should be mapped")
	assert_eq(String(result.get("user_message", "")), "运行时尚未初始化", "user message should mirror message")


func test_fallback_message_overrides_default() -> void:
	var result := RoomErrorMapperScript.to_front_error("ROOM_ENTRY_CONTEXT_MISSING", "custom message")

	assert_eq(String(result.get("message", "")), "custom message", "fallback message should be used when provided")
