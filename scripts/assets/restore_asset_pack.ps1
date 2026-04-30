param(
    [Parameter(Mandatory = $true)]
    [string]$AssetPackRoot
)

$ErrorActionPreference = 'Stop'

New-Item -ItemType Directory -Path (Join-Path $AssetPackRoot 'source\res\object') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $AssetPackRoot 'derived\assets\animation\characters\qqt_layered') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $AssetPackRoot 'derived\assets\animation\characters\qqt_layered_team_variants') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $AssetPackRoot 'derived\assets\animation\overlays\team_color') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $AssetPackRoot 'derived\assets\animation\vfx') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $AssetPackRoot 'manifests') -Force | Out-Null

$assetPackJson = Join-Path $AssetPackRoot 'asset_pack.json'
if (-not (Test-Path -LiteralPath $assetPackJson)) {
    $entry = [ordered]@{
        schema_version = 1
        asset_pack_id = 'qqt-assets'
        version = (Get-Date).ToUniversalTime().ToString('yyyy.MM.dd')
        layout_version = 1
        source_root = 'source'
        derived_root = 'derived'
        manifests = [ordered]@{
            file_manifest = 'manifests/asset_pack_manifest.json'
            qqt_layered_bake = 'manifests/qqt_layered_bake_manifest.json'
        }
    }
    [System.IO.File]::WriteAllText($assetPackJson, ($entry | ConvertTo-Json -Depth 5), [System.Text.UTF8Encoding]::new($false))
}

Write-Host ("[asset-pack-restore] layout ready root={0}" -f (Resolve-Path -LiteralPath $AssetPackRoot).Path)
