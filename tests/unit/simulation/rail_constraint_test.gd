extends Node

const RailConstraint = preload("res://gameplay/simulation/movement/rail_constraint.gd")


func _ready() -> void:
	_assert(
		RailConstraint.resolve_from_neighbors(true, true, false, false) == RailConstraint.Type.HORIZONTAL_RAIL,
		"up and down blocked resolve to horizontal rail"
	)
	_assert(
		RailConstraint.resolve_from_neighbors(false, false, true, true) == RailConstraint.Type.VERTICAL_RAIL,
		"left and right blocked resolve to vertical rail"
	)
	_assert(
		RailConstraint.resolve_from_neighbors(true, true, true, true) == RailConstraint.Type.CENTER_PIVOT,
		"four-side blocked resolves to center pivot"
	)
	_assert(
		RailConstraint.resolve_from_neighbors(false, true, false, true) == RailConstraint.Type.FREE,
		"mixed non-paired blockers remain free"
	)
	_assert(
		RailConstraint.requires_center_for_vertical_turn(RailConstraint.Type.HORIZONTAL_RAIL),
		"horizontal rail requires center before vertical turn"
	)
	_assert(
		RailConstraint.requires_center_for_horizontal_turn(RailConstraint.Type.VERTICAL_RAIL),
		"vertical rail requires center before horizontal turn"
	)

	print("test_rail_constraint: PASS")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("test_rail_constraint: FAIL - %s" % message)
