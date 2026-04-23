package manifest

import "qqtang/services/shared/contentmanifest"

var (
	ErrManifestNotReady           = contentmanifest.ErrManifestNotReady
	ErrCustomSelectionIllegal     = contentmanifest.ErrCustomSelectionIllegal
	ErrMatchFormatIllegal         = contentmanifest.ErrMatchFormatIllegal
	ErrMatchModeSetIllegal        = contentmanifest.ErrMatchModeSetIllegal
	ErrMapPoolEmpty               = contentmanifest.ErrMapPoolEmpty
	ErrMapTeamPlayerLimitExceeded = contentmanifest.ErrMapTeamPlayerLimitExceeded
)

type Query = contentmanifest.Query

func NewQuery(loader *Loader) *Query {
	return contentmanifest.NewQuery(loader)
}
