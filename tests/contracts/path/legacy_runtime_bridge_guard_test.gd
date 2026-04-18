extends "res://tests/gut/base/qqt_contract_test.gd"



func test_main() -> void:
	var prefix := "legacy_runtime_bridge_guard_test"
	var ok := true
	ok = qqt_check(ResourceLoader.exists("res://network/session/runtime/legacy_room_runtime_bridge.gd"), "legacy runtime bridge script should exist", prefix) and ok
	var compat_lines := _line_count("res://network/session/runtime/server_room_runtime_compat_impl.gd")
	ok = qqt_check(compat_lines > 0 and compat_lines <= 100, "compat wrapper should remain thin", prefix) and ok
	ok = qqt_check(_contains("res://network/session/runtime/server_room_runtime_compat_impl.gd", "legacy_room_runtime_bridge.gd"), "compat wrapper should forward to legacy bridge", prefix) and ok
	assert_true(ok, prefix)


func _line_count(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return 0
	var lines := 0
	while not file.eof_reached():
		file.get_line()
		lines += 1
	file.close()
	return lines


func _contains(path: String, needle: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var text := file.get_as_text()
	file.close()
	return text.contains(needle)

