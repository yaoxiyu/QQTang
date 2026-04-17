extends RefCounted

const FrontFlowControllerScript = preload("res://app/flow/front_flow_controller.gd")
const SceneFlowControllerScript = preload("res://app/flow/scene_flow_controller.gd")


static func ensure_navigation(runtime: Node) -> void:
	if runtime == null:
		return
	if runtime.front_flow == null or not is_instance_valid(runtime.front_flow):
		runtime.front_flow = FrontFlowControllerScript.new()
		runtime.front_flow.name = "FrontFlowController"
		runtime.add_child(runtime.front_flow)

	if runtime.scene_flow == null or not is_instance_valid(runtime.scene_flow):
		runtime.scene_flow = SceneFlowControllerScript.new()
		runtime.scene_flow.name = "SceneFlowController"
		runtime.add_child(runtime.scene_flow)

	if runtime.front_flow != null and runtime.front_flow.has_method("configure"):
		runtime.front_flow.configure(runtime.scene_flow)


static func ensure_boot_state(runtime: Node) -> void:
	if runtime == null:
		return
	if runtime.scene_flow != null and runtime.scene_flow.current_scene_path.is_empty():
		runtime.scene_flow.current_scene_path = SceneFlowControllerScript.BOOT_SCENE_PATH
	if runtime.front_flow != null and int(runtime.front_flow.current_state) != int(FrontFlowControllerScript.FlowState.BOOT):
		runtime.front_flow.current_state = FrontFlowControllerScript.FlowState.BOOT
