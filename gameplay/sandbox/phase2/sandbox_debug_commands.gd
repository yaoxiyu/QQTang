class_name Phase2SandboxDebugCommands
extends Node

@export var bootstrap_path: NodePath = ^"../SandboxBootstrap"

var _bootstrap: Phase2SandboxBootstrap = null


func _ready() -> void:
	if has_node(bootstrap_path):
		_bootstrap = get_node(bootstrap_path)
