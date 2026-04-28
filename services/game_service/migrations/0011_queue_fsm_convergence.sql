BEGIN;

ALTER TABLE matchmaking_queue_entries
    ADD COLUMN IF NOT EXISTS terminal_reason TEXT NOT NULL DEFAULT '';

ALTER TABLE matchmaking_party_queue_entries
    ADD COLUMN IF NOT EXISTS terminal_reason TEXT NOT NULL DEFAULT '';

-- Drop legacy state constraints before rewriting rows to the Current FSM names.
ALTER TABLE matchmaking_queue_entries
    DROP CONSTRAINT IF EXISTS chk_matchmaking_queue_entries_state;
ALTER TABLE matchmaking_party_queue_entries
    DROP CONSTRAINT IF EXISTS chk_matchmaking_party_queue_entries_state;

-- Backfill terminal reason from legacy terminal states.
UPDATE matchmaking_queue_entries
SET terminal_reason = CASE
    WHEN state = 'cancelled' AND cancel_reason = 'heartbeat_timeout' THEN 'heartbeat_timeout'
    WHEN state = 'cancelled' THEN 'client_cancelled'
    WHEN state = 'failed' THEN 'allocation_failed'
    WHEN state = 'expired' THEN 'assignment_expired'
    WHEN state = 'finalized' THEN 'match_finalized'
    ELSE terminal_reason
END
WHERE terminal_reason = '';

UPDATE matchmaking_party_queue_entries
SET terminal_reason = CASE
    WHEN state = 'cancelled' AND cancel_reason = 'heartbeat_timeout' THEN 'heartbeat_timeout'
    WHEN state = 'cancelled' THEN 'client_cancelled'
    WHEN state = 'failed' THEN 'allocation_failed'
    WHEN state = 'expired' THEN 'assignment_expired'
    WHEN state = 'finalized' THEN 'match_finalized'
    ELSE terminal_reason
END
WHERE terminal_reason = '';

-- Normalize active states to canonical Queue FSM state set.
UPDATE matchmaking_queue_entries SET state = 'queued' WHERE state = 'queueing';
UPDATE matchmaking_queue_entries SET state = 'assignment_pending' WHERE state = 'assigned';
UPDATE matchmaking_queue_entries SET state = 'allocating_battle' WHERE state IN ('committing', 'allocating');
UPDATE matchmaking_queue_entries SET state = 'entry_ready' WHERE state IN ('battle_ready', 'matched');
UPDATE matchmaking_queue_entries SET state = 'completed' WHERE state IN ('cancelled', 'failed', 'expired', 'finalized');

UPDATE matchmaking_party_queue_entries SET state = 'queued' WHERE state = 'queueing';
UPDATE matchmaking_party_queue_entries SET state = 'assignment_pending' WHERE state = 'assigned';
UPDATE matchmaking_party_queue_entries SET state = 'allocating_battle' WHERE state IN ('committing', 'allocating');
UPDATE matchmaking_party_queue_entries SET state = 'entry_ready' WHERE state IN ('battle_ready', 'matched');
UPDATE matchmaking_party_queue_entries SET state = 'completed' WHERE state IN ('cancelled', 'failed', 'expired', 'finalized');

-- Ensure completed entries always carry a terminal reason.
UPDATE matchmaking_queue_entries
SET terminal_reason = CASE
    WHEN cancel_reason = 'heartbeat_timeout' THEN 'heartbeat_timeout'
    WHEN cancel_reason = 'assignment_missing' THEN 'assignment_missing'
    WHEN cancel_reason = 'assignment_expired' THEN 'assignment_expired'
    WHEN cancel_reason = 'match_finalized' THEN 'match_finalized'
    WHEN cancel_reason = 'client_cancelled' THEN 'client_cancelled'
    WHEN cancel_reason = 'party_cancelled' THEN 'client_cancelled'
    WHEN cancel_reason = 'allocation_failed' THEN 'allocation_failed'
    ELSE 'allocation_failed'
END
WHERE state = 'completed' AND terminal_reason = '';

UPDATE matchmaking_party_queue_entries
SET terminal_reason = CASE
    WHEN cancel_reason = 'heartbeat_timeout' THEN 'heartbeat_timeout'
    WHEN cancel_reason = 'assignment_missing' THEN 'assignment_missing'
    WHEN cancel_reason = 'assignment_expired' THEN 'assignment_expired'
    WHEN cancel_reason = 'match_finalized' THEN 'match_finalized'
    WHEN cancel_reason = 'client_cancelled' THEN 'client_cancelled'
    WHEN cancel_reason = 'party_cancelled' THEN 'client_cancelled'
    WHEN cancel_reason = 'allocation_failed' THEN 'allocation_failed'
    ELSE 'allocation_failed'
END
WHERE state = 'completed' AND terminal_reason = '';

DROP INDEX IF EXISTS uq_matchmaking_queue_entries_profile_active;
CREATE UNIQUE INDEX uq_matchmaking_queue_entries_profile_active
    ON matchmaking_queue_entries(profile_id)
    WHERE state IN ('queued', 'assignment_pending', 'allocating_battle', 'entry_ready');

DROP INDEX IF EXISTS uq_matchmaking_party_queue_entries_room_active;
CREATE UNIQUE INDEX uq_matchmaking_party_queue_entries_room_active
    ON matchmaking_party_queue_entries(party_room_id)
    WHERE state IN ('queued', 'assignment_pending', 'allocating_battle', 'entry_ready');

ALTER TABLE matchmaking_queue_entries
    ADD CONSTRAINT chk_matchmaking_queue_entries_state
    CHECK (state IN ('queued', 'assignment_pending', 'allocating_battle', 'entry_ready', 'completed')) NOT VALID;

ALTER TABLE matchmaking_party_queue_entries
    ADD CONSTRAINT chk_matchmaking_party_queue_entries_state
    CHECK (state IN ('queued', 'assignment_pending', 'allocating_battle', 'entry_ready', 'completed')) NOT VALID;

ALTER TABLE matchmaking_queue_entries
    VALIDATE CONSTRAINT chk_matchmaking_queue_entries_state;
ALTER TABLE matchmaking_party_queue_entries
    VALIDATE CONSTRAINT chk_matchmaking_party_queue_entries_state;

COMMIT;

