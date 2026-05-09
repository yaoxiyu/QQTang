# 角色：
# pass_phases 写入 / 排序 / 扁平化 / 反扁平化 / 阶段查询的统一入口。
# 帧同步要求：所有写入必须保证 player_id 升序，否则会破坏 checksum 稳定性。
#
# 类型注解约定：
# - BubblePassPhase 是 RefCounted 子类（class_name 在 bubble_pass_phase.gd 注册），
#   因为 Godot 全局 class cache 在语法预检阶段可能尚未填充该新类，
#   本文件在 API 签名里使用 Variant 表达单个 phase 实例，运行时由调用方与 helper 自身保证元素类型一致。
#
# 读写边界：
# - 任何修改 BubbleState.pass_phases 的代码都必须经由这里。
# - 不在此处实现规则推进（推进逻辑在 BubblePhaseAdvancer）。

class_name BubblePassPhaseHelper
extends RefCounted

const BubblePassPhaseScript = preload("res://gameplay/simulation/entities/bubble_pass_phase.gd")

const PHASE_FIELD_COUNT: int = 5  # [player_id, phase_x, sign_x, phase_y, sign_y]


static func find_phase(bubble: BubbleState, player_id: int) -> Variant:
	if bubble == null:
		return null
	for phase in bubble.pass_phases:
		if phase != null and int(phase.player_id) == player_id:
			return phase
	return null


static func has_phase(bubble: BubbleState, player_id: int) -> bool:
	return find_phase(bubble, player_id) != null


static func upsert_phase(bubble: BubbleState, phase) -> void:
	if bubble == null or phase == null:
		return
	for i in range(bubble.pass_phases.size()):
		var existing = bubble.pass_phases[i]
		if existing != null and int(existing.player_id) == int(phase.player_id):
			bubble.pass_phases[i] = phase
			sort_phases(bubble)
			return
	bubble.pass_phases.append(phase)
	sort_phases(bubble)


static func remove_phase(bubble: BubbleState, player_id: int) -> bool:
	if bubble == null:
		return false
	for i in range(bubble.pass_phases.size()):
		var existing = bubble.pass_phases[i]
		if existing != null and int(existing.player_id) == player_id:
			bubble.pass_phases.remove_at(i)
			return true
	return false


static func sort_phases(bubble: BubbleState) -> void:
	if bubble == null:
		return
	bubble.pass_phases.sort_custom(_compare_phase)


static func _compare_phase(a, b) -> bool:
	return int(a.player_id) < int(b.player_id)


# 扁平化为 [player_id, phase_x, sign_x, phase_y, sign_y, ...]
static func flatten(pass_phases: Array) -> PackedInt32Array:
	var packed := PackedInt32Array()
	packed.resize(pass_phases.size() * PHASE_FIELD_COUNT)
	var write := 0
	for phase in pass_phases:
		if phase == null:
			continue
		packed[write] = int(phase.player_id)
		packed[write + 1] = int(phase.phase_x)
		packed[write + 2] = int(phase.sign_x)
		packed[write + 3] = int(phase.phase_y)
		packed[write + 4] = int(phase.sign_y)
		write += PHASE_FIELD_COUNT
	if write != packed.size():
		packed.resize(write)
	return packed


# 反扁平化：raw 元素数必须是 5 的倍数；非整组的尾部直接忽略。
static func unflatten(raw: Variant) -> Array:
	var result: Array = []
	if raw == null:
		return result
	var packed: PackedInt32Array = _coerce_to_packed(raw)
	var i := 0
	while i + PHASE_FIELD_COUNT <= packed.size():
		var phase := BubblePassPhaseScript.new()
		phase.player_id = packed[i]
		phase.phase_x = packed[i + 1]
		phase.sign_x = packed[i + 2]
		phase.phase_y = packed[i + 3]
		phase.sign_y = packed[i + 4]
		result.append(phase)
		i += PHASE_FIELD_COUNT
	result.sort_custom(_compare_phase)
	return result


static func _coerce_to_packed(raw: Variant) -> PackedInt32Array:
	if raw is PackedInt32Array:
		return raw
	var packed := PackedInt32Array()
	if raw is Array:
		for value in raw:
			packed.append(int(value))
	return packed


# 在轴上把 phase 单调降级到至少 target_phase；若已在更深阶段则不动。
# 仅当从 A 升至 B 或从 B 升至 C 时设置 sign。返回 true 表示发生了变化。
static func try_advance_axis(
	phase,
	axis: int,
	target_phase: int,
	target_sign: int
) -> bool:
	if phase == null:
		return false
	var changed := false
	if axis == 0:
		if target_phase > int(phase.phase_x):
			phase.phase_x = target_phase
			phase.sign_x = target_sign if target_sign != 0 else int(phase.sign_x)
			changed = true
	else:
		if target_phase > int(phase.phase_y):
			phase.phase_y = target_phase
			phase.sign_y = target_sign if target_sign != 0 else int(phase.sign_y)
			changed = true
	return changed
