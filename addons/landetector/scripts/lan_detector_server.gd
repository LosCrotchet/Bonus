class_name LANDetector_Server extends LANDetector

var new_peer:PacketPeerUDP = null
var b_peer:PacketPeerUDP = null
var disabled:bool = false

func is_server() -> bool:
	return true

## Turn off the LAN Detector service, and disconnect any peers
func turn_off():
	if disabled: return
	
	_listener_off()
	_kill_new_peer()
	if peer_connected():
		close_peer(LANDetector.ExitReason.Disconnected)

	set_process(false) # extremely vigorous
	disabled = true

## Turn on the LAN Detector service, and start listening for a peer to connect
func turn_on():
	if !disabled: return
	_listener_on()
	set_process(true)
	disabled = false

func _ready() -> void:
	_listener_on()
	on_peer_disconnected.connect(func(_x): if !disabled: _listener_on())

func _process(_delta: float) -> void:
	if !disabled:
		super._process(_delta) # poll the current peer
		if !peer_connected():
			_poll_broadcast_peers()
			_poll_new_peers()
		elif b_peer != null:
			_listener_off()

func _listener_on():
	if b_peer != null: return
	b_peer = PacketPeerUDP.new()
	
	if b_peer.bind(PORT) != OK:
		b_peer = null
		push_error("failed to enable listener on port " + str(PORT))

func _listener_off():
	if b_peer != null:
		b_peer.close()
		b_peer = null
		new_peer = null

func _poll_broadcast_peers():
	if b_peer == null: return

	var count = b_peer.get_available_packet_count()
	for i in range(count):
		var packet = b_peer.get_packet() # simply get the packet
		var ip = b_peer.get_packet_ip()
		var port = b_peer.get_packet_port()
		if packet.decode_u64(0) == static_broadcast_code:
			if debug_mode: print("incoming Connection Request: " + ip + ":" + str(port) )
			b_peer.set_dest_address(ip, port) # return to sender
			
			var addresses:Array
			var my_network_ip = ""
			var my_network_port = -1

			for address in IP.get_local_addresses():
				if !address.contains(":") && address != "127.0.0.1":
					addresses.append(address)

			var b_parts = ip.split(".")
			for address in addresses:
				var a_parts = address.split(".")
				if a_parts[0] != b_parts[0]:
					continue
				if a_parts[1] != b_parts[1]:
					continue
				my_network_ip = address

			if my_network_ip != "":
				if debug_mode: print("connection attempt from " + ip)
				new_peer = PacketPeerUDP.new()
				new_peer.set_dest_address(ip, port) # return to sender
				while my_network_port == -1 || !new_peer.is_bound():
					my_network_port = randi_range(12000, 15000)
					new_peer.bind(my_network_port, my_network_ip)
				b_peer.put_var({ "ip" = my_network_ip , "p" = my_network_port })

func _kill_new_peer():
	if new_peer != null:
		new_peer.close()
		new_peer = null

func _poll_new_peers():
	if b_peer == null: return

	if new_peer != null:
		if new_peer.get_available_packet_count():
			var code = new_peer.get_var()
			var ip = new_peer.get_packet_ip()
			var port = new_peer.get_packet_port()
			if debug_mode: print("peer connected from " + ip + ":" + str(port))
			if static_auth_code != code:
				if debug_mode: print("peer failed authorization")
				new_peer.close()
				new_peer = null
			else:
				if debug_mode: print("peer valid")
				new_peer.set_dest_address(ip,port)
				new_peer.put_var(static_auth_code) # magic code
				replace_peer(new_peer)
				new_peer = null
