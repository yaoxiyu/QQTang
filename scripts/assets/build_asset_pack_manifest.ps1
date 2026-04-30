param(
    [Parameter(Mandatory = $true)]
    [string]$AssetPackRoot,
    [string]$AssetPackId = 'qqt-assets',
    [string]$Version = '',
    [string]$ManifestPath = '',
    [switch]$SkipPixelHash
)

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

if (-not (Test-Path -LiteralPath $AssetPackRoot)) {
    throw "asset pack root does not exist: $AssetPackRoot"
}
$assetPackRootPath = (Resolve-Path -LiteralPath $AssetPackRoot).Path
if ([string]::IsNullOrWhiteSpace($ManifestPath)) {
    $ManifestPath = Join-Path $assetPackRootPath 'manifests\asset_pack_manifest.json'
}
if ([string]::IsNullOrWhiteSpace($Version)) {
    $assetPackJson = Join-Path $assetPackRootPath 'asset_pack.json'
    if (Test-Path -LiteralPath $assetPackJson) {
        $Version = (Get-Content -Raw -LiteralPath $assetPackJson | ConvertFrom-Json).version
    }
}
if ([string]::IsNullOrWhiteSpace($Version)) {
    $Version = (Get-Date).ToUniversalTime().ToString('yyyy.MM.dd')
}

function Get-RelativePath {
    param([string]$Path)
    return $Path.Substring($assetPackRootPath.Length + 1).Replace('\', '/')
}

function Get-PixelSha256 {
    param([string]$Path)
    if ([System.IO.Path]::GetExtension($Path).ToLowerInvariant() -ne '.png') {
        return ''
    }
    $bitmap = $null
    $stream = $null
    try {
        $stream = [System.IO.File]::OpenRead($Path)
        $bitmap = [System.Drawing.Bitmap]::new($stream)
        $bytes = New-Object byte[] ($bitmap.Width * $bitmap.Height * 4)
        $offset = 0
        for ($y = 0; $y -lt $bitmap.Height; $y++) {
            for ($x = 0; $x -lt $bitmap.Width; $x++) {
                $pixel = $bitmap.GetPixel($x, $y)
                $bytes[$offset++] = $pixel.R
                $bytes[$offset++] = $pixel.G
                $bytes[$offset++] = $pixel.B
                $bytes[$offset++] = $pixel.A
            }
        }
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try {
            return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
        } finally {
            $sha.Dispose()
        }
    } finally {
        if ($null -ne $bitmap) { $bitmap.Dispose() }
        if ($null -ne $stream) { $stream.Dispose() }
    }
}

$files = @(
    Get-ChildItem -LiteralPath $assetPackRootPath -Recurse -File |
        Where-Object {
            $relative = Get-RelativePath $_.FullName
            $relative -ne 'asset_pack.json' -and
            $relative -ne 'manifests/asset_pack_manifest.json'
        } |
        Sort-Object FullName
)

$entries = foreach ($file in $files) {
    [ordered]@{
        path = Get-RelativePath $file.FullName
        size = $file.Length
        sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $file.FullName).Hash.ToLowerInvariant()
        pixel_sha256 = if ($SkipPixelHash) { '' } else { Get-PixelSha256 $file.FullName }
    }
}

$manifest = [ordered]@{
    schema_version = 1
    asset_pack_id = $AssetPackId
    version = $Version
    files = @($entries)
}

$manifestDir = Split-Path -Parent $ManifestPath
New-Item -ItemType Directory -Path $manifestDir -Force | Out-Null
[System.IO.File]::WriteAllText($ManifestPath, ($manifest | ConvertTo-Json -Depth 6), [System.Text.UTF8Encoding]::new($false))

$assetPackEntryPath = Join-Path $assetPackRootPath 'asset_pack.json'
if (-not (Test-Path -LiteralPath $assetPackEntryPath)) {
    $assetPackEntry = [ordered]@{
        schema_version = 1
        asset_pack_id = $AssetPackId
        version = $Version
        layout_version = 1
        source_root = 'source'
        derived_root = 'derived'
        manifests = [ordered]@{
            file_manifest = 'manifests/asset_pack_manifest.json'
            qqt_layered_bake = 'manifests/qqt_layered_bake_manifest.json'
        }
    }
    [System.IO.File]::WriteAllText($assetPackEntryPath, ($assetPackEntry | ConvertTo-Json -Depth 5), [System.Text.UTF8Encoding]::new($false))
}

Write-Host ("[asset-pack-manifest] files={0} manifest={1}" -f $entries.Count, $ManifestPath)
