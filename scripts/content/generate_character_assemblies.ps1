param(
    [string]$ProjectPath = '',
    [string]$PartsCsv = 'content_source\qqt_object_manifest\parts.csv',
    [string]$CharactersCsv = 'content_source\csv\characters\characters.csv',
    [string]$OutputCsv = 'content_source\csv\characters\qqt_character_assemblies.csv'
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    $projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
} else {
    $projectRoot = Resolve-Path -LiteralPath $ProjectPath
}

function Resolve-ProjectPath {
    param([string]$Path)
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }
    return Join-Path $projectRoot $Path
}

$partsPath = Resolve-ProjectPath $PartsCsv
$charactersPath = Resolve-ProjectPath $CharactersCsv
$outputPath = Resolve-ProjectPath $OutputCsv

$parts = @(Import-Csv -LiteralPath $partsPath)
$characters = @(
    Import-Csv -LiteralPath $charactersPath |
        Where-Object { $_.tags -like '*qqt_resource*' -and -not [string]::IsNullOrWhiteSpace($_.character_id) } |
        Sort-Object character_id
)

$idsByPart = @{}
foreach ($part in ($parts | Select-Object -ExpandProperty part -Unique)) {
    $idsByPart[$part] = @($parts | Where-Object { $_.part -eq $part } | Select-Object -ExpandProperty source_id -Unique)
}

function Has-PartId {
    param(
        [string]$Part,
        [string]$Id
    )
    return $idsByPart.ContainsKey($Part) -and ($idsByPart[$Part] -contains $Id)
}

function Resolve-PartId {
    param(
        [string]$Part,
        [string]$CharacterId,
        [string]$DefaultId = ''
    )
    if (Has-PartId $Part $CharacterId) {
        return $CharacterId
    }
    if (-not [string]::IsNullOrWhiteSpace($DefaultId) -and (Has-PartId $Part $DefaultId)) {
        return $DefaultId
    }
    return ''
}

function Get-CharacterType {
    param([object]$Character)
    $value = [string]$Character.type
    $characterType = 0
    [void][int]::TryParse($value, [ref]$characterType)
    return $characterType
}

$rows = foreach ($character in $characters) {
    $characterId = $character.character_id
    $characterType = Get-CharacterType $character
    $numericId = 0
    [void][int]::TryParse($characterId, [ref]$numericId)
    $directParts = @($parts | Where-Object { $_.source_id -eq $characterId } | Select-Object -ExpandProperty part -Unique | Sort-Object)
    $hasDirectBody = $directParts -contains 'body'
    $hasDirectCloth = $directParts -contains 'cloth'
    $bodyOnly = $hasDirectBody -and -not $hasDirectCloth
    $clothOnly = (-not $bodyOnly) -and (($characterId -in @('11001', '11101')) -or ($numericId -gt 12201))

    if ($characterType -eq 4) {
        $bodyId = Resolve-PartId 'body' $characterId ''
        $clothId = ''
        $legId = ''
        $footId = ''
        $headId = ''
        $hairId = ''
        $faceId = ''
        $mouthId = ''
        $npackId = ''
        $capId = ''
        $fhadornId = ''
        $thadornId = ''
        $cladornId = ''
    } else {
        $bodyId = if ($clothOnly) { '' } elseif ($bodyOnly) { Resolve-PartId 'body' $characterId '' } else { Resolve-PartId 'body' $characterId '1' }
        $clothId = Resolve-PartId 'cloth' $characterId ''
        $legId = if ($clothOnly) { '' } else { Resolve-PartId 'leg' $characterId '' }
        $footId = if ($clothOnly) { '' } else { Resolve-PartId 'foot' $characterId '1' }
        $headId = if ($clothOnly) { '' } else { Resolve-PartId 'head' $characterId '1' }
        $hairId = if ($clothOnly) { '' } else { Resolve-PartId 'hair' $characterId '' }
        $faceId = if ($clothOnly) { '' } else { Resolve-PartId 'face' $characterId '' }
        $mouthId = if ($clothOnly) { '' } else { Resolve-PartId 'mouth' $characterId '' }
        $npackId = Resolve-PartId 'npack' $characterId ''
        $capId = if ($clothOnly) { '' } else { Resolve-PartId 'cap' $characterId '' }
        $fhadornId = if ($clothOnly) { '' } else { Resolve-PartId 'fhadorn' $characterId '' }
        $thadornId = if ($clothOnly) { '' } else { Resolve-PartId 'thadorn' $characterId '' }
        $cladornId = if ($clothOnly) { '' } else { Resolve-PartId 'cladorn' $characterId '' }
    }

    $tags = @('qqt_resource', 'auto_assembly_v1')
    $notes = @()
    $character_kind = if ($characterType -eq 4) { 'item_character' } elseif ($bodyOnly) { 'transform_body' } elseif ($numericId -gt 0 -and $numericId -le 12201) { 'regular_colorable' } else { 'monster_or_boss' }
    if ($character_kind -eq 'regular_colorable') {
        $tags += 'regular_colorable'
    } elseif ($character_kind -eq 'transform_body') {
        $tags += 'transform_body'
        $tags += 'body_only'
    } elseif ($character_kind -eq 'item_character') {
        $tags += 'item_character'
        $tags += 'team_marker_only'
        $notes += 'type 4 item character bakes own body stand/walk only'
    } else {
        $tags += 'monster_or_boss'
    }
    if ($clothOnly) {
        $tags += 'cloth_only'
    }
    if ($directParts.Count -eq 0) {
        $tags += 'missing_direct_parts'
        $notes += 'no direct source_id parts matched'
    }
    if ($characterType -eq 4) {
        if ([string]::IsNullOrWhiteSpace($bodyId)) {
            $tags += 'missing_body'
            $notes += 'own body missing'
        }
        $tags += 'runtime_team_marker'
    } elseif ($bodyOnly) {
        $notes += 'body-only transform source'
    } elseif ([string]::IsNullOrWhiteSpace($clothId)) {
        $tags += 'missing_cloth'
        $notes += 'cloth missing'
    }
    if ($characterType -ne 4 -and -not $bodyOnly -and [string]::IsNullOrWhiteSpace($hairId)) {
        $tags += 'missing_hair'
    }
    if ($characterType -ne 4 -and -not $bodyOnly -and [string]::IsNullOrWhiteSpace($faceId)) {
        $tags += 'missing_face'
    }

    [PSCustomObject]@{
        character_id = $characterId
        assembly_id = "qqt_$characterId"
        character_type = $characterType
        character_kind = $character_kind
        body_id = $bodyId
        cloth_id = $clothId
        leg_id = $legId
        foot_id = $footId
        head_id = $headId
        hair_id = $hairId
        face_id = $faceId
        mouth_id = $mouthId
        npack_id = $npackId
        cap_id = $capId
        fhadorn_id = $fhadornId
        thadorn_id = $thadornId
        cladorn_id = $cladornId
        default_palette_id = 'default'
        direct_parts = ($directParts -join ';')
        bake_enabled = if ($characterType -eq 4) { -not [string]::IsNullOrWhiteSpace($bodyId) } else { ((-not [string]::IsNullOrWhiteSpace($clothId)) -or (-not [string]::IsNullOrWhiteSpace($bodyId))) }
        tags = ($tags | Sort-Object -Unique) -join ';'
        notes = $notes -join '; '
    }
}

New-Item -ItemType Directory -Path (Split-Path -Parent $outputPath) -Force | Out-Null
$rows | Export-Csv -LiteralPath $outputPath -NoTypeInformation -Encoding utf8

$enabledCount = @($rows | Where-Object { $_.bake_enabled }).Count
Write-Host ("[qqt-assembly] rows={0} bake_enabled={1} output={2}" -f @($rows).Count, $enabledCount, $outputPath)
