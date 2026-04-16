-- Phase23: Allow 'battle_entry' purpose for battle ticket flow
ALTER TABLE room_entry_tickets
    DROP CONSTRAINT IF EXISTS ck_room_entry_tickets_purpose;

ALTER TABLE room_entry_tickets
    ADD CONSTRAINT ck_room_entry_tickets_purpose
        CHECK (purpose IN ('create', 'join', 'resume', 'battle_entry'));
