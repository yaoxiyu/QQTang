extends Node

const ContextSyncScript = preload("res://app/flow/app_runtime_context_sync.gd")
const TestAssert = preload("res://tests/helpers/test_assert.gd")

class FakeFrontContext:
	extends RefCounted
	var auth_session_state = null
	var player_profile_state = null
	var front_settings_state = null
	var current_room_entry_context = null
	var pending_room_action: String = ""
	var current_loading_mode: String = ""
	var current_resume_snapshot = null

class FakeBattleContext:
	extends RefCounted
	var current_room_snapshot = null
	var current_start_config = null
	var current_battle_content_manifest: Dictionary = {}
	var current_battle_scene = null
	var current_battle_bootstrap = null
	var current_presentation_bridge = null
	var current_battle_hud_controller = null
	var current_battle_camera_controller = null
	var current_settlement_controller = null
	var current_settlement_popup_summary: Dictionary = {}

class FakeRuntime:
	extends Node
	var front_context = FakeFrontContext.new()
	var battle_context = FakeBattleContext.new()
	var auth_session_state = {"token": "a"}
	var player_profile_state = {"nickname": "n"}
	var front_settings_state = {"lang": "zh"}
	var current_room_entry_context = {"room_id": "r1"}
	var pending_room_action: String = "rematch"
	var current_loading_mode: String = "resume"
	var current_resume_snapshot = {"match_id": "m1"}
	var _resume_state_store = null
	var current_room_snapshot = {"room_id": "r1"}
	var current_start_config = {"match_id": "m1"}
	var current_battle_content_manifest = {"map_id": "m"}
	var current_battle_scene = null
	var current_battle_bootstrap = null
	var current_presentation_bridge = null
	var current_battle_hud_controller = null
	var current_battle_camera_controller = null
	var current_settlement_controller = null
	var current_settlement_popup_summary = {"summary": true}

	func _ensure_resume_state_store() -> void:
		pass


func _ready() -> void:
	var prefix := "app_runtime_context_sync_test"
	var runtime := FakeRuntime.new()
	ContextSyncScript.sync_front_context(runtime)
	ContextSyncScript.sync_battle_context(runtime)
	var ok := true
	ok = TestAssert.is_true(runtime.front_context.pending_room_action == "rematch", "front context should mirror pending action", prefix) and ok
	ok = TestAssert.is_true(runtime.front_context.current_loading_mode == "resume", "front context should mirror loading mode", prefix) and ok
	ok = TestAssert.is_true(runtime.battle_context.current_start_config.get("match_id", "") == "m1", "battle context should mirror start config", prefix) and ok
	ok = TestAssert.is_true(runtime.battle_context.current_settlement_popup_summary.get("summary", false), "battle context should mirror settlement summary", prefix) and ok
	if ok:
		print("%s: PASS" % prefix)
	else:
		push_error("%s: FAIL" % prefix)
