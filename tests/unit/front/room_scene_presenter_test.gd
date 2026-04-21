extends "res://tests/gut/base/qqt_unit_test.gd"

const PresenterScript = preload("res://app/front/room/room_scene_presenter.gd")


func test_battle_allocation_text_prefers_canonical_ready_state() -> void:
	var presenter := PresenterScript.new()
	var text := presenter._build_battle_allocation_text({
		"room_phase": "battle_entry_ready",
		"battle_phase": "ready",
		"battle_entry_ready": true,
		"battle_server_host": "127.0.0.1",
		"battle_server_port": 19010,
	})
	assert_eq(text, "Battle Ready — 127.0.0.1:19010", "presenter should use canonical ready state and endpoint")


func test_battle_allocation_text_handles_canonical_completed_reason() -> void:
	var presenter := PresenterScript.new()
	var text := presenter._build_battle_allocation_text({
		"room_phase": "returning_to_room",
		"battle_phase": "completed",
		"battle_terminal_reason": "allocation_failed",
		"battle_entry_ready": false,
	})
	assert_eq(text, "对局分配失败", "presenter should use canonical battle terminal reason")
