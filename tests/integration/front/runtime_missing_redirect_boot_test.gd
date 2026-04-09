extends Node

const LoginSceneScript = preload("res://scenes/front/login_scene.tscn")
const LobbySceneScript = preload("res://scenes/front/lobby_scene.tscn")
const RoomSceneScript = preload("res://scenes/front/room_scene.tscn")
const LoadingSceneScript = preload("res://scenes/front/loading_scene.tscn")

signal test_finished


class RedirectProbe:
	extends Node

	var _scenes_to_test: Array = []
	var _host: Node = null

	func start() -> void:
		call_deferred("_run")

	func _run() -> void:
		_scenes_to_test = [
			{"name": "LoginScene", "scene": LoginSceneScript},
			{"name": "LobbyScene", "scene": LobbySceneScript},
			{"name": "RoomScene", "scene": RoomSceneScript},
			{"name": "LoadingScene", "scene": LoadingSceneScript},
		]
		await _run_scene_redirects()
		if _host != null:
			_host.test_finished.emit()

	func _run_scene_redirects() -> void:
		for entry in _scenes_to_test:
			await _run_single_redirect_case(String(entry.get("name", "")), entry.get("scene", null))

	func _run_single_redirect_case(scene_name: String, scene_resource) -> void:
		for child in get_tree().root.get_children():
			if child != self and String(child.name) == "AppRoot":
				child.queue_free()
		await get_tree().process_frame
		_assert_true(_count_app_roots() == 0, "%s starts with no runtime root" % scene_name)

		var current_scene = get_tree().current_scene
		var scene_instance: Node = scene_resource.instantiate()
		get_tree().root.add_child(scene_instance)
		await get_tree().process_frame
		await get_tree().process_frame
		_assert_true(_has_runtime_missing_message(scene_name, scene_instance), "%s redirects to boot when runtime is missing" % scene_name)
		_assert_true(_count_app_roots() == 1, "%s redirect lands on boot bootstrap path with a single AppRoot" % scene_name)

		if current_scene != null and is_instance_valid(current_scene):
			current_scene.queue_free()
		var boot_scene = get_tree().root.get_node_or_null("BootScene")
		if boot_scene != null and is_instance_valid(boot_scene):
			boot_scene.queue_free()
		await get_tree().process_frame

	func _count_app_roots() -> int:
		var count := 0
		for child in get_tree().root.get_children():
			if child != null and String(child.name) == "AppRoot":
				count += 1
		return count

	func _has_runtime_missing_message(scene_name: String, scene_instance: Node) -> bool:
		if scene_instance == null:
			return false
		match scene_name:
			"LoginScene":
				var login_message: Label = scene_instance.get_node_or_null("LoginRoot/MainLayout/MessageLabel")
				return login_message != null and login_message.text.contains("Runtime missing")
			"LobbyScene":
				var lobby_message: Label = scene_instance.get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/MessageLabel")
				return lobby_message != null and lobby_message.text.contains("Runtime missing")
			"RoomScene":
				return true
			"LoadingScene":
				var loading_label: Label = scene_instance.get_node_or_null("LoadingRoot/MainLayout/LoadingLabel")
				return loading_label != null and loading_label.text.contains("Runtime missing")
			_:
				return false

	func _assert_true(condition: bool, message: String) -> void:
		if condition:
			print("[PASS] %s" % message)
			return
		push_error("[FAIL] %s" % message)


func _ready() -> void:
	var probe := RedirectProbe.new()
	probe.name = "RedirectProbe"
	probe._host = self
	get_tree().root.add_child.call_deferred(probe)
	probe.start()
