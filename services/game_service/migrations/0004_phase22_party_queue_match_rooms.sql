BEGIN;

CREATE TABLE IF NOT EXISTS matchmaking_party_queue_entries (
    party_queue_entry_id      TEXT PRIMARY KEY,
    party_room_id             TEXT NOT NULL,
    queue_type                TEXT NOT NULL,
    match_format_id           TEXT NOT NULL,
    party_size                INTEGER NOT NULL,
    captain_account_id        TEXT NOT NULL,
    captain_profile_id        TEXT NOT NULL,
    selected_mode_ids_json    JSONB NOT NULL DEFAULT '[]'::jsonb,
    queue_key                 TEXT NOT NULL,
    state                     TEXT NOT NULL DEFAULT 'queued',
    assignment_id             TEXT NULL,
    assignment_revision       INTEGER NOT NULL DEFAULT 0,
    enqueue_unix_sec          BIGINT NOT NULL,
    last_heartbeat_unix_sec   BIGINT NOT NULL,
    cancel_reason             TEXT NOT NULL DEFAULT '',
    created_at                TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at                TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_matchmaking_party_queue_entries_room_active
    ON matchmaking_party_queue_entries(party_room_id)
    WHERE state IN ('queued', 'assigned', 'committing');

CREATE INDEX IF NOT EXISTS idx_matchmaking_party_queue_entries_queue_key_state
    ON matchmaking_party_queue_entries(queue_key, state, enqueue_unix_sec);

CREATE INDEX IF NOT EXISTS idx_matchmaking_party_queue_entries_captain_account
    ON matchmaking_party_queue_entries(captain_account_id, state);

CREATE TABLE IF NOT EXISTS matchmaking_party_queue_members (
    party_queue_entry_id      TEXT NOT NULL,
    account_id                TEXT NOT NULL,
    profile_id                TEXT NOT NULL,
    device_session_id         TEXT NOT NULL,
    seat_index                INTEGER NOT NULL,
    rating_snapshot           INTEGER NOT NULL DEFAULT 1000,
    created_at                TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at                TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (party_queue_entry_id, account_id)
);

CREATE INDEX IF NOT EXISTS idx_matchmaking_party_queue_members_profile
    ON matchmaking_party_queue_members(profile_id);

COMMIT;
