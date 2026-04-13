param(
    [ValidateSet("dev", "test")]
    [string]$Target = "dev",
    [switch]$Recreate
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
if ($Target -eq "dev") {
    $composeFile = Join-Path $root "docker-compose.dev.yml"
}
else {
    $composeFile = Join-Path $root "docker-compose.test.yml"
}

if ($Recreate) {
    docker compose -f $composeFile down -v
}

docker compose -f $composeFile up -d
docker compose -f $composeFile ps

Pause