extends SceneTree


func _init() -> void:
	print("[content] pipeline cli start")
	var runner = load("res://tools/content_pipeline/content_pipeline_orchestrator.gd").new()
	runner.run_all()
	print("[content] pipeline cli end")
	quit(0)
