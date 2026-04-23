param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$binDir = Join-Path $repoRoot 'addons/qqt_native/bin'

if (-not (Test-Path -LiteralPath $binDir)) {
    Write-Host "[native] bin directory does not exist: $binDir"
    exit 0
}

Get-ChildItem -LiteralPath $binDir -Force | Remove-Item -Recurse -Force
Write-Host "[native] cleaned artifacts under: $binDir"
