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

COMMIT;
