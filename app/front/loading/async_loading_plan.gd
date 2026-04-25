class_name AsyncLoadingPlan
extends RefCounted

const SELF_SCRIPT = preload("res://app/front/loading/async_loading_plan.gd")
const AsyncLoadingTaskScript = preload("res://app/front/loading/async_loading_task.gd")

var plan_id: String = ""
var tasks: Array = []


static func create(p_plan_id: String):
	var plan = SELF_SCRIPT.new()
	plan.plan_id = p_plan_id
	return plan


func add_task(task) -> void:
	if task != null:
		tasks.append(task)


func add_task_values(task_id: String, display_name: String, weight: float = 1.0):
	var task = AsyncLoadingTaskScript.create(task_id, display_name, weight)
	add_task(task)
	return task


func find_task(task_id: String):
	for task in tasks:
		if String(task.task_id) == task_id:
			return task
	return null
