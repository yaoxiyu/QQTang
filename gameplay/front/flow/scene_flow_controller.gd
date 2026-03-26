class_name SceneFlowController
extends Node

signal scene_change_requested(target_path: String)
signal scene_changed(target_path: String)

const ROOM_SCENE_PATH: String = "res://scenes/front/room_scene.tscn"
const LOADING_SCENE_PATH: String = "res://scenes/front/loading_scene.tscn"
const BATTLE_SCENE_PATH: String = "res://scenes/battle/battle_main.tscn"

var current_scene_path: String = ""


func change_to_room_scene() -> Error:
	return change_scene_to_path(ROOM_SCENE_PATH)


func change_to_loading_scene() -> Error:
	return change_scene_to_path(LOADING_SCENE_PATH)


func change_to_battle_scene() -> Error:
	return change_scene_to_path(BATTLE_SCENE_PATH)


func change_scene_to_path(target_path: String) -> Error:
	if target_path.is_empty():
		return ERR_INVALID_PARAMETER

	scene_change_requested.emit(target_path)

	var tree := get_tree()
	if tree == null:
		return ERR_UNCONFIGURED

	var result := tree.change_scene_to_file(target_path)
	if result == OK:
		current_scene_path = target_path
		scene_changed.emit(target_path)
	return result
