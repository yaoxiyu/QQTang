-- Ensure allocation error columns exist on older DBs that skipped prior migrations.
ALTER TABLE matchmaking_assignments
    ADD COLUMN IF NOT EXISTS allocation_error_code TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS allocation_last_error TEXT NOT NULL DEFAULT '';

