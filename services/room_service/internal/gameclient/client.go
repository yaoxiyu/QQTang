package gameclient

type Client struct {
	addr string
}

func New(addr string) *Client {
	return &Client{addr: addr}
}

func (c *Client) Addr() string {
	if c == nil {
		return ""
	}
	return c.addr
}
