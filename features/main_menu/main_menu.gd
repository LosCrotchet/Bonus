class_name MainMenu
extends Control

signal single_player_requested(player_count: int, rules: GameRules)
signal quit_requested

@onready var menu_panel: PanelContainer = %MenuPanel
@onready var single_player_panel: PanelContainer = %SinglePlayerPanel
@onready var settings_side_panel: AppSettingsPanel = %SettingsSidePanel
@onready var player_count_option: OptionButton = %PlayerCountOption
@onready var include_jokers_toggle: CheckButton = %IncludeJokersToggle
@onready var jokers_wild_toggle: CheckButton = %JokersWildToggle
@onready var sequences_include_two_toggle: CheckButton = %SequencesIncludeTwoToggle
@onready var variable_draw_toggle: CheckButton = %VariableDrawToggle
@onready var exit_game_button: Button = %ExitGameButton
@onready var exit_confirmation: HBoxContainer = %ExitConfirmation

var _active_secondary: Control
var _button_tweens: Dictionary = {}
var _transitioning := false


func _ready() -> void:
	%SinglePlayerButton.pressed.connect(_open_single_player)
	%SettingsButton.pressed.connect(_open_settings)
	%StartGameButton.pressed.connect(_start_single_player)
	%SinglePlayerBackButton.pressed.connect(_close_secondary)
	settings_side_panel.applied.connect(_close_secondary)
	settings_side_panel.canceled.connect(_close_secondary)
	exit_game_button.pressed.connect(_show_exit_confirmation)
	%ExitYesButton.pressed.connect(func() -> void: quit_requested.emit())
	%ExitNoButton.pressed.connect(_hide_exit_confirmation)
	_populate_player_counts()
	_reset_single_player_options()
	single_player_panel.visible = false
	settings_side_panel.visible = false
	_hide_exit_confirmation()
	_setup_button_motion()


func play_enter_transition() -> void:
	await get_tree().process_frame
	var target_position := menu_panel.position
	menu_panel.position = target_position + Vector2(-menu_panel.size.x, 0.0)
	menu_panel.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(menu_panel, "position", target_position, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(menu_panel, "modulate:a", 1.0, 0.3)
	await tween.finished


func play_exit_transition() -> void:
	_transitioning = true
	var tween := create_tween().set_parallel(true)
	tween.tween_property(menu_panel, "position", menu_panel.position + Vector2(-menu_panel.size.x, 0.0), 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(menu_panel, "modulate:a", 0.0, 0.25)
	if _active_secondary != null and _active_secondary.visible:
		tween.tween_property(_active_secondary, "position", _active_secondary.position + Vector2(-_active_secondary.size.x, 0.0), 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(_active_secondary, "modulate:a", 0.0, 0.24)
	await tween.finished


func _populate_player_counts() -> void:
	player_count_option.clear()
	for count in range(2, 5):
		player_count_option.add_item(
			tr(&"UI_PLAYER_COUNT_OPTION").format({"count": count}),
			count,
		)
		if count == 3:
			player_count_option.select(player_count_option.item_count - 1)


func _reset_single_player_options() -> void:
	include_jokers_toggle.button_pressed = true
	jokers_wild_toggle.button_pressed = true
	sequences_include_two_toggle.button_pressed = false
	variable_draw_toggle.button_pressed = false


func _open_single_player() -> void:
	_show_secondary(single_player_panel)


func _open_settings() -> void:
	settings_side_panel.begin_edit()
	_show_secondary(settings_side_panel)


func _show_secondary(panel: Control) -> void:
	if _transitioning:
		return
	if _active_secondary != null and _active_secondary != panel:
		_active_secondary.visible = false
	_active_secondary = panel
	panel.visible = true
	var target_position := panel.position
	panel.position = target_position + Vector2(-44.0, 0.0)
	panel.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(panel, "position", target_position, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, 0.22)


func _close_secondary() -> void:
	if _active_secondary == null or not _active_secondary.visible:
		return
	var panel := _active_secondary
	_active_secondary = null
	var tween := create_tween().set_parallel(true)
	tween.tween_property(panel, "position", panel.position + Vector2(-36.0, 0.0), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(panel, "modulate:a", 0.0, 0.18)
	tween.chain().tween_callback(func() -> void: panel.visible = false)


func _start_single_player() -> void:
	if _transitioning:
		return
	var rules := GameRules.new()
	rules.include_jokers = include_jokers_toggle.button_pressed
	rules.jokers_are_wild = jokers_wild_toggle.button_pressed
	rules.allow_two_in_sequences = sequences_include_two_toggle.button_pressed
	rules.draw_count_uses_dice = variable_draw_toggle.button_pressed
	single_player_requested.emit(player_count_option.get_selected_id(), rules)


func _show_exit_confirmation() -> void:
	exit_game_button.visible = false
	exit_confirmation.visible = true


func _hide_exit_confirmation() -> void:
	exit_game_button.visible = true
	exit_confirmation.visible = false


func _setup_button_motion() -> void:
	for button in [
		%SinglePlayerButton,
		%MultiplayerButton,
		%SettingsButton,
		exit_game_button,
		%StartGameButton,
		%SinglePlayerBackButton,
		%ExitYesButton,
		%ExitNoButton,
	]:
		var typed_button := button as Button
		typed_button.mouse_entered.connect(
			func() -> void: _tween_button(typed_button, Vector2(1.025, 1.025))
		)
		typed_button.mouse_exited.connect(
			func() -> void: _tween_button(typed_button, Vector2.ONE)
		)
		typed_button.button_down.connect(
			func() -> void: _tween_button(typed_button, Vector2(0.98, 0.98))
		)
		typed_button.button_up.connect(
			func() -> void: _tween_button(typed_button, Vector2(1.025, 1.025))
		)


func _tween_button(button: Button, target_scale: Vector2) -> void:
	if _button_tweens.has(button):
		(_button_tweens[button] as Tween).kill()
	button.pivot_offset = button.size * 0.5
	var tween := create_tween()
	tween.tween_property(button, "scale", target_scale, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_button_tweens[button] = tween
