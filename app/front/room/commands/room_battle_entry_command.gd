class_name RoomBattleEntryCommand
extends RefCounted

const RoomErrorMapperScript = preload("res://app/front/room/errors/room_error_mapper.gd")


func can_enter_battle(app_runtime: Object, battle_entry: Dictionary) -> Dictionary:
	if app_runtime == null:
		return RoomErrorMapperScript.to_front_error("APP_RUNTIME_MISSING")
	if battle_entry.is_empty():
		return RoomErrorMapperScript.to_front_error("BATTLE_ENTRY_MISSING", "战斗入口数据为空")
	return {"ok": true}


func can_use_battle_entry_context(app_runtime: Object, battle_entry_context) -> Dictionary:
	if app_runtime == null:
		return RoomErrorMapperScript.to_front_error("APP_RUNTIME_MISSING")
	if battle_entry_context == null:
		return RoomErrorMapperScript.to_front_error("BATTLE_ENTRY_MISSING", "战斗入口数据为空")
	return {"ok": true}
