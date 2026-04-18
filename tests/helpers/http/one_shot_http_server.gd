class_name OneShotHttpServer
extends RefCounted

var _thread := Thread.new()
var _port: int = 0
var _ready: bool = false
var _response_text: String = ""


func start(port: int, response_text: String) -> void:
	_port = port
	_response_text = response_text
	_ready = false
	_thread.start(_run)
	var deadline := Time.get_ticks_msec() + 1500
	while not _ready and Time.get_ticks_msec() < deadline:
		OS.delay_msec(10)


func wait_done() -> void:
	if _thread.is_started():
		_thread.wait_to_finish()


func _run() -> void:
	var server := TCPServer.new()
	var listen_err := server.listen(_port, "127.0.0.1")
	if listen_err != OK:
		_ready = true
		return
	_ready = true
	var deadline := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < deadline:
		if not server.is_connection_available():
			OS.delay_msec(5)
			continue
		var peer: StreamPeerTCP = server.take_connection()
		if peer == null:
			break
		var read_deadline := Time.get_ticks_msec() + 500
		while Time.get_ticks_msec() < read_deadline:
			peer.poll()
			if peer.get_available_bytes() > 0:
				peer.get_data(peer.get_available_bytes())
				break
			OS.delay_msec(5)
		peer.put_data(_response_text.to_utf8_buffer())
		peer.disconnect_from_host()
		break
	server.stop()
