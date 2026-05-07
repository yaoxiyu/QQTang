module qqtang/services/account_service

go 1.24.0

require (
	github.com/jackc/pgx/v5 v5.7.4
	golang.org/x/crypto v0.31.0
	qqtang/services/shared/httpx v0.0.0-00010101000000-000000000000
	qqtang/services/shared/internalauth v0.0.0-00010101000000-000000000000
)

require (
	github.com/jackc/pgpassfile v1.0.0 // indirect
	github.com/jackc/pgservicefile v0.0.0-20240606120523-5a60cdf6a761 // indirect
	github.com/jackc/puddle/v2 v2.2.2 // indirect
	golang.org/x/sync v0.10.0 // indirect
	golang.org/x/text v0.21.0 // indirect
)

replace qqtang/services/shared/httpx => ../shared/httpx

replace qqtang/services/shared/internalauth => ../shared/internalauth
