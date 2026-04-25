class_name AsyncLoadingTask
extends RefCounted

const SELF_SCRIPT = preload("res://app/front/loading/async_loading_task.gd")

enum Status {
	PENDING,
	RUNNING,
	COMPLETED,
	FAILED,
	CANCELLED,
}

var task_id: String = ""
var display_name: String = ""
var weight: float = 1.0
var progress: float = 0.0
var status: Status = Status.PENDING
var error_code: String = ""
var user_message: String = ""


static func create(p_task_id: String, p_display_name: String, p_weight: float = 1.0):
	var task = SELF_SCRIPT.new()
	task.task_id = p_task_id
	task.display_name = p_display_name
	task.weight = max(p_weight, 0.0)
	return task


func start() -> void:
	if status == Status.PENDING:
		status = Status.RUNNING


func complete() -> void:
	status = Status.COMPLETED
	progress = 1.0


func fail(p_error_code: String, p_user_message: String) -> void:
	status = Status.FAILED
	error_code = p_error_code
	user_message = p_user_message


func cancel() -> void:
	status = Status.CANCELLED


func set_progress(value: float) -> void:
	progress = clampf(value, 0.0, 1.0)
	if status == Status.PENDING:
		status = Status.RUNNING
	if progress >= 1.0 and status == Status.RUNNING:
		status = Status.COMPLETED


func effective_progress() -> float:
	if status == Status.COMPLETED:
		return 1.0
	if status == Status.FAILED or status == Status.CANCELLED:
		return progress
	return clampf(progress, 0.0, 1.0)
