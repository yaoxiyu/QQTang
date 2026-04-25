package economy

import (
	"context"
	"errors"
	"testing"

	"qqtang/services/account_service/internal/storage"
)

type fakeProfileLookup struct {
	profile storage.Profile
	err     error
}

func (f fakeProfileLookup) FindByAccountID(context.Context, string) (storage.Profile, error) {
	return f.profile, f.err
}

type fakeWalletReader struct {
	balances []storage.WalletBalance
	err      error
}

func (f fakeWalletReader) ListBalances(context.Context, string) ([]storage.WalletBalance, error) {
	return f.balances, f.err
}

func TestWalletServiceGetMyWalletReturnsRevisionAndBalances(t *testing.T) {
	service := NewWalletService(
		fakeProfileLookup{profile: storage.Profile{ProfileID: "profile_1", WalletRevision: 3}},
		fakeWalletReader{balances: []storage.WalletBalance{
			{ProfileID: "profile_1", CurrencyID: "premium_gem", Balance: 12, Revision: 2},
			{ProfileID: "profile_1", CurrencyID: "soft_gold", Balance: 3000, Revision: 4},
		}},
	)

	result, err := service.GetMyWallet(context.Background(), "account_1")
	if err != nil {
		t.Fatalf("GetMyWallet returned error: %v", err)
	}
	if result.ProfileID != "profile_1" || result.WalletRevision != 3 {
		t.Fatalf("unexpected wallet identity: %+v", result)
	}
	if len(result.Balances) != 2 {
		t.Fatalf("expected 2 balances, got %+v", result.Balances)
	}
	if result.Balances[1].CurrencyID != "soft_gold" || result.Balances[1].Balance != 3000 || result.Balances[1].Revision != 4 {
		t.Fatalf("unexpected soft_gold balance: %+v", result.Balances[1])
	}
}

func TestWalletServiceMapsMissingProfile(t *testing.T) {
	service := NewWalletService(
		fakeProfileLookup{err: storage.ErrNotFound},
		fakeWalletReader{},
	)

	_, err := service.GetMyWallet(context.Background(), "missing")
	if !errors.Is(err, ErrWalletProfileNotFound) {
		t.Fatalf("expected ErrWalletProfileNotFound, got %v", err)
	}
}
