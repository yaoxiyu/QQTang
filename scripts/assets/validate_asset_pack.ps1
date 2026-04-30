param(
    [Parameter(Mandatory = $true)]
    [string]$AssetPackRoot,
    [switch]$SkipHash,
    [switch]$SkipPixelHash
)

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

if (-not (Test-Path -LiteralPath $AssetPackRoot)) {
    throw "asset pack root does not exist: $AssetPackRoot"
}
$assetPackRootPath = (Resolve-Path -LiteralPath $AssetPackRoot).Path
$assetPackJsonPath = Join-Path $assetPackRootPath 'asset_pack.json'
if (-not (Test-Path -LiteralPath $assetPackJsonPath)) {
    throw "asset_pack.json missing: $assetPackJsonPath"
}
$assetPack = Get-Content -Raw -LiteralPath $assetPackJsonPath | ConvertFrom-Json
$manifestRelativePath = if ($assetPack.manifests.file_manifest) { $assetPack.manifests.file_manifest } else { 'manifests/asset_pack_manifest.json' }
$manifestPath = Join-Path $assetPackRootPath ($manifestRelativePath -replace '/', '\')
if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "asset pack file manifest missing: $manifestPath"
}
$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
if ($manifest.asset_pack_id -ne $assetPack.asset_pack_id) {
    throw "asset pack id mismatch: asset_pack.json=$($assetPack.asset_pack_id), manifest=$($manifest.asset_pack_id)"
}
if ($manifest.version -ne $assetPack.version) {
    throw "asset pack version mismatch: asset_pack.json=$($assetPack.version), manifest=$($manifest.version)"
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

$checked = 0
foreach ($entry in @($manifest.files)) {
    $path = Join-Path $assetPackRootPath ([string]$entry.path -replace '/', '\')
    if (-not (Test-Path -LiteralPath $path)) {
        throw "asset file missing: $($entry.path)"
    }
    $file = Get-Item -LiteralPath $path
    if ($file.Length -ne [int64]$entry.size) {
        throw "asset file size mismatch: $($entry.path)"
    }
    if (-not $SkipHash) {
        $actualSha = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant()
        if ($actualSha -ne [string]$entry.sha256) {
            throw "asset file sha256 mismatch: $($entry.path)"
        }
    }
    if (-not $SkipPixelHash -and -not [string]::IsNullOrWhiteSpace([string]$entry.pixel_sha256)) {
        $actualPixelSha = Get-PixelSha256 $path
        if ($actualPixelSha -ne [string]$entry.pixel_sha256) {
            throw "asset file pixel sha256 mismatch: $($entry.path)"
        }
    }
    $checked++
}

Write-Host ("[asset-pack-validate] ok files={0} root={1}" -f $checked, $assetPackRootPath)
