extends "res://tests/gut/base/qqt_unit_test.gd"

const Schema = preload("res://gameplay/native_bridge/native_battle_packed_schema.gd")
const BuilderScript = preload("res://gameplay/native_bridge/native_battle_packed_state_builder.gd")
const ReaderScript = preload("res://gameplay/native_bridge/native_battle_packed_state_reader.gd")


func test_empty_state_header_uses_schema_version() -> void:
	var builder := BuilderScript.new()
	var state := builder.build_empty(42, 15, 11)
	var header: PackedInt32Array = state["header"]

	assert_eq(int(state.get("schema_version", 0)), Schema.SCHEMA_VERSION, "top-level schema version should match")
	assert_eq(header[Schema.HEADER_SCHEMA_VERSION], Schema.SCHEMA_VERSION, "header schema version should match")
	assert_eq(ReaderScript.get_tick_id(state), 42, "reader should return tick id")
	assert_eq(header[Schema.HEADER_GRID_CELL_COUNT], 165, "grid cell count should be width * height")


func test_native_codec_reports_same_schema_version_when_available() -> void:
	if not ClassDB.can_instantiate("QQTNativePackedStateCodec"):
		pending("native packed state codec is not available in this runtime")
		return
	var codec = ClassDB.instantiate("QQTNativePackedStateCodec")
	assert_true(codec.has_method("get_battle_packed_schema_version"), "native codec should expose packed schema version")
	assert_eq(int(codec.get_battle_packed_schema_version()), Schema.SCHEMA_VERSION, "native codec schema version should match GDScript schema")


func test_append_player_updates_count_and_stride() -> void:
	var builder := BuilderScript.new()
	var state := builder.build_empty(1, 10, 10)

	builder.append_player(state, {
		"player_id": "player_alpha",
		"team_id": "team_a",
		"x_subcell": 100,
		"y_subcell": 200,
		"alive": true,
	})

	var players: PackedInt32Array = state["players"]
	assert_eq(ReaderScript.get_player_count(state), 1, "player count should update")
	assert_eq(players.size(), Schema.PLAYER_STRIDE, "player array should grow by one stride")
	assert_eq(players[Schema.PLAYER_X_SUBCELL], 100, "player x should be packed")
	assert_eq(players[Schema.PLAYER_Y_SUBCELL], 200, "player y should be packed")


func test_stable_hash_is_stable_for_same_input() -> void:
	assert_eq(Schema.stable_hash("player_alpha"), Schema.stable_hash("player_alpha"), "stable hash should be deterministic")


func test_append_bubble_item_and_grid_update_arrays() -> void:
	var builder := BuilderScript.new()
	var state := builder.build_empty(1, 10, 10)

	builder.append_bubble(state, {"entity_id": 7, "cell_x": 3, "cell_y": 4, "fire_power": 2, "bubble_type": 2, "footprint_cells": 4})
	builder.append_item(state, {"entity_id": 9, "item_type": 2, "cell_x": 5, "cell_y": 6})
	builder.append_grid_cell(state, {"tile_type": 1, "tile_flags": 4})

	assert_eq(ReaderScript.get_bubble_count(state), 1, "bubble count should update")
	assert_eq(ReaderScript.get_item_count(state), 1, "item count should update")
	assert_eq((state["bubbles"] as PackedInt32Array).size(), Schema.BUBBLE_STRIDE, "bubble array should grow by one stride")
	assert_eq((state["bubbles"] as PackedInt32Array)[Schema.BUBBLE_TYPE], 2, "bubble type should be packed into reserved field")
	assert_eq((state["bubbles"] as PackedInt32Array)[Schema.BUBBLE_FOOTPRINT_CELLS], 4, "bubble footprint should be packed into reserved field")
	assert_eq((state["items"] as PackedInt32Array).size(), Schema.ITEM_STRIDE, "item array should grow by one stride")
	assert_eq((state["grid"] as PackedInt32Array).size(), Schema.GRID_STRIDE, "grid array should grow by one stride")


func test_build_from_snapshot_packs_snapshot_sections() -> void:
	var builder := BuilderScript.new()
	var snapshot := WorldSnapshot.new()
	snapshot.tick_id = 77
	snapshot.players = [{"entity_id": 1, "cell_x": 1, "cell_y": 2, "alive": true}]
	snapshot.bubbles = [{"entity_id": 2, "cell_x": 3, "cell_y": 4}]
	snapshot.items = [{"entity_id": 3, "item_type": 2, "cell_x": 5, "cell_y": 6}]
	snapshot.walls = [{"tile_type": 1, "tile_flags": 4}]

	var state := builder.build_from_snapshot(snapshot, 12, 8)
	var players: PackedInt32Array = state["players"]

	assert_eq(ReaderScript.get_tick_id(state), 77, "snapshot tick should be packed")
	assert_eq(ReaderScript.get_player_count(state), 1, "snapshot players should be packed")
	assert_eq(players[Schema.PLAYER_X_SUBCELL], 1, "snapshot player cell_x should map to packed x when subcell is absent")
	assert_eq(players[Schema.PLAYER_Y_SUBCELL], 2, "snapshot player cell_y should map to packed y when subcell is absent")
	assert_eq(ReaderScript.get_bubble_count(state), 1, "snapshot bubbles should be packed")
	assert_eq(ReaderScript.get_item_count(state), 1, "snapshot items should be packed")
	assert_eq(ReaderScript.get_grid_cell_count(state), 96, "grid count should come from map dimensions")
