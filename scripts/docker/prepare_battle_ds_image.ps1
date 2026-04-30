param(
    [string]$GodotExe = (Join-Path $PSScriptRoot '..\..\external\godot_binary\Godot_console.exe'),
    [string]$ImageTag = '',
    [string]$LinuxBuilderImage = 'qqtang/native-linux-builder:ubuntu-24.04',
    [switch]$SkipNativeBuild,
    [switch]$SkipGodotExport,
    [switch]$SkipImageBuild
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$nativeSource = Join-Path $repoRoot 'addons\qqt_native\bin\qqt_native.linux.template_release.x86_64.so'
$nativeOutput = Join-Path $repoRoot 'build\docker\battle_ds\qqt_native.linux.template_release.x86_64.so'
$nativeOutputDir = Split-Path -Parent $nativeOutput

if (-not $SkipNativeBuild) {
    & (Join-Path $repoRoot 'tools\native\build_native_linux_docker.ps1') `
        -Target template_release `
        -Arch x86_64 `
        -Image $LinuxBuilderImage
}

if (-not (Test-Path -LiteralPath $nativeSource -PathType Leaf)) {
    throw "Native Linux release library not found: $nativeSource"
}
New-Item -ItemType Directory -Force -Path $nativeOutputDir | Out-Null
Copy-Item -LiteralPath $nativeSource -Destination $nativeOutput -Force
Write-Host "[battle-ds-prepare] synced $nativeOutput"

if (-not $SkipGodotExport) {
    & (Join-Path $repoRoot 'scripts\docker\export_battle_ds_linux.ps1') -GodotExe $GodotExe
}

if (-not $SkipImageBuild) {
    $imageArgs = @{}
    if (-not [string]::IsNullOrWhiteSpace($ImageTag)) {
        $imageArgs.ImageTag = $ImageTag
    }
    & (Join-Path $repoRoot 'scripts\docker\build_battle_ds_image.ps1') @imageArgs
}
