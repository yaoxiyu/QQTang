param(
    [Parameter(Mandatory = $true)]
    [string]$AssetPackRoot
)

$ErrorActionPreference = 'Stop'

& (Join-Path $PSScriptRoot 'build_asset_pack_manifest.ps1') -AssetPackRoot $AssetPackRoot
& (Join-Path $PSScriptRoot 'validate_asset_pack.ps1') -AssetPackRoot $AssetPackRoot

Write-Host ("[asset-pack-publish] local manifest built and validated: {0}" -f (Resolve-Path -LiteralPath $AssetPackRoot).Path)
