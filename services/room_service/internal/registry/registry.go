package registry

import (
	"sort"
	"sync"
)

type DirectoryEntry struct {
	RoomID          string
	RoomDisplayName string
	RoomKind        string
	ModeID          string
	MapID           string
	MemberCount     int32
	MaxPlayerCount  int32
	Joinable        bool
}

type DirectorySnapshot struct {
	Revision int64
	Entries  []DirectoryEntry
}

type Registry struct {
	instanceID           string
	shardID              string
	mu                   sync.RWMutex
	closed               bool
	directoryRevision    int64
	directoryEntries     map[string]DirectoryEntry
	directorySubscribers map[string]struct{}
}

func New(instanceID, shardID string) *Registry {
	return &Registry{
		instanceID:           instanceID,
		shardID:              shardID,
		directoryEntries:     map[string]DirectoryEntry{},
		directorySubscribers: map[string]struct{}{},
	}
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

func (r *Registry) UpsertRoomEntry(entry DirectoryEntry) {
	if entry.RoomID == "" {
		return
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	r.directoryEntries[entry.RoomID] = entry
	r.directoryRevision++
}

func (r *Registry) RemoveRoomEntry(roomID string) {
	if roomID == "" {
		return
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	if _, ok := r.directoryEntries[roomID]; !ok {
		return
	}
	delete(r.directoryEntries, roomID)
	r.directoryRevision++
}

func (r *Registry) DirectorySnapshot() DirectorySnapshot {
	r.mu.RLock()
	defer r.mu.RUnlock()

	entries := make([]DirectoryEntry, 0, len(r.directoryEntries))
	for _, entry := range r.directoryEntries {
		entries = append(entries, entry)
	}
	sort.Slice(entries, func(i, j int) bool {
		return entries[i].RoomID < entries[j].RoomID
	})
	return DirectorySnapshot{
		Revision: r.directoryRevision,
		Entries:  entries,
	}
}

func (r *Registry) SetDirectorySubscribed(connectionID string, subscribed bool) {
	if connectionID == "" {
		return
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	if subscribed {
		r.directorySubscribers[connectionID] = struct{}{}
		return
	}
	delete(r.directorySubscribers, connectionID)
}

func (r *Registry) DirectorySubscriberIDs() []string {
	r.mu.RLock()
	defer r.mu.RUnlock()

	result := make([]string, 0, len(r.directorySubscribers))
	for id := range r.directorySubscribers {
		result = append(result, id)
	}
	sort.Strings(result)
	return result
}
