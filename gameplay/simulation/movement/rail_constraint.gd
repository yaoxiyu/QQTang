class_name RailConstraint
extends RefCounted

enum Type {
	FREE,
	HORIZONTAL_RAIL,
	VERTICAL_RAIL,
	CENTER_PIVOT,
}


static func resolve_from_neighbors(
	up_blocked: bool,
	down_blocked: bool,
	left_blocked: bool,
	right_blocked: bool
) -> int:
	var horizontal_rail := up_blocked and down_blocked
	var vertical_rail := left_blocked and right_blocked

	if horizontal_rail and vertical_rail:
		return Type.CENTER_PIVOT
	if horizontal_rail:
		return Type.HORIZONTAL_RAIL
	if vertical_rail:
		return Type.VERTICAL_RAIL
	return Type.FREE


static func requires_center_for_vertical_turn(rail: int) -> bool:
	return rail == Type.HORIZONTAL_RAIL or rail == Type.CENTER_PIVOT


static func requires_center_for_horizontal_turn(rail: int) -> bool:
	return rail == Type.VERTICAL_RAIL or rail == Type.CENTER_PIVOT
