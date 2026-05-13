param(
    [Parameter(Mandatory = $true)]
    [string]$SourceRoot,

    [string]$OutputCsv = '',

    [string]$ProjectPath = ''
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    $projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
} else {
    $projectRoot = Resolve-Path -LiteralPath $ProjectPath
}
$projectRoot = $projectRoot.Path

$resolvedSourceRoot = Resolve-Path -LiteralPath $SourceRoot
$sourceRootPath = $resolvedSourceRoot.Path

if ([string]::IsNullOrWhiteSpace($OutputCsv)) {
    $OutputCsv = Join-Path $projectRoot 'content_source\csv\items\items.csv'
}
$resolvedOutputCsv = if ([System.IO.Path]::IsPathRooted($OutputCsv)) {
    $OutputCsv
} else {
    Join-Path $projectRoot $OutputCsv
}

$outputDir = Split-Path $resolvedOutputCsv -Parent
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

$knownItems = @{
    1  = @{ display_name = 'Bubble Up'; description = 'Increase the number of bubbles the player can place by one.'; item_type = 1; pickup_effect_type = 'modify_bomb_capacity'; rarity = 'common' }
    2  = @{ display_name = 'Power Up'; description = 'Increase explosion range by one.'; item_type = 2; pickup_effect_type = 'modify_bomb_range'; rarity = 'common' }
    3  = @{ display_name = 'Speed Up'; description = 'Increase movement speed level by one.'; item_type = 3; pickup_effect_type = 'modify_speed'; rarity = 'common' }
    6  = @{ display_name = 'Max Bubble'; description = 'Set bubble capacity to maximum.'; item_type = 6; pickup_effect_type = 'max_bomb_capacity'; rarity = 'rare' }
    7  = @{ display_name = 'Max Power'; description = 'Set explosion range to maximum.'; item_type = 7; pickup_effect_type = 'max_bomb_range'; rarity = 'rare' }
    8  = @{ display_name = 'Max Speed'; description = 'Set speed to maximum.'; item_type = 8; pickup_effect_type = 'max_speed'; rarity = 'rare' }
}

$files = Get-ChildItem -LiteralPath $sourceRootPath -File
$itemData = @{}

foreach ($f in $files) {
    $itemId = $null
    $animType = $null

    if ($f.Name -match '^[iI]tem(\d+)_(stand|trigger)') {
        $itemId = [int]$matches[1]
        $animType = $matches[2].ToLowerInvariant()
    } else {
        continue
    }

    if (-not $itemData.ContainsKey($itemId)) {
        $itemData[$itemId] = @{
            item_id = $itemId
            has_stand = $false
            has_trigger = $false
            stand_format = ''
            trigger_format = ''
        }
    }

    $ext = $f.Extension.ToLowerInvariant()
    if ($animType -eq 'stand') {
        $itemData[$itemId].has_stand = $true
        $itemData[$itemId].stand_format = $ext
    } elseif ($animType -eq 'trigger') {
        $itemData[$itemId].has_trigger = $true
        $itemData[$itemId].trigger_format = $ext
    }
}

$csvHeader = 'item_id,display_name,description,item_type,pickup_effect_type,rarity,stand_source,trigger_source,enabled'
$csvLines = @($csvHeader)

foreach ($id in ($itemData.Keys | Sort-Object)) {
    $data = $itemData[$id]
    $known = $knownItems[$id]

    $displayName = 'Item {0}' -f $id
    $description = 'Unknown item effect.'
    $itemType = 0
    $pickupEffectType = 'unknown'
    $rarity = 'common'
    $enabled = 'false'

    if ($known -ne $null) {
        $displayName = $known.display_name
        $description = $known.description
        $itemType = $known.item_type
        $pickupEffectType = $known.pickup_effect_type
        $rarity = $known.rarity
        $enabled = 'true'
    }

    $standSource = ''
    if ($data.has_stand) {
        $standSource = ('external/assets/source/res/object/item/item{0}_stand{1}' -f $id, $data.stand_format)
        $standSource = $standSource.ToLowerInvariant()
    }

    $triggerSource = ''
    if ($data.has_trigger) {
        $triggerSource = ('external/assets/source/res/object/item/item{0}_trigger{1}' -f $id, $data.trigger_format)
        $triggerSource = $triggerSource.ToLowerInvariant()
    }

    if (-not $data.has_stand) {
        Write-Warning ('Item {0} has no stand animation, skipping' -f $id)
        continue
    }

    $csvLines += ('{0},{1},{2},{3},{4},{5},{6},{7},{8}' -f
        $id,
        ('"{0}"' -f $displayName),
        ('"{0}"' -f $description),
        $itemType,
        $pickupEffectType,
        $rarity,
        $standSource,
        $triggerSource,
        $enabled
    )
}

$csvLines -join "`r`n" | Set-Content -LiteralPath $resolvedOutputCsv -Encoding UTF8
Write-Host ('[scan-item] total_items={0} csv={1}' -f ($itemData.Count), $resolvedOutputCsv)
