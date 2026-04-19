param(
    [string]$ProjectPath = '',
    [string]$GodotExecutable = 'Godot_console.exe'
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    $projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
} else {
    $projectRoot = Resolve-Path -LiteralPath $ProjectPath
}

$tempScript = Join-Path ([System.IO.Path]::GetTempPath()) ("qqt_generate_room_manifest_{0}.gd" -f ([guid]::NewGuid().ToString('N')))
$tempContent = @'
extends SceneTree

func _init() -> void:
	var generator = load("res://tools/content_pipeline/generators/generate_room_manifest.gd").new()
	generator.generate()
	quit(0)
'@

try {
    Set-Content -LiteralPath $tempScript -Value $tempContent -Encoding UTF8

    Push-Location $projectRoot
    try {
        & $GodotExecutable --headless --path $projectRoot --script $tempScript
    }
    finally {
        Pop-Location
    }

    if ($LASTEXITCODE -ne 0) {
        throw "failed to generate room manifest (godot exit code: $LASTEXITCODE)"
    }

    $manifestPath = Join-Path $projectRoot 'build\generated\room_manifest\room_manifest.json'
    if (-not (Test-Path -LiteralPath $manifestPath)) {
        throw "room manifest not found: $manifestPath"
    }

    $manifestJson = Get-Content -LiteralPath $manifestPath -Raw
    if ([string]::IsNullOrWhiteSpace($manifestJson)) {
        throw "room manifest is empty: $manifestPath"
    }

    if ($manifestJson -notmatch '"assets"\s*:') {
        throw "room manifest is invalid: missing assets section"
    }
    if ($manifestJson -notmatch '"legal_character_ids"\s*:\s*\[\s*"[^"]+') {
        throw "room manifest is invalid: legal_character_ids is empty"
    }
}
finally {
    if (Test-Path -LiteralPath $tempScript) {
        Remove-Item -LiteralPath $tempScript -ErrorAction SilentlyContinue
    }
}

Write-Host "[content] room manifest generated"
