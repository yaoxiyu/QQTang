param(
    [string]$ProjectPath = '',
    [string]$GodotExe = (Join-Path $PSScriptRoot '..\..\external\godot_binary\Godot.exe'),
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
} else {
    $repoRoot = Resolve-Path -LiteralPath $ProjectPath
}

if (-not $SkipBuild) {
    $nativeBuild = Join-Path $repoRoot 'tools\native\build_native.ps1'
    & $nativeBuild -Target template_debug
    & $nativeBuild -Target template_release
}

$tempScript = Join-Path ([System.IO.Path]::GetTempPath()) ("qqt_check_native_runtime_{0}.gd" -f ([guid]::NewGuid().ToString('N')))
$tempContent = @'
extends SceneTree

const NativeFeatureFlagsScript = preload("res://gameplay/native_bridge/native_feature_flags.gd")
const NativeKernelRuntimeScript = preload("res://gameplay/native_bridge/native_kernel_runtime.gd")

func _init() -> void:
	var ok := true
	var classes := [
		"QQTNativeChecksumBuilder",
		"QQTNativeSnapshotRing",
		"QQTNativeMovementKernel",
		"QQTNativeExplosionKernel",
	]
	for native_class_name in classes:
		if not ClassDB.can_instantiate(native_class_name):
			push_error("[native_runtime_check] missing native class: %s" % native_class_name)
			ok = false
	print("[native_runtime_check] available=%s version=%s require=%s checksum=%s snapshot=%s movement=%s movement_execute=%s explosion=%s explosion_execute=%s" % [
		str(NativeKernelRuntimeScript.is_available()),
		NativeKernelRuntimeScript.get_kernel_version(),
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
	if NativeKernelRuntimeScript.get_kernel_version() != "native_kernel_v1":
		ok = false
	if not NativeFeatureFlagsScript.require_native_kernels:
		ok = false
	if not NativeFeatureFlagsScript.enable_native_checksum:
		ok = false
	if not NativeFeatureFlagsScript.enable_native_snapshot_ring:
		ok = false
	if not NativeFeatureFlagsScript.enable_native_movement or not NativeFeatureFlagsScript.enable_native_movement_execute:
		ok = false
	if not NativeFeatureFlagsScript.enable_native_explosion or not NativeFeatureFlagsScript.enable_native_explosion_execute:
		ok = false
	quit(0 if ok else 1)
'@

try {
    Set-Content -LiteralPath $tempScript -Value $tempContent -Encoding UTF8
    & cmd /c "`"$GodotExe`" --headless --path `"$repoRoot`" --script `"$tempScript`""
    if ($LASTEXITCODE -ne 0) {
        throw "native runtime check failed (godot exit code: $LASTEXITCODE)"
    }
}
finally {
    if (Test-Path -LiteralPath $tempScript) {
        Remove-Item -LiteralPath $tempScript -Force -ErrorAction SilentlyContinue
    }
}
