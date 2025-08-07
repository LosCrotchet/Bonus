extends Node

signal player_connected(peer_id, player_info)
signal player_disconnected(peer_id)
signal server_disconnected

var port = 8087
var ip_address = "127.0.0.1"
var max_connections = 1

var players = {}

var player_info = {"order": 1, "name": "", "is_ready": false}
var players_loaded = 0
var players_registered = 0

func _ready():
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connected_fail)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _process(delta):
	if multiplayer.multiplayer_peer != null:
		var peers = multiplayer.get_peers()
		var id = multiplayer.get_unique_id()
	pass

func join_game():
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip_address, port)
	if error:
		return error
	multiplayer.multiplayer_peer = peer
	if player_info["name"] == "":
		player_info["name"] = str(multiplayer.get_unique_id())
	return OK

func create_game():
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, max_connections)
	if error:
		return error
	multiplayer.multiplayer_peer = peer
	
	if player_info["name"] == "":
		player_info["name"] = "1"
	players[1] = player_info
	player_connected.emit(1, player_info)

func _on_player_connected(id):
	_register_player.rpc_id(id, player_info)
	if multiplayer.is_server():
		if max_connections != 1:
			update_max_connections.rpc_id(id, max_connections)
		
		for index in range(2, 5):
			var is_used = false
			for k in players.keys():
				if players[k]["order"] == index:
					is_used = true
			if not is_used:
				update_player_order.rpc_id(id, index)
				break

func remove_multiplayer_peer():
	multiplayer.multiplayer_peer = null
	players.clear()
	player_info = {"order": 1, "name": "", "is_ready": false}
	max_connections = 0

# Test
@rpc("call_local", "reliable")
func load_game(game_scene_path):
	get_tree().change_scene_to_file(game_scene_path)

# Every peer will call this when they have loaded the game scene.
@rpc("any_peer", "call_local", "reliable")
func player_loaded():
	if multiplayer.is_server():
		players_loaded += 1
		if players_loaded == players.size():
			$/root/Game.start_game()
			players_loaded = 0

@rpc("any_peer", "call_local", "reliable")
func player_registered():
	if multiplayer.is_server():
		players_registered += 1

@rpc("any_peer", "reliable")
func _register_player(new_player_info):
	var new_player_id = multiplayer.get_remote_sender_id()
	players[new_player_id] = new_player_info
	player_connected.emit(new_player_id, new_player_info)

@rpc("any_peer", "reliable")
func update_player(new_player_info):
	var new_player_id = multiplayer.get_remote_sender_id()
	players[new_player_id] = new_player_info

@rpc("any_peer", "reliable")
func update_max_connections(max_conn):
	if multiplayer.get_remote_sender_id() == 1:
		max_connections = max_conn
		DeckManager.player_count = max_connections

@rpc("any_peer", "reliable")
func update_player_order(order):
	if multiplayer.get_remote_sender_id() == 1:
		player_info["order"] = order
		update_player.rpc(player_info)

@rpc("any_peer", "reliable")
func update_deck(deck:Array):
	if multiplayer.get_remote_sender_id() == 1:
		DeckManager.deck = deck

@rpc("any_peer", "reliable")
func draw_card_to(order:int, card):
	if multiplayer.get_remote_sender_id() == 1:
		DeckManager.deliver_card_to.emit(order, card)

@rpc("any_peer", "reliable")
func update_game_signal(now_whos_turn:int, now_whos_dice:int, dice_result:int, played_cards:Array, last_player:int, is_bonus:bool):
	if multiplayer.get_remote_sender_id() == 1:
		DeckManager.receive_game_signal.emit(now_whos_turn, now_whos_dice, dice_result, played_cards, last_player, is_bonus)

@rpc("any_peer", "reliable")
func player_finished(action):
	if multiplayer.get_remote_sender_id() == 1:
		DeckManager.player_finished.emit(action)

@rpc("any_peer", "reliable")
func dice_start_roll():
	if multiplayer.get_remote_sender_id() == 1:
		DeckManager.dice_roll.emit()

@rpc("any_peer", "reliable")
func send_dice_result(result):
	if multiplayer.get_remote_sender_id() == 1:
		DeckManager.dice_result.emit(result)

func _on_player_disconnected(id):
	#player_info = {"order": 1, "name": "", "is_ready": false}
	var exit_id = players[id]["order"]
	for index in range(exit_id+1, 5):
		for k in players.keys():
			if players[k]["order"] == index:
				update_player_order.rpc_id(k, index-1)
				continue
	players.erase(id)
	player_disconnected.emit(id)

func _on_connected_ok():
	var p = multiplayer
	var peers = multiplayer.get_peers()
	var peer_id = multiplayer.get_unique_id()
	if player_info["name"] == "":
		player_info["name"] = str(peer_id)
	players[peer_id] = player_info
	player_connected.emit(peer_id, player_info)

func _on_connected_fail():
	multiplayer.multiplayer_peer = null

func _on_server_disconnected():
	multiplayer.multiplayer_peer = null
	player_info = {"order": 1, "name": "", "is_ready": false}
	players.clear()
	server_disconnected.emit()

func get_ready(flag):
	player_info["is_ready"] = flag
	update_player.rpc(player_info)
