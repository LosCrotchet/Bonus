extends Node

const LAN_ROOM_STATE = preload("res://multiplayer/lobby/lan_room_state.gd")
const PUBLIC_GAME_SNAPSHOT = preload("res://multiplayer/protocol/public_game_snapshot.gd")


func _ready() -> void:
	_test_lobby_lifecycle()
	_test_reconnection()
	_test_snapshot_privacy()
	print("BONUS_TEST_LAN_ROOM_OK")
	get_tree().quit()


func _test_lobby_lifecycle() -> void:
	var room = LAN_ROOM_STATE.new()
	assert(room.create_room(1, "Host", _config(4), "host-token"))
	assert(not room.can_start())
	var first: Dictionary = room.join_peer(10, "Alice", "alice-token")
	var second: Dictionary = room.join_peer(11, "Bob", "bob-token")
	assert(bool(first.get("ok", false)))
	assert(bool(second.get("ok", false)))
	assert(int(first.get("seat_index", -1)) != int(second.get("seat_index", -1)))
	assert(int(first.get("seat_index", -1)) != 0)
	assert(not bool(room.join_peer(12, "Alice", "other-token").get("ok", true)))
	assert(room.add_ai())
	assert(room.get_free_seat_indices().is_empty())
	assert(room.set_ready(1, true))
	assert(room.set_ready(10, true))
	assert(room.set_ready(11, true))
	assert(room.can_start())
	var ai_member: Dictionary = {}
	for member in room.members:
		if bool(member.get("is_ai", false)):
			ai_member = member
			break
	assert(not ai_member.is_empty())
	assert(not room.remove_member_by_seat(int(ai_member["seat_index"])).is_empty())
	assert(not room.can_start())


func _test_reconnection() -> void:
	var room = LAN_ROOM_STATE.new()
	assert(room.create_room(1, "Host", _config(2), "host-token"))
	var joined: Dictionary = room.join_peer(20, "Alice", "alice-token")
	assert(bool(joined.get("ok", false)))
	room.game_started = true
	var disconnected: Dictionary = room.mark_disconnected(20)
	assert(not disconnected.is_empty())
	assert(bool(disconnected.get("ai_takeover", false)))
	var rejoined: Dictionary = room.join_peer(21, "Alice", "alice-token")
	assert(bool(rejoined.get("ok", false)))
	assert(bool(rejoined.get("reconnected", false)))
	assert(int(rejoined.get("seat_index", -1)) == int(joined.get("seat_index", -2)))
	assert(bool(room.get_member_by_peer(21).get("connected", false)))


func _test_snapshot_privacy() -> void:
	var room = LAN_ROOM_STATE.new()
	assert(room.create_room(1, "Host", _config(3), "host-token"))
	assert(bool(room.join_peer(30, "Alice", "alice-token").get("ok", false)))
	assert(room.add_ai())
	var session := GameSession.new()
	assert(session.start_game(room.get_seat_keys(), 24680, GameRules.new(), "test2468"))
	var room_snapshot: Dictionary = room.to_public_snapshot()
	for recipient in range(3):
		var snapshot: Dictionary = PUBLIC_GAME_SNAPSHOT.build(
			session,
			recipient,
			room_snapshot,
			1,
			30000,
		)
		assert(not PUBLIC_GAME_SNAPSHOT.contains_private_information(snapshot, recipient))
		assert(not snapshot.has("draw_pile"))
		assert(not snapshot.has("rng_state"))
		for player_value in snapshot["players"] as Array:
			var player := player_value as Dictionary
			if int(player["player_index"]) == recipient:
				assert((player["hand"] as Array).size() == 17)
			else:
				assert(not player.has("hand"))


func _config(player_count: int) -> Dictionary:
	return {
		"player_count": player_count,
		"turn_timeout": 30,
		"seed_text": "test2468",
		"use_custom_seed": true,
		"rules": GameRules.new(),
	}
