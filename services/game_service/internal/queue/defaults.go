package queue

const (
	DefaultSeasonID               = "season_s1"
	DefaultMapID                  = "map_classic_square"
	DefaultDSHost                 = "127.0.0.1"
	DefaultDSPort                 = 9000
	DefaultQueueHeartbeatSeconds  = 30
	DefaultCaptainDeadlineSeconds = 15
	DefaultCommitDeadlineSeconds  = 45
)

type AssignmentDefaults struct {
	SeasonID               string
	MapID                  string
	DSHost                 string
	DSPort                 int
	CaptainDeadlineSeconds int
	CommitDeadlineSeconds  int
}

func DefaultAssignmentDefaults() AssignmentDefaults {
	return AssignmentDefaults{
		SeasonID:               DefaultSeasonID,
		MapID:                  DefaultMapID,
		DSHost:                 DefaultDSHost,
		DSPort:                 DefaultDSPort,
		CaptainDeadlineSeconds: DefaultCaptainDeadlineSeconds,
		CommitDeadlineSeconds:  DefaultCommitDeadlineSeconds,
	}
}

func NormalizeAssignmentDefaults(defaults AssignmentDefaults) AssignmentDefaults {
	normalized := DefaultAssignmentDefaults()
	if defaults.SeasonID != "" {
		normalized.SeasonID = defaults.SeasonID
	}
	if defaults.MapID != "" {
		normalized.MapID = defaults.MapID
	}
	if defaults.DSHost != "" {
		normalized.DSHost = defaults.DSHost
	}
	if defaults.DSPort > 0 {
		normalized.DSPort = defaults.DSPort
	}
	if defaults.CaptainDeadlineSeconds > 0 {
		normalized.CaptainDeadlineSeconds = defaults.CaptainDeadlineSeconds
	}
	if defaults.CommitDeadlineSeconds > 0 {
		normalized.CommitDeadlineSeconds = defaults.CommitDeadlineSeconds
	}
	return normalized
}
