package registry

import "sync"

type Registry struct {
	instanceID string
	shardID    string
	mu         sync.RWMutex
	closed     bool
}

func New(instanceID, shardID string) *Registry {
	return &Registry{instanceID: instanceID, shardID: shardID}
}

func (r *Registry) Ready() bool {
	r.mu.RLock()
	defer r.mu.RUnlock()
	return !r.closed
}

func (r *Registry) Close() {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.closed = true
}

func (r *Registry) InstanceID() string {
	return r.instanceID
}

func (r *Registry) ShardID() string {
	return r.shardID
}
