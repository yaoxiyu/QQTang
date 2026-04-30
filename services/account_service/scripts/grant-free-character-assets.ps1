param(
    [string]$Dsn = $env:ACCOUNT_POSTGRES_DSN,

    [string]$PsqlExe = "psql",

    [string]$DockerContainer = "",

    [string]$DbUser = "",

    [string]$DbPassword = "",

    [string]$DbName = "",

    [string]$SourceType = "registration_default_backfill",

    [string]$DefaultCharacterID = "",

    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
$charactersCsv = Join-Path $repoRoot "content_source\csv\characters\characters.csv"

if (-not (Test-Path -LiteralPath $charactersCsv)) {
    throw "characters csv not found: $charactersCsv"
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
        Where-Object { $_.character_id -match '^char_1' } |
        ForEach-Object { [string]$_.character_id } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Sort-Object -Unique
)

if ($freeCharacterIds.Count -eq 0) {
    throw "no free character ids matched '^char_1' in $charactersCsv"
}

if ([string]::IsNullOrWhiteSpace($DefaultCharacterID)) {
    $DefaultCharacterID = $freeCharacterIds[0]
}

if ($freeCharacterIds -notcontains $DefaultCharacterID) {
    throw "DefaultCharacterID '$DefaultCharacterID' is not in free character ids: $($freeCharacterIds -join ', ')"
}

$escapedSourceType = $SourceType.Replace("'", "''")
$escapedDefaultCharacterID = $DefaultCharacterID.Replace("'", "''")
$characterSqlArray = Convert-ToSqlArrayLiteral -Values $freeCharacterIds

$modeStart = if ($DryRun) { "BEGIN;" } else { "BEGIN;" }
$modeEnd = if ($DryRun) { "ROLLBACK;" } else { "COMMIT;" }

$sqlTemplate = @'
\set ON_ERROR_STOP on

{0}

WITH free_characters AS (
    SELECT asset_id
    FROM unnest({1}) AS asset_id
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
revision_updates AS (
    UPDATE player_profiles p
    SET
        owned_asset_revision = owned_asset_revision + COALESCE(g.changed_count, 0) + COALESCE(d.changed_count, 0),
        updated_at = NOW()
    FROM (
        SELECT profile_id, COUNT(*) AS changed_count
        FROM granted
        GROUP BY profile_id
    ) g
    FULL OUTER JOIN (
        SELECT profile_id, COUNT(*) AS changed_count
        FROM default_updates
        GROUP BY profile_id
    ) d ON d.profile_id = g.profile_id
    WHERE p.profile_id = COALESCE(g.profile_id, d.profile_id)
    RETURNING p.profile_id
)
SELECT
    (SELECT COUNT(*) FROM player_profiles) AS profile_count,
    (SELECT COUNT(*) FROM free_characters) AS free_character_count,
    (SELECT COUNT(*) FROM granted) AS granted_asset_rows,
    (SELECT COUNT(*) FROM default_updates) AS default_character_updates,
    (SELECT COUNT(*) FROM revision_updates) AS revision_updated_profiles,
    '{3}' AS default_character_id;

{4}
'@

$sql = $sqlTemplate -f $modeStart, $characterSqlArray, $escapedSourceType, $escapedDefaultCharacterID, $modeEnd
$sqlFile = Join-Path ([System.IO.Path]::GetTempPath()) ("qqtang_grant_free_character_assets_{0}.sql" -f ([System.Guid]::NewGuid().ToString("N")))
Set-Content -LiteralPath $sqlFile -Value $sql -Encoding UTF8

try {
    Write-Host ("[grant-free-character-assets] repo_root={0}" -f $repoRoot)
    Write-Host ("[grant-free-character-assets] characters={0} ids={1}" -f $freeCharacterIds.Count, ($freeCharacterIds -join ","))
    Write-Host ("[grant-free-character-assets] default_character_id={0} dry_run={1}" -f $DefaultCharacterID, [bool]$DryRun)
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
