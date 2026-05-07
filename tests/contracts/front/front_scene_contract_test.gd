extends "res://tests/gut/base/qqt_contract_test.gd"

const SceneFlowControllerScript = preload("res://app/flow/scene_flow_controller.gd")

const FORMAL_FRONT_SCENES := {
	"res://scenes/front/boot_scene.tscn": [
		"BootRoot",
		"BootRoot/CenterPanel/MarginContainer/MainLayout/TitleLabel",
		"BootRoot/CenterPanel/MarginContainer/MainLayout/StatusLabel",
		"BootRoot/CenterPanel/MarginContainer/MainLayout/HintLabel",
	],
	"res://scenes/front/login_scene.tscn": [
		"LoginRoot",
		"LoginRoot/MainLayout/ProfileCard/ProfileVBox/PlayerNameRow/PlayerNameInput",
		"LoginRoot/MainLayout/EndpointCard/EndpointVBox/HostRow/HostInput",
		"LoginRoot/MainLayout/ActionRow/EnterLobbyButton",
		"LoginRoot/MainLayout/MessageLabel",
	],
	"res://scenes/front/lobby_scene.tscn": [
		"LobbyRoot",
		"LobbyRoot/MainLayout/HeaderRow/CurrentProfileLabel",
		"LobbyRoot/MainLayout/ScrollArea/ScrollContent/PracticeCard/PracticeVBox/StartPracticeButton",
		"LobbyRoot/MainLayout/ScrollArea/ScrollContent/OnlineCard/OnlineVBox/CreateRoomRow/CreateRoomButton",
		"LobbyRoot/MainLayout/ScrollArea/ScrollContent/OnlineCard/OnlineVBox/JoinRoomRow/JoinRoomButton",
		"LobbyRoot/MainLayout/ScrollArea/ScrollContent/MessageLabel",
	],
		"res://scenes/front/room/room_formal.tscn": [
			"RoomFormal",
			"RoomFormal/BgPanel",
			"RoomFormal/RuleSelect/ChooseModeBtn",
			"RoomFormal/RuleSelect/ChooseMapBtn",
			"RoomFormal/BottomBar/RoomActionBtn",
			"RoomFormal/BottomBar/LeaveBtn",
			"RoomFormal/RoleSelectPanel/CharacterGrid/CharIcon0",
		],
}


func test_main() -> void:
	_main_body()


func _main_body() -> void:
	_test_scene_flow_uses_formal_front_paths()
	_test_front_scenes_load_and_expose_required_nodes()


func _test_scene_flow_uses_formal_front_paths() -> void:
	_assert_true(
		SceneFlowControllerScript.BOOT_SCENE_PATH == "res://scenes/front/boot_scene.tscn",
		"scene flow points boot to formal boot scene"
	)
	_assert_true(
		SceneFlowControllerScript.LOGIN_SCENE_PATH == "res://scenes/front/login_scene.tscn",
		"scene flow points login to formal login scene"
	)
	_assert_true(
		SceneFlowControllerScript.LOBBY_SCENE_PATH == "res://scenes/front/lobby_scene.tscn",
		"scene flow points lobby to formal lobby scene"
	)
	_assert_true(
		SceneFlowControllerScript.ROOM_SCENE_PATH == "res://scenes/front/room/room_formal.tscn",
		"scene flow points room to formal room scene"
	)


func _test_front_scenes_load_and_expose_required_nodes() -> void:
	for scene_path in FORMAL_FRONT_SCENES.keys():
		var scene: PackedScene = load(scene_path)
		_assert_true(scene != null, "%s loads successfully" % scene_path)
		if scene == null:
			continue
		var root := scene.instantiate()
		for node_path in FORMAL_FRONT_SCENES[scene_path]:
			_assert_true(root.has_node(node_path), "%s exposes %s" % [scene_path, node_path])
		root.free()


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return


