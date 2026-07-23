extends Node

signal settings_changed(snapshot: Dictionary)
signal game_speed_changed(speed: GameSpeed)
signal display_changed
signal language_changed(locale: String)
signal audio_changed(master: float, sfx: float, music: float)

enum GameSpeed {
	SLOW,
	MEDIUM,
	FAST,
}

enum WindowMode {
	WINDOWED,
	FULLSCREEN,
}

enum GameplayTiming {
	DEAL_CARD,
	CARD_ENTRY,
	CARD_TRAVEL,
	AI_THINK,
	ACTION_PAUSE,
	BONUS_TRANSITION,
	FEEDBACK,
	DICE_ROLL,
	INDICATOR_MOVE,
}

const SETTINGS_PATH := "user://bonus_settings.cfg"
const DEFAULT_GAME_SPEED := GameSpeed.SLOW
const SPEED_MULTIPLIERS: Array[float] = [1.45, 0.9, 0.5]
const UI_ANIMATION_DURATION := 0.22
const BASE_TIMINGS := {
	GameplayTiming.DEAL_CARD: 0.31,
	GameplayTiming.CARD_ENTRY: 0.38,
	GameplayTiming.CARD_TRAVEL: 0.52,
	GameplayTiming.AI_THINK: 0.66,
	GameplayTiming.ACTION_PAUSE: 0.58,
	GameplayTiming.BONUS_TRANSITION: 0.56,
	GameplayTiming.FEEDBACK: 0.62,
	GameplayTiming.DICE_ROLL: 0.64,
	GameplayTiming.INDICATOR_MOVE: 0.48,
}
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1440, 1080),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]
const LOCALES: Array[String] = ["zh_CN", "en"]

var game_speed := DEFAULT_GAME_SPEED
var resolution := Vector2i(1280, 720)
var window_mode := WindowMode.WINDOWED
var locale := "zh_CN"
var show_status_text := true
var auto_pass := false
var double_click_actions := false
var master_volume := 0.8
var sfx_volume := 0.75
var music_volume := 0.65

var _audio_save_timer: Timer


func _ready() -> void:
	_audio_save_timer = Timer.new()
	_audio_save_timer.one_shot = true
	_audio_save_timer.wait_time = 0.3
	_audio_save_timer.timeout.connect(_save_settings)
	add_child(_audio_save_timer)
	_load_settings()
	_apply_language()
	_apply_audio()
	_apply_display.call_deferred()


func get_snapshot() -> Dictionary:
	return {
		"game_speed": game_speed,
		"resolution": resolution,
		"window_mode": window_mode,
		"locale": locale,
		"show_status_text": show_status_text,
		"auto_pass": auto_pass,
		"double_click_actions": double_click_actions,
		"master_volume": master_volume,
		"sfx_volume": sfx_volume,
		"music_volume": music_volume,
	}


func apply_settings(candidate: Dictionary) -> bool:
	var next_speed := int(candidate.get("game_speed", game_speed))
	var next_resolution := candidate.get("resolution", resolution) as Vector2i
	var next_window_mode := int(candidate.get("window_mode", window_mode))
	var next_locale := str(candidate.get("locale", locale))
	if next_speed < GameSpeed.SLOW or next_speed > GameSpeed.FAST:
		return false
	if next_resolution not in RESOLUTIONS:
		return false
	if next_window_mode < WindowMode.WINDOWED or next_window_mode > WindowMode.FULLSCREEN:
		return false
	if next_locale not in LOCALES:
		return false

	var speed_changed := next_speed != game_speed
	var display_has_changed := (
		next_resolution != resolution or next_window_mode != window_mode
	)
	var locale_has_changed := next_locale != locale
	game_speed = next_speed as GameSpeed
	resolution = next_resolution
	window_mode = next_window_mode as WindowMode
	locale = next_locale
	show_status_text = bool(candidate.get("show_status_text", show_status_text))
	auto_pass = bool(candidate.get("auto_pass", auto_pass))
	double_click_actions = bool(candidate.get("double_click_actions", double_click_actions))
	_save_settings()

	if locale_has_changed:
		_apply_language()
		language_changed.emit(locale)
	if display_has_changed:
		_apply_display.call_deferred()
		display_changed.emit()
	if speed_changed:
		game_speed_changed.emit(game_speed)
	settings_changed.emit(get_snapshot())
	return true


func set_game_speed(value: GameSpeed) -> void:
	var snapshot := get_snapshot()
	snapshot["game_speed"] = value
	apply_settings(snapshot)


func set_resolution(value: Vector2i) -> void:
	var snapshot := get_snapshot()
	snapshot["resolution"] = value
	apply_settings(snapshot)


func set_window_mode(value: WindowMode) -> void:
	var snapshot := get_snapshot()
	snapshot["window_mode"] = value
	apply_settings(snapshot)


func set_locale(value: String) -> void:
	var snapshot := get_snapshot()
	snapshot["locale"] = value
	apply_settings(snapshot)


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply_audio_bus(&"Master", master_volume)
	_emit_audio_change()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_audio_bus(&"SFX", sfx_volume)
	_emit_audio_change()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_audio_bus(&"Music", music_volume)
	_emit_audio_change()


func get_ai_think_delay() -> float:
	return get_gameplay_duration(GameplayTiming.AI_THINK)


func get_dice_step_duration() -> float:
	return get_gameplay_duration(GameplayTiming.DICE_ROLL) / 8.0


func get_ui_animation_duration() -> float:
	return UI_ANIMATION_DURATION


func get_card_travel_duration() -> float:
	return get_gameplay_duration(GameplayTiming.CARD_TRAVEL)


func get_deal_card_duration() -> float:
	return get_gameplay_duration(GameplayTiming.DEAL_CARD)


func get_feedback_duration() -> float:
	return get_gameplay_duration(GameplayTiming.FEEDBACK)


func get_gameplay_duration(timing: GameplayTiming) -> float:
	var base_duration := float(BASE_TIMINGS.get(timing, BASE_TIMINGS[GameplayTiming.ACTION_PAUSE]))
	return base_duration * SPEED_MULTIPLIERS[game_speed]


func _apply_language() -> void:
	TranslationServer.set_locale(locale)


func _apply_audio() -> void:
	_apply_audio_bus(&"Master", master_volume)
	_apply_audio_bus(&"SFX", sfx_volume)
	_apply_audio_bus(&"Music", music_volume)


func _apply_audio_bus(bus_name: StringName, value: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		return
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(value, 0.0001)))


func _emit_audio_change() -> void:
	audio_changed.emit(master_volume, sfx_volume, music_volume)
	if _audio_save_timer != null:
		_audio_save_timer.start()


func _apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var window := get_window()
	if window_mode == WindowMode.FULLSCREEN:
		window.mode = Window.MODE_FULLSCREEN
		return

	window.mode = Window.MODE_WINDOWED
	# Windows reports the old client area during the fullscreen exit frame.
	await get_tree().process_frame
	window.size = resolution
	await get_tree().process_frame
	var screen := DisplayServer.window_get_current_screen()
	var usable_rect := DisplayServer.screen_get_usable_rect(screen)
	var available_space := usable_rect.size - resolution
	var centered_position := usable_rect.position + Vector2i(
		floori(float(available_space.x) / 2.0),
		floori(float(available_space.y) / 2.0),
	)
	DisplayServer.window_set_position(centered_position)


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	game_speed = clampi(
		config.get_value("gameplay", "speed", DEFAULT_GAME_SPEED),
		GameSpeed.SLOW,
		GameSpeed.FAST,
	) as GameSpeed
	show_status_text = bool(config.get_value("gameplay", "show_status_text", true))
	auto_pass = bool(config.get_value("gameplay", "auto_pass", false))
	double_click_actions = bool(config.get_value("gameplay", "double_click_actions", false))
	master_volume = clampf(config.get_value("audio", "master_volume", master_volume), 0.0, 1.0)
	sfx_volume = clampf(config.get_value("audio", "sfx_volume", sfx_volume), 0.0, 1.0)
	music_volume = clampf(config.get_value("audio", "music_volume", music_volume), 0.0, 1.0)
	var loaded_resolution := config.get_value("display", "resolution", resolution) as Vector2i
	if loaded_resolution in RESOLUTIONS:
		resolution = loaded_resolution
	window_mode = clampi(
		config.get_value("display", "window_mode", WindowMode.WINDOWED),
		WindowMode.WINDOWED,
		WindowMode.FULLSCREEN,
	) as WindowMode
	var loaded_locale := str(config.get_value("language", "locale", locale))
	if loaded_locale in LOCALES:
		locale = loaded_locale


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("gameplay", "speed", game_speed)
	config.set_value("gameplay", "show_status_text", show_status_text)
	config.set_value("gameplay", "auto_pass", auto_pass)
	config.set_value("gameplay", "double_click_actions", double_click_actions)
	config.set_value("display", "resolution", resolution)
	config.set_value("display", "window_mode", window_mode)
	config.set_value("language", "locale", locale)
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.save(SETTINGS_PATH)
