class_name TransportDebugSimulator
extends RefCounted

const TickRunnerScript = preload("res://gameplay/simulation/runtime/tick_runner.gd")

const LATENCY_PROFILES_MS: Array[int] = [0, 80, 150, 250]
const LOSS_PROFILES: Array[float] = [0.0, 0.05, 0.10, 0.20]

var latency_profile_index: int = 0
var loss_profile_index: int = 0
var jitter_ms: int = 0

var _stats: Dictionary = {
	"enqueued": 0,
	"delivered": 0,
	"dropped": 0,
}
var _message_rng: RandomNumberGenerator = RandomNumberGenerator.new()


func configure(rng_seed: int = 0) -> void:
	_message_rng.seed = rng_seed


func cycle_latency_profile() -> int:
	latency_profile_index = (latency_profile_index + 1) % LATENCY_PROFILES_MS.size()
	return get_latency_profile_ms()


func cycle_loss_profile() -> int:
	loss_profile_index = (loss_profile_index + 1) % LOSS_PROFILES.size()
	return get_packet_loss_percent()


func get_latency_profile_ms() -> int:
	return LATENCY_PROFILES_MS[latency_profile_index]


func get_packet_loss_percent() -> int:
	return int(round(LOSS_PROFILES[loss_profile_index] * 100.0))


func get_network_profile_summary() -> String:
	return "%dms / %d%%" % [get_latency_profile_ms(), get_packet_loss_percent()]


func current_latency_ticks() -> int:
	return int(ceil(float(get_latency_profile_ms()) / (TickRunnerScript.TICK_DT * 1000.0)))


func should_drop_message(message_type: String, droppable_types: Array[String]) -> bool:
	if message_type.is_empty():
		return false
	if not droppable_types.has(message_type):
		return false
	return LOSS_PROFILES[loss_profile_index] > 0.0 and _message_rng.randf() < LOSS_PROFILES[loss_profile_index]


func record_enqueued() -> void:
	_stats["enqueued"] = int(_stats.get("enqueued", 0)) + 1


func record_delivered() -> void:
	_stats["delivered"] = int(_stats.get("delivered", 0)) + 1


func record_dropped() -> void:
	_stats["dropped"] = int(_stats.get("dropped", 0)) + 1


func get_stats() -> Dictionary:
	return _stats.duplicate(true)


func reset_stats() -> void:
	_stats = {
		"enqueued": 0,
		"delivered": 0,
		"dropped": 0,
	}
