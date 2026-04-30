param(
    [string]$ProjectPath = '',
    [string]$GodotExe = (Join-Path $PSScriptRoot '..\..\godot_binary\Godot_console.exe'),
    [switch]$SkipGodot
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    $projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
} else {
    $projectRoot = Resolve-Path -LiteralPath $ProjectPath
}

Push-Location $projectRoot
try {
    powershell -ExecutionPolicy Bypass -File scripts\content\run_asset_pipeline.ps1 -All -DryRun -ProjectPath $projectRoot
    $pyCmd = Get-Command py -ErrorAction SilentlyContinue
    if ($null -ne $pyCmd) {
        py -m pytest tests/unit/asset_pipeline tests/contracts/asset_pipeline
    } else {
        python -m pytest tests/unit/asset_pipeline tests/contracts/asset_pipeline
    }

    if (-not $SkipGodot) {
        powershell -ExecutionPolicy Bypass -File tests\scripts\check_gdscript_syntax.ps1 -GodotExe $GodotExe -ProjectPath $projectRoot
        powershell -ExecutionPolicy Bypass -File scripts\content\run_content_pipeline.ps1 -GodotExecutable $GodotExe -ProjectPath $projectRoot
        $phase38GutFiles = @(
            'res://tests/contracts/content/character_team_animation_contract_test.gd',
            'res://tests/contracts/content/team_color_palette_contract_test.gd',
            'res://tests/contracts/content/map_tile_direction_pass_contract_test.gd',
            'res://tests/contracts/content/vfx_animation_set_contract_test.gd',
            'res://tests/integration/battle/player_actor_animation_binding_test.gd'
        )
        foreach ($gutFile in $phase38GutFiles) {
            $reportName = ('phase38_' + ((Split-Path -Leaf $gutFile) -replace '\.gd$', ''))
            powershell -ExecutionPolicy Bypass -File tests\scripts\run_gut_suite.ps1 `
                -GodotExe $GodotExe `
                -ProjectPath $projectRoot `
                -TestFiles $gutFile `
                -ReportBaseName $reportName
            if ($LASTEXITCODE -ne 0) {
                throw "Phase38 GUT contract failed: $gutFile"
            }
        }
    }
}
finally {
    Pop-Location
}
