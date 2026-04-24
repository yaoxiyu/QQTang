param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$binDir = Join-Path $repoRoot 'addons/qqt_native/bin'

if (-not (Test-Path -LiteralPath $binDir)) {
    Write-Host "[native] bin directory does not exist: $binDir"
    exit 0
}

$lockedItems = @()
foreach ($item in Get-ChildItem -LiteralPath $binDir -Force) {
    try {
        Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction Stop
    } catch {
        $lockedItems += $item.FullName
    }
}

if ($lockedItems.Count -gt 0) {
    Write-Warning "[native] some artifacts are locked by a running Godot/editor process and were not removed:"
    foreach ($path in $lockedItems) {
        Write-Warning "  $path"
    }
    exit 1
}

Write-Host "[native] cleaned artifacts under: $binDir"
