package httpapi

import (
	"errors"
	"net/http"

	"qqtang/services/game_service/internal/battlealloc"
)

func mapBattleAllocError(err error) (int, string) {
	switch {
	case errors.Is(err, battlealloc.ErrBattleNotFound):
		return http.StatusNotFound, "BATTLE_NOT_FOUND"
	case errors.Is(err, battlealloc.ErrBattleAlreadyExists):
		return http.StatusConflict, "BATTLE_ALREADY_EXISTS"
	case errors.Is(err, battlealloc.ErrAllocationFailed):
		return http.StatusBadGateway, "BATTLE_ALLOCATION_FAILED"
	default:
		return http.StatusInternalServerError, "INTERNAL_ERROR"
	}
}
