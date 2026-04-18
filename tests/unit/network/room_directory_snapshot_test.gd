extends "res://tests/gut/base/qqt_unit_test.gd"

const RoomDirectoryEntryScript = preload("res://network/session/runtime/room_directory_entry.gd")
const RoomDirectorySnapshotScript = preload("res://network/session/runtime/room_directory_snapshot.gd")


func test_main() -> void:
	var ok := true
	ok = _test_snapshot_roundtrip_preserves_entries() and ok
	ok = _test_duplicate_deep_returns_independent_copy() and ok


func _test_snapshot_roundtrip_preserves_entries() -> bool:
	var snapshot := RoomDirectorySnapshotScript.new()
	snapshot.revision = 7
	snapshot.server_host = "10.0.0.8"
	snapshot.server_port = 9900
	snapshot.entries = [_make_entry("ROOM-A", "Alpha", true), _make_entry("ROOM-B", "Beta", false)]

	var restored := RoomDirectorySnapshotScript.from_dict(snapshot.to_dict())
	var prefix := "room_directory_snapshot_test"
	var ok := true
	ok = qqt_check(restored.revision == 7, "revision should survive roundtrip", prefix) and ok
	ok = qqt_check(restored.server_host == "10.0.0.8", "server_host should survive roundtrip", prefix) and ok
	ok = qqt_check(restored.server_port == 9900, "server_port should survive roundtrip", prefix) and ok
	ok = qqt_check(restored.entries.size() == 2, "entries should survive roundtrip", prefix) and ok
	ok = qqt_check(restored.entries[0].room_display_name == "Alpha", "entry display name should survive roundtrip", prefix) and ok
	ok = qqt_check(restored.entries[1].joinable == false, "entry joinable flag should survive roundtrip", prefix) and ok
	return ok


func _test_duplicate_deep_returns_independent_copy() -> bool:
	var snapshot := RoomDirectorySnapshotScript.new()
	snapshot.entries = [_make_entry("ROOM-C", "Gamma", true)]

	var duplicated := snapshot.duplicate_deep()
	duplicated.entries[0].room_display_name = "Mutated"

	return qqt_check(
		snapshot.entries[0].room_display_name == "Gamma",
		"duplicate_deep should not mutate original entry",
		"room_directory_snapshot_test"
	)


func _make_entry(room_id: String, room_display_name: String, joinable: bool):
	var entry := RoomDirectoryEntryScript.new()
	entry.room_id = room_id
	entry.room_display_name = room_display_name
	entry.room_kind = "public_room"
	entry.owner_peer_id = 1
	entry.owner_name = "Owner"
	entry.selected_map_id = "map"
	entry.rule_set_id = "rule"
	entry.mode_id = "mode"
	entry.member_count = 1
	entry.max_players = 4
	entry.match_active = not joinable
	entry.joinable = joinable
	return entry

