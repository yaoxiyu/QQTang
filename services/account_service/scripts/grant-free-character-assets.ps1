param(
    [string]$Dsn = $env:ACCOUNT_POSTGRES_DSN,

    [string]$PsqlExe = "psql",

    [string]$DockerContainer = "",

    [string]$DbUser = "",

    [string]$DbPassword = "",

    [string]$DbName = "",

    [string]$SourceType = "registration_default_backfill",

    [string]$DefaultCharacterID = "",

    [string]$DefaultCharacterSkinID = "skin_gold",

    [string]$DefaultBubbleStyleID = "bubble_round",

    [string]$DefaultBubbleSkinID = "bubble_skin_gold",

    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
$charactersCsv = Join-Path $repoRoot "content_source\csv\characters\characters.csv"
$characterSkinsCsv = Join-Path $repoRoot "content_source\csv\character_skins\character_skins.csv"
$bubbleStylesCsv = Join-Path $repoRoot "content_source\csv\bubbles\bubble_styles.csv"
$bubbleSkinsCsv = Join-Path $repoRoot "content_source\csv\bubble_skins\bubble_skins.csv"

if (-not (Test-Path -LiteralPath $charactersCsv)) {
    throw "characters csv not found: $charactersCsv"
}
if (-not (Test-Path -LiteralPath $characterSkinsCsv)) {
    throw "character skins csv not found: $characterSkinsCsv"
}
if (-not (Test-Path -LiteralPath $bubbleStylesCsv)) {
    throw "bubble styles csv not found: $bubbleStylesCsv"
}
if (-not (Test-Path -LiteralPath $bubbleSkinsCsv)) {
    throw "bubble skins csv not found: $bubbleSkinsCsv"
}

function Convert-ToSqlArrayLiteral {
    param([string[]]$Values)

    if ($null -eq $Values -or $Values.Count -eq 0) {
        return "ARRAY[]::text[]"
    }

    $escaped = $Values | ForEach-Object {
        "'" + ($_.Replace("'", "''")) + "'"
    }
    return "ARRAY[" + ($escaped -join ", ") + "]"
}

$rows = Import-Csv -LiteralPath $charactersCsv
$freeCharacterIds = @(
    $rows |
        Where-Object {
            $characterId = [string]$_.character_id
            $numericId = 0
            [int]::TryParse($characterId, [ref]$numericId) -and
                $numericId -ge 10101 -and
                $numericId -le 12201
        } |
        ForEach-Object { [string]$_.character_id } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Sort-Object -Unique
)

if ($freeCharacterIds.Count -eq 0) {
    throw "no free character ids in range 10101-12201 in $charactersCsv"
}

if ([string]::IsNullOrWhiteSpace($DefaultCharacterID)) {
    $DefaultCharacterID = $freeCharacterIds[0]
}

if ($freeCharacterIds -notcontains $DefaultCharacterID) {
    throw "DefaultCharacterID '$DefaultCharacterID' is not in free character ids: $($freeCharacterIds -join ', ')"
}

$characterSkinIds = @(Import-Csv -LiteralPath $characterSkinsCsv | ForEach-Object { [string]$_.skin_id })
$bubbleStyleIds = @(Import-Csv -LiteralPath $bubbleStylesCsv | ForEach-Object { [string]$_.bubble_style_id })
$bubbleSkinIds = @(Import-Csv -LiteralPath $bubbleSkinsCsv | ForEach-Object { [string]$_.bubble_skin_id })
if ($characterSkinIds -notcontains $DefaultCharacterSkinID) {
    throw "DefaultCharacterSkinID '$DefaultCharacterSkinID' is not in $characterSkinsCsv"
}
if ($bubbleStyleIds -notcontains $DefaultBubbleStyleID) {
    throw "DefaultBubbleStyleID '$DefaultBubbleStyleID' is not in $bubbleStylesCsv"
}
if ($bubbleSkinIds -notcontains $DefaultBubbleSkinID) {
    throw "DefaultBubbleSkinID '$DefaultBubbleSkinID' is not in $bubbleSkinsCsv"
}

$escapedSourceType = $SourceType.Replace("'", "''")
$escapedDefaultCharacterID = $DefaultCharacterID.Replace("'", "''")
$escapedDefaultCharacterSkinID = $DefaultCharacterSkinID.Replace("'", "''")
$escapedDefaultBubbleStyleID = $DefaultBubbleStyleID.Replace("'", "''")
$escapedDefaultBubbleSkinID = $DefaultBubbleSkinID.Replace("'", "''")
$characterSqlArray = Convert-ToSqlArrayLiteral -Values $freeCharacterIds
$starterLoadoutSqlValues = @(
    "('character_skin', '$escapedDefaultCharacterSkinID')",
    "('bubble', '$escapedDefaultBubbleStyleID')",
    "('bubble_skin', '$escapedDefaultBubbleSkinID')"
) -join ",`n        "
$legacyCharacterSqlArray = Convert-ToSqlArrayLiteral -Values @(
    "char_11001",
    "char_12001",
    "char_13001",
    "char_14001",
    "char_15001",
    "char_16001",
    "char_17001",
    "char_19001",
    "char_51001",
    "char_52001",
    "char_53001",
    "char_54001",
    "char_55001",
    "char_56001",
    "char_65001"
)

$modeStart = if ($DryRun) { "BEGIN;" } else { "BEGIN;" }
$modeEnd = if ($DryRun) { "ROLLBACK;" } else { "COMMIT;" }

$sqlTemplate = @'
\set ON_ERROR_STOP on

{0}

WITH free_characters AS (
    SELECT asset_id
    FROM unnest({1}) AS asset_id
),
legacy_characters AS (
    SELECT asset_id
    FROM unnest({5}) AS asset_id
),
starter_loadout_assets AS (
    SELECT *
    FROM (VALUES
        {6}
    ) AS asset(asset_type, asset_id)
),
deleted_legacy_assets AS (
    DELETE FROM player_owned_assets poa
    USING legacy_characters l
    WHERE poa.asset_type = 'character'
      AND (
        poa.asset_id = l.asset_id
        OR poa.asset_id LIKE 'char\_%' ESCAPE '\'
      )
    RETURNING poa.profile_id
),
granted AS (
    INSERT INTO player_owned_assets (
        account_id,
        profile_id,
        asset_type,
        asset_id,
        state,
        acquired_at,
        source_type
    )
    SELECT
        p.account_id,
        p.profile_id,
        'character',
        f.asset_id,
        'owned',
        NOW(),
        '{2}'
    FROM player_profiles p
    CROSS JOIN free_characters f
    ON CONFLICT (profile_id, asset_type, asset_id)
    DO UPDATE SET
        account_id = EXCLUDED.account_id,
        state = 'owned',
        source_type = EXCLUDED.source_type
    WHERE player_owned_assets.state <> 'owned'
    RETURNING profile_id
),
granted_loadout_assets AS (
    INSERT INTO player_owned_assets (
        account_id,
        profile_id,
        asset_type,
        asset_id,
        state,
        acquired_at,
        source_type
    )
    SELECT
        p.account_id,
        p.profile_id,
        s.asset_type,
        s.asset_id,
        'owned',
        NOW(),
        '{2}'
    FROM player_profiles p
    CROSS JOIN starter_loadout_assets s
    ON CONFLICT (profile_id, asset_type, asset_id)
    DO UPDATE SET
        account_id = EXCLUDED.account_id,
        state = 'owned',
        source_type = EXCLUDED.source_type
    WHERE player_owned_assets.state <> 'owned'
    RETURNING profile_id
),
default_updates AS (
    UPDATE player_profiles p
    SET
        default_character_id = '{3}',
        updated_at = NOW()
    WHERE p.default_character_id IS NULL
       OR btrim(p.default_character_id) = ''
       OR NOT EXISTS (
            SELECT 1
            FROM free_characters f
            WHERE f.asset_id = p.default_character_id
       )
    RETURNING p.profile_id
),
loadout_default_updates AS (
    UPDATE player_profiles p
    SET
        default_character_skin_id = CASE
            WHEN p.default_character_skin_id IS NULL
              OR btrim(p.default_character_skin_id) = ''
              OR NOT EXISTS (
                    SELECT 1
                    FROM player_owned_assets poa
                    WHERE poa.profile_id = p.profile_id
                      AND poa.asset_type = 'character_skin'
                      AND poa.asset_id = p.default_character_skin_id
                      AND poa.state = 'owned'
              )
            THEN '{7}'
            ELSE p.default_character_skin_id
        END,
        default_bubble_style_id = CASE
            WHEN p.default_bubble_style_id IS NULL
              OR btrim(p.default_bubble_style_id) = ''
              OR NOT EXISTS (
                    SELECT 1
                    FROM player_owned_assets poa
                    WHERE poa.profile_id = p.profile_id
                      AND poa.asset_type = 'bubble'
                      AND poa.asset_id = p.default_bubble_style_id
                      AND poa.state = 'owned'
              )
            THEN '{8}'
            ELSE p.default_bubble_style_id
        END,
        default_bubble_skin_id = CASE
            WHEN p.default_bubble_skin_id IS NULL
              OR btrim(p.default_bubble_skin_id) = ''
              OR NOT EXISTS (
                    SELECT 1
                    FROM player_owned_assets poa
                    WHERE poa.profile_id = p.profile_id
                      AND poa.asset_type = 'bubble_skin'
                      AND poa.asset_id = p.default_bubble_skin_id
                      AND poa.state = 'owned'
              )
            THEN '{9}'
            ELSE p.default_bubble_skin_id
        END,
        updated_at = NOW()
    WHERE p.default_character_skin_id IS NULL
       OR btrim(p.default_character_skin_id) = ''
       OR p.default_bubble_style_id IS NULL
       OR btrim(p.default_bubble_style_id) = ''
       OR p.default_bubble_skin_id IS NULL
       OR btrim(p.default_bubble_skin_id) = ''
       OR NOT EXISTS (
            SELECT 1
            FROM player_owned_assets poa
            WHERE poa.profile_id = p.profile_id
              AND poa.asset_type = 'character_skin'
              AND poa.asset_id = p.default_character_skin_id
              AND poa.state = 'owned'
       )
       OR NOT EXISTS (
            SELECT 1
            FROM player_owned_assets poa
            WHERE poa.profile_id = p.profile_id
              AND poa.asset_type = 'bubble'
              AND poa.asset_id = p.default_bubble_style_id
              AND poa.state = 'owned'
       )
       OR NOT EXISTS (
            SELECT 1
            FROM player_owned_assets poa
            WHERE poa.profile_id = p.profile_id
              AND poa.asset_type = 'bubble_skin'
              AND poa.asset_id = p.default_bubble_skin_id
              AND poa.state = 'owned'
       )
    RETURNING p.profile_id
),
revision_updates AS (
    UPDATE player_profiles p
    SET
        owned_asset_revision = owned_asset_revision
            + COALESCE(g.changed_count, 0)
            + COALESCE(l.changed_count, 0)
            + COALESCE(d.changed_count, 0)
            + COALESCE(ld.changed_count, 0)
            + COALESCE(x.changed_count, 0),
        updated_at = NOW()
    FROM (
        SELECT profile_id, COUNT(*) AS changed_count
        FROM granted
        GROUP BY profile_id
    ) g
    FULL OUTER JOIN (
        SELECT profile_id, COUNT(*) AS changed_count
        FROM granted_loadout_assets
        GROUP BY profile_id
    ) l ON l.profile_id = g.profile_id
    FULL OUTER JOIN (
        SELECT profile_id, COUNT(*) AS changed_count
        FROM default_updates
        GROUP BY profile_id
    ) d ON d.profile_id = COALESCE(g.profile_id, l.profile_id)
    FULL OUTER JOIN (
        SELECT profile_id, COUNT(*) AS changed_count
        FROM loadout_default_updates
        GROUP BY profile_id
    ) ld ON ld.profile_id = COALESCE(g.profile_id, l.profile_id, d.profile_id)
    FULL OUTER JOIN (
        SELECT profile_id, COUNT(*) AS changed_count
        FROM deleted_legacy_assets
        GROUP BY profile_id
    ) x ON x.profile_id = COALESCE(g.profile_id, l.profile_id, d.profile_id, ld.profile_id)
    WHERE p.profile_id = COALESCE(g.profile_id, l.profile_id, d.profile_id, ld.profile_id, x.profile_id)
    RETURNING p.profile_id
)
SELECT
    (SELECT COUNT(*) FROM player_profiles) AS profile_count,
    (SELECT COUNT(*) FROM free_characters) AS free_character_count,
    (SELECT COUNT(*) FROM starter_loadout_assets) AS starter_loadout_asset_count,
    (SELECT COUNT(*) FROM deleted_legacy_assets) AS deleted_legacy_character_rows,
    (SELECT COUNT(*) FROM granted) AS granted_asset_rows,
    (SELECT COUNT(*) FROM granted_loadout_assets) AS granted_loadout_asset_rows,
    (SELECT COUNT(*) FROM default_updates) AS default_character_updates,
    (SELECT COUNT(*) FROM loadout_default_updates) AS loadout_default_updates,
    (SELECT COUNT(*) FROM revision_updates) AS revision_updated_profiles,
    '{3}' AS default_character_id,
    '{7}' AS default_character_skin_id,
    '{8}' AS default_bubble_style_id,
    '{9}' AS default_bubble_skin_id;

{4}
'@

$sql = $sqlTemplate -f $modeStart, $characterSqlArray, $escapedSourceType, $escapedDefaultCharacterID, $modeEnd, $legacyCharacterSqlArray, $starterLoadoutSqlValues, $escapedDefaultCharacterSkinID, $escapedDefaultBubbleStyleID, $escapedDefaultBubbleSkinID
$sqlFile = Join-Path ([System.IO.Path]::GetTempPath()) ("qqtang_grant_free_character_assets_{0}.sql" -f ([System.Guid]::NewGuid().ToString("N")))
Set-Content -LiteralPath $sqlFile -Value $sql -Encoding UTF8

try {
    Write-Host ("[grant-free-character-assets] repo_root={0}" -f $repoRoot)
    Write-Host ("[grant-free-character-assets] characters={0} ids={1}" -f $freeCharacterIds.Count, ($freeCharacterIds -join ","))
    Write-Host ("[grant-free-character-assets] default_character_id={0} default_character_skin_id={1} default_bubble_style_id={2} default_bubble_skin_id={3} dry_run={4}" -f $DefaultCharacterID, $DefaultCharacterSkinID, $DefaultBubbleStyleID, $DefaultBubbleSkinID, [bool]$DryRun)
    if (-not [string]::IsNullOrWhiteSpace($DockerContainer)) {
        if ([string]::IsNullOrWhiteSpace($DbUser) -or [string]::IsNullOrWhiteSpace($DbPassword) -or [string]::IsNullOrWhiteSpace($DbName)) {
            throw "Docker execution requires -DbUser, -DbPassword, and -DbName."
        }
        Get-Content -LiteralPath $sqlFile -Raw | docker exec -e PGPASSWORD=$DbPassword -i $DockerContainer psql -v ON_ERROR_STOP=1 -U $DbUser -d $DbName
        if ($LASTEXITCODE -ne 0) {
            throw "docker psql exited with code $LASTEXITCODE"
        }
    } else {
        if ([string]::IsNullOrWhiteSpace($Dsn)) {
            throw "ACCOUNT_POSTGRES_DSN is empty. Pass -Dsn/set ACCOUNT_POSTGRES_DSN, or use DockerContainer + DbUser + DbPassword + DbName."
        }
        & $PsqlExe $Dsn -f $sqlFile
        if ($LASTEXITCODE -ne 0) {
            throw "psql exited with code $LASTEXITCODE"
        }
    }
} finally {
    Remove-Item -LiteralPath $sqlFile -Force -ErrorAction SilentlyContinue
}
