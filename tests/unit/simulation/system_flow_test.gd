extends "res://tests/gut/base/qqt_unit_test.gd"

var world: SimWorld

func test_main() -> void:
	world = SimWorld.new()
	world.bootstrap(SimConfig.new(), {"grid": BuiltinMapFactory.build_basic_map()})

	var players := world.state.players.active_ids
	_assert(players.size() >= 2, "need at least 2 players")
	var attacker_id := players[0]
	var victim_id := players[1]

	var attacker := world.state.players.get_player(attacker_id)
	var victim := world.state.players.get_player(victim_id)
	_assert(attacker != null and victim != null, "players should exist")

	# 将 victim 放到攻击者右侧一格，确保爆炸可命中	victim.cell_x = attacker.cell_x + 1
	victim.cell_y = attacker.cell_y
	world.state.players.update_player(victim)
	world.state.indexes.rebuild_from_state(world.state)

	var place_frame := InputFrame.new()
	place_frame.tick = world.state.match_state.tick + 1
	var place_cmd := PlayerCommand.new()
	place_cmd.place_bubble = true
	place_frame.set_command(attacker.player_slot, place_cmd)
	world.enqueue_input(place_frame)

	var place_result := world.step()
	_assert(_has_event(place_result["events"], SimEvent.EventType.BUBBLE_PLACED), "bubble placed event expected")
	_assert(world.state.bubbles.active_ids.size() == 1, "bubble should exist")

	var bubble_id := world.state.bubbles.active_ids[0]
	var bubble := world.state.bubbles.get_bubble(bubble_id)
	_assert(bubble != null, "bubble object should exist")

	var exploded := false
	var killed := false
	while world.state.match_state.tick <= bubble.explode_tick:
		var result = world.step()
		exploded = exploded or _has_event(result["events"], SimEvent.EventType.BUBBLE_EXPLODED)
		killed = killed or _has_event(result["events"], SimEvent.EventType.PLAYER_KILLED)

	var victim_after := world.state.players.get_player(victim_id)
	_assert(victim_after != null and not victim_after.alive, "victim should be killed by explosion")
	_assert(exploded, "explosion event should be emitted")
	_assert(killed, "player killed event should be emitted")
	_assert(world.state.match_state.phase == MatchState.Phase.ENDED, "match should end after one survivor")


func _has_event(events: Array, event_type: int) -> bool:
	for event in events:
		if event is SimEvent and event.event_type == event_type:
			return true
	return false

func _assert(condition: bool, message: String) -> void:
	assert_true(condition, message)

