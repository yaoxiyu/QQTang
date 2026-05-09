class_name FxPool
extends RefCounted

## 通用 FX 对象池。高频创建 / 销毁的临时特效节点通过池复用，避免 GC 压力和实例化开销。
## 新增 FX 类型只需 register_factory + prewarm，无需修改池本身。

var _available: Dictionary = {}
var _factory: Dictionary = {}
var _total_created: Dictionary = {}
var _total_reused: Dictionary = {}


func register_factory(type_key: String, factory: Callable) -> void:
	_factory[type_key] = factory
	if not _available.has(type_key):
		_available[type_key] = []
		_total_created[type_key] = 0
		_total_reused[type_key] = 0


func prewarm(type_key: String, count: int, parent: Node, configure_callable: Callable = Callable()) -> void:
	if not _factory.has(type_key):
		push_error("FxPool.prewarm: unknown type_key=%s" % type_key)
		return
	for _i in range(count):
		var node: Node = _factory[type_key].call()
		_available[type_key].append(node)
		_total_created[type_key] += 1
		if configure_callable.is_valid():
			configure_callable.call(node)
		if parent != null:
			parent.add_child(node)


func acquire(type_key: String, parent: Node, configure_callable: Callable) -> Node:
	if not _factory.has(type_key):
		push_error("FxPool.acquire: unknown type_key=%s" % type_key)
		return null

	var node: Node = null
	var pool: Array = _available[type_key]

	if pool.size() > 0:
		node = pool.pop_back()
		_total_reused[type_key] += 1
	else:
		node = _factory[type_key].call()
		_total_created[type_key] += 1

	if configure_callable.is_valid():
		configure_callable.call(node)

	parent.add_child(node)
	return node


func release(type_key: String, node: Node) -> void:
	if node == null:
		return
	if node.is_inside_tree() and node.get_parent() != null:
		node.get_parent().remove_child(node)
	_reset_node(node)
	if _available.has(type_key):
		_available[type_key].append(node)


func get_stats(type_key: String) -> Dictionary:
	return {
		"available": _available.get(type_key, []).size(),
		"total_created": _total_created.get(type_key, 0),
		"total_reused": _total_reused.get(type_key, 0),
	}


func clear(type_key: String = "") -> void:
	if type_key.is_empty():
		for key in _available.keys():
			_clear_pool(key)
		_available.clear()
		_factory.clear()
		_total_created.clear()
		_total_reused.clear()
	elif _available.has(type_key):
		_clear_pool(type_key)
		_available.erase(type_key)
		_factory.erase(type_key)
		_total_created.erase(type_key)
		_total_reused.erase(type_key)


func _clear_pool(key: String) -> void:
	for node in _available[key]:
		if node != null and is_instance_valid(node):
			node.queue_free()
	_available[key].clear()


func _reset_node(node: Node) -> void:
	node.visible = true
	node.modulate = Color.WHITE
	node.scale = Vector2.ONE
	node.position = Vector2.ZERO
	if node is Node2D:
		(node as Node2D).rotation = 0.0
	if node.has_method("reset_fx"):
		node.reset_fx()
	for child in node.get_children():
		if child is AnimatedSprite2D:
			var anim: AnimatedSprite2D = child as AnimatedSprite2D
			anim.stop()
			anim.frame = 0
