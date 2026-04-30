param(
    [string]$ProjectPath = '',
    [string]$AssetType = '',
    [string]$AssetKey = '',
    [switch]$All,
    [switch]$DryRun,
    [switch]$WriteCsv,
    [switch]$GenerateVariants
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    $projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
} else {
    $projectRoot = Resolve-Path -LiteralPath $ProjectPath
}

$argsList = @(
    (Join-Path $projectRoot 'tools\asset_pipeline\run_asset_pipeline.py'),
    '--project-root', $projectRoot
)

if ($All) {
    $argsList += '--all'
} else {
    $argsList += @('--asset-type', $AssetType, '--asset-key', $AssetKey)
}

if ($DryRun) { $argsList += '--dry-run' }
if ($WriteCsv) { $argsList += '--write-csv' }
if ($GenerateVariants) { $argsList += '--generate-variants' }

Push-Location $projectRoot
try {
    $pyCmd = Get-Command py -ErrorAction SilentlyContinue
    if ($null -ne $pyCmd) {
        & py @argsList
    } else {
        & python @argsList
    }
    if ($LASTEXITCODE -ne 0) {
        throw "asset pipeline failed (python exit code: $LASTEXITCODE)"
    }
}
finally {
    Pop-Location
}
