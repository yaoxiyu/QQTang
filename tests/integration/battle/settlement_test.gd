extends Node


func _ready() -> void:
	run_all()


func run_all() -> void:
	_test_settlement_show_and_reset()
	_test_settlement_draw_result_uses_draw_title()
	_test_battle_hud_debug_dump_reports_text_state()
	_test_battle_hud_reports_item_pickup_message()


func _test_settlement_show_and_reset() -> void:
	var settlement := SettlementController.new()
	var result_label := Label.new()
	result_label.name = "ResultLabel"
	var detail_label := Label.new()
	detail_label.name = "DetailLabel"
	var map_summary_label := Label.new()
	map_summary_label.name = "MapSummaryLabel"
	var rule_summary_label := Label.new()
	rule_summary_label.name = "RuleSummaryLabel"
	var finish_reason_label := Label.new()
	finish_reason_label.name = "FinishReasonLabel"
	settlement.add_child(result_label)
	settlement.add_child(detail_label)
	settlement.add_child(map_summary_label)
	settlement.add_child(rule_summary_label)
	settlement.add_child(finish_reason_label)
	add_child(settlement)
	settlement._ready()

	var result := BattleResult.new()
	result.local_peer_id = 7
	result.winner_peer_ids = [7]
	result.eliminated_order = [3, 5]
	result.finish_reason = "last_alive"
	result.finish_tick = 120
	settlement.show_result(result)

	var shown_dump := settlement.debug_dump_settlement_state()
	_assert_true(bool(shown_dump.get("visible", false)), "settlement becomes visible after result")
	_assert_true(String(shown_dump.get("result_text", "")) == "Victory", "settlement shows local victory title")
	_assert_true(String(shown_dump.get("detail_text", "")).contains("FinishTick: 120"), "settlement detail includes finish tick")
	_assert_true(String(shown_dump.get("finish_reason_text", "")).contains("Reason:"), "settlement shows finish reason summary")

	settlement.reset_settlement()
	var reset_dump := settlement.debug_dump_settlement_state()
	_assert_true(not bool(reset_dump.get("visible", true)), "settlement reset hides panel")
	_assert_true(not bool(reset_dump.get("input_locked", true)), "settlement reset unlocks input")

	settlement.queue_free()


func _test_settlement_draw_result_uses_draw_title() -> void:
	var settlement := SettlementController.new()
	var result_label := Label.new()
	result_label.name = "ResultLabel"
	var detail_label := Label.new()
	detail_label.name = "DetailLabel"
	var map_summary_label := Label.new()
	map_summary_label.name = "MapSummaryLabel"
	var rule_summary_label := Label.new()
	rule_summary_label.name = "RuleSummaryLabel"
	var finish_reason_label := Label.new()
	finish_reason_label.name = "FinishReasonLabel"
	settlement.add_child(result_label)
	settlement.add_child(detail_label)
	settlement.add_child(map_summary_label)
	settlement.add_child(rule_summary_label)
	settlement.add_child(finish_reason_label)
	add_child(settlement)
	settlement._ready()

	var result := BattleResult.new()
	result.local_peer_id = 7
	result.finish_reason = "last_survivor"
	result.finish_tick = 88
	settlement.show_result(result)

	var shown_dump := settlement.debug_dump_settlement_state()
	_assert_true(String(shown_dump.get("result_text", "")) == "Draw", "settlement shows draw title when no winner survives")

	settlement.queue_free()


func _test_battle_hud_debug_dump_reports_text_state() -> void:
	var hud := BattleHudController.new()
	var countdown := CountdownPanel.new()
	var player_panel := PlayerStatusPanel.new()
	var network_panel := NetworkStatusPanel.new()
	var message_panel := MatchMessagePanel.new()

	add_child(hud)
	add_child(countdown)
	add_child(player_panel)
	add_child(network_panel)
	add_child(message_panel)

	hud.countdown_panel = countdown
	hud.player_status_panel = player_panel
	hud.network_status_panel = network_panel
	hud.match_message_panel = message_panel

	countdown.apply_countdown(40, 20)
	player_panel.apply_player_statuses([
		{
			"player_slot": 0,
			"alive": true,
			"life_state_text": "NORMAL",
			"bomb_available": 2,
			"bomb_capacity": 2,
			"bomb_range": 1,
		},
		{
			"player_slot": 1,
			"alive": false,
			"life_state_text": "DEAD",
			"bomb_available": 0,
			"bomb_capacity": 1,
			"bomb_range": 1,
		}
	])
	network_panel.apply_network_metrics({
		"latency_ms": 96,
		"ack_tick": 120,
		"rollback_count": 2,
		"predicted_tick": 123,
		"snapshot_tick": 118,
	})
	message_panel.apply_message("Victory")

	var dump := hud.debug_dump_hud_state()
	_assert_true(String(dump.get("countdown_text", "")) == "00:02", "battle hud dump exposes countdown text")
	_assert_true(String(dump.get("player_status_text", "")).contains("Bomb 2/2"), "battle hud dump exposes player status text")
	_assert_true(String(dump.get("network_status_text", "")).contains("Latency: 96ms"), "battle hud dump exposes network text")
	_assert_true(String(dump.get("match_message_text", "")) == "Victory", "battle hud dump exposes message text")

	hud.queue_free()
	countdown.queue_free()
	player_panel.queue_free()
	network_panel.queue_free()
	message_panel.queue_free()


func _test_battle_hud_reports_item_pickup_message() -> void:
	var hud := BattleHudController.new()
	var message_panel := MatchMessagePanel.new()
	add_child(hud)
	add_child(message_panel)
	hud.match_message_panel = message_panel

	var item_event := SimEvent.new(12, SimEvent.EventType.ITEM_PICKED)
	item_event.payload = {
		"player_id": 3,
		"item_type": 2,
	}
	hud.on_item_picked_event(item_event, 3)

	_assert_true(message_panel.text == "Bomb Capacity Up", "battle hud shows reusable item pickup message")

	hud.queue_free()
	message_panel.queue_free()


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] %s" % message)
		return
	push_error("[FAIL] %s" % message)
