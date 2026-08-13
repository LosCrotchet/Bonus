extends Node

const SFX_ROOT := "res://assets/audio/sfx/"
const MUSIC_ROOT := "res://assets/audio/music/"
const PLAYER_POOL_SIZE := 20
const MUSIC_FADE_DURATION := 0.45
const HOVER_CUE_VOLUME := 0.6
const STANDARD_CUE_VOLUME := 0.75
const MUSIC_DUCK_DB := -12.0

var _cue_streams: Dictionary = {}
var _cue_volume_db: Dictionary = {}
var _cue_cooldowns_ms: Dictionary = {}
var _bonus_streams: Array[AudioStream] = []
var _bonus_player: AudioStreamPlayer
var _bonus_duck_generation := 0
var _players: Array[AudioStreamPlayer] = []
var _music_streams: Dictionary = {}
var _music_players: Array[AudioStreamPlayer] = []
var _music_active_index := 0
var _music_track: StringName = &""
var _music_tween: Tween
var _music_duck_tween: Tween
var _music_duck_db := 0.0
var _music_duck_generation := 0
var _pool_cursor := 0
var _last_played_at_ms: Dictionary = {}


func _ready() -> void:
	_build_stream_catalog()
	_build_player_pool()
	_build_bonus_player()
	_build_music_catalog()
	_build_music_players()
	get_tree().node_added.connect(_on_node_added)
	_bind_existing_button_hovers.call_deferred()


func _exit_tree() -> void:
	stop_all()
	stop_music()
	_players.clear()
	_music_players.clear()
	_cue_streams.clear()
	_bonus_streams.clear()
	_bonus_player = null
	_music_streams.clear()


func play(
	cue: StringName,
	volume_offset_db: float = 0.0,
	pitch_scale: float = 1.0,
) -> void:
	var stream := _cue_streams.get(cue) as AudioStream
	if stream == null or not _can_play(cue):
		return
	_play_stream(
		stream,
		float(_cue_volume_db.get(cue, 0.0)) + volume_offset_db,
		pitch_scale,
	)


func play_delayed(cue: StringName, delay: float, volume_offset_db: float = 0.0) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	play(cue, volume_offset_db)


func play_bonus_step(step: int) -> void:
	if _bonus_streams.is_empty():
		return
	var stream := _bonus_streams[posmod(step, _bonus_streams.size())]
	duck_music(MUSIC_DUCK_DB, 0.16)
	_bonus_duck_generation = _music_duck_generation
	if _bonus_player == null or DisplayServer.get_name() == "headless":
		restore_music(0.05)
		return
	_bonus_player.stop()
	_bonus_player.stream = stream
	_bonus_player.volume_db = linear_to_db(STANDARD_CUE_VOLUME)
	_bonus_player.play()


func has_cue(cue: StringName) -> bool:
	return _cue_streams.has(cue)


func get_bonus_step_count() -> int:
	return _bonus_streams.size()


func stop_all() -> void:
	for player in _players:
		player.stop()
		player.stream = null
	if _bonus_player != null:
		_bonus_player.stop()
		_bonus_player.stream = null
	if is_inside_tree():
		restore_music(0.05)
	else:
		_music_duck_db = 0.0


func shutdown() -> void:
	stop_all()
	stop_music()
	await get_tree().process_frame
	await get_tree().create_timer(0.08).timeout


func play_music(track: StringName, fade_duration: float = MUSIC_FADE_DURATION) -> void:
	var stream := _music_streams.get(track) as AudioStream
	if stream == null or _music_players.is_empty():
		return
	if _music_track == track and _music_players[_music_active_index].playing:
		return
	if _music_tween != null:
		_music_tween.kill()

	var current_player := _music_players[_music_active_index]
	var had_current_track := current_player.playing
	var next_index := _music_active_index
	if had_current_track:
		next_index = 1 - _music_active_index
	var next_player := _music_players[next_index]
	next_player.stop()
	next_player.stream = stream
	next_player.volume_db = -80.0 if had_current_track else _music_duck_db
	next_player.play()
	_music_active_index = next_index
	_music_track = track

	if not had_current_track:
		_music_tween = null
		return
	var duration := maxf(0.05, fade_duration)
	_music_tween = create_tween().set_parallel(true)
	_music_tween.tween_property(next_player, "volume_db", _music_duck_db, duration)
	_music_tween.tween_property(current_player, "volume_db", -80.0, duration)
	_music_tween.chain().tween_callback(_finish_music_crossfade.bind(current_player))


func stop_music() -> void:
	if _music_tween != null:
		_music_tween.kill()
		_music_tween = null
	if _music_duck_tween != null:
		_music_duck_tween.kill()
		_music_duck_tween = null
	_music_duck_db = 0.0
	for player in _music_players:
		player.stop()
		player.stream = null
		player.volume_db = 0.0
	_music_track = &""


func duck_music(target_db: float = MUSIC_DUCK_DB, duration: float = 0.2) -> void:
	_music_duck_generation += 1
	_music_duck_db = minf(0.0, target_db)
	_apply_music_duck(duration)


func restore_music(duration: float = 0.3) -> void:
	if is_zero_approx(_music_duck_db):
		return
	_music_duck_generation += 1
	_music_duck_db = 0.0
	_apply_music_duck(duration)


func _apply_music_duck(duration: float) -> void:
	if _music_duck_tween != null:
		_music_duck_tween.kill()
	_music_duck_tween = create_tween().set_parallel(true)
	for player in _music_players:
		if player.playing:
			_music_duck_tween.tween_property(
				player,
				"volume_db",
				_music_duck_db,
				maxf(0.05, duration),
			)


func has_music(track: StringName) -> bool:
	return _music_streams.has(track)


func _finish_music_crossfade(previous_player: AudioStreamPlayer) -> void:
	previous_player.stop()
	previous_player.stream = null
	previous_player.volume_db = 0.0
	_music_tween = null


func _build_stream_catalog() -> void:
	var tutorial_pop := _randomizer(
		["pop_1.ogg", "pop_2.ogg", "pop_3.ogg", "pop_4.ogg"],
		0.7,
		0.3,
	)
	var card_handling := _randomizer(
		["card_draw_1.ogg", "card_draw_2.ogg", "card_draw_3.ogg"],
		0.8,
		0.35,
	)
	var card_selection := _randomizer(["card_select.ogg"], 0.7, 0.2)
	_cue_streams = {
		&"ui_hover": _randomizer(["new_hover.ogg"], 0.45, 0.18),
		&"tutorial_confirm": tutorial_pop,
		&"tutorial_type": _randomizer(["dot.ogg"], 0.65, 0.35),
		&"ui_confirm": _randomizer(["ui_confirm.ogg"], 0.18),
		&"ui_cancel": _randomizer(["ui_cancel.ogg"], 0.18),
		&"ui_invalid": _randomizer(["ui_invalid.ogg"], 0.12),
		&"ui_fade_in": _randomizer(["ui_fade_in.ogg"], 0.12),
		&"ui_fade_out": _randomizer(["ui_fade_out.ogg"], 0.12),
		&"settings_applied": _randomizer(["settings_applied.ogg"], 0.12),
		&"card_deal": card_handling,
		&"card_draw": card_handling,
		&"card_select": card_selection,
		&"card_deselect": card_selection,
		&"card_hover": _randomizer(["card_hover.ogg"], 0.65, 0.2),
		&"card_play": _randomizer(["card_play.ogg"], 0.55, 0.2),
		&"card_reveal": _randomizer(["card_fan.ogg", "card_fan_2.ogg"], 0.45),
		&"dice_shake": _randomizer(
			["dice_shake_1.ogg", "dice_shake_2.ogg", "dice_shake_3.ogg"],
			0.25,
		),
		&"dice_land": _randomizer(
			["dice_roll_1.ogg", "dice_roll_2.ogg", "dice_roll_3.ogg", "dice_roll_4.ogg"],
			0.3,
		),
		&"turn_change": _randomizer(["turn_change.ogg"], 0.18),
		&"pass": _randomizer(["pass.ogg"], 0.2),
		&"round_start": _randomizer(["round_start.ogg"], 0.12),
		&"game_win": _randomizer(["game_win.ogg"]),
		&"game_lose": _randomizer(["game_lose.ogg"]),
	}
	_cue_volume_db.clear()
	for cue in _cue_streams:
		_cue_volume_db[cue] = linear_to_db(STANDARD_CUE_VOLUME)
	_cue_volume_db[&"ui_hover"] = linear_to_db(HOVER_CUE_VOLUME)
	_cue_cooldowns_ms = {
		&"ui_hover": 45,
		&"tutorial_confirm": 80,
		&"ui_invalid": 120,
		&"card_deal": 24,
		&"card_draw": 30,
		&"card_select": 22,
		&"card_deselect": 22,
		&"card_hover": 35,
		&"card_play": 45,
		&"card_reveal": 80,
		&"turn_change": 80,
		&"pass": 80,
	}
	_bonus_streams.append(_randomizer(["trumpet_cheerful.ogg"], 0.1))


func _build_music_catalog() -> void:
	var tracks := {
		&"menu": "menu_music.mp3",
		&"game": "game_music.mp3",
	}
	for track in tracks:
		var file_name := str(tracks[track])
		var stream := load(MUSIC_ROOT + file_name) as AudioStreamMP3
		if stream == null:
			push_warning("Unable to load music track: %s" % file_name)
			continue
		stream.loop = true
		_music_streams[track] = stream


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


func _build_bonus_player() -> void:
	_bonus_player = AudioStreamPlayer.new()
	_bonus_player.bus = &"SFX"
	_bonus_player.finished.connect(
		func() -> void:
			_bonus_player.stream = null
			if _bonus_duck_generation == _music_duck_generation:
				restore_music()
	)
	add_child(_bonus_player)


func _build_music_players() -> void:
	for _index in range(2):
		var player := AudioStreamPlayer.new()
		player.bus = &"Music"
		add_child(player)
		_music_players.append(player)


func _play_stream(
	stream: AudioStream,
	volume_db: float,
	pitch_scale: float = 1.0,
) -> AudioStreamPlayer:
	if (
		stream == null
		or _players.is_empty()
		or DisplayServer.get_name() == "headless"
	):
		return null
	var player := _find_available_player()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = maxf(0.01, pitch_scale)
	player.play()
	return player


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
		player.pitch_scale = 1.0


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
