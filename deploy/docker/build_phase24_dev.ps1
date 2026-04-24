param(
    [string]$ProjectPath = '',
    [string]$GodotExecutable = 'Godot_console.exe',
    [string]$ComposeFile = 'deploy/docker/docker-compose.phase24.dev.yml'
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
} else {
    $repoRoot = Resolve-Path -LiteralPath $ProjectPath
}

& (Join-Path $repoRoot 'tools\native\build_native.ps1') -Target template_debug
& (Join-Path $repoRoot 'scripts\content\generate_room_manifest.ps1') -ProjectPath $repoRoot -GodotExecutable $GodotExecutable

Push-Location $repoRoot
try {
    docker compose -f $ComposeFile build
}
finally {
    Pop-Location
}
