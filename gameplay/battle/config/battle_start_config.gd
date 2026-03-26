class_name BattleStartConfig
extends RefCounted

var room_id: String = ""
var match_id: String = ""
var map_id: String = ""
var rule_set_id: String = ""
var players: Array[Dictionary] = []
var seed: int = 0
var start_tick: int = 0


func to_dict() -> Dictionary:
	return {
		"room_id": room_id,
		"match_id": match_id,
		"map_id": map_id,
		"rule_set_id": rule_set_id,
		"players": players.duplicate(true),
		"seed": seed,
		"start_tick": start_tick,
	}


static func from_dict(data: Dictionary) -> BattleStartConfig:
	var config := BattleStartConfig.new()
	config.room_id = String(data.get("room_id", ""))
	config.match_id = String(data.get("match_id", ""))
	config.map_id = String(data.get("map_id", ""))
	config.rule_set_id = String(data.get("rule_set_id", ""))
	config.players = data.get("players", []).duplicate(true)
	config.seed = int(data.get("seed", 0))
	config.start_tick = int(data.get("start_tick", 0))
	return config


func duplicate_deep() -> BattleStartConfig:
	return BattleStartConfig.from_dict(to_dict())


func sort_players() -> void:
	players.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var slot_a := int(a.get("slot_index", -1))
		var slot_b := int(b.get("slot_index", -1))
		if slot_a == slot_b:
			return int(a.get("peer_id", -1)) < int(b.get("peer_id", -1))
		return slot_a < slot_b
	)
