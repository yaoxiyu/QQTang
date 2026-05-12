# ------------------------------------------------------------------
# DEV MODE ONLY: Client-side O-key interceptor for DS_CLIENT battles.
# Sends DEV_TOGGLE_AI to the dev DS so the human can pause/resume the
# server-side AI input drivers. This file is wired only by the dev
# battle launcher and is never referenced by production code paths.
# ------------------------------------------------------------------
extends Node

const DEV_TOGGLE_AI_MESSAGE_TYPE := "DEV_TOGGLE_AI"
const LOG_PREFIX := "[dev_ds_ai_toggle]"

var _session_adapter: Node = null
var _enabled_state: bool = true


func configure(session_adapter: Node) -> void:
	_session_adapter = session_adapter


func _input(event: InputEvent) -> void:
	if event == null or not (event is InputEventKey):
		return
	if not event.pressed or event.echo:
		return
	if event.keycode != KEY_O:
		return
	get_viewport().set_input_as_handled()
	_toggle_remote_ai()


func _toggle_remote_ai() -> void:
	if _session_adapter == null:
		print("%s session_adapter missing, ignoring O" % LOG_PREFIX)
		return
	var transport = _session_adapter.transport
	if transport == null:
		print("%s transport missing, ignoring O" % LOG_PREFIX)
		return
	_enabled_state = not _enabled_state
	var payload := {
		"message_type": DEV_TOGGLE_AI_MESSAGE_TYPE,
		"msg_type": DEV_TOGGLE_AI_MESSAGE_TYPE,
		"enabled": _enabled_state,
	}
	transport.send_to_peer(1, payload)
	print("%s sent DEV_TOGGLE_AI enabled=%s" % [LOG_PREFIX, str(_enabled_state)])
# ------------------------------------------------------------------
# END DEV MODE ONLY
# ------------------------------------------------------------------
