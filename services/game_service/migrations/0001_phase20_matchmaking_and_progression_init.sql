BEGIN;

CREATE TABLE IF NOT EXISTS season_definitions (
    season_id                TEXT PRIMARY KEY,
    display_name             TEXT NOT NULL,
    season_type              TEXT NOT NULL DEFAULT 'ranked',
    start_at                 TIMESTAMPTZ NOT NULL,
    end_at                   TIMESTAMPTZ NOT NULL,
    status                   TEXT NOT NULL DEFAULT 'pending',
    created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS matchmaking_queue_entries (
    queue_entry_id           TEXT PRIMARY KEY,
    queue_type               TEXT NOT NULL,
    queue_key                TEXT NOT NULL,
    season_id                TEXT NOT NULL,
    account_id               TEXT NOT NULL,
    profile_id               TEXT NOT NULL,
    device_session_id        TEXT NOT NULL,
    mode_id                  TEXT NOT NULL,
    rule_set_id              TEXT NOT NULL,
    preferred_map_pool_id    TEXT NOT NULL DEFAULT '',
    rating_snapshot          INTEGER NOT NULL DEFAULT 1000,
    enqueue_unix_sec         BIGINT NOT NULL,
    last_heartbeat_unix_sec  BIGINT NOT NULL,
    state                    TEXT NOT NULL DEFAULT 'queued',
    assignment_id            TEXT NULL,
    assignment_revision      INTEGER NOT NULL DEFAULT 0,
    cancel_reason            TEXT NOT NULL DEFAULT '',
    created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_matchmaking_queue_entries_queue_key_state
    ON matchmaking_queue_entries(queue_key, state, enqueue_unix_sec);

CREATE INDEX IF NOT EXISTS idx_matchmaking_queue_entries_account_id_state
    ON matchmaking_queue_entries(account_id, state);

CREATE UNIQUE INDEX IF NOT EXISTS uq_matchmaking_queue_entries_profile_active
    ON matchmaking_queue_entries(profile_id)
    WHERE state IN ('queued', 'assigned', 'committing');

CREATE TABLE IF NOT EXISTS matchmaking_assignments (
    assignment_id            TEXT PRIMARY KEY,
    queue_key                TEXT NOT NULL,
    queue_type               TEXT NOT NULL,
    season_id                TEXT NOT NULL,
    room_id                  TEXT NOT NULL,
    room_kind                TEXT NOT NULL DEFAULT 'matchmade_room',
    match_id                 TEXT NOT NULL,
    mode_id                  TEXT NOT NULL,
    rule_set_id              TEXT NOT NULL,
    map_id                   TEXT NOT NULL,
    server_host              TEXT NOT NULL,
    server_port              INTEGER NOT NULL,
    captain_account_id       TEXT NOT NULL,
    assignment_revision      INTEGER NOT NULL DEFAULT 1,
    expected_member_count    INTEGER NOT NULL,
    state                    TEXT NOT NULL DEFAULT 'assigned',
    captain_deadline_unix_sec BIGINT NOT NULL,
    commit_deadline_unix_sec BIGINT NOT NULL,
    finalized_at             TIMESTAMPTZ NULL,
    created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_matchmaking_assignments_match_id
    ON matchmaking_assignments(match_id);

CREATE TABLE IF NOT EXISTS matchmaking_assignment_members (
    assignment_id            TEXT NOT NULL,
    account_id               TEXT NOT NULL,
    profile_id               TEXT NOT NULL,
    ticket_role              TEXT NOT NULL,
    assigned_team_id         INTEGER NOT NULL,
    rating_before            INTEGER NOT NULL DEFAULT 1000,
    join_state               TEXT NOT NULL DEFAULT 'assigned',
    result_state             TEXT NOT NULL DEFAULT '',
    created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (assignment_id, account_id)
);

CREATE INDEX IF NOT EXISTS idx_matchmaking_assignment_members_profile
    ON matchmaking_assignment_members(profile_id);

CREATE TABLE IF NOT EXISTS match_results (
    match_id                 TEXT PRIMARY KEY,
    assignment_id            TEXT NOT NULL,
    room_id                  TEXT NOT NULL,
    room_kind                TEXT NOT NULL,
    season_id                TEXT NOT NULL,
    mode_id                  TEXT NOT NULL,
    rule_set_id              TEXT NOT NULL,
    map_id                   TEXT NOT NULL,
    finish_reason            TEXT NOT NULL,
    score_policy             TEXT NOT NULL,
    winner_team_ids_json     JSONB NOT NULL DEFAULT '[]'::jsonb,
    winner_peer_ids_json     JSONB NOT NULL DEFAULT '[]'::jsonb,
    started_at               TIMESTAMPTZ NULL,
    finished_at              TIMESTAMPTZ NOT NULL,
    result_hash              TEXT NOT NULL,
    finalize_revision        INTEGER NOT NULL DEFAULT 1,
    created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS player_match_results (
    match_id                 TEXT NOT NULL,
    account_id               TEXT NOT NULL,
    profile_id               TEXT NOT NULL,
    team_id                  INTEGER NOT NULL,
    peer_id                  INTEGER NOT NULL,
    outcome                  TEXT NOT NULL,
    player_score             INTEGER NOT NULL DEFAULT 0,
    team_score               INTEGER NOT NULL DEFAULT 0,
    placement                INTEGER NOT NULL DEFAULT 0,
    rating_before            INTEGER NOT NULL DEFAULT 1000,
    rating_delta             INTEGER NOT NULL DEFAULT 0,
    rating_after             INTEGER NOT NULL DEFAULT 1000,
    season_point_delta       INTEGER NOT NULL DEFAULT 0,
    career_xp_delta          INTEGER NOT NULL DEFAULT 0,
    gold_delta               INTEGER NOT NULL DEFAULT 0,
    created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (match_id, account_id)
);

CREATE INDEX IF NOT EXISTS idx_player_match_results_profile_id
    ON player_match_results(profile_id, created_at DESC);

CREATE TABLE IF NOT EXISTS season_rating_snapshots (
    season_id                TEXT NOT NULL,
    account_id               TEXT NOT NULL,
    profile_id               TEXT NOT NULL,
    rating                   INTEGER NOT NULL DEFAULT 1000,
    rank_tier                TEXT NOT NULL DEFAULT 'bronze',
    matches_played           INTEGER NOT NULL DEFAULT 0,
    wins                     INTEGER NOT NULL DEFAULT 0,
    losses                   INTEGER NOT NULL DEFAULT 0,
    draws                    INTEGER NOT NULL DEFAULT 0,
    last_match_id            TEXT NOT NULL DEFAULT '',
    updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (season_id, account_id)
);

CREATE INDEX IF NOT EXISTS idx_season_rating_snapshots_profile_id
    ON season_rating_snapshots(profile_id, updated_at DESC);

CREATE TABLE IF NOT EXISTS reward_ledger_entries (
    ledger_id                TEXT PRIMARY KEY,
    account_id               TEXT NOT NULL,
    profile_id               TEXT NOT NULL,
    match_id                 TEXT NOT NULL,
    reward_type              TEXT NOT NULL,
    delta                    INTEGER NOT NULL,
    source_type              TEXT NOT NULL,
    extra_json               JSONB NOT NULL DEFAULT '{}'::jsonb,
    issued_at                TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_reward_ledger_entries_profile_id
    ON reward_ledger_entries(profile_id, issued_at DESC);

CREATE TABLE IF NOT EXISTS career_summaries (
    profile_id               TEXT PRIMARY KEY,
    account_id               TEXT NOT NULL,
    total_matches            INTEGER NOT NULL DEFAULT 0,
    total_wins               INTEGER NOT NULL DEFAULT 0,
    total_losses             INTEGER NOT NULL DEFAULT 0,
    total_draws              INTEGER NOT NULL DEFAULT 0,
    win_rate_bp              INTEGER NOT NULL DEFAULT 0,
    current_season_id        TEXT NOT NULL DEFAULT '',
    current_rating           INTEGER NOT NULL DEFAULT 1000,
    current_rank_tier        TEXT NOT NULL DEFAULT 'bronze',
    last_match_id            TEXT NOT NULL DEFAULT '',
    last_match_outcome       TEXT NOT NULL DEFAULT '',
    last_match_finished_at   TIMESTAMPTZ NULL,
    updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMIT;
