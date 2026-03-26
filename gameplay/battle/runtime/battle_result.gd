class_name BattleResult
extends RefCounted

var winner_peer_ids: Array[int] = []
var eliminated_order: Array[int] = []
var finish_reason: String = ""
var finish_tick: int = 0


func to_dict() -> Dictionary:
	return {
		"winner_peer_ids": winner_peer_ids.duplicate(),
		"eliminated_order": eliminated_order.duplicate(),
		"finish_reason": finish_reason,
		"finish_tick": finish_tick,
	}


static func from_dict(data: Dictionary) -> BattleResult:
	var result := BattleResult.new()
	result.winner_peer_ids.assign(data.get("winner_peer_ids", []))
	result.eliminated_order.assign(data.get("eliminated_order", []))
	result.finish_reason = String(data.get("finish_reason", ""))
	result.finish_tick = int(data.get("finish_tick", 0))
	return result


func duplicate_deep() -> BattleResult:
	return BattleResult.from_dict(to_dict())
