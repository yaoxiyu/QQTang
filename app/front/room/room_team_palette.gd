class_name RoomTeamPalette
extends RefCounted

const TEAM_IDS: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8]
const TEAM_LABELS: Array[String] = ["A", "B", "C", "D", "E", "F", "G", "H"]
const TEAM_COLORS: Array[Color] = [
	Color(0.35, 0.47, 0.78, 1.0),
	Color(0.46, 0.36, 0.78, 1.0),
	Color(0.43, 0.75, 0.82, 1.0),
	Color(0.42, 0.80, 0.46, 1.0),
	Color(0.86, 0.86, 0.36, 1.0),
	Color(0.82, 0.40, 0.40, 1.0),
	Color(0.78, 0.36, 0.78, 1.0),
	Color(0.42, 0.44, 0.82, 1.0),
]


static func label_for_team(team_id: int) -> String:
	var index := clampi(team_id - 1, 0, TEAM_LABELS.size() - 1)
	return TEAM_LABELS[index]


static func color_for_team(team_id: int) -> Color:
	var index := clampi(team_id - 1, 0, TEAM_COLORS.size() - 1)
	return TEAM_COLORS[index]
