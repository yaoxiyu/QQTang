class_name WalletBalanceState
extends RefCounted

const SELF_SCRIPT = preload("res://app/front/economy/wallet_balance_state.gd")

var currency_id: String = ""
var balance: int = 0
var revision: int = 0


static func from_dict(data: Dictionary):
	var state = SELF_SCRIPT.new()
	state.currency_id = String(data.get("currency_id", ""))
	state.balance = int(data.get("balance", 0))
	state.revision = int(data.get("revision", 0))
	return state


func to_dict() -> Dictionary:
	return {
		"currency_id": currency_id,
		"balance": balance,
		"revision": revision,
	}
