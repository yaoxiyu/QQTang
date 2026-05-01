param(
    [ValidateSet('windows')]
    [string]$Platform = 'windows',
    [ValidateSet('template_debug', 'template_release')]
    [string]$Target = 'template_debug',
    [string]$Arch = 'x86_64',
    [string]$SconsExe = 'scons'
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$repoRoot = $repoRoot.Path
. (Join-Path $repoRoot 'tools\lib\dev_common.ps1')
$activity = 'native-windows'
$projectRoot = Join-Path $repoRoot 'addons/qqt_native'
$sconstructPath = Join-Path $projectRoot 'SConstruct'
$binDir = Join-Path $projectRoot 'bin'
$godotCppRoot = Join-Path $projectRoot 'third_party\godot-cpp'
$godotCppLib = Join-Path $godotCppRoot ("bin\libgodot-cpp.{0}.{1}.{2}.lib" -f $Platform, $Target, $Arch)

if (-not (Test-Path -LiteralPath $sconstructPath)) {
    throw "SConstruct not found: $sconstructPath"
}

if ($Arch -ne 'x86_64') {
    throw "Unsupported arch '$Arch'. Current repo only ships Windows x86_64 qqt_native artifacts."
}

if (-not (Test-Path -LiteralPath $godotCppLib)) {
    Invoke-QQTProgressStep -Activity $activity -Step 1 -Total 2 -Name 'godot-cpp static library' -Action {
        Write-Host "[native] building missing godot-cpp static library: $godotCppLib"
        & $SconsExe "-C" $godotCppRoot "platform=$Platform" "target=$Target" "arch=$Arch"
        if ($LASTEXITCODE -ne 0) {
            throw "godot-cpp build failed (scons exit code: $LASTEXITCODE)"
        }
    }
} else {
    Write-Host "[native] skip godot-cpp static library (exists): $godotCppLib"
}

Push-Location $repoRoot
try {
    Invoke-QQTProgressStep -Activity $activity -Step 2 -Total 2 -Name "qqt_native $Platform $Target $Arch" -Action {
        Write-Host "[native] building qqt_native platform=$Platform target=$Target arch=$Arch"
        & $SconsExe "-C" $projectRoot "platform=$Platform" "target=$Target" "arch=$Arch"
        if ($LASTEXITCODE -ne 0) {
            throw "Native build failed (scons exit code: $LASTEXITCODE)"
        }
    }

    Write-Host "[native] build completed"
    Write-Host "[native] artifacts directory: $binDir"
    if (Test-Path -LiteralPath $binDir) {
        Get-ChildItem -LiteralPath $binDir -File | Select-Object FullName
    }
}
finally {
    Pop-Location
}
Write-QQTProgress -Activity $activity -Completed
