package wsapi

import (
	"sync"

	"github.com/gorilla/websocket"
)

type Connection struct {
	id       string
	socket   *websocket.Conn
	writeMu  sync.Mutex
	sequence int64
}

func newConnection(id string, socket *websocket.Conn) *Connection {
	return &Connection{
		id:     id,
		socket: socket,
	}
}

func (c *Connection) ID() string {
	return c.id
}

func (c *Connection) NextSequence() int64 {
	c.sequence++
	return c.sequence
}

func (c *Connection) SendBinary(payload []byte) error {
	c.writeMu.Lock()
	defer c.writeMu.Unlock()
	return c.socket.WriteMessage(websocket.BinaryMessage, payload)
}
