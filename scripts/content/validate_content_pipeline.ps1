param(
    [string]$GodotExe = 'D:\Godot\Godot_console.exe',
    [string]$ProjectPath = ''
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
} else {
    $repoRoot = Resolve-Path -LiteralPath $ProjectPath
}

$gutScript = Join-Path $repoRoot 'tests\scripts\run_gut_suite.ps1'
$syntaxPreflightScript = Join-Path $repoRoot 'tests\scripts\check_gdscript_syntax.ps1'
$phase29SanityScript = Join-Path $repoRoot 'scripts\content\check_phase29_sanity.ps1'
$reportPath = Join-Path $repoRoot 'build\generated\content_reports\content_pipeline_report.json'

& $syntaxPreflightScript -GodotExe $GodotExe -ProjectPath $repoRoot
& $phase29SanityScript -ProjectPath $repoRoot

& $gutScript -GodotExe $GodotExe -ProjectPath $repoRoot -SuiteName 'content_pipeline_contracts' -ReportBaseName 'content_pipeline_contracts' -TestFiles @(
    'res://tests/contracts/content/map_resource_generation_contract_test.gd',
    'res://tests/contracts/content/map_variant_integrity_contract_test.gd',
    'res://tests/contracts/content/match_format_catalog_contract_test.gd',
    'res://tests/contracts/content/room_manifest_export_contract_test.gd',
    'res://tests/contracts/content/room_manifest_matches_catalog_contract_test.gd',
    'res://tests/contracts/content/generated_catalog_index_contract_test.gd',
    'res://tests/contracts/content/generated_catalog_index_matches_room_manifest_test.gd',
    'res://tests/contracts/content/character_animation_pipeline_contract_test.gd'
)

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

exit 0
