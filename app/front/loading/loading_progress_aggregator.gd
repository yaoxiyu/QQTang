class_name LoadingProgressAggregator
extends RefCounted

const AsyncLoadingTaskScript = preload("res://app/front/loading/async_loading_task.gd")


func aggregate(plan) -> Dictionary:
	if plan == null:
		return _empty_result()
	var total_weight := 0.0
	var weighted_progress := 0.0
	var failed_tasks: Array[String] = []
	var cancelled_tasks: Array[String] = []
	var running_tasks: Array[String] = []
	for task in plan.tasks:
		if task == null:
			continue
		var weight: float = max(float(task.weight), 0.0)
		if weight <= 0.0:
			continue
		total_weight += weight
		weighted_progress += task.effective_progress() * weight
		match int(task.status):
			AsyncLoadingTaskScript.Status.FAILED:
				failed_tasks.append(String(task.task_id))
			AsyncLoadingTaskScript.Status.CANCELLED:
				cancelled_tasks.append(String(task.task_id))
			AsyncLoadingTaskScript.Status.RUNNING, AsyncLoadingTaskScript.Status.PENDING:
				running_tasks.append(String(task.task_id))
	if total_weight <= 0.0:
		return _empty_result()
	var progress := clampf(weighted_progress / total_weight, 0.0, 1.0)
	return {
		"ok": failed_tasks.is_empty() and cancelled_tasks.is_empty(),
		"progress": progress,
		"progress_percent": int(round(progress * 100.0)),
		"failed_tasks": failed_tasks,
		"cancelled_tasks": cancelled_tasks,
		"running_tasks": running_tasks,
		"is_complete": progress >= 1.0 and running_tasks.is_empty() and failed_tasks.is_empty() and cancelled_tasks.is_empty(),
	}


func _empty_result() -> Dictionary:
	return {
		"ok": true,
		"progress": 0.0,
		"progress_percent": 0,
		"failed_tasks": [],
		"cancelled_tasks": [],
		"running_tasks": [],
		"is_complete": false,
	}
