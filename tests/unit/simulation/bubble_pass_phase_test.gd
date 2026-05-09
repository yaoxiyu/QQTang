extends "res://tests/gut/base/qqt_unit_test.gd"

# 验证泡泡阻挡的双轴 phase 状态机：A→B→C 单调推进、单向墙、双轴独立。
# 注意：本测试只覆盖 BubblePassPhaseHelper / BubblePhaseAdvancer / SimQueries 的纯逻辑判定，
# 不进入 MovementSystem 完整子步循环——确保任何重写都能直接捕捉模型层的回归。

const BubblePassPhaseScript = preload("res://gameplay/simulation/entities/bubble_pass_phase.gd")
const BubblePassPhaseHelper = preload("res://gameplay/simulation/movement/bubble_pass_phase_helper.gd")
const BubblePhaseAdvancer = preload("res://gameplay/simulation/movement/bubble_phase_advancer.gd")
const GridMotionMath = preload("res://gameplay/simulation/movement/grid_motion_math.gd")
const M := GridMotionMath.CELL_UNITS  # 1000
const HALF_M := GridMotionMath.HALF_CELL_UNITS  # 500


func test_main() -> void:
	_test_phase_helper_upsert_keeps_player_id_sorted()
	_test_flatten_unflatten_roundtrip()
	_test_axis_advance_a_to_b_locks_sign()
	_test_axis_advance_b_to_c_keeps_sign()
	_test_axis_does_not_regress_when_player_returns()
	_test_two_axes_advance_independently()
	_test_phase_blocks_returns_false_in_a_a()
	_test_phase_blocks_b_single_directional_wall()
	_test_phase_blocks_c_full_block()
	_test_lazy_init_disabled_treats_missing_as_blocked()


func _test_phase_helper_upsert_keeps_player_id_sorted() -> void:
	var bubble := BubbleState.new()
	for pid in [5, 1, 3, 2]:
		var phase = BubblePassPhaseScript.new()
		phase.player_id = pid
		BubblePassPhaseHelper.upsert_phase(bubble, phase)
	_assert(bubble.pass_phases.size() == 4, "upsert should append unique phases")
	for i in range(bubble.pass_phases.size() - 1):
		var a: int = int(bubble.pass_phases[i].player_id)
		var b: int = int(bubble.pass_phases[i + 1].player_id)
		_assert(a < b, "pass_phases must remain ascending by player_id (got %d before %d)" % [a, b])

	# 重复 upsert 同一 player 应替换而非追加。
	var replaced = BubblePassPhaseScript.new()
	replaced.player_id = 3
	replaced.phase_x = BubblePassPhaseScript.Phase.B
	BubblePassPhaseHelper.upsert_phase(bubble, replaced)
	_assert(bubble.pass_phases.size() == 4, "duplicate player_id upsert must not grow array")
	_assert(int(BubblePassPhaseHelper.find_phase(bubble, 3).phase_x) == BubblePassPhaseScript.Phase.B, "upsert should replace existing entry")


func _test_flatten_unflatten_roundtrip() -> void:
	var phases: Array = []
	var p1 = BubblePassPhaseScript.new()
	p1.player_id = 1
	p1.phase_x = BubblePassPhaseScript.Phase.B
	p1.sign_x = 1
	p1.phase_y = BubblePassPhaseScript.Phase.A
	phases.append(p1)
	var p2 = BubblePassPhaseScript.new()
	p2.player_id = 5
	p2.phase_x = BubblePassPhaseScript.Phase.C
	p2.sign_x = -1
	p2.phase_y = BubblePassPhaseScript.Phase.B
	p2.sign_y = 1
	phases.append(p2)

	var flat: PackedInt32Array = BubblePassPhaseHelper.flatten(phases)
	_assert(flat.size() == 2 * BubblePassPhaseHelper.PHASE_FIELD_COUNT, "flatten size must equal entries * 5")

	var restored: Array = BubblePassPhaseHelper.unflatten(flat)
	_assert(restored.size() == 2, "unflatten should produce 2 entries")
	_assert(int(restored[0].player_id) == 1 and int(restored[0].phase_x) == BubblePassPhaseScript.Phase.B, "first entry roundtrips")
	_assert(int(restored[1].player_id) == 5 and int(restored[1].sign_x) == -1, "second entry roundtrips negative sign")


func _test_axis_advance_a_to_b_locks_sign() -> void:
	var phase = BubblePassPhaseScript.new()
	phase.player_id = 1
	# 玩家从中心 d=0 移动到 d=+M/2 (刚好达到 B 阈值)
	BubblePhaseAdvancer._advance_axes(phase, HALF_M, 0)
	_assert(int(phase.phase_x) == BubblePassPhaseScript.Phase.B, "|d|=M/2 应触发 A→B")
	_assert(int(phase.sign_x) == 1, "正向出去应锁定 sign_x=+1")
	_assert(int(phase.phase_y) == BubblePassPhaseScript.Phase.A, "y 轴未达阈值，保持 A")


func _test_axis_advance_b_to_c_keeps_sign() -> void:
	var phase = BubblePassPhaseScript.new()
	phase.player_id = 1
	BubblePhaseAdvancer._advance_axes(phase, HALF_M, 0)
	BubblePhaseAdvancer._advance_axes(phase, M, 0)
	_assert(int(phase.phase_x) == BubblePassPhaseScript.Phase.C, "|d|=M 应触发 B→C")
	_assert(int(phase.sign_x) == 1, "B→C 不重设 sign")


func _test_axis_does_not_regress_when_player_returns() -> void:
	var phase = BubblePassPhaseScript.new()
	phase.player_id = 1
	# 推到 B 阶段
	BubblePhaseAdvancer._advance_axes(phase, HALF_M, 0)
	_assert(int(phase.phase_x) == BubblePassPhaseScript.Phase.B, "must reach B first")
	# 玩家被推回到 d=0：phase 不应回退到 A。
	BubblePhaseAdvancer._advance_axes(phase, 0, 0)
	_assert(int(phase.phase_x) == BubblePassPhaseScript.Phase.B, "phase 单调，不可回退")


func _test_two_axes_advance_independently() -> void:
	var phase = BubblePassPhaseScript.new()
	phase.player_id = 1
	# x 推到 B(+)，y 仍在 A
	BubblePhaseAdvancer._advance_axes(phase, HALF_M, 0)
	_assert(int(phase.phase_x) == BubblePassPhaseScript.Phase.B and int(phase.phase_y) == BubblePassPhaseScript.Phase.A, "x=B, y=A independent")
	# y 单独推到 B(-)，x 不变
	BubblePhaseAdvancer._advance_axes(phase, 0, -HALF_M)
	_assert(int(phase.phase_y) == BubblePassPhaseScript.Phase.B, "y reaches B")
	_assert(int(phase.sign_y) == -1, "y locks negative sign")
	_assert(int(phase.phase_x) == BubblePassPhaseScript.Phase.B and int(phase.sign_x) == 1, "x state preserved")


func _test_phase_blocks_returns_false_in_a_a() -> void:
	var phase = BubblePassPhaseScript.new()
	phase.player_id = 1
	# 在中心位置（d=0,0）：A,A → 不阻挡。
	var blocks: bool = SimQueries._phase_blocks(phase, 0, 0)
	_assert(not blocks, "A/A 任意位置都不应阻挡")
	blocks = SimQueries._phase_blocks(phase, 200, -300)
	_assert(not blocks, "A/A 即使有偏移也不应阻挡")


func _test_phase_blocks_b_single_directional_wall() -> void:
	# X 在 B(+) — 玩家被推到右侧；不能再让 d_x 减小到 M/2 以下。
	var phase = BubblePassPhaseScript.new()
	phase.player_id = 1
	phase.phase_x = BubblePassPhaseScript.Phase.B
	phase.sign_x = 1
	phase.phase_y = BubblePassPhaseScript.Phase.A
	# d_x = M/2，刚好满足约束（>=M/2），不阻挡。
	_assert(not SimQueries._phase_blocks(phase, HALF_M, 0), "d_x 恰好等于 M/2 时不阻挡")
	# d_x = M/2 - 1，违反 → 阻挡。
	_assert(SimQueries._phase_blocks(phase, HALF_M - 1, 0), "d_x < M/2 时阻挡（单向墙）")
	# 继续向右走 d_x = 700，仍允许（没回退到左侧）。
	_assert(not SimQueries._phase_blocks(phase, 700, 0), "继续向右走不阻挡")
	# y 任意（A 自由）。
	_assert(not SimQueries._phase_blocks(phase, HALF_M, 999), "y 在 A 时随便偏移不影响")


func _test_phase_blocks_c_full_block() -> void:
	var phase = BubblePassPhaseScript.new()
	phase.player_id = 1
	phase.phase_x = BubblePassPhaseScript.Phase.C
	phase.sign_x = 1
	phase.phase_y = BubblePassPhaseScript.Phase.A
	_assert(SimQueries._phase_blocks(phase, M - 1, 0), "C(s=+) 下 d_x < M 时阻挡")
	_assert(not SimQueries._phase_blocks(phase, M, 0), "C(s=+) 下 d_x = M 不再重叠也不阻挡")


func _test_lazy_init_disabled_treats_missing_as_blocked() -> void:
	# 默认 mode=0：bubble.pass_phases 中无该玩家 → is_bubble_blocking_at_pos 返回 true。
	# 这里通过直接构造 SimWorld 绕开太重，改为验证 _phase_blocks/_compute_lazy_phase 的契约：
	var lazy = SimQueries._compute_lazy_phase(M / 4, 0)
	_assert(int(lazy.phase_x) == BubblePassPhaseScript.Phase.A, "懒初始化 |d|<M/2 → A")
	_assert(int(lazy.phase_y) == BubblePassPhaseScript.Phase.A, "y 同")
	var lazy2 = SimQueries._compute_lazy_phase(700, -800)
	_assert(int(lazy2.phase_x) == BubblePassPhaseScript.Phase.B and int(lazy2.sign_x) == 1, "懒初始化 |d|∈[M/2,M) → B(s)")
	_assert(int(lazy2.phase_y) == BubblePassPhaseScript.Phase.B and int(lazy2.sign_y) == -1, "y 同")
	var lazy3 = SimQueries._compute_lazy_phase(M, M)
	_assert(int(lazy3.phase_x) == BubblePassPhaseScript.Phase.C, "懒初始化 |d|>=M → C")


func _assert(condition: bool, message: String) -> void:
	assert_true(condition, message)
