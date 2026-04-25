-- Phase34: wallet, inventory extension, and shop purchase transaction schema.

BEGIN;

ALTER TABLE player_profiles
    ADD COLUMN IF NOT EXISTS avatar_id VARCHAR(64) NULL,
    ADD COLUMN IF NOT EXISTS title_id VARCHAR(64) NULL,
    ADD COLUMN IF NOT EXISTS wallet_revision BIGINT NOT NULL DEFAULT 0;

ALTER TABLE player_profiles
    DROP CONSTRAINT IF EXISTS ck_player_profiles_wallet_revision_nonnegative;

ALTER TABLE player_profiles
    ADD CONSTRAINT ck_player_profiles_wallet_revision_nonnegative
        CHECK (wallet_revision >= 0);

ALTER TABLE player_owned_assets
    ADD COLUMN IF NOT EXISTS quantity BIGINT NOT NULL DEFAULT 1,
    ADD COLUMN IF NOT EXISTS expire_at TIMESTAMPTZ NULL,
    ADD COLUMN IF NOT EXISTS source_ref_id VARCHAR(128) NULL,
    ADD COLUMN IF NOT EXISTS revision BIGINT NOT NULL DEFAULT 1;

ALTER TABLE player_owned_assets
    DROP CONSTRAINT IF EXISTS ck_player_owned_assets_asset_type;

ALTER TABLE player_owned_assets
    ADD CONSTRAINT ck_player_owned_assets_asset_type
        CHECK (asset_type IN ('character', 'character_skin', 'bubble', 'bubble_skin', 'avatar', 'title'));

ALTER TABLE player_owned_assets
    DROP CONSTRAINT IF EXISTS ck_player_owned_assets_state;

ALTER TABLE player_owned_assets
    ADD CONSTRAINT ck_player_owned_assets_state
        CHECK (state IN ('owned', 'disabled', 'expired', 'trial'));

ALTER TABLE player_owned_assets
    DROP CONSTRAINT IF EXISTS ck_player_owned_assets_quantity_positive;

ALTER TABLE player_owned_assets
    ADD CONSTRAINT ck_player_owned_assets_quantity_positive
        CHECK (quantity > 0);

ALTER TABLE player_owned_assets
    DROP CONSTRAINT IF EXISTS ck_player_owned_assets_revision_positive;

ALTER TABLE player_owned_assets
    ADD CONSTRAINT ck_player_owned_assets_revision_positive
        CHECK (revision > 0);

CREATE TABLE IF NOT EXISTS wallet_balances (
    profile_id      VARCHAR(64) NOT NULL,
    currency_id     VARCHAR(64) NOT NULL,
    balance         BIGINT NOT NULL DEFAULT 0,
    revision        BIGINT NOT NULL DEFAULT 1,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT pk_wallet_balances PRIMARY KEY (profile_id, currency_id),
    CONSTRAINT fk_wallet_balances_profile FOREIGN KEY (profile_id)
        REFERENCES player_profiles(profile_id) ON DELETE CASCADE,
    CONSTRAINT ck_wallet_balances_balance_nonnegative CHECK (balance >= 0),
    CONSTRAINT ck_wallet_balances_revision_positive CHECK (revision > 0),
    CONSTRAINT ck_wallet_balances_currency_nonempty CHECK (char_length(trim(currency_id)) > 0)
);

CREATE TABLE IF NOT EXISTS wallet_ledger_entries (
    ledger_id       VARCHAR(64) PRIMARY KEY,
    profile_id      VARCHAR(64) NOT NULL,
    currency_id     VARCHAR(64) NOT NULL,
    delta           BIGINT NOT NULL,
    balance_after   BIGINT NOT NULL,
    reason          VARCHAR(32) NOT NULL,
    ref_type        VARCHAR(32) NOT NULL,
    ref_id          VARCHAR(128) NOT NULL,
    idempotency_key VARCHAR(128) NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_wallet_ledger_profile FOREIGN KEY (profile_id)
        REFERENCES player_profiles(profile_id) ON DELETE CASCADE,
    CONSTRAINT ck_wallet_ledger_reason CHECK (reason IN ('purchase', 'reward', 'admin', 'compensation', 'bootstrap')),
    CONSTRAINT ck_wallet_ledger_ref_type_nonempty CHECK (char_length(trim(ref_type)) > 0),
    CONSTRAINT ck_wallet_ledger_ref_id_nonempty CHECK (char_length(trim(ref_id)) > 0),
    CONSTRAINT ck_wallet_ledger_balance_after_nonnegative CHECK (balance_after >= 0)
);

CREATE INDEX IF NOT EXISTS idx_wallet_ledger_profile_time
    ON wallet_ledger_entries(profile_id, created_at DESC);

CREATE UNIQUE INDEX IF NOT EXISTS uq_wallet_ledger_idempotency
    ON wallet_ledger_entries(profile_id, idempotency_key)
    WHERE idempotency_key IS NOT NULL;

CREATE TABLE IF NOT EXISTS purchase_orders (
    purchase_id      VARCHAR(64) PRIMARY KEY,
    profile_id       VARCHAR(64) NOT NULL,
    offer_id         VARCHAR(128) NOT NULL,
    catalog_revision BIGINT NOT NULL,
    currency_id      VARCHAR(64) NOT NULL,
    price            BIGINT NOT NULL,
    status           VARCHAR(32) NOT NULL,
    idempotency_key  VARCHAR(128) NOT NULL,
    request_json     JSONB NOT NULL DEFAULT '{}'::jsonb,
    result_json      JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at     TIMESTAMPTZ NULL,

    CONSTRAINT fk_purchase_orders_profile FOREIGN KEY (profile_id)
        REFERENCES player_profiles(profile_id) ON DELETE CASCADE,
    CONSTRAINT ck_purchase_orders_status CHECK (status IN ('pending', 'completed', 'failed', 'cancelled')),
    CONSTRAINT ck_purchase_orders_price_nonnegative CHECK (price >= 0),
    CONSTRAINT ck_purchase_orders_catalog_revision_positive CHECK (catalog_revision > 0),
    CONSTRAINT ck_purchase_orders_offer_nonempty CHECK (char_length(trim(offer_id)) > 0),
    CONSTRAINT ck_purchase_orders_currency_nonempty CHECK (char_length(trim(currency_id)) > 0),
    CONSTRAINT ck_purchase_orders_idempotency_nonempty CHECK (char_length(trim(idempotency_key)) > 0),
    CONSTRAINT uq_purchase_orders_idempotency UNIQUE (profile_id, idempotency_key)
);

CREATE INDEX IF NOT EXISTS idx_purchase_orders_profile_time
    ON purchase_orders(profile_id, created_at DESC);

CREATE TABLE IF NOT EXISTS purchase_grants (
    grant_id    VARCHAR(64) PRIMARY KEY,
    purchase_id VARCHAR(64) NOT NULL,
    profile_id  VARCHAR(64) NOT NULL,
    asset_type  VARCHAR(32) NOT NULL,
    asset_id    VARCHAR(64) NOT NULL,
    quantity    BIGINT NOT NULL DEFAULT 1,
    granted_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_purchase_grants_purchase FOREIGN KEY (purchase_id)
        REFERENCES purchase_orders(purchase_id) ON DELETE CASCADE,
    CONSTRAINT fk_purchase_grants_profile FOREIGN KEY (profile_id)
        REFERENCES player_profiles(profile_id) ON DELETE CASCADE,
    CONSTRAINT ck_purchase_grants_asset_type
        CHECK (asset_type IN ('character', 'character_skin', 'bubble', 'bubble_skin', 'avatar', 'title')),
    CONSTRAINT ck_purchase_grants_asset_id_nonempty CHECK (char_length(trim(asset_id)) > 0),
    CONSTRAINT ck_purchase_grants_quantity_positive CHECK (quantity > 0),
    CONSTRAINT uq_purchase_grants_asset UNIQUE (purchase_id, asset_type, asset_id)
);

COMMIT;
