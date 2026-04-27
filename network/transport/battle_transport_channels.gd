class_name BattleTransportChannels
extends RefCounted

const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")

const CH_CRITICAL := 0
const CH_STATE := 1
const CH_INPUT := 2
const CH_CHECKPOINT := 3
const CH_DEBUG := 4
const CHANNEL_COUNT := 5


static func resolve_channel(message_type: String) -> int:
	match message_type:
		TransportMessageTypesScript.STATE_SUMMARY, TransportMessageTypesScript.STATE_DELTA:
			return CH_STATE
		TransportMessageTypesScript.INPUT_BATCH:
			return CH_INPUT
		TransportMessageTypesScript.CHECKPOINT, TransportMessageTypesScript.AUTHORITATIVE_SNAPSHOT:
			return CH_CHECKPOINT
		TransportMessageTypesScript.PING, TransportMessageTypesScript.PONG:
			return CH_DEBUG
		_:
			return CH_CRITICAL


static func resolve_transfer_mode(message_type: String) -> int:
	match message_type:
		TransportMessageTypesScript.STATE_SUMMARY, TransportMessageTypesScript.STATE_DELTA:
			return MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED
		TransportMessageTypesScript.INPUT_BATCH:
			return MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED
		TransportMessageTypesScript.PING, TransportMessageTypesScript.PONG:
			return MultiplayerPeer.TRANSFER_MODE_UNRELIABLE
		_:
			return MultiplayerPeer.TRANSFER_MODE_RELIABLE
