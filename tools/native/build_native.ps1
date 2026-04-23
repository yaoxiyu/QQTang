param(
    [ValidateSet('windows', 'linux', 'macos')]
    [string]$Platform = 'windows',
    [ValidateSet('editor', 'template_debug', 'template_release')]
    [string]$Target = 'template_debug',
    [string]$Arch = 'x86_64',
    [string]$SconsExe = 'scons'
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$projectRoot = Join-Path $repoRoot 'addons/qqt_native'
$sconstructPath = Join-Path $projectRoot 'SConstruct'
$binDir = Join-Path $projectRoot 'bin'

if (-not (Test-Path -LiteralPath $sconstructPath)) {
    throw "SConstruct not found: $sconstructPath"
}

Push-Location $repoRoot
try {
    Write-Host "[native] building qqt_native platform=$Platform target=$Target arch=$Arch"
    & $SconsExe "-C" $projectRoot "platform=$Platform" "target=$Target" "arch=$Arch"
    if ($LASTEXITCODE -ne 0) {
        throw "Native build failed (scons exit code: $LASTEXITCODE)"
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
