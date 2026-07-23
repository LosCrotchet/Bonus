extends Node

const SFX_ROOT := "res://assets/audio/sfx/"
const PLAYER_POOL_SIZE := 20

var _cue_streams: Dictionary = {}
var _cue_volume_db: Dictionary = {}
var _cue_cooldowns_ms: Dictionary = {}
var _bonus_streams: Array[AudioStream] = []
var _players: Array[AudioStreamPlayer] = []
var _pool_cursor := 0
var _last_played_at_ms: Dictionary = {}


func _ready() -> void:
	_build_stream_catalog()
	_build_player_pool()
	get_tree().node_added.connect(_on_node_added)
	_bind_existing_button_hovers.call_deferred()


func _exit_tree() -> void:
	stop_all()
	_players.clear()
	_cue_streams.clear()
	_bonus_streams.clear()


func play(cue: StringName, volume_offset_db: float = 0.0) -> void:
	var stream := _cue_streams.get(cue) as AudioStream
	if stream == null or not _can_play(cue):
		return
	_play_stream(stream, float(_cue_volume_db.get(cue, 0.0)) + volume_offset_db)


func play_delayed(cue: StringName, delay: float, volume_offset_db: float = 0.0) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	play(cue, volume_offset_db)


func play_bonus_step(step: int) -> void:
	if _bonus_streams.is_empty():
		return
	_play_stream(_bonus_streams[posmod(step, _bonus_streams.size())], -1.0)


func has_cue(cue: StringName) -> bool:
	return _cue_streams.has(cue)


func get_bonus_step_count() -> int:
	return _bonus_streams.size()


func stop_all() -> void:
	for player in _players:
		player.stop()
		player.stream = null


func shutdown() -> void:
	stop_all()
	await get_tree().process_frame
	await get_tree().create_timer(0.08).timeout


func _build_stream_catalog() -> void:
	var card_handling := _randomizer(
		["card_draw_1.wav", "card_draw_2.wav", "card_draw_3.wav"],
		0.8,
		0.35,
	)
	_cue_streams = {
		&"ui_hover": _randomizer(
			["pop_1.wav", "pop_2.wav", "pop_3.wav", "pop_4.wav"],
			0.7,
			0.3,
		),
		&"ui_confirm": _randomizer(["ui_confirm.wav"], 0.18),
		&"ui_cancel": _randomizer(["ui_cancel.wav"], 0.18),
		&"ui_invalid": _randomizer(["ui_invalid.wav"], 0.12),
		&"ui_fade_in": _randomizer(["ui_fade_in.wav"], 0.12),
		&"ui_fade_out": _randomizer(["ui_fade_out.wav"], 0.12),
		&"settings_applied": _randomizer(["settings_applied.wav"], 0.12),
		&"card_deal": card_handling,
		&"card_draw": card_handling,
		&"card_play": card_handling,
		&"card_reveal": _randomizer(["card_fan.wav", "card_fan_2.wav"], 0.45),
		&"dice_shake": _randomizer(
			["dice_shake_1.wav", "dice_shake_2.wav", "dice_shake_3.wav"],
			0.25,
		),
		&"dice_land": _randomizer(
			["dice_roll_1.wav", "dice_roll_2.wav", "dice_roll_3.wav", "dice_roll_4.wav"],
			0.3,
		),
		&"turn_change": _randomizer(["turn_change.wav"], 0.18),
		&"pass": _randomizer(["pass.wav"], 0.2),
		&"round_start": _randomizer(["round_start.wav"], 0.12),
		&"game_win": _randomizer(["game_win.wav"]),
		&"game_lose": _randomizer(["game_lose.wav"]),
	}
	_cue_volume_db = {
		&"ui_hover": -8.0,
		&"card_deal": -5.5,
		&"card_draw": -3.5,
		&"card_play": -2.0,
		&"card_reveal": -2.5,
		&"dice_shake": -2.0,
		&"turn_change": -3.0,
		&"pass": -2.0,
	}
	_cue_cooldowns_ms = {
		&"ui_hover": 45,
		&"ui_invalid": 120,
		&"card_deal": 24,
		&"card_draw": 30,
		&"card_play": 45,
		&"card_reveal": 80,
		&"turn_change": 80,
		&"pass": 80,
	}
	for file_name in [
		"match_synth_1.wav",
		"match_synth_2.wav",
		"match_synth_3.wav",
		"match_synth_4.wav",
		"match_synth_5.wav",
		"match_synth_6.wav",
		"match_synth_7.wav",
		"match_synth_8.wav",
		"match_synth_9.wav",
		"match_synth_10_MAX.wav",
	]:
		_bonus_streams.append(_randomizer([file_name], 0.1))


func _randomizer(
	file_names: Array,
	random_pitch_semitones: float = 0.0,
	random_volume_db: float = 0.0,
) -> AudioStreamRandomizer:
	var randomizer := AudioStreamRandomizer.new()
	randomizer.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
	randomizer.random_pitch_semitones = random_pitch_semitones
	randomizer.random_volume_offset_db = random_volume_db
	for file_name_value in file_names:
		var file_name := str(file_name_value)
		var stream := load(SFX_ROOT + file_name) as AudioStream
		if stream != null:
			randomizer.add_stream(-1, stream)
	return randomizer


func _build_player_pool() -> void:
	for _index in range(PLAYER_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		player.finished.connect(_release_player.bind(player))
		add_child(player)
		_players.append(player)


func _play_stream(stream: AudioStream, volume_db: float) -> void:
	if (
		stream == null
		or _players.is_empty()
		or DisplayServer.get_name() == "headless"
	):
		return
	var player := _find_available_player()
	player.stream = stream
	player.volume_db = volume_db
	player.play()


func _find_available_player() -> AudioStreamPlayer:
	for offset in range(_players.size()):
		var index := (_pool_cursor + offset) % _players.size()
		if not _players[index].playing:
			_pool_cursor = (index + 1) % _players.size()
			return _players[index]
	var player := _players[_pool_cursor]
	_pool_cursor = (_pool_cursor + 1) % _players.size()
	player.stop()
	return player


func _release_player(player: AudioStreamPlayer) -> void:
	if is_instance_valid(player) and not player.playing:
		player.stream = null


func _can_play(cue: StringName) -> bool:
	var cooldown := int(_cue_cooldowns_ms.get(cue, 0))
	if cooldown <= 0:
		return true
	var now := Time.get_ticks_msec()
	var previous := int(_last_played_at_ms.get(cue, -cooldown))
	if now - previous < cooldown:
		return false
	_last_played_at_ms[cue] = now
	return true


func _on_node_added(node: Node) -> void:
	if node is Button:
		_bind_button_hover(node as Button)


func _bind_existing_button_hovers() -> void:
	for node in get_tree().root.find_children("*", "Button", true, false):
		_bind_button_hover(node as Button)


func _bind_button_hover(button: Button) -> void:
	if button.has_meta(&"audio_hover_bound"):
		return
	button.set_meta(&"audio_hover_bound", true)
	button.mouse_entered.connect(
		func() -> void:
			if not button.disabled and button.visible:
				play(&"ui_hover")
	)
