class_name RoomDirectorySnapshot
extends RefCounted

const RoomDirectoryEntryScript = preload("res://network/session/room/model/room_directory_entry.gd")

var revision: int = 0
var server_host: String = ""
var server_port: int = 0
var entries: Array[RoomDirectoryEntry] = []


func to_dict() -> Dictionary:
	var entry_dicts: Array[Dictionary] = []
	for entry in entries:
		if entry == null:
			continue
		entry_dicts.append(entry.to_dict())
	return {
		"revision": revision,
		"server_host": server_host,
		"server_port": server_port,
		"entries": entry_dicts,
	}


static func from_dict(data: Dictionary) -> RoomDirectorySnapshot:
	var snapshot := RoomDirectorySnapshot.new()
	snapshot.revision = int(data.get("revision", 0))
	snapshot.server_host = String(data.get("server_host", ""))
	snapshot.server_port = int(data.get("server_port", 0))
	var entry_variants: Array = data.get("entries", [])
	for entry_variant in entry_variants:
		if entry_variant is Dictionary:
			snapshot.entries.append(RoomDirectoryEntryScript.from_dict(entry_variant))
	return snapshot


func duplicate_deep() -> RoomDirectorySnapshot:
	return RoomDirectorySnapshot.from_dict(to_dict())
