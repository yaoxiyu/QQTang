param(
    [string]$GodotExe = (Join-Path $PSScriptRoot '..\..\godot_binary\Godot_console.exe'),
    [string]$ProjectPath = ''
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
} else {
    $repoRoot = Resolve-Path -LiteralPath $ProjectPath
}

if (-not (Test-Path -LiteralPath $GodotExe)) {
    throw "Godot executable not found: $GodotExe"
}

Push-Location $repoRoot
try {
    & $GodotExe --headless --path $repoRoot --script res://tools/dev/check_gdscript_syntax.gd
    if ($LASTEXITCODE -ne 0) {
        throw "GDScript syntax preflight failed (godot exit code: $LASTEXITCODE)"
    }
}
finally {
    Pop-Location
}

Write-Host "[gdsyntax] syntax preflight passed"
