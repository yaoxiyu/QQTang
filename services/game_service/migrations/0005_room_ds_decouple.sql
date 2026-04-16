BEGIN;

ALTER TABLE matchmaking_assignments
    ADD COLUMN IF NOT EXISTS source_room_id TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS source_room_kind TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS battle_id TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS ds_instance_id TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS battle_server_host TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS battle_server_port INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS allocation_state TEXT NOT NULL DEFAULT 'assigned',
    ADD COLUMN IF NOT EXISTS room_return_policy TEXT NOT NULL DEFAULT 'return_to_source_room',
    ADD COLUMN IF NOT EXISTS allocation_started_at TIMESTAMPTZ NULL,
    ADD COLUMN IF NOT EXISTS battle_ready_at TIMESTAMPTZ NULL,
    ADD COLUMN IF NOT EXISTS battle_finished_at TIMESTAMPTZ NULL,
    ADD COLUMN IF NOT EXISTS return_completed_at TIMESTAMPTZ NULL;

ALTER TABLE matchmaking_assignment_members
    ADD COLUMN IF NOT EXISTS source_room_id TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS source_room_member_id TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS battle_join_state TEXT NOT NULL DEFAULT 'assigned',
    ADD COLUMN IF NOT EXISTS room_return_state TEXT NOT NULL DEFAULT 'pending';

CREATE TABLE IF NOT EXISTS battle_instances (
    battle_id        TEXT PRIMARY KEY,
    assignment_id    TEXT NOT NULL,
    match_id         TEXT NOT NULL,
    ds_instance_id   TEXT NOT NULL DEFAULT '',
    server_host      TEXT NOT NULL DEFAULT '',
    server_port      INTEGER NOT NULL DEFAULT 0,
    state            TEXT NOT NULL DEFAULT 'allocating',
    started_at       TIMESTAMPTZ NULL,
    ready_at         TIMESTAMPTZ NULL,
    finished_at      TIMESTAMPTZ NULL,
    finalized_at     TIMESTAMPTZ NULL,
    reaped_at        TIMESTAMPTZ NULL,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_battle_instances_assignment_id
    ON battle_instances(assignment_id);

CREATE UNIQUE INDEX IF NOT EXISTS uq_battle_instances_match_id
    ON battle_instances(match_id);

CREATE INDEX IF NOT EXISTS idx_battle_instances_state
    ON battle_instances(state, created_at DESC);

CREATE TABLE IF NOT EXISTS ds_instance_leases (
    ds_instance_id   TEXT PRIMARY KEY,
    battle_id        TEXT NOT NULL,
    host             TEXT NOT NULL,
    port             INTEGER NOT NULL,
    process_pid      INTEGER NOT NULL DEFAULT 0,
    state            TEXT NOT NULL DEFAULT 'reserved',
    started_at       TIMESTAMPTZ NULL,
    heartbeat_at     TIMESTAMPTZ NULL,
    exit_code        INTEGER NOT NULL DEFAULT 0,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_ds_instance_leases_battle_id
    ON ds_instance_leases(battle_id);

CREATE INDEX IF NOT EXISTS idx_ds_instance_leases_state
    ON ds_instance_leases(state, created_at DESC);

COMMIT;
