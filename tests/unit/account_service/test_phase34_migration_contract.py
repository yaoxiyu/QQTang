from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
MIGRATION = ROOT / "services" / "account_service" / "migrations" / "0003_wallet_inventory_shop.sql"


class Phase34MigrationContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.sql = MIGRATION.read_text(encoding="utf-8")

    def test_wallet_tables_and_constraints_are_defined(self) -> None:
        required_fragments = [
            "CREATE TABLE IF NOT EXISTS wallet_balances",
            "CONSTRAINT pk_wallet_balances PRIMARY KEY (profile_id, currency_id)",
            "CONSTRAINT ck_wallet_balances_balance_nonnegative CHECK (balance >= 0)",
            "CREATE TABLE IF NOT EXISTS wallet_ledger_entries",
            "CONSTRAINT ck_wallet_ledger_reason CHECK (reason IN ('purchase', 'reward', 'admin', 'compensation', 'bootstrap'))",
            "CREATE UNIQUE INDEX IF NOT EXISTS uq_wallet_ledger_idempotency",
        ]
        for fragment in required_fragments:
            self.assertIn(fragment, self.sql)

    def test_purchase_tables_are_transaction_ready(self) -> None:
        required_fragments = [
            "CREATE TABLE IF NOT EXISTS purchase_orders",
            "CONSTRAINT uq_purchase_orders_idempotency UNIQUE (profile_id, idempotency_key)",
            "CONSTRAINT ck_purchase_orders_status CHECK (status IN ('pending', 'completed', 'failed', 'cancelled'))",
            "CREATE TABLE IF NOT EXISTS purchase_grants",
            "CONSTRAINT uq_purchase_grants_asset UNIQUE (purchase_id, asset_type, asset_id)",
        ]
        for fragment in required_fragments:
            self.assertIn(fragment, self.sql)

    def test_profile_and_inventory_extensions_are_compatible(self) -> None:
        required_fragments = [
            "ADD COLUMN IF NOT EXISTS avatar_id VARCHAR(64) NULL",
            "ADD COLUMN IF NOT EXISTS title_id VARCHAR(64) NULL",
            "ADD COLUMN IF NOT EXISTS wallet_revision BIGINT NOT NULL DEFAULT 0",
            "ADD COLUMN IF NOT EXISTS quantity BIGINT NOT NULL DEFAULT 1",
            "ADD COLUMN IF NOT EXISTS expire_at TIMESTAMPTZ NULL",
            "ADD COLUMN IF NOT EXISTS source_ref_id VARCHAR(128) NULL",
            "ADD COLUMN IF NOT EXISTS revision BIGINT NOT NULL DEFAULT 1",
            "CHECK (asset_type IN ('character', 'character_skin', 'bubble', 'bubble_skin', 'avatar', 'title'))",
            "CHECK (state IN ('owned', 'disabled', 'expired', 'trial'))",
        ]
        for fragment in required_fragments:
            self.assertIn(fragment, self.sql)


if __name__ == "__main__":
    unittest.main()
