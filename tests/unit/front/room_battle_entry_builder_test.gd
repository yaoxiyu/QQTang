extends "res://tests/gut/base/qqt_unit_test.gd"

const RoomBattleEntryBuilderScript = preload("res://app/front/room/room_battle_entry_builder.gd")
const RoomEntryContextScript = preload("res://app/front/room/room_entry_context.gd")


func test_build_returns_null_until_battle_entry_is_ready() -> void:
	var snapshot := RoomSnapshot.new()
	snapshot.battle_entry_ready = false
	snapshot.current_assignment_id = "assign_1"
	snapshot.current_battle_id = "battle_1"
	snapshot.battle_server_host = "127.0.0.1"
	snapshot.battle_server_port = 9200

	assert_eq(RoomBattleEntryBuilderScript.build(snapshot), null, "builder should wait for battle_entry_ready")


func test_build_allows_active_battle_resume_context() -> void:
	var snapshot := RoomSnapshot.new()
	snapshot.battle_entry_ready = false
	snapshot.room_phase = "in_battle"
	snapshot.battle_phase = "active"
	snapshot.current_assignment_id = "assign_resume"
	snapshot.current_battle_id = "battle_resume"
	snapshot.current_match_id = "match_resume"
	snapshot.battle_server_host = "127.0.0.1"
	snapshot.battle_server_port = 9200

	var ctx = RoomBattleEntryBuilderScript.build(snapshot)

	assert_not_null(ctx, "active in_battle snapshot should build DS resume context")
	assert_eq(ctx.battle_id, "battle_resume", "resume context should keep battle id")
	assert_eq(ctx.match_id, "match_resume", "resume context should keep match id")


func test_build_maps_snapshot_and_source_room_fields() -> void:
	var snapshot := RoomSnapshot.new()
	snapshot.battle_entry_ready = true
	snapshot.current_assignment_id = "assign_1"
	snapshot.current_battle_id = "battle_1"
	snapshot.current_match_id = "match_1"
	snapshot.selected_map_id = "map_1"
	snapshot.rule_set_id = "rule_1"
	snapshot.mode_id = "mode_1"
	snapshot.battle_server_host = "10.0.0.2"
	snapshot.battle_server_port = 9200
	snapshot.room_return_policy = "return_to_source_room"
	snapshot.room_id = "room_1"
	snapshot.room_kind = "public_room"
	var entry_context := RoomEntryContextScript.new()
	entry_context.server_host = "10.0.0.1"
	entry_context.server_port = 9100

	var ctx = RoomBattleEntryBuilderScript.build(snapshot, entry_context)

	assert_not_null(ctx, "builder should create context")
	assert_eq(ctx.assignment_id, "assign_1", "context should keep assignment id")
	assert_eq(ctx.battle_id, "battle_1", "context should keep battle id")
	assert_eq(ctx.match_id, "match_1", "context should keep match id")
	assert_eq(ctx.map_id, "map_1", "context should keep map id")
	assert_eq(ctx.source_room_id, "room_1", "context should keep source room")
	assert_eq(ctx.source_server_host, "10.0.0.1", "context should keep source server host")
