param(
    [Parameter(Mandatory = $true)]
    [string]$SourceRoot,

    [string]$ProjectPath = '',

    [string]$OutputDir = 'content_source\qqt_object_manifest'
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    $projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
} else {
    $projectRoot = Resolve-Path -LiteralPath $ProjectPath
}

$resolvedSourceRoot = Resolve-Path -LiteralPath $SourceRoot
$sourceRootPath = $resolvedSourceRoot.Path

$resolvedOutputDir = if ([System.IO.Path]::IsPathRooted($OutputDir)) {
    $OutputDir
} else {
    Join-Path $projectRoot $OutputDir
}

$rolePartDirs = @(
    'body',
    'head',
    'face',
    'mouth',
    'hair',
    'cloth',
    'leg',
    'foot',
    'npack',
    'cap',
    'fhadorn',
    'thadorn',
    'cladorn'
)

$directionMap = @{
    '0' = 'right'
    '1' = 'up'
    '2' = 'left'
    '3' = 'down'
}

$partFilePattern = '^(?<part>[a-z]+)(?<source_id>\d+)_(?<action>[a-z]+)(?<tail>(?:[_.][a-z0-9_]+)?)\.(?<format>png|gif)$'

Add-Type -AssemblyName System.Drawing

function Get-RelativePath {
    param(
        [string]$Root,
        [string]$Path
    )

    $rootUri = [System.Uri]::new((Join-Path $Root '.'))
    $pathUri = [System.Uri]::new($Path)
    return [System.Uri]::UnescapeDataString($rootUri.MakeRelativeUri($pathUri).ToString())
}

function Get-ProjectRelativePath {
    param(
        [string]$ProjectRoot,
        [string]$Path
    )

    return Get-RelativePath $ProjectRoot $Path
}

function Read-ImageInfo {
    param([string]$Path)

    $image = $null
    try {
        $image = [System.Drawing.Image]::FromFile($Path)
        $dimension = [System.Drawing.Imaging.FrameDimension]::new($image.FrameDimensionsList[0])
        return [PSCustomObject]@{
            Width = $image.Width
            Height = $image.Height
            FrameCount = $image.GetFrameCount($dimension)
        }
    }
    finally {
        if ($null -ne $image) {
            $image.Dispose()
        }
    }
}

function Add-Count {
    param(
        [hashtable]$Table,
        [string]$Key
    )

    if ([string]::IsNullOrWhiteSpace($Key)) {
        return
    }
    if (-not $Table.ContainsKey($Key)) {
        $Table[$Key] = 0
    }
    $Table[$Key] = [int]$Table[$Key] + 1
}

function Add-SetValue {
    param(
        [hashtable]$Table,
        [string]$Key,
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Key) -or [string]::IsNullOrWhiteSpace($Value)) {
        return
    }
    if (-not $Table.ContainsKey($Key)) {
        $Table[$Key] = [System.Collections.Generic.HashSet[string]]::new()
    }
    [void]$Table[$Key].Add($Value)
}

function Convert-SetTable {
    param([hashtable]$Table)

    $result = [ordered]@{}
    foreach ($key in ($Table.Keys | Sort-Object)) {
        $result[$key] = @($Table[$key] | Sort-Object)
    }
    return $result
}

function Convert-SourceIdTable {
    param([hashtable]$Table)

    $result = [ordered]@{}
    foreach ($key in ($Table.Keys | Sort-Object)) {
        $ids = @($Table[$key] | Sort-Object)
        $result[$key] = [ordered]@{
            count = $ids.Count
            sample = @($ids | Select-Object -First 40)
        }
    }
    return $result
}

function Convert-CountTable {
    param([hashtable]$Table)

    $result = [ordered]@{}
    foreach ($key in ($Table.Keys | Sort-Object)) {
        $result[$key] = $Table[$key]
    }
    return $result
}

New-Item -ItemType Directory -Path $resolvedOutputDir -Force | Out-Null

$allFiles = @(Get-ChildItem -LiteralPath $sourceRootPath -Recurse -File)
$records = New-Object System.Collections.Generic.List[object]
$errors = New-Object System.Collections.Generic.List[object]
$warnings = New-Object System.Collections.Generic.List[object]

$countsByExtension = @{}
$countsByDirectory = @{}
$countsByPart = @{}
$countsByAction = @{}
$countsByProjectDirection = @{}
$countsBySourceFormat = @{}
$sourceIdsByPart = @{}
$actionsByPart = @{}
$directionsByAction = @{}
$pathsByHash = @{}

foreach ($file in $allFiles) {
    Add-Count $countsByExtension $file.Extension.ToLowerInvariant()
    Add-Count $countsByDirectory $file.Directory.Name

    if (-not ($rolePartDirs -contains $file.Directory.Name)) {
        continue
    }
    if ($file.Extension.ToLowerInvariant() -notin @('.png', '.gif')) {
        continue
    }

    $match = [regex]::Match($file.Name, $partFilePattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if (-not $match.Success) {
        $warnings.Add([ordered]@{
            path = Get-RelativePath $sourceRootPath $file.FullName
            error = 'unmatched role-part filename'
        }) | Out-Null
        continue
    }

    $tail = $match.Groups['tail'].Value
    $namingSeparator = ''
    $variant = ''
    $sourceDirection = ''
    if (-not [string]::IsNullOrWhiteSpace($tail)) {
        $namingSeparator = $tail.Substring(0, 1)
        $tokens = @($tail.Substring(1).Split('_') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        if ($tokens.Count -eq 1) {
            if ($tokens[0] -match '^\d+$') {
                $sourceDirection = $tokens[0]
            } else {
                $variant = $tokens[0].ToLowerInvariant()
            }
        } elseif ($tokens.Count -ge 2) {
            $variant = $tokens[0].ToLowerInvariant()
            if ($tokens[-1] -match '^\d+$') {
                $sourceDirection = $tokens[-1]
            }
        }
    }

    try {
        $imageInfo = Read-ImageInfo $file.FullName
    }
    catch {
        $errors.Add([ordered]@{
            path = Get-RelativePath $sourceRootPath $file.FullName
            error = $_.Exception.Message
        }) | Out-Null
        continue
    }

    $projectDirection = ''
    if (-not [string]::IsNullOrWhiteSpace($sourceDirection) -and $directionMap.ContainsKey($sourceDirection)) {
        $projectDirection = $directionMap[$sourceDirection]
    }

    $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    $contentHash = "sha256:$hash"
    $relativePath = Get-RelativePath $sourceRootPath $file.FullName
    $projectRelativePath = Get-ProjectRelativePath $projectRoot $file.FullName

    $record = [PSCustomObject]@{
        part = $match.Groups['part'].Value.ToLowerInvariant()
        source_id = $match.Groups['source_id'].Value
        action = $match.Groups['action'].Value.ToLowerInvariant()
        variant = $variant
        source_direction = $sourceDirection
        project_direction = $projectDirection
        source_path = $projectRelativePath
        relative_path = $relativePath
        frame_width = $imageInfo.Width
        frame_height = $imageInfo.Height
        frame_count = $imageInfo.FrameCount
        source_format = $match.Groups['format'].Value.ToLowerInvariant()
        naming_separator = $namingSeparator
        content_hash = $contentHash
    }
    $records.Add($record) | Out-Null

    Add-Count $countsByPart $record.part
    Add-Count $countsByAction $record.action
    Add-Count $countsByProjectDirection $record.project_direction
    Add-Count $countsBySourceFormat $record.source_format
    Add-SetValue $sourceIdsByPart $record.part $record.source_id
    Add-SetValue $actionsByPart $record.part $record.action
    Add-SetValue $directionsByAction $record.action $record.project_direction

    if (-not $pathsByHash.ContainsKey($contentHash)) {
        $pathsByHash[$contentHash] = New-Object System.Collections.Generic.List[string]
    }
    $pathsByHash[$contentHash].Add($relativePath) | Out-Null
}

$records |
    Sort-Object part, source_id, action, source_direction, relative_path |
    Export-Csv -LiteralPath (Join-Path $resolvedOutputDir 'parts.csv') -NoTypeInformation -Encoding utf8

$characterCsvPath = Join-Path $projectRoot 'content_source\csv\characters\characters.csv'
$projectCharacterIds = @()
if (Test-Path -LiteralPath $characterCsvPath) {
    $projectCharacterIds = @(
        Import-Csv -LiteralPath $characterCsvPath |
            Where-Object { $_.tags -like '*qqt_resource*' -and -not [string]::IsNullOrWhiteSpace($_.character_id) } |
            ForEach-Object { $_.character_id } |
            Sort-Object -Unique
    )
}

$recordsBySourceId = @{}
foreach ($record in $records) {
    if (-not $recordsBySourceId.ContainsKey($record.source_id)) {
        $recordsBySourceId[$record.source_id] = New-Object System.Collections.Generic.List[object]
    }
    $recordsBySourceId[$record.source_id].Add($record) | Out-Null
}

$coverage = foreach ($characterId in $projectCharacterIds) {
    $matched = @()
    if ($recordsBySourceId.ContainsKey($characterId)) {
        $matched = @($recordsBySourceId[$characterId].ToArray())
    }
    [PSCustomObject]@{
        character_id = $characterId
        has_direct_part = ($matched.Count -gt 0)
        parts = (($matched | ForEach-Object { $_.part } | Sort-Object -Unique) -join ';')
        actions = (($matched | ForEach-Object { $_.action } | Sort-Object -Unique) -join ';')
        directions = (($matched | ForEach-Object { $_.project_direction } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique) -join ';')
    }
}

$coverage |
    Sort-Object character_id |
    Export-Csv -LiteralPath (Join-Path $resolvedOutputDir 'character_coverage.csv') -NoTypeInformation -Encoding utf8

$duplicateGroups = @(
    foreach ($hashKey in ($pathsByHash.Keys | Sort-Object)) {
        $paths = @($pathsByHash[$hashKey] | Sort-Object)
        if ($paths.Count -gt 1) {
            [ordered]@{
                content_hash = $hashKey
                paths = $paths
            }
        }
    }
)

$missingDirectIds = @($coverage | Where-Object { -not $_.has_direct_part } | ForEach-Object { $_.character_id })

$summary = [ordered]@{
    source_root = Get-ProjectRelativePath $projectRoot $sourceRootPath
    total_files = $allFiles.Count
    role_part_records = $records.Count
    errors = @($errors.ToArray())
    warnings = @($warnings.ToArray())
    counts = [ordered]@{
        by_extension = Convert-CountTable $countsByExtension
        by_directory = Convert-CountTable $countsByDirectory
        by_part = Convert-CountTable $countsByPart
        by_action = Convert-CountTable $countsByAction
        by_project_direction = Convert-CountTable $countsByProjectDirection
        by_source_format = Convert-CountTable $countsBySourceFormat
    }
    source_ids_by_part = Convert-SourceIdTable $sourceIdsByPart
    actions_by_part = Convert-SetTable $actionsByPart
    directions_by_action = Convert-SetTable $directionsByAction
    duplicate_group_count = $duplicateGroups.Count
    duplicate_groups = @($duplicateGroups | Select-Object -First 200)
    project_character_coverage = [ordered]@{
        character_csv = Get-ProjectRelativePath $projectRoot $characterCsvPath
        qqt_character_count = $coverage.Count
        direct_match_count = ($coverage.Count - $missingDirectIds.Count)
        missing_direct_ids = $missingDirectIds
    }
}

$summary |
    ConvertTo-Json -Depth 8 |
    Set-Content -LiteralPath (Join-Path $resolvedOutputDir 'summary.json') -Encoding utf8

Write-Host ("[qqt-object] records={0} warnings={1} errors={2} output={3}" -f $records.Count, $warnings.Count, $errors.Count, $resolvedOutputDir)
Write-Host ("[qqt-object] project_direct_matches={0}/{1}" -f ($coverage.Count - $missingDirectIds.Count), $coverage.Count)

if ($errors.Count -gt 0) {
    throw "QQTang object resource scan completed with errors: $($errors.Count)"
}
