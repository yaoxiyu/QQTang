param(
    [string]$EnvFile = ''
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$serviceRoot = Split-Path -Parent $scriptDir
$envFilePath = if ([string]::IsNullOrWhiteSpace($EnvFile)) { Join-Path $serviceRoot '.env' } else { $EnvFile }

if (Test-Path $envFilePath) {
    Get-Content -LiteralPath $envFilePath | ForEach-Object {
        if ($_ -match '^\s*#' -or $_ -notmatch '=') {
            return
        }
        $parts = $_.Split('=', 2)
        [Environment]::SetEnvironmentVariable($parts[0], $parts[1])
    }
}

Push-Location $serviceRoot
try {
    go run ./cmd/game_service
}
finally {
    Pop-Location
}
