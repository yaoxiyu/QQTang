extends SceneTree

const SKIP_DIRS := {
	"res://.godot": true,
	"res://build": true,
	"res://addons/gut/.tmp": true,
	"res://addons/qqt_native/third_party/godot-cpp/test": true
}


func _init() -> void:
	var script_paths := []
	_collect_gd_scripts("res://", script_paths)
	script_paths.sort()

	var failed_paths: Array[String] = []
	for script_path in script_paths:
		var source_code := FileAccess.get_file_as_string(script_path)
		if source_code.is_empty() and not FileAccess.file_exists(script_path):
			failed_paths.append(script_path)
			push_error("[gdsyntax] missing file: %s" % script_path)
			continue

		var script := GDScript.new()
		script.source_code = source_code
		script.take_over_path(script_path)
		var err := script.reload()
		if err != OK:
			failed_paths.append(script_path)
			push_error("[gdsyntax] compile failed: %s (err=%d)" % [script_path, err])

	if failed_paths.is_empty():
		print("[gdsyntax] PASS checked=%d" % script_paths.size())
		quit(0)
		return

	push_error("[gdsyntax] FAIL count=%d" % failed_paths.size())
	for failed_path in failed_paths:
		push_error("[gdsyntax] parse/load failed: %s" % failed_path)
	quit(1)


func _collect_gd_scripts(dir_path: String, out_paths: Array) -> void:
	for skipped_dir in SKIP_DIRS.keys():
		if dir_path.begins_with(skipped_dir):
			return

	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	while true:
		var entry := dir.get_next()
		if entry == "":
			break
		if entry == "." or entry == "..":
			continue

		var child_path := dir_path.path_join(entry)
		if dir.current_is_dir():
			_collect_gd_scripts(child_path, out_paths)
		elif entry.ends_with(".gd"):
			out_paths.append(child_path)
	dir.list_dir_end()
