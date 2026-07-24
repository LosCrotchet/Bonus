extends Control

const MAIN_MENU_SCENE := preload("res://features/main_menu/main_menu.tscn")
const GAME_SCENE := preload("res://features/game/game_scene.tscn")

@onready var content: Control = %Content

var _current_screen: Control
var _transitioning := false


func _ready() -> void:
	_show_main_menu(false)


func _show_main_menu(animate: bool) -> void:
	var menu := MAIN_MENU_SCENE.instantiate() as Control
	content.add_child(menu)
	_current_screen = menu
	menu.connect("single_player_requested", _on_single_player_requested)
	menu.connect("resume_game_requested", _on_resume_game_requested)
	menu.connect("lan_game_requested", _on_lan_game_requested)
	menu.connect("tutorial_requested", _on_tutorial_requested)
	menu.connect("quit_requested", _on_quit_requested)
	if animate:
		await menu.call("play_enter_transition")


func _on_single_player_requested(
	player_count: int,
	rules: GameRules,
	seed_value: int,
	use_custom_seed: bool,
	seed_text: String,
) -> void:
	await _open_game({
		"player_count": player_count,
		"rules": rules,
		"seed_value": seed_value,
		"use_custom_seed": use_custom_seed,
		"seed_text": seed_text,
	})


func _on_resume_game_requested() -> void:
	var payload := SaveGameService.load_game()
	if payload.is_empty():
		return
	await _open_game({"resume_payload": payload})


func _on_lan_game_requested(snapshot: Dictionary) -> void:
	await _open_game({"network_snapshot": snapshot})


func _on_tutorial_requested() -> void:
	await _open_game({"tutorial": true})


func _open_game(configuration: Dictionary) -> void:
	if _transitioning:
		return
	_transitioning = true
	var menu := _current_screen
	await menu.call("play_exit_transition")
	menu.queue_free()

	var game := GAME_SCENE.instantiate() as Control
	if configuration.has("resume_payload"):
		game.call("configure_resume", configuration["resume_payload"], true)
	elif configuration.has("network_snapshot"):
		game.call("configure_network", configuration["network_snapshot"], true)
	elif bool(configuration.get("tutorial", false)):
		game.call("configure_tutorial", true)
	else:
		game.call(
			"configure",
			int(configuration["player_count"]),
			configuration["rules"] as GameRules,
			true,
			int(configuration["seed_value"]),
			bool(configuration["use_custom_seed"]),
			str(configuration["seed_text"]),
		)
	content.add_child(game)
	_current_screen = game
	game.connect("return_to_menu_requested", _on_return_to_menu_requested)
	await game.call("play_enter_transition")
	_transitioning = false


func _on_return_to_menu_requested() -> void:
	if _transitioning or _current_screen == null:
		return
	_transitioning = true
	await _current_screen.call("play_exit_transition")
	_current_screen.queue_free()
	_current_screen = null
	await _show_main_menu(true)
	_transitioning = false


func _on_quit_requested() -> void:
	await AudioService.shutdown()
	get_tree().quit()
