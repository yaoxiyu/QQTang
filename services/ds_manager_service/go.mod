module qqtang/services/ds_manager_service

go 1.24.0

replace qqtang/services/shared/httpx => ../shared/httpx

replace qqtang/services/shared/internalauth => ../shared/internalauth

require (
	qqtang/services/shared/httpx v0.0.0-00010101000000-000000000000
	qqtang/services/shared/internalauth v0.0.0-00010101000000-000000000000
)
