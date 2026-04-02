class_name BattleMetaPanel
extends PanelContainer

@export var map_name_label_path: NodePath = ^"VBoxContainer/MapNameLabel"
@export var rule_name_label_path: NodePath = ^"VBoxContainer/RuleNameLabel"
@export var match_meta_label_path: NodePath = ^"VBoxContainer/MatchMetaLabel"

var map_name_label: Label = null
var rule_name_label: Label = null
var match_meta_label: Label = null
var _pending_map_display_name: String = ""
var _pending_rule_display_name: String = ""
var _pending_match_meta_text: String = ""


func _ready() -> void:
	if has_node(map_name_label_path):
		map_name_label = get_node(map_name_label_path)
	if has_node(rule_name_label_path):
		rule_name_label = get_node(rule_name_label_path)
	if has_node(match_meta_label_path):
		match_meta_label = get_node(match_meta_label_path)
	_apply_pending_metadata()


func apply_metadata(map_display_name: String, rule_display_name: String, match_meta_text: String) -> void:
	_pending_map_display_name = map_display_name
	_pending_rule_display_name = rule_display_name
	_pending_match_meta_text = match_meta_text
	_apply_pending_metadata()


func _apply_pending_metadata() -> void:
	if map_name_label != null:
		map_name_label.text = "地图: %s" % _pending_map_display_name
	if rule_name_label != null:
		rule_name_label.text = "规则: %s" % _pending_rule_display_name
	if match_meta_label != null:
		match_meta_label.text = _pending_match_meta_text


func debug_dump_state() -> Dictionary:
	return {
		"map_text": map_name_label.text if map_name_label != null else "",
		"rule_text": rule_name_label.text if rule_name_label != null else "",
		"match_text": match_meta_label.text if match_meta_label != null else "",
	}
