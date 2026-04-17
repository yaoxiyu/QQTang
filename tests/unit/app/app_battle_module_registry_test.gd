extends Node

const RegistryScript = preload("res://app/flow/app_battle_module_registry.gd")
const TestAssert = preload("res://tests/helpers/test_assert.gd")

class FakeBattleContext:
	extends RefCounted
	var cleared: bool = false
	func clear_battle_payload() -> void:
		cleared = true

class FakeRuntime:
	extends Node
	var current_battle_scene = null
	var current_battle_bootstrap = null
	var current_presentation_bridge = null
	var current_battle_hud_controller = null
	var current_battle_camera_controller = null
	var current_settlement_controller = null
	var current_start_config = {"match_id": "m1"}
	var current_battle_content_manifest = {"map_id": "x"}
	var current_settlement_popup_summary = {"ok": true}
	var current_battle_entry_context = {"e": 1}
	var battle_root := Node.new()
	var battle_context := FakeBattleContext.new()
	var front_context = null
	var _resume_state_store = null
	var synced: int = 0
	var resume_synced: int = 0

	func _init() -> void:
		battle_root.name = "BattleRoot"

	func _sync_battle_context_from_fields() -> void:
		synced += 1

	func _reparent_to(node: Node, parent: Node) -> void:
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		parent.add_child(node)

	func _ensure_resume_state_store() -> void:
		pass

	func _sync_resume_fields_from_store() -> void:
		resume_synced += 1


func _ready() -> void:
	var prefix := "app_battle_module_registry_test"
	var runtime := FakeRuntime.new()
	var scene := Node.new()
	RegistryScript.register_modules(runtime, scene, Node.new(), Node.new(), Node.new(), Node.new(), Node.new())
	RegistryScript.unregister_modules(runtime, scene)
	RegistryScript.clear_battle_payload(runtime)
	var ok := true
	ok = TestAssert.is_true(runtime.current_battle_scene == null, "unregister should clear current battle scene", prefix) and ok
	ok = TestAssert.is_true(runtime.battle_context.cleared, "clear should reset battle context payload", prefix) and ok
	ok = TestAssert.is_true(runtime.synced > 0, "register and unregister should sync battle context", prefix) and ok
	if ok:
		print("%s: PASS" % prefix)
	else:
		push_error("%s: FAIL" % prefix)
