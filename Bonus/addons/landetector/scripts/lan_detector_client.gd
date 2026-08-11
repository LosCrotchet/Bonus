class_name LANDetector_Client extends LANDetector

const HANDSHAKE_TIMEOUT = 2500 # Wait this number of milliseconds before giving up on handshake
const BROADCAST_INTERVAL = 500 # Interval in milliseconds at which the server search frame will be executed

var disabled:bool = false
var search_timeout = 0
var handshake_timeout = 0

enum BStage {
	Searching,
	Authorizing,
	Handshake,
	Complete
}

var b_peer:PacketPeerUDP = null

func is_server() -> bool:
	return false

## Turn Off The Client and Disconnect
func turn_off():
	if disabled: return
	
	_broadcaster_off()
	_kill_new_peer()
	if peer_connected():
		close_peer(LANDetector.ExitReason.Disconnected)
	disabled = true
	set_process(false) # extremely vigorous

## Turn On the LAN Detector, and automatically connect
func turn_on():
	if !disabled: return
	
	_broadcaster_on()
	disabled = false
	set_process(true)

func _init() -> void:
	_broadcaster_on()

func _process(_delta: float) -> void:
	if !disabled:
		super._process(_delta) # poll the current peer
		poll_remote_broadcast()

func broadcaster_running():
	return b_peer != null && b_peer.is_bound()

func _broadcaster_on():
	if b_peer != null:
		if !b_peer.is_bound():
			b_peer.close()
			b_peer = null
		else:
			return

	b_peer = PacketPeerUDP.new()
	while !b_peer.is_bound():
		b_peer.bind(randi_range(20000, 60000))

	b_peer.set_broadcast_enabled(true)
	b_peer.set_dest_address("255.255.255.255", PORT)

func _broadcaster_off():
	if b_peer == null: return
	b_peer.close()
	b_peer = null

func _kill_new_peer():
	if new_peer != null:
		stage = BStage.Complete
		new_peer.close()
		new_peer = null

var stage:BStage = BStage.Searching
var new_peer:PacketPeerUDP = null
func find_server() -> bool:
	match stage:
		BStage.Searching:
			if new_peer != null:
				new_peer.close()
				new_peer = null
			var data = PackedByteArray()
			data.resize(8)
			data.encode_u64(0, static_broadcast_code)
			b_peer.put_packet(data)
			stage = BStage.Authorizing
			handshake_timeout = Time.get_ticks_msec()
			return true # continue immediately
		BStage.Authorizing:
			var count = b_peer.get_available_packet_count()
			if !count:
				if Time.get_ticks_msec() - handshake_timeout > HANDSHAKE_TIMEOUT:
					stage = BStage.Searching
				return true # continue immediately

			var dest = b_peer.get_var()
			if dest == null || !(dest is Dictionary):
				stage = BStage.Searching
				if debug_mode: print("Error " + str(b_peer.get_packet_error()) + ": Invalid response")
				return false
			var address = dest.get("ip")
			var port = dest.get("p")
			if debug_mode: print("connecting to " + address + ":" + str(port))
			new_peer = PacketPeerUDP.new()
			new_peer.set_dest_address(address, port)
			while new_peer.bind(randi_range(20000, 60000)) != OK:
				pass
			new_peer.put_var( static_auth_code )
			stage = BStage.Handshake
			handshake_timeout = Time.get_ticks_msec()
			return true # continue immediately
		BStage.Handshake:
			var count = new_peer.get_available_packet_count()
			if !count:
				if Time.get_ticks_msec() - handshake_timeout > HANDSHAKE_TIMEOUT:
					stage = BStage.Searching
				return true # continue immediately
			var auth = new_peer.get_var()
			if auth != static_auth_code:
				stage = BStage.Searching
				return false
			replace_peer(new_peer)
			if debug_mode: print("connected successfully")
			stage = BStage.Complete
		BStage.Complete:
			if !peer_connected():
				stage = BStage.Searching
				return true # continue immediately
			else:
				_broadcaster_off()
			return false
	return false

func poll_remote_broadcast():
	if b_peer != null:
		if Time.get_ticks_msec() - search_timeout > BROADCAST_INTERVAL:
			if(!find_server()): # Search for a server
				search_timeout = Time.get_ticks_msec() # reset the timeout only if not continuing immediately
	elif !peer_connected():
		_broadcaster_on()
