BEGIN;

ALTER TABLE matchmaking_assignments
    ADD COLUMN IF NOT EXISTS allocation_error_code TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS allocation_last_error TEXT NOT NULL DEFAULT '';

ALTER TABLE matchmaking_assignments
    DROP CONSTRAINT IF EXISTS chk_matchmaking_assignments_allocation_state;
ALTER TABLE matchmaking_assignments
    ADD CONSTRAINT chk_matchmaking_assignments_allocation_state
    CHECK (
        allocation_state IN (
            'assigned',
            'pending_allocate',
            'allocating',
            'allocated',
            'starting',
            'battle_ready',
            'battle_finished',
            'alloc_failed',
            'allocation_failed'
        )
    );

COMMIT;
