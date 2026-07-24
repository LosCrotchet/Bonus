@abstract
class_name LANDetector extends Node

const PORT = 4599 # broadcaster port used
const UDP_PING_INTERVAL = 5500
const UDP_TIMEOUT = 10000

const static_broadcast_code = 0xEEEEEEEE0000000 # 64bit signed magic broadcast code
const static_auth_code = 0xFFFFFFFF0000000 # 64bit signed magic authorization code

signal on_peer_connected()
signal on_peer_disconnected(code:ExitReason)
signal on_peer_message(msg:LANDATA.TYPE, data:Variant)


var debug_mode = OS.is_debug_build()

var peer:PacketPeerUDP = null
var last_ping = 0
var ping_timeout = 0

enum LANMessage {
	Close,
	Open,
	Kick,
	Ping,
	Data,
	Log
}

enum DataMessage {
	ReadyAuth
}

enum ExitReason {
	Unknown,
	Kicked,
	ConnectionLost,
	Disconnected,
	Replaced
}

var peer_buffer:StreamPeerBuffer = null
var reason:ExitReason = ExitReason.Unknown

@abstract func is_server() -> bool

func _process(_delta: float) -> void:

	if peer_connected():
		for i in range(peer.get_available_packet_count()):
			peer_buffer.data_array = peer.get_packet()
			_receive()
			peer_buffer.clear() # flush packet data each cycle
		
		if Time.get_ticks_msec() - ping_timeout > UDP_PING_INTERVAL:
			send_raw(LANMessage.Ping)
			ping_timeout = Time.get_ticks_msec()

		if Time.get_ticks_msec() - last_ping > UDP_TIMEOUT:
			close_peer(ExitReason.ConnectionLost)


var _data_packet = StreamPeerBuffer.new() # send packet cache
## High level function for sending data messages for user interaction
func send(msg:LANDATA.TYPE, data:Variant = null):
	if !peer_connected():
		return
	_data_packet.clear()
	_data_packet.put_u8(LANMessage.Data)
	_data_packet.put_u8( int(msg) )
	_data_packet.put_var(data)
	peer.put_packet(_data_packet.data_array)

var _raw_packet = StreamPeerBuffer.new() # send packet cache
## Lower level function for sending raw data with a basic LANMessage
func send_raw(msg:LANMessage, data:Variant = null):
	if !peer_connected():
		return
	_raw_packet.clear()
	_raw_packet.put_u8(msg)
	if data != null:
		_raw_packet.put_var(data)
	peer.put_packet(_raw_packet.data_array)

func peer_connected():
	return peer != null

func replace_peer(new_peer:PacketPeerUDP):
	if peer_connected():
		close_peer(ExitReason.Replaced)
	peer_buffer = StreamPeerBuffer.new()
	peer = new_peer
	last_ping = Time.get_ticks_msec()
	if peer != null:
		on_peer_connected.emit()

func close_peer(code:ExitReason = ExitReason.Unknown):
	if peer == null:
		return
	if code != ExitReason.Kicked && code != ExitReason.Disconnected:
		send_raw(LANMessage.Close)
	peer.close.call_deferred()
	peer = null
	reason = code
	on_peer_disconnected.emit(reason)

func kick_peer():
	send_raw(LANMessage.Kick)
	close_peer(ExitReason.Kicked)

# On packets received
func _receive():
	while peer_buffer.get_position() < peer_buffer.get_size():
		var msg:LANMessage = peer_buffer.get_u8() as LANMessage
		
		match msg:
			LANMessage.Ping:
				last_ping = Time.get_ticks_msec()
				continue
			LANMessage.Kick:
				if is_server():
					kick_peer() # clients can't kick server - so kick them back instead!
				else:
					close_peer.call_deferred(ExitReason.Kicked)
				continue
			LANMessage.Close:
				close_peer.call_deferred(ExitReason.Disconnected)
				continue
			LANMessage.Log:
				var _log = peer_buffer.get_var()
				print(_log)
				continue
			LANMessage.Data:
				var _data_message:LANDATA.TYPE = (peer_buffer.get_u8() as LANDATA.TYPE)
				var _data:Variant = peer_buffer.get_var()
				on_peer_message.emit(_data_message, _data)
				continue
		push_warning("invalid packet received")
