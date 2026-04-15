package allocator

import (
	"fmt"
	"sync"
)

type PortPool struct {
	mu        sync.Mutex
	available []int
	inUse     map[int]bool
}

func NewPortPool(start, end int) *PortPool {
	pool := &PortPool{
		available: make([]int, 0, end-start),
		inUse:     make(map[int]bool),
	}
	for p := start; p < end; p++ {
		pool.available = append(pool.available, p)
	}
	return pool
}

func (pp *PortPool) Acquire() (int, error) {
	pp.mu.Lock()
	defer pp.mu.Unlock()
	if len(pp.available) == 0 {
		return 0, fmt.Errorf("port pool exhausted")
	}
	port := pp.available[0]
	pp.available = pp.available[1:]
	pp.inUse[port] = true
	return port, nil
}

func (pp *PortPool) Release(port int) {
	pp.mu.Lock()
	defer pp.mu.Unlock()
	if !pp.inUse[port] {
		return
	}
	delete(pp.inUse, port)
	pp.available = append(pp.available, port)
}
