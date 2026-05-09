param(
    [string]$Root = "."
)

$ErrorActionPreference = "Stop"

Set-Location -LiteralPath $Root

$targets = @(
    "content_source/csv",
    "content",
    "presentation",
    "gameplay",
    "app"
)

$allowPatterns = @(
    "res://external/assets/source/res/object/ui/"
)

$hits = @()
foreach ($target in $targets) {
    if (-not (Test-Path -LiteralPath $target)) {
        continue
    }
    $result = rg -n "res://external/assets/" $target -S
    if ($LASTEXITCODE -gt 1) {
        throw "rg failed on $target"
    }
    if ($LASTEXITCODE -eq 0 -and $result) {
        $hits += $result
    }
}

if ($hits.Count -eq 0) {
    Write-Host "[asset-policy] PASS: no res://external/assets/ references found."
    exit 0
}

$violations = @()
foreach ($line in $hits) {
    $isAllowed = $false
    foreach ($pattern in $allowPatterns) {
        if ($line.Contains($pattern)) {
            $isAllowed = $true
            break
        }
    }
    if (-not $isAllowed) {
        $violations += $line
    }
}

Write-Host ("[asset-policy] total res://assets refs: {0}" -f $hits.Count)
Write-Host ("[asset-policy] allowlisted refs: {0}" -f ($hits.Count - $violations.Count))
Write-Host ("[asset-policy] violations: {0}" -f $violations.Count)

if ($violations.Count -gt 0) {
    $violations | Select-Object -First 200 | ForEach-Object { Write-Host $_ }
    exit 2
}

exit 0
