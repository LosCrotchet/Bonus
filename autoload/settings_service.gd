extends Node

signal game_speed_changed(speed: GameSpeed)
signal display_changed
signal language_changed(locale: String)

enum GameSpeed {
	SLOW,
	MEDIUM,
	FAST,
}

enum WindowMode {
	WINDOWED,
	FULLSCREEN,
}

const SETTINGS_PATH := "user://bonus_settings.cfg"
const DEFAULT_GAME_SPEED := GameSpeed.MEDIUM
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1440, 1080),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]

var game_speed := DEFAULT_GAME_SPEED
var resolution := Vector2i(1280, 720)
var window_mode := WindowMode.WINDOWED
var locale := "zh_CN"


func _ready() -> void:
	_load_settings()
	_apply_language()
	_apply_display.call_deferred()


func set_game_speed(value: GameSpeed) -> void:
	if value == game_speed:
		return
	game_speed = value
	_save_settings()
	game_speed_changed.emit(game_speed)


func set_resolution(value: Vector2i) -> void:
	if value not in RESOLUTIONS or value == resolution:
		return
	resolution = value
	_save_settings()
	_apply_display()
	display_changed.emit()


func set_window_mode(value: WindowMode) -> void:
	if value == window_mode:
		return
	window_mode = value
	_save_settings()
	_apply_display()
	display_changed.emit()


func set_locale(value: String) -> void:
	if value not in ["zh_CN", "en"] or value == locale:
		return
	locale = value
	_save_settings()
	_apply_language()
	language_changed.emit(locale)


func get_ai_think_delay() -> float:
	return [1.15, 0.8, 0.58][game_speed]


func get_dice_step_duration() -> float:
	return [0.09, 0.07, 0.055][game_speed]


func get_ui_animation_duration() -> float:
	return [0.32, 0.24, 0.18][game_speed]


func get_card_travel_duration() -> float:
	return [0.58, 0.42, 0.3][game_speed]


func get_feedback_duration() -> float:
	return [0.9, 0.65, 0.45][game_speed]


func _apply_language() -> void:
	TranslationServer.set_locale(locale)


func _apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if window_mode == WindowMode.FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return

	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(resolution)
	var screen_size := DisplayServer.screen_get_size()
	var available_space := screen_size - resolution
	DisplayServer.window_set_position(
		Vector2i(
			floori(float(available_space.x) / 2.0),
			floori(float(available_space.y) / 2.0),
		)
	)


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	game_speed = clampi(
		config.get_value("gameplay", "speed", DEFAULT_GAME_SPEED),
		GameSpeed.SLOW,
		GameSpeed.FAST,
	) as GameSpeed
	var loaded_resolution := config.get_value("display", "resolution", resolution) as Vector2i
	if loaded_resolution in RESOLUTIONS:
		resolution = loaded_resolution
	window_mode = clampi(
		config.get_value("display", "window_mode", WindowMode.WINDOWED),
		WindowMode.WINDOWED,
		WindowMode.FULLSCREEN,
	) as WindowMode
	var loaded_locale := str(config.get_value("language", "locale", locale))
	if loaded_locale in ["zh_CN", "en"]:
		locale = loaded_locale


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("gameplay", "speed", game_speed)
	config.set_value("display", "resolution", resolution)
	config.set_value("display", "window_mode", window_mode)
	config.set_value("language", "locale", locale)
	config.save(SETTINGS_PATH)
