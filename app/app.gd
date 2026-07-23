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
	menu.connect("quit_requested", _on_quit_requested)
	if animate:
		await menu.call("play_enter_transition")


func _on_single_player_requested(player_count: int, rules: GameRules) -> void:
	if _transitioning:
		return
	_transitioning = true
	var menu := _current_screen
	await menu.call("play_exit_transition")
	menu.queue_free()

	var game := GAME_SCENE.instantiate() as Control
	game.call("configure", player_count, rules, true)
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
