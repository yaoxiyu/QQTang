param(
    [string]$GodotExe = (Join-Path $PSScriptRoot '..\..\external\godot_binary\Godot.exe'),
    [string]$ImageTag = '',
    [string]$LinuxBuilderImage = 'qqtang/native-linux-builder:ubuntu-24.04',
    [switch]$SkipNativeBuild,
    [switch]$SkipGodotExport,
    [switch]$SkipImageBuild,
    [switch]$ForceBuild
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$repoRoot = $repoRoot.Path
. (Join-Path $repoRoot 'tools\lib\dev_common.ps1')
$activity = 'battle-ds-prepare'
$step = 1
$total = 4
$nativeSource = Join-Path $repoRoot 'external\qqt_native\bin\qqt_native.linux.template_release.x86_64.so'
$nativeOutput = Join-Path $repoRoot 'build\docker\battle_ds\qqt_native.linux.template_release.x86_64.so'
$nativeOutputDir = Split-Path -Parent $nativeOutput

if (-not $SkipNativeBuild) {
    Invoke-QQTProgressStep -Activity $activity -Step $step -Total $total -Name 'native linux artifact' -Action {
        & (Join-Path $repoRoot 'tools\native\build_native_linux_docker.ps1') `
            -Target template_release `
            -Arch x86_64 `
            -Image $LinuxBuilderImage `
            -ForceBuild:$ForceBuild
    }
}
$step++

if (-not (Test-Path -LiteralPath $nativeSource -PathType Leaf)) {
    throw "Native Linux release library not found: $nativeSource"
}
Invoke-QQTProgressStep -Activity $activity -Step $step -Total $total -Name 'sync native library' -Action {
    New-Item -ItemType Directory -Force -Path $nativeOutputDir | Out-Null
    Copy-Item -LiteralPath $nativeSource -Destination $nativeOutput -Force
    Write-Host "[battle-ds-prepare] synced $nativeOutput"
}
$step++

if (-not $SkipGodotExport) {
    Invoke-QQTProgressStep -Activity $activity -Step $step -Total $total -Name 'godot linux export' -Action {
        & (Join-Path $repoRoot 'scripts\docker\export_battle_ds_linux.ps1') -GodotExe $GodotExe -ForceBuild:$ForceBuild
    }
}
$step++

if (-not $SkipImageBuild) {
    $imageArgs = @{}
    if (-not [string]::IsNullOrWhiteSpace($ImageTag)) {
        $imageArgs.ImageTag = $ImageTag
    }
    if ($ForceBuild) {
        $imageArgs.ForceBuild = $true
    }
    Invoke-QQTProgressStep -Activity $activity -Step $step -Total $total -Name 'docker image build' -Action {
        & (Join-Path $repoRoot 'scripts\docker\build_battle_ds_image.ps1') @imageArgs
    }
}
Write-QQTProgress -Activity $activity -Completed
