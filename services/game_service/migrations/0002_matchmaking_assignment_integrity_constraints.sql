BEGIN;

UPDATE matchmaking_queue_entries
SET assignment_id = NULL
WHERE assignment_id = '';

UPDATE matchmaking_queue_entries q
SET assignment_id = NULL,
    assignment_revision = 0
WHERE assignment_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM matchmaking_assignments a
      WHERE a.assignment_id = q.assignment_id
  );

DELETE FROM matchmaking_assignment_members m
WHERE NOT EXISTS (
    SELECT 1
    FROM matchmaking_assignments a
    WHERE a.assignment_id = m.assignment_id
);

ALTER TABLE matchmaking_queue_entries
    ALTER COLUMN assignment_id DROP DEFAULT,
    ALTER COLUMN assignment_id DROP NOT NULL;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_matchmaking_queue_entries_state') THEN
        ALTER TABLE matchmaking_queue_entries
            ADD CONSTRAINT chk_matchmaking_queue_entries_state
            CHECK (state IN ('queued', 'assigned', 'committing', 'cancelled', 'expired', 'finalized')) NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_matchmaking_queue_entries_queue_type') THEN
        ALTER TABLE matchmaking_queue_entries
            ADD CONSTRAINT chk_matchmaking_queue_entries_queue_type
            CHECK (queue_type IN ('casual', 'ranked')) NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_matchmaking_assignments_queue_type') THEN
        ALTER TABLE matchmaking_assignments
            ADD CONSTRAINT chk_matchmaking_assignments_queue_type
            CHECK (queue_type IN ('casual', 'ranked')) NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_matchmaking_assignments_state') THEN
        ALTER TABLE matchmaking_assignments
            ADD CONSTRAINT chk_matchmaking_assignments_state
            CHECK (state IN ('assigned', 'committed', 'finalized', 'cancelled', 'expired')) NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_matchmaking_assignment_members_ticket_role') THEN
        ALTER TABLE matchmaking_assignment_members
            ADD CONSTRAINT chk_matchmaking_assignment_members_ticket_role
            CHECK (ticket_role IN ('create', 'join')) NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_matchmaking_assignment_members_join_state') THEN
        ALTER TABLE matchmaking_assignment_members
            ADD CONSTRAINT chk_matchmaking_assignment_members_join_state
            CHECK (join_state IN ('assigned', 'ticket_granted', 'room_committed', 'cancelled')) NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_matchmaking_assignment_members_result_state') THEN
        ALTER TABLE matchmaking_assignment_members
            ADD CONSTRAINT chk_matchmaking_assignment_members_result_state
            CHECK (result_state IN ('', 'finalized')) NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_matchmaking_assignment_members_assignment') THEN
        ALTER TABLE matchmaking_assignment_members
            ADD CONSTRAINT fk_matchmaking_assignment_members_assignment
            FOREIGN KEY (assignment_id)
            REFERENCES matchmaking_assignments(assignment_id)
            ON DELETE CASCADE
            NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_matchmaking_queue_entries_assignment') THEN
        ALTER TABLE matchmaking_queue_entries
            ADD CONSTRAINT fk_matchmaking_queue_entries_assignment
            FOREIGN KEY (assignment_id)
            REFERENCES matchmaking_assignments(assignment_id)
            ON DELETE SET NULL
            NOT VALID;
    END IF;
END $$;

ALTER TABLE matchmaking_queue_entries VALIDATE CONSTRAINT chk_matchmaking_queue_entries_state;
ALTER TABLE matchmaking_queue_entries VALIDATE CONSTRAINT chk_matchmaking_queue_entries_queue_type;
ALTER TABLE matchmaking_assignments VALIDATE CONSTRAINT chk_matchmaking_assignments_queue_type;
ALTER TABLE matchmaking_assignments VALIDATE CONSTRAINT chk_matchmaking_assignments_state;
ALTER TABLE matchmaking_assignment_members VALIDATE CONSTRAINT chk_matchmaking_assignment_members_ticket_role;
ALTER TABLE matchmaking_assignment_members VALIDATE CONSTRAINT chk_matchmaking_assignment_members_join_state;
ALTER TABLE matchmaking_assignment_members VALIDATE CONSTRAINT chk_matchmaking_assignment_members_result_state;
ALTER TABLE matchmaking_assignment_members VALIDATE CONSTRAINT fk_matchmaking_assignment_members_assignment;
ALTER TABLE matchmaking_queue_entries VALIDATE CONSTRAINT fk_matchmaking_queue_entries_assignment;

COMMIT;
