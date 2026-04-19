package wsapi

import (
	"sync"

	"github.com/gorilla/websocket"
)

type Connection struct {
	id                  string
	socket              *websocket.Conn
	writeMu             sync.Mutex
	sequence            int64
	boundRoomID         string
	boundMemberID       string
	directorySubscribed bool
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

func (c *Connection) BindRoom(roomID, memberID string) {
	c.writeMu.Lock()
	defer c.writeMu.Unlock()
	c.boundRoomID = roomID
	c.boundMemberID = memberID
}

func (c *Connection) ClearRoomBinding() {
	c.writeMu.Lock()
	defer c.writeMu.Unlock()
	c.boundRoomID = ""
	c.boundMemberID = ""
}

func (c *Connection) SetDirectorySubscribed(value bool) {
	c.writeMu.Lock()
	defer c.writeMu.Unlock()
	c.directorySubscribed = value
}

func (c *Connection) BoundRoomID() string {
	c.writeMu.Lock()
	defer c.writeMu.Unlock()
	return c.boundRoomID
}

func (c *Connection) BoundMemberID() string {
	c.writeMu.Lock()
	defer c.writeMu.Unlock()
	return c.boundMemberID
}

func (c *Connection) IsDirectorySubscribed() bool {
	c.writeMu.Lock()
	defer c.writeMu.Unlock()
	return c.directorySubscribed
}
