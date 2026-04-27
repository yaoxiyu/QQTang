extends "res://tests/gut/base/qqt_unit_test.gd"

const BattleTransportChannelsScript = preload("res://network/transport/battle_transport_channels.gd")
const ENetBattleTransportScript = preload("res://network/transport/enet_battle_transport.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")


func test_routes_critical_messages_to_reliable_critical_channel() -> void:
	_assert_route(TransportMessageTypesScript.MATCH_START, BattleTransportChannelsScript.CH_CRITICAL, MultiplayerPeer.TRANSFER_MODE_RELIABLE)
	_assert_route(TransportMessageTypesScript.OPENING_SNAPSHOT, BattleTransportChannelsScript.CH_CRITICAL, MultiplayerPeer.TRANSFER_MODE_RELIABLE)
	_assert_route(TransportMessageTypesScript.MATCH_FINISHED, BattleTransportChannelsScript.CH_CRITICAL, MultiplayerPeer.TRANSFER_MODE_RELIABLE)
	_assert_route("UNKNOWN_CRITICAL", BattleTransportChannelsScript.CH_CRITICAL, MultiplayerPeer.TRANSFER_MODE_RELIABLE)


func test_routes_state_messages_to_unreliable_ordered_state_channel() -> void:
	_assert_route(TransportMessageTypesScript.STATE_SUMMARY, BattleTransportChannelsScript.CH_STATE, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED)
	_assert_route("AUTHORITY_DELTA", BattleTransportChannelsScript.CH_STATE, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED)


func test_routes_input_messages_to_unreliable_ordered_input_channel() -> void:
	_assert_route(TransportMessageTypesScript.INPUT_FRAME, BattleTransportChannelsScript.CH_INPUT, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED)
	_assert_route(TransportMessageTypesScript.INPUT_BATCH, BattleTransportChannelsScript.CH_INPUT, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED)


func test_routes_checkpoint_messages_to_reliable_checkpoint_channel() -> void:
	_assert_route(TransportMessageTypesScript.CHECKPOINT, BattleTransportChannelsScript.CH_CHECKPOINT, MultiplayerPeer.TRANSFER_MODE_RELIABLE)
	_assert_route(TransportMessageTypesScript.AUTHORITATIVE_SNAPSHOT, BattleTransportChannelsScript.CH_CHECKPOINT, MultiplayerPeer.TRANSFER_MODE_RELIABLE)


func test_routes_debug_messages_to_unreliable_debug_channel() -> void:
	_assert_route(TransportMessageTypesScript.PING, BattleTransportChannelsScript.CH_DEBUG, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE)
	_assert_route(TransportMessageTypesScript.PONG, BattleTransportChannelsScript.CH_DEBUG, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE)


func test_transport_metrics_expose_promotion_counter_name() -> void:
	var transport = ENetBattleTransportScript.new()
	var metrics := transport.get_transport_metrics()
	assert_true(metrics.has("transport_unreliable_promoted_to_reliable_count"))
	assert_eq(int(metrics.get("transport_unreliable_promoted_to_reliable_count", -1)), 0)


func _assert_route(message_type: String, expected_channel: int, expected_mode: int) -> void:
	assert_eq(BattleTransportChannelsScript.resolve_channel(message_type), expected_channel)
	assert_eq(BattleTransportChannelsScript.resolve_transfer_mode(message_type), expected_mode)
