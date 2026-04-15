-- Phase23: relax constraints for manual-room-battle flow
BEGIN;

-- 1. queue_type: allow 'manual' alongside 'casual' and 'ranked'
ALTER TABLE matchmaking_assignments
    DROP CONSTRAINT IF EXISTS chk_matchmaking_assignments_queue_type;
ALTER TABLE matchmaking_assignments
    ADD CONSTRAINT chk_matchmaking_assignments_queue_type
    CHECK (queue_type IN ('casual', 'ranked', 'manual'));

ALTER TABLE matchmaking_queue_entries
    DROP CONSTRAINT IF EXISTS chk_matchmaking_queue_entries_queue_type;
ALTER TABLE matchmaking_queue_entries
    ADD CONSTRAINT chk_matchmaking_queue_entries_queue_type
    CHECK (queue_type IN ('casual', 'ranked', 'manual'));

-- 2. server_port: allow 0 for assignments created before DS allocation
ALTER TABLE matchmaking_assignments
    DROP CONSTRAINT IF EXISTS chk_matchmaking_assignments_server_port;
ALTER TABLE matchmaking_assignments
    ADD CONSTRAINT chk_matchmaking_assignments_server_port
    CHECK (server_port BETWEEN 0 AND 65535);

COMMIT;
