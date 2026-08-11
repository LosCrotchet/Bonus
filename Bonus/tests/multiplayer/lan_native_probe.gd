extends Node

const PROBE_PORT := 19077
const PUBLIC_GAME_SNAPSHOT = preload("res://multiplayer/protocol/public_game_snapshot.gd")

var _role := ""
var _started := false
var _last_revision := 0


func _ready() -> void:
	var arguments := OS.get_cmdline_user_args()
	_role = arguments[0] if not arguments.is_empty() else ""
	LanMultiplayerService.lobby_updated.connect(_on_lobby_updated)
	LanMultiplayerService.game_started.connect(_on_game_started)
	LanMultiplayerService.game_snapshot_received.connect(_on_game_snapshot_received)
	LanMultiplayerService.network_error.connect(_on_network_error)
	get_tree().create_timer(10.0).timeout.connect(_on_timeout)
	if _role == "host":
		var config := {
			"player_count": 2,
			"turn_timeout": 15,
			"seed_text": "lanprobe",
			"use_custom_seed": true,
			"rules": GameRules.new(),
		}
		assert(LanMultiplayerService.host_room("ProbeHost", PROBE_PORT, config))
		LanMultiplayerService.set_ready(true)
	elif _role == "client":
		assert(LanMultiplayerService.join_room(
			"ProbeClient",
			"127.0.0.1",
			PROBE_PORT,
		))
	else:
		push_error("LAN probe role missing")
		get_tree().quit(2)


func _on_lobby_updated(_snapshot: Dictionary) -> void:
	if _role == "client":
		var local_member := LanMultiplayerService.get_local_member()
		if not local_member.is_empty() and not bool(local_member.get("ready", false)):
			LanMultiplayerService.set_ready(true)
	elif (
		_role == "host"
		and not _started
		and LanMultiplayerService.can_start_game()
	):
		_started = true
		_start_host_game.call_deferred()


func _start_host_game() -> void:
	assert(LanMultiplayerService.start_game())


func _on_game_started(snapshot: Dictionary) -> void:
	_validate_snapshot(snapshot)
	_last_revision = int(snapshot.get("revision", 0))
	if _role == "host":
		_request_initial_roll.call_deferred()


func _request_initial_roll() -> void:
	LanMultiplayerService.request_roll()


func _on_game_snapshot_received(snapshot: Dictionary) -> void:
	_validate_snapshot(snapshot)
	var revision := int(snapshot.get("revision", 0))
	assert(revision > _last_revision)
	_last_revision = revision
	var action := snapshot.get("public_action", {}) as Dictionary
	var action_type := StringName(str(action.get("type", "")))
	var actor := int(action.get("player_index", -1))
	if revision == 2:
		assert(action_type == &"roll")
		assert(int(snapshot.get("dice_value", 0)) in range(1, 7))
		if _role == "host":
			LanMultiplayerService.request_pass()
	elif revision == 3:
		assert(action_type == &"pass" and actor == 0)
		if _role == "client":
			LanMultiplayerService.request_pass()
	elif revision == 4:
		assert(action_type == &"pass" and actor == 1)
		assert(int(snapshot.get("current_player_index", -1)) == 1)
		assert(int(snapshot.get("phase", -1)) == GameSession.Phase.AWAITING_ROLL)
		print("BONUS_LAN_NATIVE_%s_OK seat=%d revision=%d" % [
			_role.to_upper(),
			int(snapshot.get("local_player_index", -1)),
			revision,
		])
		await get_tree().create_timer(0.3).timeout
		LanMultiplayerService.close_connection()
		get_tree().quit()


func _validate_snapshot(snapshot: Dictionary) -> void:
	var local_index := int(snapshot.get("local_player_index", -1))
	assert(local_index >= 0)
	assert(not PUBLIC_GAME_SNAPSHOT.contains_private_information(snapshot, local_index))
	assert((snapshot.get("players", []) as Array).size() == 2)
	var own_player := (snapshot.get("players", []) as Array)[local_index] as Dictionary
	assert(
		(own_player.get("hand", []) as Array).size()
		== int(own_player.get("hand_count", -1))
	)
	assert(int(own_player.get("hand_count", 0)) > 0)


func _on_network_error(error_key: StringName) -> void:
	push_error("LAN probe error: %s" % error_key)


func _on_timeout() -> void:
	push_error("LAN probe timed out: %s" % _role)
	get_tree().quit(3)
