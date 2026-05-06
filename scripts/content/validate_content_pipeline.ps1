param(
    [string]$GodotExe = (Join-Path $PSScriptRoot '..\..\external\godot_binary\Godot.exe'),
    [string]$ProjectPath = ''
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
} else {
    $repoRoot = Resolve-Path -LiteralPath $ProjectPath
}
$repoRoot = $repoRoot.Path
. (Join-Path $repoRoot 'tools\lib\dev_common.ps1')

$gutScript = Join-Path $repoRoot 'tests\scripts\run_gut_suite.ps1'
$syntaxPreflightScript = Join-Path $repoRoot 'tests\scripts\check_gdscript_syntax.ps1'
$contentSanityScript = Join-Path $repoRoot 'scripts\content\check_content_sanity.ps1'
$reportPath = Join-Path $repoRoot 'build\generated\content_reports\content_pipeline_report.json'

$activity = 'content-validate'
Invoke-QQTProgressStep -Activity $activity -Step 1 -Total 4 -Name 'gdscript syntax preflight' -Action {
    & $syntaxPreflightScript -GodotExe $GodotExe -ProjectPath $repoRoot
}
Invoke-QQTProgressStep -Activity $activity -Step 2 -Total 4 -Name 'content sanity' -Action {
    & $contentSanityScript -ProjectPath $repoRoot
}

Invoke-QQTProgressStep -Activity $activity -Step 3 -Total 4 -Name 'content contracts' -Action {
    & $gutScript -GodotExe $GodotExe -ProjectPath $repoRoot -SuiteName 'content_pipeline_contracts' -ReportBaseName 'content_pipeline_contracts' -TestFiles @(
        'res://tests/contracts/content/map_resource_generation_contract_test.gd',
        'res://tests/contracts/content/map_variant_integrity_contract_test.gd',
        'res://tests/contracts/content/match_format_catalog_contract_test.gd',
        'res://tests/contracts/content/room_manifest_export_contract_test.gd',
        'res://tests/contracts/content/room_manifest_matches_catalog_contract_test.gd',
        'res://tests/contracts/content/generated_catalog_index_contract_test.gd',
        'res://tests/contracts/content/generated_catalog_index_matches_room_manifest_test.gd',
        'res://tests/contracts/content/explosion_flame_asset_contract_test.gd',
        'res://tests/contracts/content/character_animation_pipeline_contract_test.gd'
    )
}

Write-QQTProgress -Activity $activity -Step 4 -Total 4 -Status 'report check'

if (-not (Test-Path -LiteralPath $reportPath)) {
    throw "content pipeline report not found: $reportPath"
}

$reportJson = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
if ($null -eq $reportJson) {
    throw "content pipeline report is invalid json: $reportPath"
}

$errorCount = @($reportJson.errors).Count
Write-Host ("[content] report error_count={0}" -f $errorCount)
if ($errorCount -gt 0) {
    exit 1
}

Write-QQTProgress -Activity $activity -Completed
exit 0
