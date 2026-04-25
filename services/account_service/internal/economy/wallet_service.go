package economy

import (
	"context"
	"errors"

	"qqtang/services/account_service/internal/storage"
)

var ErrWalletProfileNotFound = errors.New("WALLET_PROFILE_NOT_FOUND")

type ProfileLookup interface {
	FindByAccountID(ctx context.Context, accountID string) (storage.Profile, error)
}

type WalletReader interface {
	ListBalances(ctx context.Context, profileID string) ([]storage.WalletBalance, error)
}

type WalletService struct {
	profileRepo ProfileLookup
	walletRepo  WalletReader
}

type WalletBalanceResponse struct {
	CurrencyID string `json:"currency_id"`
	Balance    int64  `json:"balance"`
	Revision   int64  `json:"revision"`
}

type WalletResponse struct {
	ProfileID      string                  `json:"profile_id"`
	WalletRevision int64                   `json:"wallet_revision"`
	Balances       []WalletBalanceResponse `json:"balances"`
}

func NewWalletService(profileRepo ProfileLookup, walletRepo WalletReader) *WalletService {
	return &WalletService{
		profileRepo: profileRepo,
		walletRepo:  walletRepo,
	}
}

func (s *WalletService) GetMyWallet(ctx context.Context, accountID string) (WalletResponse, error) {
	profileRecord, err := s.profileRepo.FindByAccountID(ctx, accountID)
	if err != nil {
		if errors.Is(err, storage.ErrNotFound) {
			return WalletResponse{}, ErrWalletProfileNotFound
		}
		return WalletResponse{}, err
	}
	balances, err := s.walletRepo.ListBalances(ctx, profileRecord.ProfileID)
	if err != nil {
		return WalletResponse{}, err
	}
	return ToWalletResponse(profileRecord, balances), nil
}

func ToWalletResponse(profileRecord storage.Profile, balances []storage.WalletBalance) WalletResponse {
	response := WalletResponse{
		ProfileID:      profileRecord.ProfileID,
		WalletRevision: profileRecord.WalletRevision,
		Balances:       make([]WalletBalanceResponse, 0, len(balances)),
	}
	for _, balance := range balances {
		response.Balances = append(response.Balances, WalletBalanceResponse{
			CurrencyID: balance.CurrencyID,
			Balance:    balance.Balance,
			Revision:   balance.Revision,
		})
	}
	return response
}
