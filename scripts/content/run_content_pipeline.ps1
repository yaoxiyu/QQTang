param(
    [string]$GodotExecutable = 'D:\Godot\Godot_console.exe',
    [string]$ProjectPath = ''
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    $projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
} else {
    $projectRoot = Resolve-Path -LiteralPath $ProjectPath
}

$syntaxPreflightScript = Join-Path $projectRoot 'tests\scripts\check_gdscript_syntax.ps1'
& $syntaxPreflightScript -GodotExe $GodotExecutable -ProjectPath $projectRoot

Push-Location $projectRoot
try {
    & $GodotExecutable --headless --path $projectRoot --script res://tools/content_pipeline/run_content_pipeline_cli.gd

    if ($LASTEXITCODE -ne 0) {
        throw "content pipeline failed (godot exit code: $LASTEXITCODE)"
    }

    $requiredPaths = @(
        'content\maps\resources\map_classic_square.tres',
        'content\maps\resources\map_breakable_center_lane.tres',
        'content\match_formats\data\formats\1v1.tres',
        'content\match_formats\data\formats\2v2.tres',
        'content\match_formats\data\formats\4v4.tres',
        'build\generated\room_manifest\room_manifest.json',
        'build\generated\content_catalog\characters_catalog_index.json',
        'build\generated\content_catalog\bubbles_catalog_index.json',
        'build\generated\content_catalog\maps_catalog_index.json',
        'build\generated\content_catalog\modes_catalog_index.json',
        'build\generated\content_catalog\rulesets_catalog_index.json',
        'build\generated\content_catalog\match_formats_catalog_index.json',
        'build\generated\content_catalog\content_catalog_summary.json',
        'build\generated\content_reports\content_pipeline_report.json'
    )

    foreach ($relativePath in $requiredPaths) {
        $fullPath = Join-Path $projectRoot $relativePath
        if (-not (Test-Path -LiteralPath $fullPath)) {
            throw "missing content pipeline output: $fullPath"
        }
    }

    $reportPath = Join-Path $projectRoot 'build\generated\content_reports\content_pipeline_report.json'
    $reportJson = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
    if ($null -eq $reportJson) {
        throw "content pipeline report is invalid json: $reportPath"
    }
    $errorCount = @($reportJson.errors).Count
    Write-Host ("[content] report error_count={0}" -f $errorCount)
    if ($errorCount -gt 0) {
        throw "content pipeline report contains errors: $errorCount"
    }
}
finally {
    Pop-Location
}

Write-Host "[content] content pipeline generated successfully"
