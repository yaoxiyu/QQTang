extends "res://tests/gut/base/qqt_unit_test.gd"

const RoomSelectionPolicyScript = preload("res://app/front/room/room_selection_policy.gd")
const RoomEntryContextScript = preload("res://app/front/room/room_entry_context.gd")
const FrontRoomKindScript = preload("res://app/front/navigation/front_room_kind.gd")
const MapSelectionCatalogScript = preload("res://content/maps/catalog/map_selection_catalog.gd")
const ModeCatalogScript = preload("res://content/modes/catalog/mode_catalog.gd")
const ClientConnectionConfigScript = preload("res://network/runtime/client_connection_config.gd")


func test_matchmade_selection_uses_locked_values() -> void:
	var entry_context := RoomEntryContextScript.new()
	entry_context.room_kind = FrontRoomKindScript.MATCHMADE_ROOM
	entry_context.locked_map_id = "locked_map"
	entry_context.locked_rule_set_id = "locked_rule"
	entry_context.locked_mode_id = "locked_mode"

	var result := RoomSelectionPolicyScript.resolve_default_selection(entry_context, "ignored_map")

	assert_eq(String(result.get("map_id", "")), "locked_map", "matchmade room should keep locked map")
	assert_eq(String(result.get("rule_set_id", "")), "locked_rule", "matchmade room should keep locked rule")
	assert_eq(String(result.get("mode_id", "")), "locked_mode", "matchmade room should keep locked mode")


func test_custom_selection_prefers_valid_preferred_map_binding() -> void:
	var preferred_map_id := MapSelectionCatalogScript.get_default_custom_room_map_id()
	var binding := MapSelectionCatalogScript.get_map_binding(preferred_map_id)

	var result := RoomSelectionPolicyScript.resolve_default_selection(null, preferred_map_id)

	assert_eq(String(result.get("map_id", "")), preferred_map_id, "custom room should preserve valid preferred map")
	assert_eq(String(result.get("rule_set_id", "")), String(binding.get("bound_rule_set_id", "")), "custom room should resolve bound rule")
	assert_eq(String(result.get("mode_id", "")), String(binding.get("bound_mode_id", "")), "custom room should resolve bound mode")


func test_sanitize_connection_selection_fills_map_binding_and_valid_mode() -> void:
	var config := ClientConnectionConfigScript.new()
	config.selected_map_id = ""
	config.selected_rule_set_id = "stale_rule"
	config.selected_mode_id = "missing_mode"

	RoomSelectionPolicyScript.sanitize_connection_selection(config, true)
	var binding := MapSelectionCatalogScript.get_map_binding(config.selected_map_id)

	assert_false(config.selected_map_id.is_empty(), "sanitize should fill default map")
	assert_eq(config.selected_rule_set_id, String(binding.get("bound_rule_set_id", "")), "sanitize should use map bound rule")
	assert_true(ModeCatalogScript.has_mode(config.selected_mode_id), "sanitize should leave a valid mode")


func test_locked_team_prefers_snapshot_then_entry_context() -> void:
	var snapshot := RoomSnapshot.new()
	var member := RoomMemberState.new()
	member.peer_id = 7
	member.team_id = 2
	snapshot.members.append(member)
	var entry_context := RoomEntryContextScript.new()
	entry_context.assigned_team_id = 1

	assert_eq(RoomSelectionPolicyScript.resolve_locked_team_id(snapshot, entry_context, 7, 9), 2, "snapshot team should win")
	assert_eq(RoomSelectionPolicyScript.resolve_locked_team_id(null, entry_context, 7, 9), 1, "entry assigned team should be fallback")
	assert_eq(RoomSelectionPolicyScript.resolve_locked_team_id(null, null, 7, 9), 9, "explicit fallback should be last resort")
