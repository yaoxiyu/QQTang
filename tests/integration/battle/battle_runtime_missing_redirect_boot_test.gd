extends Node

const BattleSceneScript = preload("res://scenes/battle/battle_main.tscn")

signal test_finished


func _ready() -> void:
	call_deferred("run_all")


func run_all() -> void:
	await _ensure_no_app_root()
	_assert_true(_count_app_roots() == 0, "battle redirect test starts with no runtime root")

	var result := get_tree().change_scene_to_packed(BattleSceneScript)
	_assert_true(result == OK, "battle scene loads for missing-runtime redirect test")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var current_scene := get_tree().current_scene
	var current_scene_name := String(current_scene.name) if current_scene != null else ""
	_assert_true(
		current_scene != null and current_scene_name != "BattleMain" and ["BootScene", "LoginScene", "LobbyScene"].has(current_scene_name),
		"battle scene redirects back into the boot-owned front flow when runtime is missing"
	)
	_assert_true(_count_app_roots() == 1, "battle missing-runtime redirect lands on boot bootstrap path with a single AppRoot")

	await _cleanup_tree()
	test_finished.emit()


func _ensure_no_app_root() -> void:
	for child in get_tree().root.get_children():
		if child != self and String(child.name) == "AppRoot":
			child.queue_free()
	await get_tree().process_frame


func _cleanup_tree() -> void:
	var current_scene := get_tree().current_scene
	if current_scene != null and is_instance_valid(current_scene):
		current_scene.queue_free()
	var app_root := get_tree().root.get_node_or_null("AppRoot")
	if app_root != null and is_instance_valid(app_root):
		app_root.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _count_app_roots() -> int:
	var count := 0
	for child in get_tree().root.get_children():
		if child != null and String(child.name) == "AppRoot":
			count += 1
	return count


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] %s" % message)
		return
	push_error("[FAIL] %s" % message)
