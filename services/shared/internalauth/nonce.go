package internalauth

import (
	"sync"
	"time"
)

// NonceStore abstracts nonce recording and replay detection.
type NonceStore interface {
	// SeenOrStore returns true if the nonce was already seen within the ttl.
	SeenOrStore(key string, ttl time.Duration) bool
}

// MemoryNonceStore is a bounded in-memory nonce store with periodic cleanup.
type MemoryNonceStore struct {
	mu       sync.RWMutex
	entries  map[string]time.Time
	maxSize  int
	stopCh   chan struct{}
	stopped  bool
}

// NewMemoryNonceStore creates a new store with the given maximum capacity.
// When capacity is reached, new nonces are rejected.
func NewMemoryNonceStore(maxSize int) *MemoryNonceStore {
	s := &MemoryNonceStore{
		entries: make(map[string]time.Time, maxSize),
		maxSize: maxSize,
		stopCh:  make(chan struct{}),
	}
	go s.purgeLoop()
	return s
}

// SeenOrStore implements NonceStore.
func (s *MemoryNonceStore) SeenOrStore(key string, ttl time.Duration) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.stopped {
		return true
	}
	if _, seen := s.entries[key]; seen {
		return true
	}
	if len(s.entries) >= s.maxSize {
		// At capacity, reject to prevent unbounded growth.
		return true
	}
	s.entries[key] = time.Now().Add(ttl)
	return false
}

func (s *MemoryNonceStore) purgeLoop() {
	ticker := time.NewTicker(60 * time.Second)
	defer ticker.Stop()
	for {
		select {
		case <-s.stopCh:
			return
		case <-ticker.C:
			s.purge()
		}
	}
}

func (s *MemoryNonceStore) purge() {
	s.mu.Lock()
	defer s.mu.Unlock()
	now := time.Now()
	for k, exp := range s.entries {
		if now.After(exp) {
			delete(s.entries, k)
		}
	}
}

// Close stops the purge loop and clears entries.
func (s *MemoryNonceStore) Close() {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.stopped {
		return
	}
	s.stopped = true
	close(s.stopCh)
	s.entries = nil
}
