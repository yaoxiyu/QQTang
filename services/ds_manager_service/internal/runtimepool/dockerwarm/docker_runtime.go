package dockerwarm

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"sync"
	"time"
)

type ContainerRuntime interface {
	CreateWarmContainer(ctx context.Context, spec ContainerSpec) (ContainerInfo, error)
	StartContainer(ctx context.Context, containerID string) error
	StopContainer(ctx context.Context, containerID string, timeout time.Duration) error
	RemoveContainer(ctx context.Context, containerID string) error
	InspectContainer(ctx context.Context, containerID string) (ContainerInfo, error)
	ListPoolContainers(ctx context.Context, poolID string) ([]ContainerInfo, error)
}

type DockerEngineRuntime struct {
	httpClient *http.Client
	baseURL    string
}

func NewDockerEngineRuntime(socket string) (*DockerEngineRuntime, error) {
	if socket == "" {
		socket = "unix:///var/run/docker.sock"
	}
	if !strings.HasPrefix(socket, "unix://") {
		return nil, fmt.Errorf("unsupported docker socket %q", socket)
	}
	socketPath := strings.TrimPrefix(socket, "unix://")
	transport := &http.Transport{
		DialContext: func(ctx context.Context, _, _ string) (net.Conn, error) {
			var dialer net.Dialer
			return dialer.DialContext(ctx, "unix", socketPath)
		},
	}
	return &DockerEngineRuntime{
		httpClient: &http.Client{Transport: transport, Timeout: 10 * time.Second},
		baseURL:    "http://docker",
	}, nil
}

func (r *DockerEngineRuntime) CreateWarmContainer(ctx context.Context, spec ContainerSpec) (ContainerInfo, error) {
	if spec.Name == "" || spec.Image == "" {
		return ContainerInfo{}, fmt.Errorf("container name and image are required")
	}
	labels := cloneLabels(spec.Labels)
	if labels == nil {
		labels = BuildLabels(spec.PoolID, spec.SlotID, spec.DSInstanceID, time.Now().UTC())
	}
	env := make([]string, 0, len(spec.Env))
	for key, value := range spec.Env {
		env = append(env, key+"="+value)
	}
	body := map[string]any{
		"Image":  spec.Image,
		"Labels": labels,
		"Env":    env,
		"ExposedPorts": map[string]map[string]any{
			fmt.Sprintf("%d/tcp", spec.AgentPort):  {},
			fmt.Sprintf("%d/udp", spec.BattlePort): {},
		},
		"HostConfig": map[string]any{
			"NetworkMode": spec.NetworkName,
		},
	}
	if spec.HostBattlePort > 0 {
		body["HostConfig"].(map[string]any)["PortBindings"] = map[string][]map[string]string{
			fmt.Sprintf("%d/udp", spec.BattlePort): {
				{
					"HostIp":   "0.0.0.0",
					"HostPort": strconv.Itoa(spec.HostBattlePort),
				},
			},
		}
	}
	var createResp struct {
		ID string `json:"Id"`
	}
	if err := r.doJSON(ctx, http.MethodPost, "/containers/create?name="+url.QueryEscape(spec.Name), body, &createResp); err != nil {
		return ContainerInfo{}, err
	}
	if createResp.ID == "" {
		return ContainerInfo{}, fmt.Errorf("docker create returned empty container id")
	}
	return r.InspectContainer(ctx, createResp.ID)
}

func (r *DockerEngineRuntime) StartContainer(ctx context.Context, containerID string) error {
	return r.doNoBody(ctx, http.MethodPost, "/containers/"+url.PathEscape(containerID)+"/start")
}

func (r *DockerEngineRuntime) StopContainer(ctx context.Context, containerID string, timeout time.Duration) error {
	seconds := int(timeout.Seconds())
	if seconds <= 0 {
		seconds = 1
	}
	return r.doNoBody(ctx, http.MethodPost, "/containers/"+url.PathEscape(containerID)+"/stop?t="+strconv.Itoa(seconds))
}

func (r *DockerEngineRuntime) RemoveContainer(ctx context.Context, containerID string) error {
	return r.doNoBody(ctx, http.MethodDelete, "/containers/"+url.PathEscape(containerID)+"?force=true")
}

func (r *DockerEngineRuntime) InspectContainer(ctx context.Context, containerID string) (ContainerInfo, error) {
	var inspected dockerInspectResponse
	if err := r.doJSON(ctx, http.MethodGet, "/containers/"+url.PathEscape(containerID)+"/json", nil, &inspected); err != nil {
		return ContainerInfo{}, err
	}
	return containerInfoFromInspect(inspected), nil
}

func (r *DockerEngineRuntime) ListPoolContainers(ctx context.Context, poolID string) ([]ContainerInfo, error) {
	filters, err := json.Marshal(map[string][]string{
		"label": {
			LabelComponent + "=" + LabelComponentBattleDS,
			LabelManagedBy + "=" + LabelManagedByDSM,
			LabelPoolID + "=" + poolID,
		},
	})
	if err != nil {
		return nil, err
	}
	var listed []dockerListContainer
	if err := r.doJSON(ctx, http.MethodGet, "/containers/json?all=true&filters="+url.QueryEscape(string(filters)), nil, &listed); err != nil {
		return nil, err
	}
	result := make([]ContainerInfo, 0, len(listed))
	for _, item := range listed {
		name := ""
		if len(item.Names) > 0 {
			name = strings.TrimPrefix(item.Names[0], "/")
		}
		battlePort := 9000
		publishedPort := 0
		for _, port := range item.Ports {
			if strings.EqualFold(port.Type, "udp") && port.PrivatePort > 0 {
				battlePort = port.PrivatePort
				if port.PublicPort > 0 {
					publishedPort = port.PublicPort
				}
			}
		}
		result = append(result, ContainerInfo{
			ContainerID:   item.ID,
			Name:          name,
			Image:         item.Image,
			AgentEndpoint: agentEndpoint(name, item.Labels, 19090),
			BattleHost:    name,
			BattlePort:    battlePort,
			PublishedPort: publishedPort,
			Labels:        item.Labels,
			State:         item.State,
			CreatedAt:     time.Unix(item.Created, 0).UTC(),
		})
	}
	return result, nil
}

func (r *DockerEngineRuntime) doNoBody(ctx context.Context, method string, path string) error {
	return r.doJSON(ctx, method, path, nil, nil)
}

func (r *DockerEngineRuntime) doJSON(ctx context.Context, method string, path string, payload any, dst any) error {
	var body []byte
	var err error
	if payload != nil {
		body, err = json.Marshal(payload)
		if err != nil {
			return err
		}
	}
	req, err := http.NewRequestWithContext(ctx, method, r.baseURL+path, bytes.NewReader(body))
	if err != nil {
		return err
	}
	if payload != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	resp, err := r.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	respBody, err := io.ReadAll(io.LimitReader(resp.Body, 4<<20))
	if err != nil {
		return err
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("docker api %s %s failed status=%d body=%s", method, path, resp.StatusCode, string(respBody))
	}
	if dst != nil && len(respBody) > 0 {
		if err := json.Unmarshal(respBody, dst); err != nil {
			return fmt.Errorf("docker api response parse failed: %w", err)
		}
	}
	return nil
}

type dockerListContainer struct {
	ID      string            `json:"Id"`
	Names   []string          `json:"Names"`
	Image   string            `json:"Image"`
	State   string            `json:"State"`
	Created int64             `json:"Created"`
	Labels  map[string]string `json:"Labels"`
	Ports   []dockerListPort  `json:"Ports"`
}

type dockerListPort struct {
	PrivatePort int    `json:"PrivatePort"`
	PublicPort  int    `json:"PublicPort"`
	Type        string `json:"Type"`
}

type dockerInspectResponse struct {
	ID              string        `json:"Id"`
	Name            string        `json:"Name"`
	Config          dockerConfig  `json:"Config"`
	State           dockerState   `json:"State"`
	NetworkSettings dockerNetwork `json:"NetworkSettings"`
	Created         string        `json:"Created"`
}

type dockerConfig struct {
	Image  string            `json:"Image"`
	Labels map[string]string `json:"Labels"`
}

type dockerState struct {
	Status string `json:"Status"`
}

type dockerNetwork struct {
	Networks map[string]any             `json:"Networks"`
	Ports    map[string][]dockerPortMap `json:"Ports"`
}

type dockerPortMap struct {
	HostIP   string `json:"HostIp"`
	HostPort string `json:"HostPort"`
}

func containerInfoFromInspect(inspected dockerInspectResponse) ContainerInfo {
	name := strings.TrimPrefix(inspected.Name, "/")
	labels := inspected.Config.Labels
	createdAt, _ := time.Parse(time.RFC3339Nano, inspected.Created)
	battlePort := 9000
	publishedPort := 0
	for portName, bindings := range inspected.NetworkSettings.Ports {
		rawPort := strings.Split(portName, "/")[0]
		parsed, err := strconv.Atoi(rawPort)
		if err == nil && parsed != 19090 {
			battlePort = parsed
		}
		if len(bindings) > 0 {
			if parsedHostPort, err := strconv.Atoi(bindings[0].HostPort); err == nil {
				publishedPort = parsedHostPort
			}
		}
	}
	networkName := ""
	for name := range inspected.NetworkSettings.Networks {
		networkName = name
		break
	}
	return ContainerInfo{
		ContainerID:   inspected.ID,
		Name:          name,
		Image:         inspected.Config.Image,
		NetworkName:   networkName,
		AgentEndpoint: agentEndpoint(name, labels, 19090),
		BattleHost:    name,
		BattlePort:    battlePort,
		PublishedPort: publishedPort,
		Labels:        labels,
		State:         inspected.State.Status,
		CreatedAt:     createdAt,
	}
}

func agentEndpoint(containerName string, labels map[string]string, fallbackPort int) string {
	if containerName == "" && labels != nil {
		containerName = labels[LabelSlotID]
	}
	return fmt.Sprintf("http://%s:%d", containerName, fallbackPort)
}

type FakeContainerRuntime struct {
	mu         sync.Mutex
	nextID     int
	containers map[string]ContainerInfo
}

func NewFakeContainerRuntime() *FakeContainerRuntime {
	return &FakeContainerRuntime{
		nextID:     1,
		containers: map[string]ContainerInfo{},
	}
}

func (r *FakeContainerRuntime) CreateWarmContainer(_ context.Context, spec ContainerSpec) (ContainerInfo, error) {
	r.mu.Lock()
	defer r.mu.Unlock()

	containerID := fmt.Sprintf("fake-container-%d", r.nextID)
	r.nextID++
	createdAt := time.Now().UTC()
	labels := cloneLabels(spec.Labels)
	if labels == nil {
		labels = BuildLabels(spec.PoolID, spec.SlotID, spec.DSInstanceID, createdAt)
	}
	info := ContainerInfo{
		ContainerID:   containerID,
		Name:          spec.Name,
		Image:         spec.Image,
		NetworkName:   spec.NetworkName,
		AgentEndpoint: fmt.Sprintf("http://%s:%d", spec.Name, spec.AgentPort),
		BattleHost:    spec.Name,
		BattlePort:    spec.BattlePort,
		Labels:        labels,
		State:         "created",
		CreatedAt:     createdAt,
	}
	r.containers[containerID] = info
	return info, nil
}

func (r *FakeContainerRuntime) StartContainer(_ context.Context, containerID string) error {
	return r.updateState(containerID, "running")
}

func (r *FakeContainerRuntime) StopContainer(_ context.Context, containerID string, _ time.Duration) error {
	return r.updateState(containerID, "stopped")
}

func (r *FakeContainerRuntime) RemoveContainer(_ context.Context, containerID string) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if _, ok := r.containers[containerID]; !ok {
		return fmt.Errorf("container %s not found", containerID)
	}
	delete(r.containers, containerID)
	return nil
}

func (r *FakeContainerRuntime) InspectContainer(_ context.Context, containerID string) (ContainerInfo, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	info, ok := r.containers[containerID]
	if !ok {
		return ContainerInfo{}, fmt.Errorf("container %s not found", containerID)
	}
	return info, nil
}

func (r *FakeContainerRuntime) ListPoolContainers(_ context.Context, poolID string) ([]ContainerInfo, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	result := make([]ContainerInfo, 0)
	for _, info := range r.containers {
		if info.Labels[LabelPoolID] == poolID {
			result = append(result, info)
		}
	}
	return result, nil
}

func (r *FakeContainerRuntime) updateState(containerID string, state string) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	info, ok := r.containers[containerID]
	if !ok {
		return fmt.Errorf("container %s not found", containerID)
	}
	info.State = state
	r.containers[containerID] = info
	return nil
}

func cloneLabels(labels map[string]string) map[string]string {
	if labels == nil {
		return nil
	}
	result := make(map[string]string, len(labels))
	for key, value := range labels {
		result[key] = value
	}
	return result
}
