param(
    [string]$ImageTag = '',
    [string]$BattleDSBinary = 'build/docker/battle_ds/qqtang_battle_ds.x86_64',
    [string]$BattleDSPack = 'build/docker/battle_ds/qqtang_battle_ds.pck',
    [string]$BattleDSDataDir = 'build/docker/battle_ds/data_QQTang_linuxbsd_x86_64',
    [string]$BattleDSNativeLib = 'build/docker/battle_ds/qqt_native.linux.template_release.x86_64.so',
    [switch]$ForceBuild
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$repoRoot = $repoRoot.Path
. (Join-Path $repoRoot 'tools\lib\dev_common.ps1')
$cacheRoot = Join-Path $repoRoot 'build\.docker-cache'
$activity = 'battle-ds-image'
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

function Test-QQTDockerImageExists {
    param([string]$Tag)
    docker image inspect $Tag *> $null
    return $LASTEXITCODE -eq 0
}

$imageFingerprint = Get-QQTFileFingerprint `
    -Root $repoRoot `
    -IncludePaths @(
        'services\ds_agent\Dockerfile',
        'services\ds_agent',
        $BattleDSBinary,
        $BattleDSPack,
        $BattleDSDataDir,
        $BattleDSNativeLib
    ) `
    -ExcludePathParts @(
        '\.git\',
        '\logs\',
        '\tests\reports\'
    )
$stampPath = Join-Path $cacheRoot ("battle_ds_image_{0}.sha256" -f ($ImageTag -replace '[^A-Za-z0-9_.-]', '_'))
$previousFingerprint = ''
if (Test-Path -LiteralPath $stampPath -PathType Leaf) {
    $previousFingerprint = (Get-Content -LiteralPath $stampPath -Raw).Trim()
}
if ((-not $ForceBuild) -and $previousFingerprint -eq $imageFingerprint -and (Test-QQTDockerImageExists -Tag $ImageTag)) {
    Write-Host "[battle-ds-image] skip $ImageTag (inputs unchanged)"
    Write-QQTProgress -Activity $activity -Completed
    exit 0
}

Push-Location $repoRoot
try {
    Invoke-QQTProgressStep -Activity $activity -Step 1 -Total 1 -Name "docker build $ImageTag" -Action {
        docker build -f services/ds_agent/Dockerfile -t $ImageTag .
        if ($LASTEXITCODE -ne 0) {
            throw "Battle DS image build failed: $ImageTag"
        }
    }
}
finally {
    Pop-Location
}

New-Item -ItemType Directory -Force -Path $cacheRoot | Out-Null
Set-Content -LiteralPath $stampPath -Value $imageFingerprint -Encoding ASCII
Write-QQTProgress -Activity $activity -Completed
Write-Host "[battle-ds-image] built $ImageTag"
