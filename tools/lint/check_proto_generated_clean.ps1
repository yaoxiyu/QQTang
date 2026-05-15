param(
    [string]$ProjectRoot = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
}

Push-Location $ProjectRoot
try {
    buf generate

    $targets = @(
        "services/room_service/internal/gen",
        "services/game_service/internal/gen",
        "network/client_net/generated"
    )
    $diff = git diff --name-only -- $targets
    if (-not [string]::IsNullOrWhiteSpace($diff)) {
        Write-Host "[proto-gen-guard] FAIL generated outputs drifted:"
        Write-Host $diff
        exit 1
    }
    Write-Host "[proto-gen-guard] PASS"
}
finally {
    Pop-Location
}
