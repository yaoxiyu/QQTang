#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$ROOT_DIR/external/godot_binary/Godot_console.exe}"
TEMP_SCRIPT="$(mktemp "${TMPDIR:-/tmp}/qqt_check_native_runtime_XXXXXX.gd")"
trap 'rm -f "$TEMP_SCRIPT"' EXIT

"$ROOT_DIR/tools/native/build_native_linux.sh" template_debug x86_64
"$ROOT_DIR/tools/native/build_native_linux.sh" template_release x86_64

cd "$ROOT_DIR"

cat >"$TEMP_SCRIPT" <<'GDSCRIPT'
extends SceneTree

const NativeFeatureFlagsScript = preload("res://gameplay/native_bridge/native_feature_flags.gd")
const NativeKernelRuntimeScript = preload("res://gameplay/native_bridge/native_kernel_runtime.gd")

func _init() -> void:
	var classes := [
		"QQTNativeChecksumBuilder",
		"QQTNativeSnapshotRing",
		"QQTNativeMovementKernel",
		"QQTNativeExplosionKernel",
		"QQTNativeInputBuffer",
		"QQTNativeBattleMessageCodec",
	]
	var ok := true
	for native_class_name in classes:
		if not ClassDB.can_instantiate(native_class_name):
			push_error("[native_runtime_check_linux] missing native class: %s" % native_class_name)
			ok = false
	print("[native_runtime_check_linux] available=%s version=%s require=%s checksum=%s snapshot=%s movement=%s movement_execute=%s explosion=%s explosion_execute=%s" % [
		str(NativeKernelRuntimeScript.is_available()),
		NativeKernelRuntimeScript.get_version(),
		str(NativeFeatureFlagsScript.require_native_kernels),
		str(NativeFeatureFlagsScript.enable_native_checksum),
		str(NativeFeatureFlagsScript.enable_native_snapshot_ring),
		str(NativeFeatureFlagsScript.enable_native_movement),
		str(NativeFeatureFlagsScript.enable_native_movement_execute),
		str(NativeFeatureFlagsScript.enable_native_explosion),
		str(NativeFeatureFlagsScript.enable_native_explosion_execute),
	])
	if not NativeKernelRuntimeScript.is_available():
		ok = false
		push_error("[native_runtime_check_linux] native runtime unavailable")
	if not NativeFeatureFlagsScript.require_native_kernels:
		ok = false
		push_error("[native_runtime_check_linux] require_native_kernels must be true")
	quit(0 if ok else 1)
GDSCRIPT

"$GODOT_BIN" --headless --path "$ROOT_DIR" --script "$TEMP_SCRIPT" || {
  echo "Godot headless failed to load/check project native extension" >&2
  exit 3
}

echo "[qqt_native] linux runtime load check passed"
