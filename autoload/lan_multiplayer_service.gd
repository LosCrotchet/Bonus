extends Node

const LAN_PROTOCOL = preload("res://multiplayer/protocol/lan_protocol.gd")
const LAN_ROOM_STATE = preload("res://multiplayer/lobby/lan_room_state.gd")
const PUBLIC_GAME_SNAPSHOT = preload("res://multiplayer/protocol/public_game_snapshot.gd")
const LAN_TRANSPORT = preload("res://multiplayer/transports/lan_transport.gd")

signal connection_state_changed(state: ConnectionState)
signal lobby_updated(snapshot: Dictionary)
signal network_error(error_key: StringName)
signal game_started(snapshot: Dictionary)
signal game_snapshot_received(snapshot: Dictionary)
signal match_ended(reason_key: StringName)

enum ConnectionState {
	OFFLINE,
	CONNECTING,
	IN_LOBBY,
	IN_GAME,
}

const SERVER_PEER_ID := 1
const AI_THINK_DELAY := 0.7

var connection_state := ConnectionState.OFFLINE
var is_host := false
var local_player_index := -1
var reconnect_token := ""
var last_lobby_snapshot: Dictionary = {}
var last_game_snapshot: Dictionary = {}
var last_error_key: StringName = &""

var _transport = LAN_TRANSPORT.new()
var _room
var _server_session: GameSession
var _server_strategies: Dictionary = {}
var _server_action_pending := false
var _turn_serial := 0
var _turn_deadline_ms := 0
var _revision := 0
var _last_public_action: Dictionary = {}
var _timed_out_seat := -1
var _last_host_address := ""
var _last_port := LAN_PROTOCOL.DEFAULT_PORT
var _local_player_id := ""


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	set_process(true)


func _process(_delta: float) -> void:
	if not is_host or connection_state != ConnectionState.IN_GAME:
		return
	if _server_session == null or _server_session.phase == GameSession.Phase.FINISHED:
		return
	var member: Dictionary = _room.get_member_by_seat(_server_session.current_player_index)
	if member.is_empty():
		return
	if bool(member.get("is_ai", false)) or not bool(member.get("connected", true)):
		_schedule_server_ai(false)
	elif _turn_deadline_ms > 0 and Time.get_ticks_msec() >= _turn_deadline_ms:
		_schedule_server_ai(true)


func host_room(player_id: String, port: int, config: Dictionary) -> bool:
	close_connection()
	var clean_id: String = LAN_PROTOCOL.sanitize_player_id(player_id)
	if not LAN_PROTOCOL.is_valid_player_id(clean_id):
		return _fail(&"LAN_ERROR_PLAYER_ID_REQUIRED")
	if not LAN_PROTOCOL.is_valid_port(port):
		return _fail(&"LAN_ERROR_INVALID_PORT")
	var peer: ENetMultiplayerPeer = _transport.create_server(port)
	if peer == null:
		return _fail(&"LAN_ERROR_CREATE_SERVER")
	multiplayer.multiplayer_peer = peer
	is_host = true
	_local_player_id = clean_id
	_last_port = port
	reconnect_token = _generate_token()
	_room = LAN_ROOM_STATE.new()
	if not _room.create_room(SERVER_PEER_ID, clean_id, config, reconnect_token):
		close_connection()
		return _fail(_room.last_error)
	local_player_index = 0
	_set_connection_state(ConnectionState.IN_LOBBY)
	_broadcast_lobby()
	return true


func join_room(player_id: String, address: String, port: int) -> bool:
	close_connection(false)
	var clean_id: String = LAN_PROTOCOL.sanitize_player_id(player_id)
	if not LAN_PROTOCOL.is_valid_player_id(clean_id):
		return _fail(&"LAN_ERROR_PLAYER_ID_REQUIRED")
	if address.strip_edges().is_empty():
		return _fail(&"LAN_ERROR_ADDRESS_REQUIRED")
	if not LAN_PROTOCOL.is_valid_port(port):
		return _fail(&"LAN_ERROR_INVALID_PORT")
	var peer: ENetMultiplayerPeer = _transport.create_client(address.strip_edges(), port)
	if peer == null:
		return _fail(&"LAN_ERROR_CONNECT_FAILED")
	multiplayer.multiplayer_peer = peer
	is_host = false
	_local_player_id = clean_id
	_last_host_address = address.strip_edges()
	_last_port = port
	_set_connection_state(ConnectionState.CONNECTING)
	return true


func reconnect_last() -> bool:
	if is_host or _last_host_address.is_empty() or reconnect_token.is_empty():
		return false
	return join_room(_local_player_id, _last_host_address, _last_port)


func close_connection(clear_reconnect_token: bool = true) -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer = null
	_transport.close()
	_room = null
	_server_session = null
	_server_strategies.clear()
	_server_action_pending = false
	_turn_deadline_ms = 0
	_revision = 0
	_last_public_action.clear()
	_timed_out_seat = -1
	last_lobby_snapshot.clear()
	last_game_snapshot.clear()
	local_player_index = -1
	is_host = false
	if clear_reconnect_token:
		reconnect_token = ""
	_set_connection_state(ConnectionState.OFFLINE)


func set_ready(ready_value: bool) -> void:
	if connection_state != ConnectionState.IN_LOBBY:
		return
	if is_host:
		if _room.set_ready(SERVER_PEER_ID, ready_value):
			_broadcast_lobby()
	else:
		_server_set_ready.rpc_id(SERVER_PEER_ID, ready_value)


func add_ai(seat_index: int = -1) -> bool:
	if not is_host or _room == null:
		return false
	if not _room.add_ai(seat_index):
		return _fail(_room.last_error)
	_broadcast_lobby()
	return true


func remove_member(seat_index: int) -> bool:
	if not is_host or _room == null:
		return false
	var removed: Dictionary = _room.remove_member_by_seat(seat_index)
	if removed.is_empty():
		return _fail(_room.last_error)
	var peer_id := int(removed.get("peer_id", 0))
	if peer_id > SERVER_PEER_ID and _transport.peer != null:
		_client_kicked.rpc_id(peer_id)
		_transport.peer.disconnect_peer(peer_id)
	_broadcast_lobby()
	return true


func update_room_config(config: Dictionary) -> bool:
	if not is_host or _room == null:
		return false
	if not _room.update_config(config):
		return _fail(_room.last_error)
	_broadcast_lobby()
	return true


func can_start_game() -> bool:
	return is_host and _room != null and _room.can_start()


func start_game() -> bool:
	if not can_start_game():
		return _fail(&"LAN_ERROR_NOT_ALL_READY")
	_room.game_started = true
	_server_session = GameSession.new()
	_server_session.action_resolved.connect(_on_server_public_action)
	_server_session.game_finished.connect(_on_server_game_finished)
	var config: Dictionary = _room.room_config
	var rules: GameRules = LAN_PROTOCOL.rules_from_dictionary(config.get("rules", {}) as Dictionary)
	if not _server_session.start_game(
		_room.get_seat_keys(),
		int(config.get("seed_value", 0)),
		rules,
		str(config.get("seed_text", "")),
	):
		return _fail(_server_session.last_error_key)
	_initialize_server_strategies()
	_revision = 1
	_last_public_action.clear()
	_start_turn_clock()
	_set_connection_state(ConnectionState.IN_GAME)
	_broadcast_lobby()
	_broadcast_game_snapshots(true)
	_schedule_server_ai(false)
	return true


func restart_game() -> bool:
	if not is_host or _room == null or connection_state != ConnectionState.IN_GAME:
		return false
	_room.game_started = false
	for member in _room.members:
		member["ready"] = true
	return start_game()


func request_roll() -> void:
	_send_action_request({"type": LAN_PROTOCOL.ActionType.ROLL})


func request_play(card_ids: Array[int], interpretation_key: String = "") -> void:
	_send_action_request({
		"type": LAN_PROTOCOL.ActionType.PLAY,
		"card_ids": card_ids,
		"interpretation_key": interpretation_key,
	})


func request_pass() -> void:
	_send_action_request({"type": LAN_PROTOCOL.ActionType.PASS})


func get_local_member() -> Dictionary:
	for value in last_lobby_snapshot.get("members", []) as Array:
		if value is Dictionary and int(value.get("seat_index", -1)) == local_player_index:
			return value as Dictionary
	return {}


func get_member_for_seat(seat_index: int) -> Dictionary:
	for value in last_lobby_snapshot.get("members", []) as Array:
		if value is Dictionary and int(value.get("seat_index", -1)) == seat_index:
			return value as Dictionary
	return {}


func get_turn_seconds_remaining() -> int:
	if last_game_snapshot.is_empty():
		return 0
	var deadline := int(last_game_snapshot.get("turn_deadline_ms", 0))
	var server_time := int(last_game_snapshot.get("server_time_ms", 0))
	var received_at := int(last_game_snapshot.get("received_at_ms", Time.get_ticks_msec()))
	var estimated_server_now := server_time + Time.get_ticks_msec() - received_at
	return maxi(0, ceili(float(deadline - estimated_server_now) / 1000.0))


@rpc("any_peer", "call_remote", "reliable")
func _server_join_request(
	player_id: String,
	token: String,
	protocol_version: int,
) -> void:
	if not is_host or _room == null:
		return
	var sender := multiplayer.get_remote_sender_id()
	if protocol_version != LAN_PROTOCOL.PROTOCOL_VERSION:
		_join_rejected.rpc_id(sender, &"LAN_ERROR_PROTOCOL_MISMATCH")
		return
	var result: Dictionary = _room.join_peer(sender, player_id, token)
	if not bool(result.get("ok", false)):
		_join_rejected.rpc_id(sender, StringName(str(result.get("error", ""))))
		return
	_join_accepted.rpc_id(
		sender,
		int(result.get("seat_index", -1)),
		str(result.get("reconnect_token", "")),
		_room.to_public_snapshot(),
	)
	_broadcast_lobby()
	if _room.game_started and _server_session != null:
		_broadcast_game_snapshot_to(sender, int(result.get("seat_index", -1)), true)


@rpc("authority", "call_remote", "reliable")
func _join_accepted(
	seat_index: int,
	token: String,
	lobby_snapshot: Dictionary,
) -> void:
	local_player_index = seat_index
	reconnect_token = token
	_apply_lobby_snapshot(lobby_snapshot)
	_set_connection_state(
		ConnectionState.IN_GAME
		if bool(lobby_snapshot.get("game_started", false))
		else ConnectionState.IN_LOBBY
	)


@rpc("authority", "call_remote", "reliable")
func _join_rejected(error_key: StringName) -> void:
	_fail(error_key)
	close_connection(false)


@rpc("any_peer", "call_remote", "reliable")
func _server_set_ready(ready_value: bool) -> void:
	if not is_host or _room == null or _room.game_started:
		return
	if _room.set_ready(multiplayer.get_remote_sender_id(), ready_value):
		_broadcast_lobby()


@rpc("any_peer", "call_remote", "reliable")
func _server_action_request(action: Dictionary) -> void:
	if not is_host:
		return
	_server_handle_action(multiplayer.get_remote_sender_id(), action)


@rpc("authority", "call_remote", "reliable")
func _receive_lobby_snapshot(snapshot: Dictionary) -> void:
	_apply_lobby_snapshot(snapshot)


@rpc("authority", "call_remote", "reliable")
func _receive_game_snapshot(snapshot: Dictionary, initial: bool) -> void:
	_apply_game_snapshot(snapshot, initial)


@rpc("authority", "call_remote", "reliable")
func _receive_action_error(error_key: StringName) -> void:
	_fail(error_key)


@rpc("authority", "call_remote", "reliable")
func _client_kicked() -> void:
	match_ended.emit(&"LAN_ERROR_KICKED")
	close_connection()


func _send_action_request(action: Dictionary) -> void:
	if connection_state != ConnectionState.IN_GAME:
		return
	if is_host:
		_server_handle_action(SERVER_PEER_ID, action)
	else:
		_server_action_request.rpc_id(SERVER_PEER_ID, action)


func _server_handle_action(peer_id: int, action: Dictionary) -> void:
	if _server_session == null or _room == null or _server_action_pending:
		return
	var member: Dictionary = _room.get_member_by_peer(peer_id)
	if member.is_empty() or not bool(member.get("connected", false)):
		_send_action_error(peer_id, &"LAN_ERROR_MEMBER_NOT_FOUND")
		return
	var seat_index := int(member.get("seat_index", -1))
	if seat_index != _server_session.current_player_index:
		_send_action_error(peer_id, &"ERROR_NOT_PLAYER_TURN")
		return
	var succeeded := false
	match int(action.get("type", -1)):
		LAN_PROTOCOL.ActionType.ROLL:
			succeeded = _server_session.roll_dice(seat_index)
		LAN_PROTOCOL.ActionType.PLAY:
			var card_ids: Array[int] = []
			for value in action.get("card_ids", []) as Array:
				card_ids.append(int(value))
			if card_ids.size() > 6 or str(action.get("interpretation_key", "")).length() > 48:
				_send_action_error(peer_id, &"ERROR_INVALID_HAND")
				return
			succeeded = _server_session.play_cards(
				seat_index,
				card_ids,
				str(action.get("interpretation_key", "")),
			)
		LAN_PROTOCOL.ActionType.PASS:
			succeeded = _server_session.pass_turn(seat_index)
	if not succeeded:
		_send_action_error(peer_id, _server_session.last_error_key)
		return
	_after_server_action()


func _after_server_action() -> void:
	_revision += 1
	_start_turn_clock()
	_broadcast_game_snapshots(false)
	_schedule_server_ai(false)


func _schedule_server_ai(timed_out: bool) -> void:
	if _server_action_pending or _server_session == null:
		return
	if _server_session.phase == GameSession.Phase.FINISHED:
		return
	var member: Dictionary = _room.get_member_by_seat(_server_session.current_player_index)
	if member.is_empty():
		return
	if not timed_out and not (
		bool(member.get("is_ai", false))
		or not bool(member.get("connected", true))
		or _timed_out_seat == _server_session.current_player_index
	):
		return
	if timed_out:
		_timed_out_seat = _server_session.current_player_index
	_server_action_pending = true
	var serial := _turn_serial
	_run_server_ai.call_deferred(serial, _server_session.current_player_index, timed_out)


func _run_server_ai(serial: int, seat_index: int, _timed_out: bool) -> void:
	await get_tree().create_timer(AI_THINK_DELAY).timeout
	if (
		_server_session == null
		or serial != _turn_serial
		or seat_index != _server_session.current_player_index
		or _server_session.phase == GameSession.Phase.FINISHED
	):
		_server_action_pending = false
		return
	var strategy := _server_strategies.get(seat_index) as PlayerStrategy
	if strategy == null:
		strategy = StrategyRegistry.create(&"default")
		strategy.setup(seat_index, _server_session.players.size())
		_server_strategies[seat_index] = strategy
	var decision := strategy.choose_action(_server_session.create_strategy_context(seat_index))
	var succeeded := false
	match decision.action:
		PlayerDecision.Action.ROLL:
			succeeded = _server_session.roll_dice(seat_index)
		PlayerDecision.Action.PLAY:
			succeeded = _server_session.play_cards(
				seat_index,
				decision.card_ids,
				decision.interpretation_key,
			)
		PlayerDecision.Action.PASS:
			succeeded = _server_session.pass_turn(seat_index)
	if not succeeded:
		succeeded = _server_fallback_action(seat_index)
	_server_action_pending = false
	if succeeded:
		_after_server_action()


func _server_fallback_action(seat_index: int) -> bool:
	if _server_session.phase == GameSession.Phase.AWAITING_ROLL:
		return _server_session.roll_dice(seat_index)
	var recommendation: Array[int] = _server_session.get_recommended_play(seat_index)
	if recommendation.is_empty():
		return _server_session.pass_turn(seat_index)
	var interpretations: Array[HandPattern] = _server_session.get_legal_interpretations(
		seat_index,
		recommendation,
	)
	return _server_session.play_cards(
		seat_index,
		recommendation,
		interpretations[0].get_key() if not interpretations.is_empty() else "",
	)


func _initialize_server_strategies() -> void:
	_server_strategies.clear()
	for seat_index in range(_server_session.players.size()):
		var strategy := StrategyRegistry.create(&"default")
		strategy.setup(seat_index, _server_session.players.size())
		_server_strategies[seat_index] = strategy


func _start_turn_clock() -> void:
	_turn_serial += 1
	_server_action_pending = false
	if _server_session == null or _server_session.phase == GameSession.Phase.FINISHED:
		_turn_deadline_ms = 0
		return
	if _timed_out_seat != _server_session.current_player_index:
		_timed_out_seat = -1
	var timeout_seconds := int(_room.room_config.get("turn_timeout", 30))
	_turn_deadline_ms = Time.get_ticks_msec() + timeout_seconds * 1000


func _broadcast_lobby() -> void:
	if _room == null:
		return
	var snapshot: Dictionary = _room.to_public_snapshot()
	_apply_lobby_snapshot(snapshot)
	for member in _room.members:
		var peer_id := int(member.get("peer_id", 0))
		if peer_id > SERVER_PEER_ID and bool(member.get("connected", false)):
			_receive_lobby_snapshot.rpc_id(peer_id, snapshot)


func _broadcast_game_snapshots(initial: bool) -> void:
	if _room == null or _server_session == null:
		return
	var host_seat_index := -1
	for member in _room.members:
		if bool(member.get("is_ai", false)) or not bool(member.get("connected", true)):
			continue
		var peer_id := int(member.get("peer_id", 0))
		var seat_index := int(member.get("seat_index", -1))
		if peer_id == SERVER_PEER_ID:
			host_seat_index = seat_index
		else:
			_broadcast_game_snapshot_to(peer_id, seat_index, initial)
	# Apply the host view last. A local signal handler may immediately submit the
	# next action; remote peers must already have received this revision first.
	if host_seat_index != -1:
		_broadcast_game_snapshot_to(SERVER_PEER_ID, host_seat_index, initial)
	_last_public_action.clear()


func _broadcast_game_snapshot_to(peer_id: int, seat_index: int, initial: bool) -> void:
	var snapshot: Dictionary = PUBLIC_GAME_SNAPSHOT.build(
		_server_session,
		seat_index,
		_room.to_public_snapshot(),
		_revision,
		_turn_deadline_ms,
		_last_public_action,
	)
	if peer_id == SERVER_PEER_ID:
		_apply_game_snapshot(snapshot, initial)
	else:
		_receive_game_snapshot.rpc_id(peer_id, snapshot, initial)


func _apply_lobby_snapshot(snapshot: Dictionary) -> void:
	last_lobby_snapshot = snapshot.duplicate(true)
	lobby_updated.emit(last_lobby_snapshot)


func _apply_game_snapshot(snapshot: Dictionary, initial: bool) -> void:
	var received: Dictionary = snapshot.duplicate(true)
	received["received_at_ms"] = Time.get_ticks_msec()
	last_game_snapshot = received
	local_player_index = int(received.get("local_player_index", local_player_index))
	_set_connection_state(ConnectionState.IN_GAME)
	if initial:
		game_started.emit(last_game_snapshot)
	else:
		game_snapshot_received.emit(last_game_snapshot)


func _on_connected_to_server() -> void:
	_server_join_request.rpc_id(
		SERVER_PEER_ID,
		_local_player_id,
		reconnect_token,
		LAN_PROTOCOL.PROTOCOL_VERSION,
	)


func _on_connection_failed() -> void:
	_fail(&"LAN_ERROR_CONNECT_FAILED")
	close_connection(false)


func _on_server_disconnected() -> void:
	var was_in_game := connection_state == ConnectionState.IN_GAME
	close_connection(false)
	if was_in_game:
		match_ended.emit(&"LAN_ERROR_HOST_DISCONNECTED")
	else:
		_fail(&"LAN_ERROR_HOST_DISCONNECTED")


func _on_peer_connected(_peer_id: int) -> void:
	pass


func _on_peer_disconnected(peer_id: int) -> void:
	if not is_host or _room == null:
		return
	var member: Dictionary = _room.mark_disconnected(peer_id)
	if member.is_empty():
		return
	if not _room.game_started:
		_room.remove_member_by_seat(int(member.get("seat_index", -1)))
	_broadcast_lobby()
	if _room.game_started:
		_revision += 1
		_broadcast_game_snapshots(false)
		_schedule_server_ai(false)


func _on_server_public_action(action: Dictionary) -> void:
	_last_public_action = action.duplicate(true)


func _on_server_game_finished(_winner_index: int) -> void:
	_turn_deadline_ms = 0


func _send_action_error(peer_id: int, error_key: StringName) -> void:
	if peer_id == SERVER_PEER_ID:
		_fail(error_key)
	else:
		_receive_action_error.rpc_id(peer_id, error_key)


func _set_connection_state(value: ConnectionState) -> void:
	if connection_state == value:
		return
	connection_state = value
	connection_state_changed.emit(connection_state)


func _generate_token() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()


func _fail(error_key: StringName) -> bool:
	last_error_key = error_key
	network_error.emit(error_key)
	return false
