param(
    [string]$ProjectPath = '',
    [string]$GodotExecutable = 'Godot_console.exe',
    [string]$ComposeFile = 'deploy/docker/docker-compose.phase24.dev.yml',
    [switch]$SkipDotnetBuild,
    [switch]$SkipNativeBuild
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
} else {
    $repoRoot = Resolve-Path -LiteralPath $ProjectPath
}

& (Join-Path $repoRoot 'tests\scripts\check_gdscript_syntax.ps1') -GodotExe $GodotExecutable -ProjectPath $repoRoot

if (-not $SkipDotnetBuild) {
    $projectFile = Join-Path $repoRoot 'QQTang.csproj'
    if (Test-Path -LiteralPath $projectFile) {
        Write-Host '[docker-build] building QQTang C# project'
        & dotnet build $projectFile
        if ($LASTEXITCODE -ne 0) {
            throw "dotnet build failed: $projectFile"
        }
    }
}

if (-not $SkipNativeBuild) {
    & (Join-Path $repoRoot 'tools\native\build_native.ps1') -Target template_debug
}
& (Join-Path $repoRoot 'scripts\content\generate_room_manifest.ps1') -ProjectPath $repoRoot -GodotExecutable $GodotExecutable

Push-Location $repoRoot
try {
    docker compose -f $ComposeFile build
}
finally {
    Pop-Location
}
