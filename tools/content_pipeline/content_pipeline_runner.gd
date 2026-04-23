@tool
extends EditorScript
class_name ContentPipelineRunner

const ContentPipelineOrchestratorScript = preload("res://tools/content_pipeline/content_pipeline_orchestrator.gd")


func _run() -> void:
	run_all()


func run_all() -> void:
	ContentPipelineOrchestratorScript.new().run_all()
