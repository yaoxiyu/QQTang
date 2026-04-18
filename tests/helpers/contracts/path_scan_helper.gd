class_name PathScanHelper
extends RefCounted


static func collect_files_recursive(root_path: String, suffix: String = "") -> Array[String]:
	var results: Array[String] = []
	_collect_files_recursive_impl(root_path, suffix, results)
	results.sort()
	return results


static func collect_files_from_roots(roots: Array[String], suffix: String = "", exclude_prefixes: Array[String] = []) -> Array[String]:
	var all_files: Array[String] = []
	for root in roots:
		var files := collect_files_recursive(root, suffix)
		for file_path in files:
			if _starts_with_any(file_path, exclude_prefixes):
				continue
			all_files.append(file_path)
	all_files.sort()
	return all_files


static func file_contains(path: String, pattern: String) -> bool:
	if pattern.is_empty():
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	return file.get_as_text().find(pattern) >= 0


static func file_contains_any(path: String, patterns: Array[String]) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var content := file.get_as_text()
	for pattern in patterns:
		if content.find(pattern) >= 0:
			return true
	return false


static func _collect_files_recursive_impl(root_path: String, suffix: String, results: Array[String]) -> void:
	var dir := DirAccess.open(root_path)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name.is_empty():
			break
		if name == "." or name == "..":
			continue
		var child_path := root_path.path_join(name)
		if dir.current_is_dir():
			_collect_files_recursive_impl(child_path, suffix, results)
			continue
		if suffix.is_empty() or child_path.ends_with(suffix):
			results.append(child_path)
	dir.list_dir_end()


static func _starts_with_any(path: String, prefixes: Array[String]) -> bool:
	for prefix in prefixes:
		if path.begins_with(prefix):
			return true
	return false
