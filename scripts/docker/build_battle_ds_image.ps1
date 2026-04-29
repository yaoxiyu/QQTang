param(
    [string]$ImageTag = '',
    [string]$BattleDSBinary = 'build/docker/battle_ds/qqtang_battle_ds.x86_64',
    [string]$BattleDSPack = 'build/docker/battle_ds/qqtang_battle_ds.pck',
    [string]$BattleDSDataDir = 'build/docker/battle_ds/data_QQTang_linuxbsd_x86_64',
    [string]$BattleDSNativeLib = 'build/docker/battle_ds/qqt_native.linux.template_release.x86_64.so'
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
if ([string]::IsNullOrWhiteSpace($ImageTag)) {
    $ImageTag = if ([string]::IsNullOrWhiteSpace($env:QQT_BATTLE_DS_IMAGE)) {
        'qqtang/battle-ds:dev'
    } else {
        $env:QQT_BATTLE_DS_IMAGE
    }
}

function Assert-QQTPath {
    param(
        [string]$Path,
        [switch]$Directory
    )

    $absolutePath = Join-Path $repoRoot $Path
    if ($Directory) {
        if (-not (Test-Path -LiteralPath $absolutePath -PathType Container)) {
            throw "missing Battle DS data directory: $Path"
        }
        return
    }
    if (-not (Test-Path -LiteralPath $absolutePath -PathType Leaf)) {
        throw "missing Battle DS build artifact: $Path"
    }
}

Assert-QQTPath -Path $BattleDSBinary
Assert-QQTPath -Path $BattleDSPack
Assert-QQTPath -Path $BattleDSDataDir -Directory
Assert-QQTPath -Path $BattleDSNativeLib

Push-Location $repoRoot
try {
    docker build -f services/ds_agent/Dockerfile -t $ImageTag .
    if ($LASTEXITCODE -ne 0) {
        throw "Battle DS image build failed: $ImageTag"
    }
}
finally {
    Pop-Location
}

Write-Host "[battle-ds-image] built $ImageTag"
