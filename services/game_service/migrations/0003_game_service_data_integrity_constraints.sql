BEGIN;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_season_definitions_type') THEN
        ALTER TABLE season_definitions
            ADD CONSTRAINT chk_season_definitions_type
            CHECK (season_type IN ('casual', 'ranked', 'event')) NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_season_definitions_status') THEN
        ALTER TABLE season_definitions
            ADD CONSTRAINT chk_season_definitions_status
            CHECK (status IN ('pending', 'active', 'finished', 'archived')) NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_season_definitions_time_window') THEN
        ALTER TABLE season_definitions
            ADD CONSTRAINT chk_season_definitions_time_window
            CHECK (end_at > start_at) NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_matchmaking_queue_entries_rating') THEN
        ALTER TABLE matchmaking_queue_entries
            ADD CONSTRAINT chk_matchmaking_queue_entries_rating
            CHECK (rating_snapshot >= 0) NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_matchmaking_queue_entries_heartbeat') THEN
        ALTER TABLE matchmaking_queue_entries
            ADD CONSTRAINT chk_matchmaking_queue_entries_heartbeat
            CHECK (last_heartbeat_unix_sec >= enqueue_unix_sec) NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_matchmaking_queue_entries_assignment_revision') THEN
        ALTER TABLE matchmaking_queue_entries
            ADD CONSTRAINT chk_matchmaking_queue_entries_assignment_revision
            CHECK (assignment_revision >= 0) NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_matchmaking_assignments_member_count') THEN
        ALTER TABLE matchmaking_assignments
            ADD CONSTRAINT chk_matchmaking_assignments_member_count
            CHECK (expected_member_count > 0) NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_matchmaking_assignments_server_port') THEN
        ALTER TABLE matchmaking_assignments
            ADD CONSTRAINT chk_matchmaking_assignments_server_port
            CHECK (server_port BETWEEN 1 AND 65535) NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_matchmaking_assignments_revision') THEN
        ALTER TABLE matchmaking_assignments
            ADD CONSTRAINT chk_matchmaking_assignments_revision
            CHECK (assignment_revision > 0) NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_matchmaking_assignments_deadlines') THEN
        ALTER TABLE matchmaking_assignments
            ADD CONSTRAINT chk_matchmaking_assignments_deadlines
            CHECK (commit_deadline_unix_sec >= captain_deadline_unix_sec) NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_matchmaking_assignments_finalized_at') THEN
        ALTER TABLE matchmaking_assignments
            ADD CONSTRAINT chk_matchmaking_assignments_finalized_at
            CHECK ((state = 'finalized') = (finalized_at IS NOT NULL)) NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_matchmaking_assignment_members_team') THEN
        ALTER TABLE matchmaking_assignment_members
            ADD CONSTRAINT chk_matchmaking_assignment_members_team
            CHECK (assigned_team_id > 0) NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_matchmaking_assignment_members_rating') THEN
        ALTER TABLE matchmaking_assignment_members
            ADD CONSTRAINT chk_matchmaking_assignment_members_rating
            CHECK (rating_before >= 0) NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_match_results_assignment') THEN
        ALTER TABLE match_results
            ADD CONSTRAINT fk_match_results_assignment
            FOREIGN KEY (assignment_id)
            REFERENCES matchmaking_assignments(assignment_id)
            ON DELETE RESTRICT
            NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'uq_match_results_assignment') THEN
        ALTER TABLE match_results
            ADD CONSTRAINT uq_match_results_assignment
            UNIQUE (assignment_id);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_match_results_revision') THEN
        ALTER TABLE match_results
            ADD CONSTRAINT chk_match_results_revision
            CHECK (finalize_revision > 0) NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_match_results_time_window') THEN
        ALTER TABLE match_results
            ADD CONSTRAINT chk_match_results_time_window
            CHECK (started_at IS NULL OR finished_at >= started_at) NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_match_results_winner_team_json') THEN
        ALTER TABLE match_results
            ADD CONSTRAINT chk_match_results_winner_team_json
            CHECK (jsonb_typeof(winner_team_ids_json) = 'array') NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_match_results_winner_peer_json') THEN
        ALTER TABLE match_results
            ADD CONSTRAINT chk_match_results_winner_peer_json
            CHECK (jsonb_typeof(winner_peer_ids_json) = 'array') NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_player_match_results_match') THEN
        ALTER TABLE player_match_results
            ADD CONSTRAINT fk_player_match_results_match
            FOREIGN KEY (match_id)
            REFERENCES match_results(match_id)
            ON DELETE CASCADE
            NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_player_match_results_outcome') THEN
        ALTER TABLE player_match_results
            ADD CONSTRAINT chk_player_match_results_outcome
            CHECK (outcome IN ('win', 'loss', 'draw')) NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_player_match_results_scores') THEN
        ALTER TABLE player_match_results
            ADD CONSTRAINT chk_player_match_results_scores
            CHECK (
                team_id > 0
                AND peer_id > 0
                AND player_score >= 0
                AND team_score >= 0
                AND placement >= 0
            ) NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_player_match_results_rating') THEN
        ALTER TABLE player_match_results
            ADD CONSTRAINT chk_player_match_results_rating
            CHECK (
                rating_before >= 0
                AND rating_after >= 0
                AND rating_after = rating_before + rating_delta
            ) NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_season_rating_snapshots_values') THEN
        ALTER TABLE season_rating_snapshots
            ADD CONSTRAINT chk_season_rating_snapshots_values
            CHECK (
                rating >= 0
                AND matches_played >= 0
                AND wins >= 0
                AND losses >= 0
                AND draws >= 0
                AND wins + losses + draws <= matches_played
            ) NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_season_rating_snapshots_rank_tier') THEN
        ALTER TABLE season_rating_snapshots
            ADD CONSTRAINT chk_season_rating_snapshots_rank_tier
            CHECK (rank_tier IN ('bronze', 'silver', 'gold', 'platinum', 'diamond')) NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_reward_ledger_entries_match') THEN
        ALTER TABLE reward_ledger_entries
            ADD CONSTRAINT fk_reward_ledger_entries_match
            FOREIGN KEY (match_id)
            REFERENCES match_results(match_id)
            ON DELETE CASCADE
            NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'uq_reward_ledger_entries_match_account_type_source') THEN
        ALTER TABLE reward_ledger_entries
            ADD CONSTRAINT uq_reward_ledger_entries_match_account_type_source
            UNIQUE (match_id, account_id, reward_type, source_type);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_reward_ledger_entries_type') THEN
        ALTER TABLE reward_ledger_entries
            ADD CONSTRAINT chk_reward_ledger_entries_type
            CHECK (reward_type IN ('season_point', 'career_xp', 'soft_gold')) NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_reward_ledger_entries_source') THEN
        ALTER TABLE reward_ledger_entries
            ADD CONSTRAINT chk_reward_ledger_entries_source
            CHECK (source_type IN ('match_finalize')) NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_reward_ledger_entries_delta') THEN
        ALTER TABLE reward_ledger_entries
            ADD CONSTRAINT chk_reward_ledger_entries_delta
            CHECK (delta <> 0) NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_reward_ledger_entries_extra_json') THEN
        ALTER TABLE reward_ledger_entries
            ADD CONSTRAINT chk_reward_ledger_entries_extra_json
            CHECK (jsonb_typeof(extra_json) = 'object') NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_career_summaries_values') THEN
        ALTER TABLE career_summaries
            ADD CONSTRAINT chk_career_summaries_values
            CHECK (
                total_matches >= 0
                AND total_wins >= 0
                AND total_losses >= 0
                AND total_draws >= 0
                AND total_wins + total_losses + total_draws <= total_matches
                AND win_rate_bp BETWEEN 0 AND 10000
                AND current_rating >= 0
            ) NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_career_summaries_rank_tier') THEN
        ALTER TABLE career_summaries
            ADD CONSTRAINT chk_career_summaries_rank_tier
            CHECK (current_rank_tier IN ('bronze', 'silver', 'gold', 'platinum', 'diamond')) NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_career_summaries_last_outcome') THEN
        ALTER TABLE career_summaries
            ADD CONSTRAINT chk_career_summaries_last_outcome
            CHECK (last_match_outcome IN ('', 'win', 'loss', 'draw')) NOT VALID;
    END IF;
END $$;

ALTER TABLE season_definitions VALIDATE CONSTRAINT chk_season_definitions_type;
ALTER TABLE season_definitions VALIDATE CONSTRAINT chk_season_definitions_status;
ALTER TABLE season_definitions VALIDATE CONSTRAINT chk_season_definitions_time_window;
ALTER TABLE matchmaking_queue_entries VALIDATE CONSTRAINT chk_matchmaking_queue_entries_rating;
ALTER TABLE matchmaking_queue_entries VALIDATE CONSTRAINT chk_matchmaking_queue_entries_heartbeat;
ALTER TABLE matchmaking_queue_entries VALIDATE CONSTRAINT chk_matchmaking_queue_entries_assignment_revision;
ALTER TABLE matchmaking_assignments VALIDATE CONSTRAINT chk_matchmaking_assignments_member_count;
ALTER TABLE matchmaking_assignments VALIDATE CONSTRAINT chk_matchmaking_assignments_server_port;
ALTER TABLE matchmaking_assignments VALIDATE CONSTRAINT chk_matchmaking_assignments_revision;
ALTER TABLE matchmaking_assignments VALIDATE CONSTRAINT chk_matchmaking_assignments_deadlines;
ALTER TABLE matchmaking_assignments VALIDATE CONSTRAINT chk_matchmaking_assignments_finalized_at;
ALTER TABLE matchmaking_assignment_members VALIDATE CONSTRAINT chk_matchmaking_assignment_members_team;
ALTER TABLE matchmaking_assignment_members VALIDATE CONSTRAINT chk_matchmaking_assignment_members_rating;
ALTER TABLE match_results VALIDATE CONSTRAINT fk_match_results_assignment;
ALTER TABLE match_results VALIDATE CONSTRAINT chk_match_results_revision;
ALTER TABLE match_results VALIDATE CONSTRAINT chk_match_results_time_window;
ALTER TABLE match_results VALIDATE CONSTRAINT chk_match_results_winner_team_json;
ALTER TABLE match_results VALIDATE CONSTRAINT chk_match_results_winner_peer_json;
ALTER TABLE player_match_results VALIDATE CONSTRAINT fk_player_match_results_match;
ALTER TABLE player_match_results VALIDATE CONSTRAINT chk_player_match_results_outcome;
ALTER TABLE player_match_results VALIDATE CONSTRAINT chk_player_match_results_scores;
ALTER TABLE player_match_results VALIDATE CONSTRAINT chk_player_match_results_rating;
ALTER TABLE season_rating_snapshots VALIDATE CONSTRAINT chk_season_rating_snapshots_values;
ALTER TABLE season_rating_snapshots VALIDATE CONSTRAINT chk_season_rating_snapshots_rank_tier;
ALTER TABLE reward_ledger_entries VALIDATE CONSTRAINT fk_reward_ledger_entries_match;
ALTER TABLE reward_ledger_entries VALIDATE CONSTRAINT chk_reward_ledger_entries_type;
ALTER TABLE reward_ledger_entries VALIDATE CONSTRAINT chk_reward_ledger_entries_source;
ALTER TABLE reward_ledger_entries VALIDATE CONSTRAINT chk_reward_ledger_entries_delta;
ALTER TABLE reward_ledger_entries VALIDATE CONSTRAINT chk_reward_ledger_entries_extra_json;
ALTER TABLE career_summaries VALIDATE CONSTRAINT chk_career_summaries_values;
ALTER TABLE career_summaries VALIDATE CONSTRAINT chk_career_summaries_rank_tier;
ALTER TABLE career_summaries VALIDATE CONSTRAINT chk_career_summaries_last_outcome;

COMMIT;
