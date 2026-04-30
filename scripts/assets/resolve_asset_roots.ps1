param(
    [string]$ProjectPath = '',
    [string]$ConfigPath = 'config\local_asset_roots.json',
    [string]$AssetPackId = 'qqt-assets'
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    $projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
} else {
    $projectRoot = Resolve-Path -LiteralPath $ProjectPath
}

$configFullPath = if ([System.IO.Path]::IsPathRooted($ConfigPath)) {
    $ConfigPath
} else {
    Join-Path $projectRoot $ConfigPath
}

$roots = New-Object System.Collections.Generic.List[object]
if (Test-Path -LiteralPath $configFullPath) {
    $config = Get-Content -Raw -LiteralPath $configFullPath | ConvertFrom-Json
    foreach ($entry in @($config.asset_roots)) {
        if ($entry.asset_pack_id -eq $AssetPackId -and $entry.enabled) {
            $roots.Add([PSCustomObject]@{
                source = 'config'
                asset_pack_id = $entry.asset_pack_id
                root = $entry.root
            }) | Out-Null
        }
    }
}

if (-not [string]::IsNullOrWhiteSpace($env:QQT_ASSET_ROOT)) {
    $roots.Add([PSCustomObject]@{
        source = 'env:QQT_ASSET_ROOT'
        asset_pack_id = $AssetPackId
        root = $env:QQT_ASSET_ROOT
    }) | Out-Null
}

$roots.ToArray() | ConvertTo-Json -Depth 4
