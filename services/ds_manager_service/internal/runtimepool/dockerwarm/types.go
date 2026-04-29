package dockerwarm

import "time"

type ContainerSpec struct {
	PoolID         string
	SlotID         string
	DSInstanceID   string
	Name           string
	Image          string
	NetworkName    string
	Env            map[string]string
	AgentPort      int
	BattlePort     int
	HostBattlePort int
	Labels         map[string]string
}

type ContainerInfo struct {
	ContainerID   string
	Name          string
	Image         string
	NetworkName   string
	AgentEndpoint string
	BattleHost    string
	BattlePort    int
	PublishedHost string
	PublishedPort int
	Labels        map[string]string
	State         string
	CreatedAt     time.Time
}
