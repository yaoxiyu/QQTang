BEGIN;

CREATE TABLE IF NOT EXISTS accounts (
    account_id           VARCHAR(64)  PRIMARY KEY,
    login_name           VARCHAR(64)  NOT NULL,
    password_hash        VARCHAR(255) NOT NULL,
    password_algo        VARCHAR(32)  NOT NULL,
    status               VARCHAR(32)  NOT NULL DEFAULT 'active',
    created_at           TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at           TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    last_login_at        TIMESTAMPTZ  NULL,

    CONSTRAINT ck_accounts_login_name_nonempty
        CHECK (char_length(trim(login_name)) > 0),

    CONSTRAINT ck_accounts_status
        CHECK (status IN ('active', 'disabled', 'banned'))
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_accounts_login_name
    ON accounts (login_name);

CREATE INDEX IF NOT EXISTS idx_accounts_status
    ON accounts (status);

CREATE INDEX IF NOT EXISTS idx_accounts_last_login_at
    ON accounts (last_login_at);


CREATE TABLE IF NOT EXISTS player_profiles (
    profile_id                  VARCHAR(64) PRIMARY KEY,
    account_id                  VARCHAR(64) NOT NULL,
    nickname                    VARCHAR(32) NOT NULL,
    default_character_id        VARCHAR(64) NOT NULL DEFAULT 'char_huoying',
    default_character_skin_id   VARCHAR(64) NOT NULL DEFAULT 'skin_gold',
    default_bubble_style_id     VARCHAR(64) NOT NULL DEFAULT 'bubble_round',
    default_bubble_skin_id      VARCHAR(64) NOT NULL DEFAULT 'bubble_skin_gold',
    preferred_mode_id           VARCHAR(64) NULL,
    preferred_map_id            VARCHAR(64) NULL,
    preferred_rule_set_id       VARCHAR(64) NULL,
    profile_version             BIGINT      NOT NULL DEFAULT 1,
    owned_asset_revision        BIGINT      NOT NULL DEFAULT 0,
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_player_profiles_account
        FOREIGN KEY (account_id)
        REFERENCES accounts(account_id)
        ON DELETE CASCADE,

    CONSTRAINT uq_player_profiles_account
        UNIQUE (account_id),

    CONSTRAINT uq_player_profiles_account_profile
        UNIQUE (account_id, profile_id),

    CONSTRAINT ck_player_profiles_nickname_nonempty
        CHECK (char_length(trim(nickname)) > 0),

    CONSTRAINT ck_player_profiles_profile_version_positive
        CHECK (profile_version > 0),

    CONSTRAINT ck_player_profiles_owned_asset_revision_nonnegative
        CHECK (owned_asset_revision >= 0)
);

CREATE INDEX IF NOT EXISTS idx_player_profiles_nickname
    ON player_profiles (nickname);

CREATE INDEX IF NOT EXISTS idx_player_profiles_updated_at
    ON player_profiles (updated_at);


CREATE TABLE IF NOT EXISTS player_owned_assets (
    account_id           VARCHAR(64) NOT NULL,
    profile_id           VARCHAR(64) NOT NULL,
    asset_type           VARCHAR(32) NOT NULL,
    asset_id             VARCHAR(64) NOT NULL,
    state                VARCHAR(32) NOT NULL DEFAULT 'owned',
    acquired_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    source_type          VARCHAR(32) NOT NULL DEFAULT 'system',

    CONSTRAINT pk_player_owned_assets
        PRIMARY KEY (profile_id, asset_type, asset_id),

    CONSTRAINT fk_player_owned_assets_account
        FOREIGN KEY (account_id)
        REFERENCES accounts(account_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_player_owned_assets_profile_pair
        FOREIGN KEY (account_id, profile_id)
        REFERENCES player_profiles(account_id, profile_id)
        ON DELETE CASCADE,

    CONSTRAINT ck_player_owned_assets_asset_type
        CHECK (asset_type IN ('character', 'character_skin', 'bubble', 'bubble_skin')),

    CONSTRAINT ck_player_owned_assets_state
        CHECK (state IN ('owned', 'disabled', 'expired')),

    CONSTRAINT ck_player_owned_assets_asset_id_nonempty
        CHECK (char_length(trim(asset_id)) > 0),

    CONSTRAINT ck_player_owned_assets_source_type_nonempty
        CHECK (char_length(trim(source_type)) > 0)
);

CREATE INDEX IF NOT EXISTS idx_player_owned_assets_account_id
    ON player_owned_assets (account_id);

CREATE INDEX IF NOT EXISTS idx_player_owned_assets_profile_id
    ON player_owned_assets (profile_id);

CREATE INDEX IF NOT EXISTS idx_player_owned_assets_asset_lookup
    ON player_owned_assets (asset_type, asset_id);

CREATE INDEX IF NOT EXISTS idx_player_owned_assets_acquired_at
    ON player_owned_assets (acquired_at);


CREATE TABLE IF NOT EXISTS account_sessions (
    session_id           VARCHAR(64)  PRIMARY KEY,
    account_id           VARCHAR(64)  NOT NULL,
    device_session_id    VARCHAR(64)  NOT NULL,
    refresh_token_hash   VARCHAR(255) NOT NULL,
    client_platform      VARCHAR(32)  NOT NULL DEFAULT 'unknown',
    issued_at            TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    access_expire_at     TIMESTAMPTZ  NOT NULL,
    refresh_expire_at    TIMESTAMPTZ  NOT NULL,
    revoked_at           TIMESTAMPTZ  NULL,
    last_seen_at         TIMESTAMPTZ  NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_account_sessions_account
        FOREIGN KEY (account_id)
        REFERENCES accounts(account_id)
        ON DELETE CASCADE,

    CONSTRAINT uq_account_sessions_refresh_token_hash
        UNIQUE (refresh_token_hash),

    CONSTRAINT ck_account_sessions_device_session_id_nonempty
        CHECK (char_length(trim(device_session_id)) > 0),

    CONSTRAINT ck_account_sessions_client_platform_nonempty
        CHECK (char_length(trim(client_platform)) > 0),

    CONSTRAINT ck_account_sessions_access_expire_after_issue
        CHECK (access_expire_at > issued_at),

    CONSTRAINT ck_account_sessions_refresh_expire_after_access
        CHECK (refresh_expire_at > access_expire_at)
);

CREATE INDEX IF NOT EXISTS idx_account_sessions_account_id
    ON account_sessions (account_id);

CREATE INDEX IF NOT EXISTS idx_account_sessions_device_session_id
    ON account_sessions (device_session_id);

CREATE INDEX IF NOT EXISTS idx_account_sessions_refresh_expire_at
    ON account_sessions (refresh_expire_at);

CREATE INDEX IF NOT EXISTS idx_account_sessions_last_seen_at
    ON account_sessions (last_seen_at);

CREATE INDEX IF NOT EXISTS idx_account_sessions_active_account
    ON account_sessions (account_id, refresh_expire_at DESC)
    WHERE revoked_at IS NULL;


CREATE TABLE IF NOT EXISTS room_entry_tickets (
    ticket_id            VARCHAR(64) PRIMARY KEY,
    account_id           VARCHAR(64) NOT NULL,
    profile_id           VARCHAR(64) NOT NULL,
    device_session_id    VARCHAR(64) NOT NULL,
    room_id              VARCHAR(64) NULL,
    room_kind            VARCHAR(32) NULL,
    purpose              VARCHAR(16) NOT NULL,
    requested_match_id   VARCHAR(64) NULL,
    claims_json          JSONB       NOT NULL DEFAULT '{}'::jsonb,
    issued_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expire_at            TIMESTAMPTZ NOT NULL,
    consumed_at          TIMESTAMPTZ NULL,

    CONSTRAINT fk_room_entry_tickets_account
        FOREIGN KEY (account_id)
        REFERENCES accounts(account_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_room_entry_tickets_profile_pair
        FOREIGN KEY (account_id, profile_id)
        REFERENCES player_profiles(account_id, profile_id)
        ON DELETE CASCADE,

    CONSTRAINT ck_room_entry_tickets_device_session_id_nonempty
        CHECK (char_length(trim(device_session_id)) > 0),

    CONSTRAINT ck_room_entry_tickets_purpose
        CHECK (purpose IN ('create', 'join', 'resume')),

    CONSTRAINT ck_room_entry_tickets_expire_after_issue
        CHECK (expire_at > issued_at)
);

CREATE INDEX IF NOT EXISTS idx_room_entry_tickets_account_id
    ON room_entry_tickets (account_id);

CREATE INDEX IF NOT EXISTS idx_room_entry_tickets_profile_id
    ON room_entry_tickets (profile_id);

CREATE INDEX IF NOT EXISTS idx_room_entry_tickets_room_id
    ON room_entry_tickets (room_id);

CREATE INDEX IF NOT EXISTS idx_room_entry_tickets_expire_at
    ON room_entry_tickets (expire_at);

CREATE INDEX IF NOT EXISTS idx_room_entry_tickets_purpose
    ON room_entry_tickets (purpose);

CREATE INDEX IF NOT EXISTS idx_room_entry_tickets_active_lookup
    ON room_entry_tickets (account_id, purpose, expire_at DESC)
    WHERE consumed_at IS NULL;

COMMIT;
