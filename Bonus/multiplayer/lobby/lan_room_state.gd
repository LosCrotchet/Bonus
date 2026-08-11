class_name LanRoomState
extends RefCounted

const LAN_PROTOCOL = preload("res://multiplayer/protocol/lan_protocol.gd")

const HOST_PEER_ID := 1

var room_config: Dictionary = {}
var members: Array[Dictionary] = []
var host_peer_id := HOST_PEER_ID
var room_id := ""
var room_open := false
var game_started := false
var last_error: StringName = &""

var _random := RandomNumberGenerator.new()
var _next_ai_number := 1


func _init() -> void:
	_random.randomize()


func create_room(
	peer_id: int,
	player_id: String,
	config: Dictionary,
	reconnect_token: String,
	client_instance_id: String = "host",
) -> bool:
	var clean_id: String = LAN_PROTOCOL.sanitize_player_id(player_id)
	if not LAN_PROTOCOL.is_valid_player_id(clean_id):
		return _fail(&"LAN_ERROR_PLAYER_ID_REQUIRED")
	room_config = LAN_PROTOCOL.normalize_room_config(config)
	room_id = _generate_room_id()
	host_peer_id = peer_id
	members.clear()
	_next_ai_number = 1
	game_started = false
	room_open = true
	members.append(_make_human_member(
		peer_id,
		clean_id,
		0,
		reconnect_token,
		true,
		client_instance_id,
	))
	last_error = &""
	return true


func join_peer(
	peer_id: int,
	player_id: String,
	reconnect_token: String,
	requested_room_id: String = "",
	client_instance_id: String = "",
) -> Dictionary:
	if not room_open:
		return _result_error(&"LAN_ERROR_ROOM_NOT_JOINABLE")
	var clean_id: String = LAN_PROTOCOL.sanitize_player_id(player_id)
	if not LAN_PROTOCOL.is_valid_player_id(clean_id):
		return _result_error(&"LAN_ERROR_PLAYER_ID_REQUIRED")

	if not reconnect_token.is_empty() and requested_room_id == room_id:
		for member in members:
			if (
				not bool(member.get("is_ai", false))
				and str(member.get("reconnect_token", "")) == reconnect_token
				and str(member.get("player_id", "")) == clean_id
				and str(member.get("client_instance_id", "")) == client_instance_id
			):
				var previous_peer_id := int(member.get("peer_id", 0))
				member["peer_id"] = peer_id
				member["connected"] = true
				member["ai_takeover"] = false
				last_error = &""
				return _result_ok(member, true, previous_peer_id)
	if game_started:
		return _result_error(&"LAN_ERROR_ROOM_NOT_JOINABLE")

	for member in members:
		if str(member.get("player_id", "")) == clean_id:
			return _result_error(&"LAN_ERROR_DUPLICATE_PLAYER_ID")

	var free_seats := get_free_seat_indices()
	if free_seats.is_empty():
		return _result_error(&"LAN_ERROR_ROOM_FULL")
	var seat_index: int = free_seats[_random.randi_range(0, free_seats.size() - 1)]
	var token := _generate_reconnect_token()
	var new_member := _make_human_member(
		peer_id,
		clean_id,
		seat_index,
		token,
		false,
		client_instance_id,
	)
	members.append(new_member)
	_sort_members()
	last_error = &""
	return _result_ok(new_member, false)


func set_ready(peer_id: int, ready: bool) -> bool:
	var member := get_member_by_peer(peer_id)
	if member.is_empty() or bool(member.get("is_ai", false)):
		return _fail(&"LAN_ERROR_MEMBER_NOT_FOUND")
	member["ready"] = ready
	last_error = &""
	return true


func add_ai(seat_index: int = -1) -> bool:
	if game_started:
		return _fail(&"LAN_ERROR_GAME_ALREADY_STARTED")
	var free_seats := get_free_seat_indices()
	if free_seats.is_empty():
		return _fail(&"LAN_ERROR_ROOM_FULL")
	if seat_index == -1:
		seat_index = free_seats[0]
	if seat_index not in free_seats:
		return _fail(&"LAN_ERROR_SEAT_UNAVAILABLE")
	var member := {
		"peer_id": 0,
		"player_id": "AI %d" % _next_ai_number,
		"seat_index": seat_index,
		"seat_key": get_seat_keys()[seat_index],
		"reconnect_token": "",
		"ready": true,
		"is_ai": true,
		"connected": true,
		"ai_takeover": false,
		"is_host": false,
		"client_instance_id": "",
	}
	_next_ai_number += 1
	members.append(member)
	_sort_members()
	last_error = &""
	return true


func remove_member_by_seat(seat_index: int) -> Dictionary:
	for index in range(members.size()):
		var member := members[index]
		if int(member.get("seat_index", -1)) != seat_index:
			continue
		if bool(member.get("is_host", false)):
			_fail(&"LAN_ERROR_CANNOT_REMOVE_HOST")
			return {}
		members.remove_at(index)
		last_error = &""
		return member
	_fail(&"LAN_ERROR_MEMBER_NOT_FOUND")
	return {}


func mark_disconnected(peer_id: int) -> Dictionary:
	var member := get_member_by_peer(peer_id)
	if member.is_empty():
		return {}
	member["connected"] = false
	member["ai_takeover"] = game_started
	member["ready"] = false if not game_started else member.get("ready", true)
	return member


func update_config(config: Dictionary) -> bool:
	if game_started:
		return _fail(&"LAN_ERROR_GAME_ALREADY_STARTED")
	var normalized: Dictionary = LAN_PROTOCOL.normalize_room_config(config)
	var new_count := int(normalized["player_count"])
	for member in members:
		if int(member.get("seat_index", -1)) >= new_count:
			return _fail(&"LAN_ERROR_SEATS_OCCUPIED")
	room_config = normalized
	var seat_keys := get_seat_keys()
	for member in members:
		member["seat_key"] = seat_keys[int(member.get("seat_index", 0))]
		if not bool(member.get("is_ai", false)):
			member["ready"] = false
	last_error = &""
	return true


func can_start() -> bool:
	if not room_open or game_started:
		return false
	if members.size() != int(room_config.get("player_count", 0)):
		return false
	for member in members:
		if not bool(member.get("ready", false)):
			return false
		if not bool(member.get("is_ai", false)) and not bool(member.get("connected", false)):
			return false
	return true


func get_free_seat_indices() -> Array[int]:
	var occupied := {}
	for member in members:
		occupied[int(member.get("seat_index", -1))] = true
	var result: Array[int] = []
	for seat_index in range(int(room_config.get("player_count", 3))):
		if not occupied.has(seat_index):
			result.append(seat_index)
	return result


func get_member_by_peer(peer_id: int) -> Dictionary:
	for member in members:
		if int(member.get("peer_id", 0)) == peer_id:
			return member
	return {}


func get_member_by_seat(seat_index: int) -> Dictionary:
	for member in members:
		if int(member.get("seat_index", -1)) == seat_index:
			return member
	return {}


func to_public_snapshot() -> Dictionary:
	var public_members: Array[Dictionary] = []
	for member in members:
		public_members.append({
			"peer_id": int(member.get("peer_id", 0)),
			"player_id": str(member.get("player_id", "")),
			"seat_index": int(member.get("seat_index", -1)),
			"seat_key": str(member.get("seat_key", "")),
			"ready": bool(member.get("ready", false)),
			"is_ai": bool(member.get("is_ai", false)),
			"connected": bool(member.get("connected", true)),
			"ai_takeover": bool(member.get("ai_takeover", false)),
			"is_host": bool(member.get("is_host", false)),
		})
	return {
		"protocol_version": LAN_PROTOCOL.PROTOCOL_VERSION,
		"room_id": room_id,
		"config": room_config.duplicate(true),
		"members": public_members,
		"host_peer_id": host_peer_id,
		"game_started": game_started,
	}


func get_seat_keys() -> Array[String]:
	match int(room_config.get("player_count", 3)):
		2:
			return ["SEAT_SOUTH", "SEAT_NORTH"]
		3:
			return ["SEAT_SOUTH", "SEAT_NORTH", "SEAT_WEST"]
		4:
			return ["SEAT_SOUTH", "SEAT_EAST", "SEAT_NORTH", "SEAT_WEST"]
	return ["SEAT_SOUTH", "SEAT_NORTH", "SEAT_WEST"]


func _make_human_member(
	peer_id: int,
	player_id: String,
	seat_index: int,
	reconnect_token: String,
	is_host: bool,
	client_instance_id: String,
) -> Dictionary:
	return {
		"peer_id": peer_id,
		"player_id": player_id,
		"seat_index": seat_index,
		"seat_key": get_seat_keys()[seat_index],
		"reconnect_token": reconnect_token,
		"ready": false,
		"is_ai": false,
		"connected": true,
		"ai_takeover": false,
		"is_host": is_host,
		"client_instance_id": client_instance_id,
	}


func _generate_reconnect_token() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	return bytes.hex_encode()


func _sort_members() -> void:
	members.sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			return int(left.get("seat_index", -1)) < int(right.get("seat_index", -1))
	)


func _result_ok(
	member: Dictionary,
	reconnected: bool,
	previous_peer_id: int = 0,
) -> Dictionary:
	return {
		"ok": true,
		"seat_index": int(member.get("seat_index", -1)),
		"reconnect_token": str(member.get("reconnect_token", "")),
		"reconnected": reconnected,
		"previous_peer_id": previous_peer_id,
		"room_id": room_id,
	}


func _generate_room_id() -> String:
	return Crypto.new().generate_random_bytes(8).hex_encode()


func _result_error(error_key: StringName) -> Dictionary:
	last_error = error_key
	return {"ok": false, "error": str(error_key)}


func _fail(error_key: StringName) -> bool:
	last_error = error_key
	return false
